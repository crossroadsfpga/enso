`include "pcie_consts.sv"

module pcie_top (
    // PCIE
    input logic pcie_clk,
    input logic pcie_reset_n,

    input  logic         pcie_wrdm_desc_ready,
    output logic         pcie_wrdm_desc_valid,
    output logic [173:0] pcie_wrdm_desc_data,
    input  logic         pcie_wrdm_prio_ready,
    output logic         pcie_wrdm_prio_valid,
    output logic [173:0] pcie_wrdm_prio_data,
    input  logic         pcie_wrdm_tx_valid,
    input  logic [31:0]  pcie_wrdm_tx_data,
    
    input  logic         pcie_rddm_desc_ready,
    output logic         pcie_rddm_desc_valid,
    output logic [173:0] pcie_rddm_desc_data,
    input  logic         pcie_rddm_prio_ready,
    output logic         pcie_rddm_prio_valid,
    output logic [173:0] pcie_rddm_prio_data,
    input  logic         pcie_rddm_tx_valid,
    input  logic [31:0]  pcie_rddm_tx_data,

    input  logic         pcie_bas_waitrequest,
    output logic [63:0]  pcie_bas_address,
    output logic [63:0]  pcie_bas_byteenable,
    output logic         pcie_bas_read,
    input  logic [511:0] pcie_bas_readdata,
    input  logic         pcie_bas_readdatavalid,
    output logic         pcie_bas_write,
    output logic [511:0] pcie_bas_writedata,
    output logic [3:0]   pcie_bas_burstcount,
    input  logic [1:0]   pcie_bas_response,

    input  logic [PCIE_ADDR_WIDTH-1:0] pcie_address_0,
    input  logic                       pcie_write_0,
    input  logic                       pcie_read_0,
    output logic                       pcie_readdatavalid_0,
    output logic [511:0]               pcie_readdata_0,
    input  logic [511:0]               pcie_writedata_0,
    input  logic [63:0]                pcie_byteenable_0,

    input  logic [PCIE_ADDR_WIDTH-1:0] pcie_address_1,
    input  logic                       pcie_write_1,
    input  logic                       pcie_read_1,
    output logic                       pcie_readdatavalid_1,
    output logic [511:0]               pcie_readdata_1,
    input  logic [511:0]               pcie_writedata_1,
    input  logic [63:0]                pcie_byteenable_1,

    input  var flit_lite_t         pcie_pkt_buf_data,
    input  logic                   pcie_pkt_buf_valid,
    output logic                   pcie_pkt_buf_ready,
    output logic [F2C_RB_AWIDTH:0] pcie_pkt_buf_occup,
    input  var pkt_meta_t          pcie_meta_buf_data,
    input  logic                   pcie_meta_buf_valid,
    output logic                   pcie_meta_buf_ready,
    output logic [F2C_RB_AWIDTH:0] pcie_meta_buf_occup,

    output logic                  disable_pcie,
    output logic                  sw_reset,
    output var pdu_metadata_t     pdumeta_cpu_data,
    output logic                  pdumeta_cpu_valid,
    input  logic [9:0]            pdumeta_cnt,
    output logic [31:0]           dma_queue_full_cnt,
    output logic [31:0]           cpu_dsc_buf_full_cnt,
    output logic [31:0]           cpu_pkt_buf_full_cnt,

    // status register bus
    input  logic        clk_status,
    input  logic [29:0] status_addr,
    input  logic        status_read,
    input  logic        status_write,
    input  logic [31:0] status_writedata,
    output logic [31:0] status_readdata,
    output logic        status_readdata_valid
);

logic [RB_AWIDTH:0] dsc_rb_size;
logic [RB_AWIDTH:0] pkt_rb_size;

// descriptor queue table interface signals
bram_interface_io dsc_q_table_tails();
bram_interface_io dsc_q_table_heads();
bram_interface_io dsc_q_table_l_addrs();
bram_interface_io dsc_q_table_h_addrs();

// packet queue table interface signals (used by the JTAG MMIO arbiter)
bram_interface_io pkt_q_table_tails();
bram_interface_io pkt_q_table_heads();
bram_interface_io pkt_q_table_l_addrs();
bram_interface_io pkt_q_table_h_addrs();

// packet queue table interface signals (used by the packet queue managers)
bram_interface_io #(
    .ADDR_WIDTH(BRAM_TABLE_IDX_WIDTH - PKT_QM_ID_WIDTH)
) pqm_pkt_q_table_tails[NB_PKT_QUEUE_MANAGERS]();
bram_interface_io #(
    .ADDR_WIDTH(BRAM_TABLE_IDX_WIDTH - PKT_QM_ID_WIDTH)
) pqm_pkt_q_table_heads[NB_PKT_QUEUE_MANAGERS]();
bram_interface_io #(
    .ADDR_WIDTH(BRAM_TABLE_IDX_WIDTH - PKT_QM_ID_WIDTH)
) pqm_pkt_q_table_l_addrs[NB_PKT_QUEUE_MANAGERS]();
bram_interface_io #(
    .ADDR_WIDTH(BRAM_TABLE_IDX_WIDTH - PKT_QM_ID_WIDTH)
) pqm_pkt_q_table_h_addrs[NB_PKT_QUEUE_MANAGERS]();

bram_mux #( .NB_BRAMS(NB_PKT_QUEUE_MANAGERS) ) pkt_q_table_tails_mux (
    .clk (pcie_clk),
    .in  (pkt_q_table_tails),
    .out (pqm_pkt_q_table_tails)
);

bram_mux #( .NB_BRAMS(NB_PKT_QUEUE_MANAGERS) ) pkt_q_table_heads_mux (
    .clk (pcie_clk),
    .in  (pkt_q_table_heads),
    .out (pqm_pkt_q_table_heads)
);

bram_mux #( .NB_BRAMS(NB_PKT_QUEUE_MANAGERS) ) pkt_q_table_l_addrs_mux (
    .clk (pcie_clk),
    .in  (pkt_q_table_l_addrs),
    .out (pqm_pkt_q_table_l_addrs)
);

bram_mux #( .NB_BRAMS(NB_PKT_QUEUE_MANAGERS) ) pkt_q_table_h_addrs_mux (
    .clk (pcie_clk),
    .in  (pkt_q_table_h_addrs),
    .out (pqm_pkt_q_table_h_addrs)
);

logic [31:0] control_regs [NB_CONTROL_REGS];

assign disable_pcie = control_regs[0][0];
assign pkt_rb_size = control_regs[0][1 +: RB_AWIDTH+1];

// Use to reset stats from software. Must also be unset from software
assign sw_reset = control_regs[0][27];

assign dsc_rb_size = control_regs[1][0 +: RB_AWIDTH+1];

logic queue_updated [NB_PKT_QUEUE_MANAGERS];
logic [BRAM_TABLE_IDX_WIDTH-1:0] queue_idx;
logic [BRAM_TABLE_IDX_WIDTH-1:0] updated_queue_idx [NB_PKT_QUEUE_MANAGERS];
assign queue_idx = pcie_address_0[12 +: BRAM_TABLE_IDX_WIDTH];

logic head_upd;
assign head_upd = pcie_byteenable_0[1*REG_SIZE +: REG_SIZE] == {REG_SIZE{1'b1}};

// use to default ranges to a single bit when using a single pkt queue manager.
localparam NON_NEG_PKT_QM_MSB = PKT_QM_ID_WIDTH ? PKT_QM_ID_WIDTH - 1 : 0;

// Monitor PCIe writes to detect updates to a pkt queue head.
always @(posedge pcie_clk) begin
    for (integer i = 0; i < NB_PKT_QUEUE_MANAGERS; ++i) begin
        queue_updated[i] <= 0;
    end

    // Got a PCIe write to a packet queue head.
    if (pcie_write_0 && (queue_idx < MAX_NB_FLOWS) && head_upd) begin
        automatic logic [NON_NEG_PKT_QM_MSB:0] pkt_qm_id;

        // Use packet queue index's LSBs to choose the queue manager.
        if (PKT_QM_ID_WIDTH > 0) begin
            pkt_qm_id = queue_idx[NON_NEG_PKT_QM_MSB:0];
        end else begin
            pkt_qm_id = 0;
        end

        updated_queue_idx[pkt_qm_id] <=
            queue_idx[BRAM_TABLE_IDX_WIDTH-1:PKT_QM_ID_WIDTH];
        queue_updated[pkt_qm_id] <= 1;
    end
end

jtag_mmio_arbiter #(
    .PKT_QUEUE_RD_DELAY(4)  // 2 cycle BRAM read + 2 cycle bram mux read.
)
jtag_mmio_arbiter_inst (
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

// TODO move packet buffer here.
// // Input packet buffer.
// fifo_wrapper_infill #(
//     .SYMBOLS_PER_BEAT(1),
//     .BITS_PER_SYMBOL($bits(flit_lite_t)),
//     .FIFO_DEPTH(F2C_RB_DEPTH)
// )
// pkt_buf (
//     .clk           (clk),
//     .reset         (rst),
//     .csr_address   (2'b0),
//     .csr_read      (1'b1),
//     .csr_write     (1'b0),
//     .csr_readdata  (pkt_buf_csr_readdata),
//     .csr_writedata (32'b0),
//     .in_data       (pkt_buf_in_data),
//     .in_valid      (pkt_buf_in_valid),
//     .in_ready      (pkt_buf_in_ready),
//     .out_data      (pkt_buf_out_data),
//     .out_valid     (pkt_buf_out_valid),
//     .out_ready     (pkt_buf_out_ready)
// );

// assign pcie_pkt_buf_occup = pkt_buf_csr_readdata[F2C_RB_AWIDTH:0];

// // Input metadata buffer. This was sized considering the worst case -- where all
// // packets are min-sized. We may use a smaller buffer here to save BRAM.
// fifo_wrapper_infill #(
//     .SYMBOLS_PER_BEAT(1),
//     .BITS_PER_SYMBOL($bits(pkt_meta_with_queues_t)),
//     .FIFO_DEPTH(F2C_RB_DEPTH)
// )
// metadata_buf (
//     .clk           (clk),
//     .reset         (rst),
//     .csr_address   (2'b0),
//     .csr_read      (1'b1),
//     .csr_write     (1'b0),
//     .csr_readdata  (metadata_buf_csr_readdata),
//     .csr_writedata (32'b0),
//     .in_data       (metadata_buf_in_data),
//     .in_valid      (metadata_buf_in_valid),
//     .in_ready      (metadata_buf_in_ready),
//     .out_data      (metadata_buf_out_data),
//     .out_valid     (metadata_buf_out_valid),
//     .out_ready     (metadata_buf_out_ready | !metadata_buf_out_valid_r)
// );

pkt_meta_with_queues_t pkt_q_mngr_in_meta_data   [NB_PKT_QUEUE_MANAGERS];
pkt_meta_with_queues_t pkt_q_mngr_out_meta_data  [NB_PKT_QUEUE_MANAGERS];
logic                  pkt_q_mngr_in_meta_valid  [NB_PKT_QUEUE_MANAGERS];
logic                  pkt_q_mngr_out_meta_valid [NB_PKT_QUEUE_MANAGERS];
logic                  pkt_q_mngr_in_meta_ready  [NB_PKT_QUEUE_MANAGERS];
logic                  pkt_q_mngr_out_meta_ready [NB_PKT_QUEUE_MANAGERS];

logic [31:0] pkt_full_counters [NB_PKT_QUEUE_MANAGERS];
logic [31:0] cpu_pkt_buf_full_cnt_r;

logic st_mux_ord_ready;

logic [NON_NEG_PKT_QM_MSB:0] pkt_q_mngr_id;
assign pkt_q_mngr_id = !pcie_meta_buf_valid 
                       | pcie_meta_buf_data.pkt_queue_id[NON_NEG_PKT_QM_MSB:0];

always_comb begin
    pcie_meta_buf_ready = 1;
    cpu_pkt_buf_full_cnt_r = 0;
    for (integer i = 0; i < NB_PKT_QUEUE_MANAGERS; i++) begin
        pkt_q_mngr_in_meta_data[i].dsc_queue_id = 
            pcie_meta_buf_data.dsc_queue_id;
        pkt_q_mngr_in_meta_data[i].pkt_queue_id = 
            pcie_meta_buf_data.pkt_queue_id;
        pkt_q_mngr_in_meta_data[i].size = pcie_meta_buf_data.size;

        pcie_meta_buf_ready &= 
            pkt_q_mngr_in_meta_ready[i] & st_mux_ord_ready;

        pkt_q_mngr_in_meta_valid[i] = pcie_meta_buf_valid & pcie_meta_buf_ready;
        if (PKT_QM_ID_WIDTH > 0) begin
            pkt_q_mngr_in_meta_valid[i] &= (pcie_meta_buf_data.pkt_queue_id[
                NON_NEG_PKT_QM_MSB:0] == i);
        end

        cpu_pkt_buf_full_cnt_r += pkt_full_counters[i];
    end
end

always @(posedge pcie_clk) begin
    cpu_pkt_buf_full_cnt <= cpu_pkt_buf_full_cnt_r;
end

pkt_queue_manager #(
    .NB_QUEUES(MAX_NB_FLOWS/NB_PKT_QUEUE_MANAGERS)
)
pkt_queue_manager_inst [NB_PKT_QUEUE_MANAGERS] (
    .clk               (pcie_clk),
    .rst               (!pcie_reset_n),
    .in_meta_data      (pkt_q_mngr_in_meta_data),
    .in_meta_valid     (pkt_q_mngr_in_meta_valid),
    .in_meta_ready     (pkt_q_mngr_in_meta_ready),
    .out_meta_data     (pkt_q_mngr_out_meta_data),
    .out_meta_valid    (pkt_q_mngr_out_meta_valid),
    .out_meta_ready    (pkt_q_mngr_out_meta_ready),
    .q_table_tails     (pqm_pkt_q_table_tails),
    .q_table_heads     (pqm_pkt_q_table_heads),
    .q_table_l_addrs   (pqm_pkt_q_table_l_addrs),
    .q_table_h_addrs   (pqm_pkt_q_table_h_addrs),
    .queue_updated     (queue_updated),
    .updated_queue_idx (updated_queue_idx),
    .rb_size           (pkt_rb_size),
    .full_cnt          (pkt_full_counters)
);

pkt_meta_with_queues_t dsc_q_mngr_in_meta_data;
logic dsc_q_mngr_in_meta_valid;
logic dsc_q_mngr_in_meta_ready;

pkt_meta_with_queues_t f2c_in_meta_data;
logic f2c_in_meta_valid;
logic f2c_in_meta_ready;

st_ordered_multiplexer #(
    .NB_IN(NB_PKT_QUEUE_MANAGERS),
    .DWIDTH($bits(pkt_meta_with_queues_t))
) st_mux (
    .clk         (pcie_clk),
    .rst         (!pcie_reset_n),
    .in_valid    (pkt_q_mngr_out_meta_valid),
    .in_ready    (pkt_q_mngr_out_meta_ready),
    .in_data     (pkt_q_mngr_out_meta_data),
    .out_valid   (dsc_q_mngr_in_meta_valid),
    .out_ready   (dsc_q_mngr_in_meta_ready),
    .out_data    (dsc_q_mngr_in_meta_data),
    .order_valid (pcie_meta_buf_valid & pcie_meta_buf_ready),
    .order_ready (st_mux_ord_ready),
    .order_data  (pkt_q_mngr_id)
);

dsc_queue_manager #(
    .NB_QUEUES(MAX_NB_APPS)
)
dsc_queue_manager_inst (
    .clk             (pcie_clk),
    .rst             (!pcie_reset_n),
    .in_meta_data    (dsc_q_mngr_in_meta_data),
    .in_meta_valid   (dsc_q_mngr_in_meta_valid),
    .in_meta_ready   (dsc_q_mngr_in_meta_ready),
    .out_meta_data   (f2c_in_meta_data),
    .out_meta_valid  (f2c_in_meta_valid),
    .out_meta_ready  (f2c_in_meta_ready),
    .q_table_tails   (dsc_q_table_tails.owner),
    .q_table_heads   (dsc_q_table_heads.owner),
    .q_table_l_addrs (dsc_q_table_l_addrs.owner),
    .q_table_h_addrs (dsc_q_table_h_addrs.owner),
    .rb_size         (dsc_rb_size),
    .full_cnt        (cpu_dsc_buf_full_cnt)
);

fpga_to_cpu fpga_to_cpu_inst (
    .clk                    (pcie_clk),
    .rst                    (!pcie_reset_n),
    .pkt_buf_in_data        (pcie_pkt_buf_data),
    .pkt_buf_in_valid       (pcie_pkt_buf_valid),
    .pkt_buf_in_ready       (pcie_pkt_buf_ready),
    .pkt_buf_occup          (pcie_pkt_buf_occup),
    .metadata_buf_in_data   (f2c_in_meta_data),
    .metadata_buf_in_valid  (f2c_in_meta_valid),
    .metadata_buf_in_ready  (f2c_in_meta_ready),
    .metadata_buf_occup     (pcie_meta_buf_occup),
    .pkt_rb_size            (pkt_rb_size),
    .dsc_rb_size            (dsc_rb_size),
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
    .sw_reset               (sw_reset),
    .dma_queue_full_cnt     (dma_queue_full_cnt)
);

// TODO(sadok): remove this when using WRDM and RDDM
assign pcie_wrdm_desc_valid = 0;
assign pcie_wrdm_prio_valid = 0;
assign pcie_rddm_desc_valid = 0;
assign pcie_rddm_prio_valid = 0;
assign pcie_readdatavalid_1 = 0;

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
