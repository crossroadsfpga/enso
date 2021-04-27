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
    input logic [25:0] rb_size
);

pkt_meta_with_queues_t out_meta_extra;
queue_state_t out_q_state;

// Consider only the MSBs that we need to index NB_QUEUES, this lets us use the
// LSBs outside the module as an index to the packet queue manager instance.
logic [$clog2(NB_QUEUES)-1:0] local_queue_id;
assign local_queue_id = in_meta_data.pkt_queue_id[
    $bits(in_meta_data.pkt_queue_id)-1 -: $clog2(NB_QUEUES)];

queue_manager #(
    .NB_QUEUES(NB_QUEUES),
    .EXTRA_META_BITS($bits(in_meta_data)),
    .UNIT_POINTER(0)
)
queue_manager_inst (
    .clk             (clk),
    .rst             (rst),
    .in_pass_through (1'b0),
    .in_queue_id     (local_queue_id),
    .in_size         (in_meta_data.size),
    .in_meta_extra   (in_meta_data),
    .in_meta_valid   (in_meta_valid),
    .in_meta_ready   (in_meta_ready),
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

// Bit vector holding the status of every pkt queue
// (i.e., if they need a descriptor or not).
logic [NB_QUEUES-1:0] pkt_q_status;

// update pkt_q_status to indicate if a pkt queue needs a descriptor
always @(posedge clk) begin
    if (out_meta_valid & out_meta_ready) begin
        pkt_q_status[local_queue_id] <= 1'b1;
    end

    if (rst) begin
        pkt_q_status <= 0;
    end else if (queue_updated) begin
        // update queue status so that we send a descriptor next time
        pkt_q_status[updated_queue_idx] <= 1'b0;
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
    end
end

always_comb begin
    out_meta_data = out_meta_extra;
    out_meta_data.pkt_q_state = out_q_state;
    out_meta_data.needs_dsc = !pkt_q_status[local_queue_id];
end

endmodule
