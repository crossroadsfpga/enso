`include "pcie_consts.sv"

/*
 * TX descriptor queue manager.
 */

module tx_dsc_queue_manager #(
    parameter NB_QUEUES,
    parameter QUEUE_ID_WIDTH=$clog2(NB_QUEUES)
)(
    input logic clk,
    input logic rst,

    // // input metadata stream
    // input  var pkt_meta_with_queues_t in_meta_data,
    // input  logic                      in_meta_valid,
    // output logic                      in_meta_ready,

    // // output metadata stream
    // output var pkt_meta_with_queues_t out_meta_data,
    // output logic                      out_meta_valid,
    // input  logic                      out_meta_ready,
    
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

assign q_table_a_tails.wr_en = 0;
assign q_table_a_tails.rd_en = 0;
assign q_table_a_heads.wr_en = 0;
assign q_table_a_heads.rd_en = 0;
assign q_table_a_l_addrs.wr_en = 0;
assign q_table_a_l_addrs.rd_en = 0;
assign q_table_a_h_addrs.wr_en = 0;
assign q_table_a_h_addrs.rd_en = 0;

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
