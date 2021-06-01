`include "pcie_consts.sv"

/*
 * This module specializes the generic queue manager to packet queues.
 */

module pkt_queue_manager #(
    parameter NB_QUEUES
)(
    input logic clk,
    input logic rst,

    // input metadata stream
    input  var pkt_meta_with_queues_t in_meta_data,
    input  logic                      in_meta_valid,
    output logic                      in_meta_ready,

    // output metadata stream
    output var pkt_meta_with_queues_t out_meta_data,
    output logic                      out_meta_valid,
    input  logic                      out_meta_ready,

    // BRAM signals for queues
    bram_interface_io.owner q_table_tails,
    bram_interface_io.owner q_table_heads,
    bram_interface_io.owner q_table_l_addrs,
    bram_interface_io.owner q_table_h_addrs,

    // PCIe write signals (used to intercept pointer updates)
    input  logic                            queue_updated,
    input  logic [BRAM_TABLE_IDX_WIDTH-1:0] updated_queue_idx,

    // config signals
    input logic [RB_AWIDTH:0] rb_size
);

pkt_meta_with_queues_t out_meta_extra;
queue_state_t out_q_state;

localparam QUEUE_ID_WIDTH = $clog2(NB_QUEUES);

// Consider only the MSBs that we need to index NB_QUEUES, this lets us use the
// LSBs outside the module as an index to the packet queue manager instance.
function logic [QUEUE_ID_WIDTH-1:0] local_queue_id(
    logic [$bits(in_meta_data.pkt_queue_id)-1:0] queue_id
);
    return queue_id[$bits(in_meta_data.pkt_queue_id)-1 -: QUEUE_ID_WIDTH];
endfunction

pkt_meta_with_queues_t in_queue_data;
logic                  in_queue_valid;
logic                  in_queue_ready;
pkt_meta_with_queues_t out_queue_data;
logic                  out_queue_valid;
logic                  out_queue_ready;

bram_interface_io #(
    .ADDR_WIDTH(QUEUE_ID_WIDTH),
    .DATA_WIDTH(1)
) pkt_q_status_interf_a();
bram_interface_io #(
    .ADDR_WIDTH(QUEUE_ID_WIDTH),
    .DATA_WIDTH(1)
) pkt_q_status_interf_b();

logic [31:0] queue_occup;
logic queue_almost_full;
assign queue_almost_full = queue_occup > 4;
assign in_meta_ready = !queue_almost_full;

pkt_meta_with_queues_t     delayed_metadata [3];
logic                      pkt_q_status_interf_a_rd_en_r [2];

logic [QUEUE_ID_WIDTH-1:0] delayed_queue [3];
logic [QUEUE_ID_WIDTH:0]   last_queues [3]; // Extra bit to represent invalid.

// fetch next pkt queue status
// FIXME(sadok) this will only work if the queue eventually
// receives more packets. Otherwise, there will be some residue
// packets that software will never know about. To fix this, we
// need to check if the latest tail pointer is greater than the
// new head that we received. If it is, that means that we need
// to send an extra descriptor. The logic to send an extra
// descriptor, however, is quite tricky. We probably need to add
// a queue with `descriptor requests` to send to the fpga2cpu so
// that it can send these descriptor when it has a chance -- it
// may even ignore some of them if it receives a new packet for
// the queue. Another tricky part is that there may be some race
// conditions, where this part of the design thinks that the
// queue is updated but the fpga2cpu is processing a new packet
// and will not send a descriptor. To overcome this, fpga2cpu
// should make sure pcie_top has the latest tail, before it
// decides if it needs to send the descriptor.
always @(posedge clk) begin
    pkt_q_status_interf_a.rd_en <= 0;
    pkt_q_status_interf_a.wr_en <= 0;
    pkt_q_status_interf_b.rd_en <= 0;
    pkt_q_status_interf_b.wr_en <= 0;

    pkt_q_status_interf_a_rd_en_r[0] <= pkt_q_status_interf_a_rd_en_r[1];
    pkt_q_status_interf_a_rd_en_r[1] <= pkt_q_status_interf_a.rd_en;
    delayed_metadata[0] <= delayed_metadata[1];
    delayed_metadata[1] <= delayed_metadata[2];
    delayed_queue[0] <= delayed_queue[1];
    delayed_queue[1] <= delayed_queue[2];
    last_queues[2] <= last_queues[1];
    last_queues[1] <= last_queues[0];
    last_queues[0] <= -1;

    in_queue_valid <= 0;

    if (in_meta_ready & in_meta_valid) begin
        // fetch next state
        automatic logic [QUEUE_ID_WIDTH-1:0] local_q;
        local_q = local_queue_id(in_meta_data.pkt_queue_id);
        delayed_metadata[2] <= in_meta_data;
        delayed_queue[2] <= local_q;
        pkt_q_status_interf_a.addr <= local_q;
        pkt_q_status_interf_a.rd_en <= 1;
    end

    if (pkt_q_status_interf_a_rd_en_r[0]) begin
        in_queue_data <= delayed_metadata[0];
        // Packet to the same queue arrived in the last 3 cycles
        if (last_queues[0] == delayed_queue[0]
                || last_queues[1] == delayed_queue[0]
                || last_queues[2] == delayed_queue[0]) begin
            in_queue_data.needs_dsc <= 0;
        end else begin
            in_queue_data.needs_dsc <= !pkt_q_status_interf_a.rd_data;
            if (!pkt_q_status_interf_a.rd_data) begin
                pkt_q_status_interf_b.wr_data <= 1;
                pkt_q_status_interf_b.addr <= delayed_queue[0];
                pkt_q_status_interf_b.wr_en <= 1;
            end
        end
        in_queue_valid <= 1;
    end

    // FIXME(sadok) this may cause extra descriptors to be sent by overriding
    // the write above. We should probably create a queue of these.
    // update pkt_q_status to indicate if a pkt queue needs a descriptor
    if (queue_updated) begin
        pkt_q_status_interf_b.wr_data <= 0;
        pkt_q_status_interf_b.addr <= updated_queue_idx;
        pkt_q_status_interf_b.wr_en <= 1;
    end
end

fifo_wrapper_infill_mlab #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL($bits(pkt_meta_with_queues_t)),
    .FIFO_DEPTH(8)
)
queue (
    .clk           (clk),
    .reset         (rst),
    .csr_address   (2'b0),
    .csr_read      (1'b1),
    .csr_write     (1'b0),
    .csr_readdata  (queue_occup),
    .csr_writedata (32'b0),
    .in_data       (in_queue_data),
    .in_valid      (in_queue_valid),
    .in_ready      (in_queue_ready),
    .out_data      (out_queue_data),
    .out_valid     (out_queue_valid),
    .out_ready     (out_queue_ready)
);

logic [QUEUE_ID_WIDTH-1:0] in_local_queue_id;
assign in_local_queue_id = local_queue_id(out_queue_data.pkt_queue_id);

queue_manager #(
    .NB_QUEUES(NB_QUEUES),
    .EXTRA_META_BITS($bits(out_queue_data)),
    .UNIT_POINTER(0)
)
queue_manager_inst (
    .clk             (clk),
    .rst             (rst),
    .in_pass_through (1'b0),
    .in_queue_id     (in_local_queue_id),
    .in_size         (out_queue_data.size),
    .in_meta_extra   (out_queue_data),
    .in_meta_valid   (out_queue_valid),
    .in_meta_ready   (out_queue_ready),
    .out_q_state     (out_q_state),
    .out_meta_extra  (out_meta_extra),
    .out_meta_valid  (out_meta_valid),
    .out_meta_ready  (out_meta_ready),
    .q_table_tails   (q_table_tails),
    .q_table_heads   (q_table_heads),
    .q_table_l_addrs (q_table_l_addrs),
    .q_table_h_addrs (q_table_h_addrs),
    .rb_size         (rb_size)
);

always_comb begin
    out_meta_data = out_meta_extra;
    out_meta_data.pkt_q_state = out_q_state;
end

logic no_confl_pkt_q_status_interf_a_rd_en;
logic no_confl_pkt_q_status_interf_a_rd_data;
logic pkt_q_status_interf_b_wr_data_r;
logic pkt_q_status_interf_b_wr_data_r2;
logic conflict_rd_wr;
logic conflict_rd_wr_r;
logic conflict_rd_wr_r2;

// handle concurrent read and write to same pkt_q_status_bram address
always_comb begin
    conflict_rd_wr = pkt_q_status_interf_a.rd_en & pkt_q_status_interf_b.wr_en
        & (pkt_q_status_interf_a.addr == pkt_q_status_interf_b.addr);
    if (conflict_rd_wr) begin
        no_confl_pkt_q_status_interf_a_rd_en = 0;
        $display("Conflict!");
    end else begin
        no_confl_pkt_q_status_interf_a_rd_en = pkt_q_status_interf_a.rd_en;
    end
    if (conflict_rd_wr_r2) begin
        pkt_q_status_interf_a.rd_data = pkt_q_status_interf_b_wr_data_r2;
    end else begin
        pkt_q_status_interf_a.rd_data = no_confl_pkt_q_status_interf_a_rd_data;
    end
end

always @(posedge clk) begin
    // save write so we can return it to a concurrent read 2 cycles later
    pkt_q_status_interf_b_wr_data_r <= pkt_q_status_interf_b.wr_data;
    pkt_q_status_interf_b_wr_data_r2 <= pkt_q_status_interf_b_wr_data_r;
    conflict_rd_wr_r <= conflict_rd_wr;
    conflict_rd_wr_r2 <= conflict_rd_wr_r;
end

// Bit vector holding the status of every pkt queue
// (i.e., if they need a descriptor or not).
bram_true2port #(
    .AWIDTH(QUEUE_ID_WIDTH),
    .DWIDTH(1),
    .DEPTH(NB_QUEUES)
)
pkt_q_status_bram (
    .address_a  (pkt_q_status_interf_a.addr),
    .address_b  (pkt_q_status_interf_b.addr),
    .clock      (clk),
    .data_a     (pkt_q_status_interf_a.wr_data),
    .data_b     (pkt_q_status_interf_b.wr_data),
    .rden_a     (no_confl_pkt_q_status_interf_a_rd_en),
    .rden_b     (pkt_q_status_interf_b.rd_en),
    .wren_a     (pkt_q_status_interf_a.wr_en),
    .wren_b     (pkt_q_status_interf_b.wr_en),
    .q_a        (no_confl_pkt_q_status_interf_a_rd_data),
    .q_b        (pkt_q_status_interf_b.rd_data)
);

endmodule
