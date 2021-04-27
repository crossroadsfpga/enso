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
    parameter QUEUE_ID_WIDTH=$clog2(NB_QUEUES)
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
    input logic [25:0] rb_size
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
    
typedef struct packed {
    logic [$clog2(MAX_PKT_SIZE):0] pkt_size; // in number of flits
    logic [EXTRA_META_BITS-1:0]    meta_extra;
} pkt_metadata_t;

internal_queue_state_t last_states [2];
internal_queue_state_t next_states [2];
pkt_metadata_t         next_metadata [2];

// We can only read or write at a given time, when both are issued in the same
// cycle, the write is ignored and must be repeated in the following cycle. We
// use the following signal so that the writer knows if it needs to reissue the
// write.
logic concurrent_rd_wr;
assign concurrent_rd_wr = tail_wr_en & queue_rd_en;

logic pkt_sender_ready;
// If concurrent_rd_wr is set, there is a pending write and we must wait.
assign pkt_sender_ready = !concurrent_rd_wr & out_meta_ready;
assign in_meta_ready = pkt_sender_ready;

// Read fetched queue states and push metadata out
always @(posedge clk) begin
    tail_wr_en <= 0;
    
    // Ensure previous transfer is done before unsetting out_meta_valid
    if (out_meta_ready) begin
        out_meta_valid <= 0;
    end

    if (rst) begin
        // set last states to invalid so we ignore those in the beginning.
        last_states[0].valid <= 0;
        last_states[1].valid <= 0;
        out_meta_valid <= 0;
    end else begin
        if (next_states[0].valid & pkt_sender_ready) begin
            automatic internal_queue_state_t cur_state = next_states[0];

            // The queue tail may be outdated if any of the last two packets
            // were directed to the current queue. Therefore, we save the last
            // two queue states and grab the most up to date tail value if any
            // of those match the current queue.
            if (last_states[1].valid && 
                    last_states[1].queue == cur_state.queue) begin
                cur_state.tail = last_states[1].tail;
            end else if (last_states[0].valid &&
                    last_states[0].queue == cur_state.queue) begin
                cur_state.tail = last_states[0].tail;
            end

            // Advance last states pipeline.
            last_states[0] <= last_states[1];
            last_states[1] <= cur_state;

            // Output metadata.
            out_q_state.tail <= cur_state.tail;
            out_q_state.head <= cur_state.head;
            out_q_state.kmem_addr <= cur_state.addr;
            out_meta_extra <= next_metadata[0].meta_extra;
            out_meta_valid <= 1;

            // write updated tail to BRAM only if not pass through
            if (!in_pass_through) begin
                tail_wr_en <= 1;
            end
            if (UNIT_POINTER) begin
                new_tail <= get_new_pointer(cur_state.tail, 1, rb_size);
            end else begin
                new_tail <= get_new_pointer(cur_state.tail,
                    next_metadata[0].pkt_size, rb_size);
            end
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
pkt_metadata_t delayed_metadata [2];

// State fetcher: Read queue state for next available queue descriptor
always @(posedge clk) begin
    queue_rd_en <= 0;
    delayed_metadata[0] <= delayed_metadata[1];
    rd_queue_r <= rd_queue;

    if (rst) begin
        next_states[0].valid <= 0;
        next_states[1].valid <= 0;
    end else begin
        if (pkt_sender_ready) begin
            // advance pipeline of states
            next_states[0] <= next_states[1];
            next_states[1].valid <= 0;

            next_metadata[0] <= next_metadata[1];

            if (in_meta_valid) begin
                // fetch next state
                rd_queue <= in_queue_id;
                queue_rd_en <= 1;
                delayed_metadata[1].pkt_size <= in_size;
                delayed_metadata[1].meta_extra <= in_meta_extra;
            end
        end

        if (queue_ready) begin
            next_states[1].valid <= 1;
            next_states[1].head <= head;
            next_states[1].tail <= tail;
            next_states[1].addr <= buf_addr;
            next_states[1].queue <= rd_queue_r;

            next_metadata[1] <= delayed_metadata[0];
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
        q_table_a_tails.rd_en = !tail_wr_en 
            || (rd_queue != wr_queue);
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
