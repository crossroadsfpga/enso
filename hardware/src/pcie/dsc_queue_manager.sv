`include "pcie_consts.sv"

/*
 * This module specializes the generic queue manager to descriptor queues.
 */

module dsc_queue_manager #(
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

    // config signals
    input logic [RB_AWIDTH:0] rb_size,

    // counters
    output logic [31:0] full_cnt
);

pkt_meta_with_queues_t out_meta_extra;
queue_state_t out_q_state;
logic out_drop;

queue_manager #(
    .NB_QUEUES(NB_QUEUES),
    .EXTRA_META_BITS($bits(in_meta_data)),
    .UNIT_POINTER(1)
)
queue_manager_inst (
    .clk             (clk),
    .rst             (rst),
    .in_pass_through (!in_meta_data.needs_dsc),
    .in_queue_id     (in_meta_data.dsc_queue_id),
    .in_size         (in_meta_data.size),
    .in_meta_extra   (in_meta_data),
    .in_meta_valid   (in_meta_valid),
    .in_meta_ready   (in_meta_ready),
    .out_q_state     (out_q_state),
    .out_drop        (out_drop),
    .out_meta_extra  (out_meta_extra),
    .out_meta_valid  (out_meta_valid),
    .out_meta_ready  (out_meta_ready),
    .q_table_tails   (q_table_tails),
    .q_table_heads   (q_table_heads),
    .q_table_l_addrs (q_table_l_addrs),
    .q_table_h_addrs (q_table_h_addrs),
    .rb_size         (rb_size),
    .full_cnt        (full_cnt)
);

always_comb begin
    out_meta_data = out_meta_extra;
    out_meta_data.dsc_q_state = out_q_state;
    // FIXME(sadok): If we drop the packet now, the packet queue would become
    // out of sync, as we have already advanced its pointer. So instead we only
    // prevent the descriptor from being sent. This may be problematic if no
    // descriptor is present for the associated packet queue, as software may
    // never know of this new packet. Right now this can be avoided by sizing
    // the descriptor queue appropriately so that it never becomes full. This is
    // possible to ensure with reactive descriptors -- as we should never have
    // more descriptors than packet queues at any given moment -- but not
    // possible if we send a descriptor per packet. A potential solution is to
    // send a request for an extra descriptor to the packet queue, using the
    // same mechanism that we use when software advances the pointer.
    if (out_drop) begin
        out_meta_data.needs_dsc = 0;
    end
end

endmodule
