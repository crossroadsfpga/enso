`include "../constants.sv"
`include "pcie_consts.sv"

module pcie_top (
    // PCIE
    input logic pcie_clk,
    input logic pcie_reset_n,

    input  logic                       pcie_bas_waitrequest,
    output logic [63:0]                pcie_bas_address,
    output logic [63:0]                pcie_bas_byteenable,
    output logic                       pcie_bas_read,
    input  logic [511:0]               pcie_bas_readdata,
    input  logic                       pcie_bas_readdatavalid,
    output logic                       pcie_bas_write,
    output logic [511:0]               pcie_bas_writedata,
    output logic [3:0]                 pcie_bas_burstcount,
    input  logic [1:0]                 pcie_bas_response,
    input  logic [PCIE_ADDR_WIDTH-1:0] pcie_address_0,
    input  logic                       pcie_write_0,
    input  logic                       pcie_read_0,
    output logic                       pcie_readdatavalid_0,
    output logic [511:0]               pcie_readdata_0,
    input  logic [511:0]               pcie_writedata_0,
    input  logic [63:0]                pcie_byteenable_0,

    input  var flit_lite_t           pcie_pkt_buf_wr_data,
    input  logic                     pcie_pkt_buf_wr_en,
    output logic                     pcie_pkt_buf_in_ready,
    output logic [F2C_RB_AWIDTH-1:0] pcie_pkt_buf_occup,
    input  var pkt_dsc_t             pcie_desc_buf_wr_data,
    input  logic                     pcie_desc_buf_wr_en,
    output logic                     pcie_desc_buf_in_ready,
    output logic [F2C_RB_AWIDTH-1:0] pcie_desc_buf_occup,

    output logic                  disable_pcie,
    output logic                  sw_reset,
    output var pdu_metadata_t     pdumeta_cpu_data,
    output logic                  pdumeta_cpu_valid,
    input  logic [9:0]            pdumeta_cnt,
    output logic [31:0]           dma_queue_full_cnt,
    output logic [31:0]           cpu_dsc_buf_full_cnt,
    output logic [31:0]           cpu_pkt_buf_full_cnt,
    output logic [31:0]           pending_prefetch_cnt,

    // status register bus
    input  logic        clk_status,
    input  logic [29:0] status_addr,
    input  logic        status_read,
    input  logic        status_write,
    input  logic [31:0] status_writedata,
    output logic [31:0] status_readdata,
    output logic        status_readdata_valid
);

logic [25:0] dsc_rb_size;
logic [25:0] pkt_rb_size;

// descriptor queue table interface signals
bram_interface_io dsc_q_table_tails();
bram_interface_io dsc_q_table_heads();
bram_interface_io dsc_q_table_l_addrs();
bram_interface_io dsc_q_table_h_addrs();

// packet queue table interface signals
bram_interface_io pkt_q_table_tails();
bram_interface_io pkt_q_table_heads();
bram_interface_io pkt_q_table_l_addrs();
bram_interface_io pkt_q_table_h_addrs();

logic [31:0] control_regs [NB_CONTROL_REGS];

assign disable_pcie = control_regs[0][0];
assign pkt_rb_size = control_regs[0][26:1];

// Use to reset stats from software. Must also be unset from software
assign sw_reset = control_regs[0][27];

assign dsc_rb_size = control_regs[1][25:0];

logic queue_updated;
logic [BRAM_TABLE_IDX_WIDTH-1:0] queue_idx;
logic [BRAM_TABLE_IDX_WIDTH-1:0] updated_queue_idx;
assign queue_idx = pcie_address_0[12 +: BRAM_TABLE_IDX_WIDTH];

logic head_upd;
assign head_upd = pcie_byteenable_0[1*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}};

// Monitor PCIe writes to detect updates to a pkt queue head.
always @(posedge pcie_clk) begin
    queue_updated <= 0;

    // Got a PCIe write to a packet queue head.
    if (pcie_write_0 && queue_idx < MAX_NB_FLOWS && head_upd) begin
        updated_queue_idx <= queue_idx;
        queue_updated <= 1;
    end
end

jtag_mmio_arbiter jtag_mmio_arbiter_inst (
    .pcie_clk              (pcie_clk),
    .jtag_clk              (clk_status),
    .pcie_reset_n          (pcie_reset_n),
    .pcie_address_0        (pcie_address_0),
    .pcie_write_0          (pcie_write_0),
    .pcie_read_0           (pcie_read_0),
    .pcie_readdatavalid_0  (pcie_readdatavalid_0),
    .pcie_readdata_0       (pcie_readdata_0),
    .pcie_writedata_0      (pcie_writedata_0),
    .pcie_byteenable_0     (pcie_byteenable_0),
    .status_addr           (status_addr),
    .status_read           (status_read),
    .status_write          (status_write),
    .status_writedata      (status_writedata),
    .status_readdata       (status_readdata),
    .status_readdata_valid (status_readdata_valid),
    .dsc_q_table_tails     (dsc_q_table_tails.user),
    .dsc_q_table_heads     (dsc_q_table_heads.user),
    .dsc_q_table_l_addrs   (dsc_q_table_l_addrs.user),
    .dsc_q_table_h_addrs   (dsc_q_table_h_addrs.user),
    .pkt_q_table_tails     (pkt_q_table_tails.user),
    .pkt_q_table_heads     (pkt_q_table_heads.user),
    .pkt_q_table_l_addrs   (pkt_q_table_l_addrs.user),
    .pkt_q_table_h_addrs   (pkt_q_table_h_addrs.user),
    .control_regs          (control_regs)
);

fpga2cpu_pcie f2c_inst (
    .clk                    (pcie_clk),
    .rst                    (!pcie_reset_n),
    .pkt_buf_wr_data        (pcie_pkt_buf_wr_data),
    .pkt_buf_wr_en          (pcie_pkt_buf_wr_en),
    .pkt_buf_in_ready       (pcie_pkt_buf_in_ready),
    .pkt_buf_occup          (pcie_pkt_buf_occup),
    .desc_buf_wr_data       (pcie_desc_buf_wr_data),
    .desc_buf_wr_en         (pcie_desc_buf_wr_en),
    .desc_buf_in_ready      (pcie_desc_buf_in_ready),
    .desc_buf_occup         (pcie_desc_buf_occup),
    .dsc_rb_size            ({5'b0, dsc_rb_size}),
    .pkt_rb_size            ({5'b0, pkt_rb_size}),
    .dsc_q_table_tails      (dsc_q_table_tails.owner),
    .dsc_q_table_heads      (dsc_q_table_heads.owner),
    .dsc_q_table_l_addrs    (dsc_q_table_l_addrs.owner),
    .dsc_q_table_h_addrs    (dsc_q_table_h_addrs.owner),
    .pkt_q_table_tails      (pkt_q_table_tails.owner),
    .pkt_q_table_heads      (pkt_q_table_heads.owner),
    .pkt_q_table_l_addrs    (pkt_q_table_l_addrs.owner),
    .pkt_q_table_h_addrs    (pkt_q_table_h_addrs.owner),
    .pcie_bas_waitrequest   (pcie_bas_waitrequest),
    .pcie_bas_address       (pcie_bas_address),
    .pcie_bas_byteenable    (pcie_bas_byteenable),
    .pcie_bas_read          (pcie_bas_read),
    .pcie_bas_readdata      (pcie_bas_readdata),
    .pcie_bas_readdatavalid (pcie_bas_readdatavalid),
    .pcie_bas_write         (pcie_bas_write),
    .pcie_bas_writedata     (pcie_bas_writedata),
    .pcie_bas_burstcount    (pcie_bas_burstcount),
    .pcie_bas_response      (pcie_bas_response),
    .queue_updated          (queue_updated),
    .updated_queue_idx      (updated_queue_idx),
    .sw_reset               (sw_reset),
    .dma_queue_full_cnt     (dma_queue_full_cnt),
    .cpu_dsc_buf_full_cnt   (cpu_dsc_buf_full_cnt),
    .cpu_pkt_buf_full_cnt   (cpu_pkt_buf_full_cnt),
    .pending_prefetch_cnt   (pending_prefetch_cnt)
);

// cpu2fpga_pcie c2f_inst (
//     .clk                    (pcie_clk),
//     .rst                    (!pcie_reset_n),
//     .pdumeta_cpu_data       (pdumeta_cpu_data),
//     .pdumeta_cpu_valid      (pdumeta_cpu_valid),
//     .pdumeta_cnt            (pdumeta_cnt),
//     .head                   (c2f_head[C2F_RB_AWIDTH-1:0]),
//     .tail                   (c2f_tail[C2F_RB_AWIDTH-1:0]),
//     .kmem_addr              (c2f_kmem_addr),
//     .cpu_c2f_head_addr      (c2f_head_addr),
//     .wrdm_prio_ready        (pcie_wrdm_prio_ready),
//     .wrdm_prio_valid        (pcie_wrdm_prio_valid),
//     .wrdm_prio_data         (pcie_wrdm_prio_data),
//     .rddm_desc_ready        (pcie_rddm_desc_ready),
//     .rddm_desc_valid        (pcie_rddm_desc_valid),
//     .rddm_desc_data         (pcie_rddm_desc_data),
//     .c2f_writedata          (pcie_writedata_1),
//     .c2f_write              (pcie_write_1),
//     .c2f_address            (pcie_address_1[14:6])
// );

endmodule
