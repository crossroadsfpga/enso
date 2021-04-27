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
    input logic [25:0] rb_size
);

pkt_meta_with_queues_t out_meta_extra;
queue_state_t out_q_state;

queue_manager #(
    .NB_QUEUES(NB_QUEUES),
    .EXTRA_META_BITS($bits(in_meta_data)),
    .UNIT_POINTER(1)
)
queue_manager_inst (
    .clk             (clk),
    .rst             (rst),
    .in_pass_through (in_meta_data.needs_dsc),
    .in_queue_id     (in_meta_data.dsc_queue_id),
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

always_comb begin
    out_meta_data = out_meta_extra;
    out_meta_data.dsc_q_state = out_q_state;
end

endmodule
