`include "pcie_consts.sv"

/*
 * This module manages the packet queues. It fetches the appropriate packet
 * queue state and adds it to the packet's metadata. It also advances the
 * queue's pointer. This means that packets cannot be dropped after they go
 * through this module.
 */

module queue_manager #(
    parameter NB_QUEUES,
    parameter EXTRA_META_BITS, // Number fo bits in the extra metadata
    parameter UNIT_POINTER=0, // Set it to 1 to advance pointer by a single unit
    parameter QUEUE_ID_WIDTH=$clog2(NB_QUEUES),
    parameter OUT_FIFO_DEPTH=64,
    parameter ALMOST_FULL_THRESHOLD=OUT_FIFO_DEPTH - MAX_PKT_SIZE * 2
)(
    input logic clk,
    input logic rst,

    // input metadata stream
    input  logic                          in_pass_through,
    input  logic [QUEUE_ID_WIDTH-1:0]     in_queue_id,
    input  logic [$clog2(MAX_PKT_SIZE):0] in_size, // in number of flits
    input  logic [EXTRA_META_BITS-1:0]    in_meta_extra,
    input  logic                          in_meta_valid,
    output logic                          in_meta_ready,

    // output metadata stream
    output var queue_state_t              out_q_state,
    output logic [EXTRA_META_BITS-1:0]    out_meta_extra,
    output logic                          out_meta_valid,
    input  logic                          out_meta_ready,

    // BRAM signals for queues
    bram_interface_io.owner q_table_tails,
    bram_interface_io.owner q_table_heads,
    bram_interface_io.owner q_table_l_addrs,
    bram_interface_io.owner q_table_h_addrs,

    // config signals
    input logic [RB_AWIDTH:0] rb_size
);

// The BRAM port b's are exposed outside the module while port a's are only used
// internally.
bram_interface_io q_table_a_tails();
bram_interface_io q_table_a_heads();
bram_interface_io q_table_a_l_addrs();
bram_interface_io q_table_a_h_addrs();

logic                      queue_ready;
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
} internal_queue_state_t;

typedef struct packed
{
    logic [RB_AWIDTH-1:0]      tail;
    logic                      valid;
    logic [QUEUE_ID_WIDTH-1:0] queue;
} internal_last_queue_state_t;

typedef struct packed {
    logic [$clog2(MAX_PKT_SIZE):0] pkt_size; // in number of flits
    logic [EXTRA_META_BITS-1:0]    meta_extra;
    logic                          pass_through;
} pkt_metadata_t;

internal_last_queue_state_t last_states [2];

logic [31:0] next_state_queue_occup;
logic next_state_queue_almost_full;
assign next_state_queue_almost_full = next_state_queue_occup > 4;

internal_queue_state_t in_next_state_data;
pkt_metadata_t         in_next_metadata_data;
logic                  in_next_state_ready;
logic                  in_next_state_valid;
internal_queue_state_t out_next_state_data;
pkt_metadata_t         out_next_metadata_data;
logic                  out_next_state_ready;
logic                  out_next_state_valid;

queue_state_t               out_queue_q_state;
queue_state_t               out_queue_q_state_r;
queue_state_t               out_queue_q_state_r2;
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

// We can only read or write at a given time, when both are issued in the same
// cycle, the write is ignored and must be repeated in the following cycle. We
// use the following signal so that the writer knows if it needs to reissue the
// write.
logic concurrent_rd_wr;
assign concurrent_rd_wr = tail_wr_en & queue_rd_en;

// If concurrent_rd_wr is set, there is a pending write and we must wait.
assign out_next_state_ready = !out_queue_almost_full & !concurrent_rd_wr;

logic [RB_AWIDTH-1:0] rb_mask;
always @(posedge clk) begin
    rb_mask <= rb_size - 1;
end

// Read fetched queue states and push metadata out
always @(posedge clk) begin
    tail_wr_en <= 0;
    out_queue_meta_valid <= 0;

    out_queue_q_state_r2 <= out_queue_q_state_r;
    out_queue_q_state_r <= out_queue_q_state;
    out_queue_meta_extra_r2 <= out_queue_meta_extra_r;
    out_queue_meta_extra_r <= out_queue_meta_extra;
    out_queue_meta_valid_r2 <= out_queue_meta_valid_r;
    out_queue_meta_valid_r <= out_queue_meta_valid;

    if (rst) begin
        // set last states to invalid so we ignore those in the beginning.
        last_states[0].valid <= 0;
        last_states[1].valid <= 0;
    end else begin
        if (out_next_state_ready & out_next_state_valid) begin
            automatic internal_queue_state_t cur_state = out_next_state_data;

            // The queue tail may be outdated if any of the last two packets
            // were directed to the current queue. Therefore, we save the last
            // two queue states and grab the most up to date tail value if any
            // of those match the current queue.
            // if (last_states[2].valid &&
            //         last_states[2].queue == cur_state.queue) begin
            //     cur_state.tail = last_states[2].tail;
            // end else 
            if (out_queue_meta_valid && last_queue == cur_state.queue) begin
                cur_state.tail = new_tail;
            end else if (last_states[1].valid &&
                    last_states[1].queue == cur_state.queue) begin
                cur_state.tail = last_states[1].tail;
            end else if (last_states[0].valid &&
                    last_states[0].queue == cur_state.queue) begin
                cur_state.tail = last_states[0].tail;
            end

            // Output metadata.
            out_queue_q_state.tail <= cur_state.tail;
            out_queue_q_state.head <= cur_state.head;
            out_queue_q_state.kmem_addr <= cur_state.addr;
            out_queue_meta_extra <= out_next_metadata_data.meta_extra;
            out_queue_meta_valid <= 1;
            last_queue <= cur_state.queue;

            // Increment tail only if not pass through
            if (!out_next_metadata_data.pass_through) begin
                tail_wr_en <= 1;
                if (UNIT_POINTER) begin
                    cur_state.tail = (cur_state.tail + 1) & rb_mask;
                end else begin
                    cur_state.tail = (cur_state.tail 
                        + out_next_metadata_data.pkt_size) & rb_mask;
                end
                new_tail <= cur_state.tail;
                wr_queue <= cur_state.queue;
            end

            // Advance last states pipeline.
            last_states[0] <= last_states[1];
            last_states[1].valid <= 1;
            last_states[1].queue <= cur_state.queue;
            last_states[1].tail <= cur_state.tail;
        end

        // If we write in the same cycle as a read, it will be ignored. We need
        // to try again.
        if (concurrent_rd_wr) begin
            tail_wr_en <= 1;
        end
    end
end

// We use this signal to hold the packet metadata while we are fetching its
// associated state from BRAM.
pkt_metadata_t delayed_metadata [3];

assign in_meta_ready = !next_state_queue_almost_full;

// State fetcher: Read queue state for next available queue descriptor
always @(posedge clk) begin
    queue_rd_en <= 0;
    delayed_metadata[0] <= delayed_metadata[1];
    delayed_metadata[1] <= delayed_metadata[2];
    rd_queue_r2 <= rd_queue_r;
    rd_queue_r <= rd_queue;
    in_next_state_valid <= 0;

    if (rst) begin
    end else begin
        if (in_meta_ready & in_meta_valid) begin
            // fetch next state
            rd_queue <= in_queue_id;
            queue_rd_en <= 1;
            delayed_metadata[2].pkt_size <= in_size;
            delayed_metadata[2].meta_extra <= in_meta_extra;
            delayed_metadata[2].pass_through <= in_pass_through;
        end

        if (queue_ready) begin
            in_next_state_data.valid <= 1;
            in_next_state_data.head <= head;
            in_next_state_data.tail <= tail;
            in_next_state_data.addr <= buf_addr;
            in_next_state_data.queue <= rd_queue_r2;

            in_next_metadata_data <= delayed_metadata[0];
            in_next_state_valid <= 1;
        end
    end
end

fifo_wrapper_infill_mlab #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL($bits(internal_queue_state_t) + $bits(pkt_metadata_t)),
    .FIFO_DEPTH(8)
)
next_state_queue (
    .clk           (clk),
    .reset         (rst),
    .csr_address   (2'b0),
    .csr_read      (1'b1),
    .csr_write     (1'b0),
    .csr_readdata  (next_state_queue_occup),
    .csr_writedata (32'b0),
    .in_data       ({in_next_state_data, in_next_metadata_data}),
    .in_valid      (in_next_state_valid),
    .in_ready      (in_next_state_ready),
    .out_data      ({out_next_state_data, out_next_metadata_data}),
    .out_valid     (out_next_state_valid),
    .out_ready     (out_next_state_ready)
);

fifo_wrapper_infill_mlab #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL($bits(out_q_state) + $bits(out_meta_extra)),
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
    .in_data       ({out_queue_q_state_r2, out_queue_meta_extra_r2}),
    .in_valid      (out_queue_meta_valid_r2),
    .in_ready      (out_queue_meta_ready),
    .out_data      ({out_q_state, out_meta_extra}),
    .out_valid     (out_meta_valid),
    .out_ready     (out_meta_ready)
);

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

    // we used the delayed wr signals for head and tail to use when there are
    // concurrent reads
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
        // when reading and writing the same queue, we avoid reading the tail
        // and use the new written tail instead
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

    queue_ready =
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
        // return the delayed concurrent write
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
