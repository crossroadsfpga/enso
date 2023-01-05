`include "pcie_consts.sv"

/// This module manages generic queues. It fetches the appropriate packet queue
/// state and adds it to the packet's metadata. It also advances the queue's
/// pointer. This means that packets cannot be dropped after they go through
/// this module.
module queue_manager #(
    /// Number of queue in the module.
    parameter NB_QUEUES,

    /// Number of bits in the extra metadata.
    parameter EXTRA_META_BITS,

    /// Set to 1 to advance pointer by a single unit.
    parameter UNIT_POINTER=0,

    /// Queue ID width.
    parameter QUEUE_ID_WIDTH=$clog2(NB_QUEUES),

    /// Depth of the input FIFO.
    parameter IN_FIFO_DEPTH=16,

    /// Depth of the output FIFO.
    parameter OUT_FIFO_DEPTH=16,

    /// Almost full threshold for the output FIFO.
    parameter ALMOST_FULL_THRESHOLD=(OUT_FIFO_DEPTH - 8)
)(
    input logic clk,
    input logic rst,

    /// If set, the packet passes through without changing the queue state
    /// (i.e., we do not advance the queue pointer).
    input  logic                          in_pass_through,

    /// Input metadata stream.
    input  logic [QUEUE_ID_WIDTH-1:0]     in_queue_id,
    input  logic [$clog2(MAX_PKT_SIZE):0] in_size, /// (In number of flits.)
    input  logic [EXTRA_META_BITS-1:0]    in_meta_extra,
    input  logic                          in_meta_valid,
    output logic                          in_meta_ready,

    /// Output metadata stream.
    output var queue_state_t              out_q_state,
    output logic                          out_drop,
    output logic [EXTRA_META_BITS-1:0]    out_meta_extra,
    output logic                          out_meta_valid,
    input  logic                          out_meta_ready,

    /// BRAM signals for queues.
    bram_interface_io.owner q_table_tails,
    bram_interface_io.owner q_table_heads,
    bram_interface_io.owner q_table_l_addrs,
    bram_interface_io.owner q_table_h_addrs,

    /// Config signals.
    input logic [RB_AWIDTH:0] rb_size,

    /// Number of packets dropped because the queue was full.
    output logic [31:0] full_cnt,

    /// Number of input packets.
    output logic [31:0] in_cnt,

    /// Number of output packets.
    output logic [31:0] out_cnt
);

// The BRAM port b's are exposed outside the module while port a's are only used
// internally.
bram_interface_io q_table_a_tails();
bram_interface_io q_table_a_heads();
bram_interface_io q_table_a_l_addrs();
bram_interface_io q_table_a_h_addrs();

logic                      queue_state_rd_ready;
logic [QUEUE_ID_WIDTH-1:0] rd_queue;
logic [QUEUE_ID_WIDTH-1:0] rd_queue_r;
logic [QUEUE_ID_WIDTH-1:0] rd_queue_r2;
logic [QUEUE_ID_WIDTH-1:0] wr_queue;
logic [RB_AWIDTH-1:0]      new_tail;
logic [RB_AWIDTH-1:0]      head;
logic [RB_AWIDTH-1:0]      tail;

logic        tail_wr_en;
logic        queue_rd_en;
logic [63:0] buf_addr;

typedef struct packed
{
    logic [RB_AWIDTH-1:0]      head;
    logic [RB_AWIDTH-1:0]      tail;
    logic [63:0]               addr;
    logic                      valid;
    logic [QUEUE_ID_WIDTH-1:0] queue;
    logic                      queue_full;
    logic [RB_AWIDTH-1:0]      incr_tail;
} internal_queue_state_t;

typedef struct packed
{
    logic                      valid;
    logic [QUEUE_ID_WIDTH-1:0] queue;
    logic [RB_AWIDTH-1:0]      tail;
} internal_last_queue_state_t;

typedef struct packed {
    logic [$clog2(MAX_PKT_SIZE):0] pkt_size; // in number of flits
    logic [EXTRA_META_BITS-1:0]    meta_extra;
    logic                          pass_through;
} pkt_metadata_t;

logic [31:0] in_queue_occup;
pkt_metadata_t in_queue_in_meta;
pkt_metadata_t in_queue_out_meta;

logic [QUEUE_ID_WIDTH-1:0] in_queue_out_queue_id;

logic in_queue_out_valid;
logic in_queue_out_ready;

always_comb begin
    in_queue_in_meta.pkt_size = in_size;
    in_queue_in_meta.meta_extra = in_meta_extra;
    in_queue_in_meta.pass_through = in_pass_through;
end

fifo_wrapper_infill_mlab #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL($bits(pkt_metadata_t) + QUEUE_ID_WIDTH),
    .FIFO_DEPTH(IN_FIFO_DEPTH)
)
in_queue (
    .clk           (clk),
    .reset         (rst),
    .csr_address   (2'b0),
    .csr_read      (1'b1),
    .csr_write     (1'b0),
    .csr_readdata  (in_queue_occup),
    .csr_writedata (32'b0),
    .in_data       ({in_queue_in_meta, in_queue_id}),
    .in_valid      (in_meta_valid),
    .in_ready      (in_meta_ready),
    .out_data      ({in_queue_out_meta, in_queue_out_queue_id}),
    .out_valid     (in_queue_out_valid),
    .out_ready     (in_queue_out_ready)
);

internal_last_queue_state_t last_states [2];

queue_state_t               out_queue_q_state;
queue_state_t               out_queue_q_state_r;
queue_state_t               out_queue_q_state_r2;
logic                       out_queue_drop;
logic                       out_queue_drop_r;
logic                       out_queue_drop_r2;
logic [EXTRA_META_BITS-1:0] out_queue_meta_extra;
logic [EXTRA_META_BITS-1:0] out_queue_meta_extra_r;
logic [EXTRA_META_BITS-1:0] out_queue_meta_extra_r2;
logic                       out_queue_meta_valid;
logic                       out_queue_meta_valid_r;
logic                       out_queue_meta_valid_r2;
logic                       out_queue_meta_ready;

logic [QUEUE_ID_WIDTH-1:0] last_queue;

logic [31:0] out_queue_occup;
logic out_queue_almost_full;
assign out_queue_almost_full = out_queue_occup > ALMOST_FULL_THRESHOLD;

// We use this signal to hold the packet metadata while we are fetching its
// associated state from BRAM.
pkt_metadata_t delayed_metadata [3];
pkt_metadata_t cur_metadata;
assign cur_metadata = delayed_metadata[0];

logic may_write;
assign may_write = queue_state_rd_ready & !cur_metadata.pass_through;

// Can only issue a read when there is no write in a given cycle.
assign in_queue_out_ready = !out_queue_almost_full & !may_write;

logic [RB_AWIDTH-1:0] rb_mask;
always @(posedge clk) begin
    rb_mask <= rb_size - 1;
end

logic queue_full;
logic last_queue_full_0;
logic last_queue_full_1;

logic [RB_AWIDTH-1:0] incr_tail;
logic [RB_AWIDTH-1:0] last_incr_tail_0;
logic [RB_AWIDTH-1:0] last_incr_tail_1;

// Logic to determine if the software ring buffer is full.
always_comb begin
    automatic logic [RB_AWIDTH-1:0] free_slot;
    automatic logic [RB_AWIDTH-1:0] last_free_slot_0;
    automatic logic [RB_AWIDTH-1:0] last_free_slot_1;

    free_slot = (head - tail - 1) & rb_mask;

    // Free slots for last states. These are only correct if the current queue
    // is the same -- which is the only case that we care about.
    last_free_slot_0 = (head - last_states[0].tail - 1) & rb_mask;
    last_free_slot_1 = (head - last_states[1].tail - 1) & rb_mask;

    // Check if there is enough room in the queue and calculate incremented tail
    // for every possibility.
    if (UNIT_POINTER) begin
        queue_full = (free_slot == 0) & !cur_metadata.pass_through;
        last_queue_full_0 = (last_free_slot_0 == 0)
                            & !cur_metadata.pass_through;
        last_queue_full_1 = (last_free_slot_1 == 0)
                            & !cur_metadata.pass_through;

        incr_tail = (tail + 1) & rb_mask;
        last_incr_tail_0 = (last_states[0].tail + 1) & rb_mask;
        last_incr_tail_1 = (last_states[1].tail + 1) & rb_mask;
    end else begin
        // Length occupied in the buffer (in flits). When SKIP_AHEAD is enabled,
        // we use more than the packet size.
        automatic logic [$clog2(MAX_PKT_SIZE):0] size_in_buffer;
        automatic logic [$clog2(MAX_PKT_SIZE):0] size_in_buffer_0;
        automatic logic [$clog2(MAX_PKT_SIZE):0] size_in_buffer_1;
`ifdef SKIP_AHEAD
        size_in_buffer = cur_metadata.pkt_size + tail[4:2];
        size_in_buffer_0 = cur_metadata.pkt_size + last_states[0].tail[4:2];
        size_in_buffer_1 = cur_metadata.pkt_size + last_states[1].tail[4:2];
`else
        size_in_buffer = cur_metadata.pkt_size;
        size_in_buffer_0 = cur_metadata.pkt_size;
        size_in_buffer_1 = cur_metadata.pkt_size;
`endif  // SKIP_AHEAD
        queue_full = (free_slot < size_in_buffer) & !cur_metadata.pass_through;
        last_queue_full_0 =
            (last_free_slot_0 < size_in_buffer_0) & !cur_metadata.pass_through;
        last_queue_full_1 =
            (last_free_slot_1 < size_in_buffer_1)
            & !cur_metadata.pass_through;
        incr_tail = (tail + size_in_buffer) & rb_mask;
        last_incr_tail_0 =
            (last_states[0].tail + size_in_buffer_0) & rb_mask;
        last_incr_tail_1 =
            (last_states[1].tail + size_in_buffer_1) & rb_mask;
    end
end

logic queue_full_r;

// Read fetched queue states and push metadata out.
always @(posedge clk) begin
    tail_wr_en <= 0;
    out_queue_meta_valid <= 0;

    out_queue_q_state_r2 <= out_queue_q_state_r;
    out_queue_q_state_r <= out_queue_q_state;
    out_queue_drop_r2 <= out_queue_drop_r;
    out_queue_drop_r <= out_queue_drop;
    out_queue_meta_extra_r2 <= out_queue_meta_extra_r;
    out_queue_meta_extra_r <= out_queue_meta_extra;
    out_queue_meta_valid_r2 <= out_queue_meta_valid_r;
    out_queue_meta_valid_r <= out_queue_meta_valid;

    queue_rd_en <= 0;
    delayed_metadata[0] <= delayed_metadata[1];
    delayed_metadata[1] <= delayed_metadata[2];
    rd_queue_r2 <= rd_queue_r;
    rd_queue_r <= rd_queue;

    out_queue_drop <= 0;
    last_states[1].valid <= 0;

    if (rst) begin
        // Set last states to invalid so we ignore those in the beginning.
        last_states[0].valid <= 0;
    end else begin
        // A fetched queue state just became ready. We must consume it in this
        // cycle.
        if (queue_state_rd_ready) begin
            automatic internal_queue_state_t cur_state;
            cur_state.head = head;
            cur_state.tail = tail;
            cur_state.addr = buf_addr;
            cur_state.queue = rd_queue_r2;
            cur_state.queue_full = queue_full;
            cur_state.incr_tail = incr_tail;

            // The queue tail may be outdated if any of the last two packets
            // were directed to the current queue. Therefore, we save the last
            // two queue states and grab the most up to date tail value if any
            // of those match the current queue.
            if (last_states[1].valid &
                (last_states[1].queue == cur_state.queue))
            begin
                cur_state.tail = last_states[1].tail;
                cur_state.queue_full = last_queue_full_1;
                cur_state.incr_tail = last_incr_tail_1;
            end else if (last_states[0].valid &
                         (last_states[0].queue == cur_state.queue)) begin
                cur_state.tail = last_states[0].tail;
                cur_state.queue_full = last_queue_full_0;
                cur_state.incr_tail = last_incr_tail_0;
            end

            // Output metadata.
            out_queue_q_state.tail <= cur_state.tail;
            out_queue_q_state.head <= cur_state.head;
            out_queue_q_state.kmem_addr <= cur_state.addr;
            out_queue_meta_extra <= cur_metadata.meta_extra;
            out_queue_meta_valid <= 1;
            last_queue <= cur_state.queue;

            if (cur_state.queue_full || (cur_state.addr == 0)) begin
                // No space left in the host buffer or address not configured.
                // Must drop the packet.
                out_queue_drop <= 1;
            end else begin
                // Increment tail only if not pass through.
                if (!cur_metadata.pass_through) begin
                    tail_wr_en <= 1;
                    cur_state.tail = cur_state.incr_tail;
                end
            end
            new_tail <= cur_state.tail;
            wr_queue <= cur_state.queue;

            queue_full_r <= cur_state.queue_full;

            last_states[1].valid <= 1;
            last_states[1].queue <= cur_state.queue;
            last_states[1].tail <= cur_state.tail;
        end

        // Consume input and issue a queue state read.
        if (in_queue_out_ready & in_queue_out_valid) begin
            // Fetch next state.
            rd_queue <= in_queue_out_queue_id;
            queue_rd_en <= 1;
            delayed_metadata[2] <= in_queue_out_meta;
        end

        // Advance last states pipeline.
        last_states[0] <= last_states[1];
    end
end

logic [31:0] full_cnt_r1;
logic [31:0] full_cnt_r2;

logic queue_state_rd_ready_r;

// Keep track of dropped packets.
always @(posedge clk) begin
    full_cnt_r1 <= full_cnt_r2;
    full_cnt <= full_cnt_r1;

    queue_state_rd_ready_r <= queue_state_rd_ready;

    if (rst) begin
        full_cnt_r2 <= 0;
    end else begin
        if (queue_state_rd_ready_r & queue_full_r) begin
            full_cnt_r2 <= full_cnt_r2 + 1;
        end
    end
end

fifo_wrapper_infill_mlab #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL($bits(out_q_state) + 1 + $bits(out_meta_extra)),
    .FIFO_DEPTH(OUT_FIFO_DEPTH)
)
out_queue (
    .clk           (clk),
    .reset         (rst),
    .csr_address   (2'b0),
    .csr_read      (1'b1),
    .csr_write     (1'b0),
    .csr_readdata  (out_queue_occup),
    .csr_writedata (32'b0),
    .in_data       ({
        out_queue_q_state_r2, out_queue_drop_r2, out_queue_meta_extra_r2}),
    .in_valid      (out_queue_meta_valid_r2),
    .in_ready      (out_queue_meta_ready),
    .out_data      ({out_q_state, out_drop, out_meta_extra}),
    .out_valid     (out_meta_valid),
    .out_ready     (out_meta_ready)
);

always @(posedge clk) begin
    if (rst) begin
        in_cnt <= 0;
        out_cnt <= 0;
    end else begin
        if (in_meta_valid & in_meta_ready) begin
            in_cnt <= in_cnt + 1;
        end
        if (out_queue_meta_valid_r2 & out_queue_meta_ready) begin
            out_cnt <= out_cnt + 1;
        end
    end
end

logic q_table_a_tails_rd_en_r;
logic q_table_a_tails_rd_en_r2;
logic q_table_a_heads_rd_en_r;
logic q_table_a_heads_rd_en_r2;
logic q_table_a_l_addrs_rd_en_r;
logic q_table_a_l_addrs_rd_en_r2;
logic q_table_a_h_addrs_rd_en_r;
logic q_table_a_h_addrs_rd_en_r2;

logic [RB_AWIDTH-1:0] q_table_heads_wr_data_b_r;
logic [RB_AWIDTH-1:0] q_table_heads_wr_data_b_r2;
logic [RB_AWIDTH-1:0] q_table_tails_wr_data_a_r;
logic [RB_AWIDTH-1:0] q_table_tails_wr_data_a_r2;

always @(posedge clk) begin
    q_table_a_tails_rd_en_r <= q_table_a_tails.rd_en;
    q_table_a_tails_rd_en_r2 <= q_table_a_tails_rd_en_r;
    q_table_a_heads_rd_en_r <= q_table_a_heads.rd_en;
    q_table_a_heads_rd_en_r2 <= q_table_a_heads_rd_en_r;
    q_table_a_l_addrs_rd_en_r <= q_table_a_l_addrs.rd_en;
    q_table_a_l_addrs_rd_en_r2 <= q_table_a_l_addrs_rd_en_r;
    q_table_a_h_addrs_rd_en_r <= q_table_a_h_addrs.rd_en;
    q_table_a_h_addrs_rd_en_r2 <= q_table_a_h_addrs_rd_en_r;

    // We used the delayed wr signals for head and tail to use when there are
    // concurrent reads.
    q_table_heads_wr_data_b_r <= q_table_heads.wr_data[RB_AWIDTH-1:0];
    q_table_heads_wr_data_b_r2 <= q_table_heads_wr_data_b_r;
    q_table_tails_wr_data_a_r <= q_table_a_tails.wr_data[RB_AWIDTH-1:0];
    q_table_tails_wr_data_a_r2 <= q_table_tails_wr_data_a_r;
end

always_comb begin
    q_table_a_tails.addr = rd_queue;
    q_table_a_heads.addr = rd_queue;
    q_table_a_l_addrs.addr = rd_queue;
    q_table_a_h_addrs.addr = rd_queue;

    q_table_a_tails.rd_en = 0;
    q_table_a_heads.rd_en = 0;
    q_table_a_l_addrs.rd_en = 0;
    q_table_a_h_addrs.rd_en = 0;

    q_table_a_tails.wr_en = 0;
    q_table_a_heads.wr_en = 0;
    q_table_a_l_addrs.wr_en = 0;
    q_table_a_h_addrs.wr_en = 0;

    q_table_a_tails.wr_data = new_tail;

    if (queue_rd_en) begin
        // When reading and writing the same queue, we avoid reading the tail
        // and use the new written tail instead.
        q_table_a_tails.rd_en = !tail_wr_en || (rd_queue != wr_queue);
        q_table_a_heads.rd_en = 1;
        q_table_a_l_addrs.rd_en = 1;
        q_table_a_h_addrs.rd_en = 1;

        // Concurrent head write from PCIe or JTAG, we bypass the read and use
        // the new written value instead. This is done to prevent concurrent
        // read and write to the same address, which causes undefined behavior.
        if ((q_table_a_heads.addr == q_table_heads.addr)
                && q_table_heads.wr_en) begin
            q_table_a_heads.rd_en = 0;
        end
    end else if (tail_wr_en) begin
        q_table_a_tails.wr_en = 1;
        q_table_a_tails.addr = wr_queue;
    end

    queue_state_rd_ready =
        q_table_a_tails_rd_en_r2   || q_table_a_heads_rd_en_r2   ||
        q_table_a_l_addrs_rd_en_r2 || q_table_a_h_addrs_rd_en_r2;

    if (q_table_a_tails_rd_en_r2) begin
        tail = q_table_a_tails.rd_data[RB_AWIDTH-1:0];
    end else begin
        tail = q_table_tails_wr_data_a_r2;
    end

    if (q_table_a_heads_rd_en_r2) begin
        head = q_table_a_heads.rd_data[RB_AWIDTH-1:0];
    end else begin
        // Return the delayed concurrent write.
        head = q_table_heads_wr_data_b_r2;
    end

    buf_addr[31:0] = q_table_a_l_addrs.rd_data;
    buf_addr[63:32] = q_table_a_h_addrs.rd_data;
end

/////////////////
// Queue BRAMs //
/////////////////

bram_true2port #(
    .AWIDTH(QUEUE_ID_WIDTH),
    .DWIDTH(PKT_Q_TABLE_TAILS_DWIDTH),
    .DEPTH(NB_QUEUES)
)
q_table_tails_bram (
    .address_a  (q_table_a_tails.addr[QUEUE_ID_WIDTH-1:0]),
    .address_b  (q_table_tails.addr[QUEUE_ID_WIDTH-1:0]),
    .clock      (clk),
    .data_a     (q_table_a_tails.wr_data),
    .data_b     (q_table_tails.wr_data),
    .rden_a     (q_table_a_tails.rd_en),
    .rden_b     (q_table_tails.rd_en),
    .wren_a     (q_table_a_tails.wr_en),
    .wren_b     (q_table_tails.wr_en),
    .q_a        (q_table_a_tails.rd_data),
    .q_b        (q_table_tails.rd_data)
);

bram_true2port #(
    .AWIDTH(QUEUE_ID_WIDTH),
    .DWIDTH(PKT_Q_TABLE_HEADS_DWIDTH),
    .DEPTH(NB_QUEUES)
)
q_table_heads_bram (
    .address_a  (q_table_a_heads.addr[QUEUE_ID_WIDTH-1:0]),
    .address_b  (q_table_heads.addr[QUEUE_ID_WIDTH-1:0]),
    .clock      (clk),
    .data_a     (q_table_a_heads.wr_data),
    .data_b     (q_table_heads.wr_data),
    .rden_a     (q_table_a_heads.rd_en),
    .rden_b     (q_table_heads.rd_en),
    .wren_a     (q_table_a_heads.wr_en),
    .wren_b     (q_table_heads.wr_en),
    .q_a        (q_table_a_heads.rd_data),
    .q_b        (q_table_heads.rd_data)
);

bram_true2port #(
    .AWIDTH(QUEUE_ID_WIDTH),
    .DWIDTH(PKT_Q_TABLE_L_ADDRS_DWIDTH),
    .DEPTH(NB_QUEUES)
)
q_table_l_addrs_bram (
    .address_a  (q_table_a_l_addrs.addr[QUEUE_ID_WIDTH-1:0]),
    .address_b  (q_table_l_addrs.addr[QUEUE_ID_WIDTH-1:0]),
    .clock      (clk),
    .data_a     (q_table_a_l_addrs.wr_data),
    .data_b     (q_table_l_addrs.wr_data),
    .rden_a     (q_table_a_l_addrs.rd_en),
    .rden_b     (q_table_l_addrs.rd_en),
    .wren_a     (q_table_a_l_addrs.wr_en),
    .wren_b     (q_table_l_addrs.wr_en),
    .q_a        (q_table_a_l_addrs.rd_data),
    .q_b        (q_table_l_addrs.rd_data)
);

bram_true2port #(
    .AWIDTH(QUEUE_ID_WIDTH),
    .DWIDTH(PKT_Q_TABLE_H_ADDRS_DWIDTH),
    .DEPTH(NB_QUEUES)
)
q_table_h_addrs_bram (
    .address_a  (q_table_a_h_addrs.addr[QUEUE_ID_WIDTH-1:0]),
    .address_b  (q_table_h_addrs.addr[QUEUE_ID_WIDTH-1:0]),
    .clock      (clk),
    .data_a     (q_table_a_h_addrs.wr_data),
    .data_b     (q_table_h_addrs.wr_data),
    .rden_a     (q_table_a_h_addrs.rd_en),
    .rden_b     (q_table_h_addrs.rd_en),
    .wren_a     (q_table_a_h_addrs.wr_en),
    .wren_b     (q_table_h_addrs.wr_en),
    .q_a        (q_table_a_h_addrs.rd_data),
    .q_b        (q_table_h_addrs.rd_data)
);

// unused inputs
assign q_table_a_heads.wr_data = 32'bx;
assign q_table_a_l_addrs.wr_data = 32'bx;
assign q_table_a_h_addrs.wr_data = 32'bx;

endmodule
