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

    // RDDM Avalon-MM signals.
    input  logic [63:0]  pcie_rddm_address,
    input  logic         pcie_rddm_write,
    input  logic [511:0] pcie_rddm_writedata,
    input  logic [63:0]  pcie_rddm_byteenable,
    output logic         pcie_rddm_waitrequest,

    input  var flit_lite_t         pcie_rx_pkt_buf_data,
    input  logic                   pcie_rx_pkt_buf_valid,
    output logic                   pcie_rx_pkt_buf_ready,
    output logic [F2C_RB_AWIDTH:0] pcie_rx_pkt_buf_occup,
    input  var pkt_meta_t          pcie_rx_meta_buf_data,
    input  logic                   pcie_rx_meta_buf_valid,
    output logic                   pcie_rx_meta_buf_ready,
    output logic [F2C_RB_AWIDTH:0] pcie_rx_meta_buf_occup,

    // Packet buffer output.
    output logic         pcie_tx_pkt_sop,
    output logic         pcie_tx_pkt_eop,
    output logic         pcie_tx_pkt_valid,
    output logic [511:0] pcie_tx_pkt_data,
    output logic [5:0]   pcie_tx_pkt_empty,
    input  logic         pcie_tx_pkt_ready,
    input  logic [31:0]  pcie_tx_pkt_occup,

    output logic        disable_pcie,
    output logic        sw_reset,
    output logic [31:0] dma_queue_full_cnt,
    output logic [31:0] cpu_dsc_buf_full_cnt,
    output logic [31:0] cpu_pkt_buf_full_cnt,
    output logic [31:0] rx_ignored_head_cnt,
    output logic [31:0] tx_ignored_dsc_cnt,
    output logic [31:0] tx_q_full_signals,
    output logic [31:0] tx_dsc_cnt,
    output logic [31:0] tx_empty_tail_cnt,
    output logic [31:0] tx_dsc_read_cnt,
    output logic [31:0] tx_pkt_read_cnt,
    output logic [31:0] tx_batch_cnt,
    output logic [31:0] tx_max_inflight_dscs,
    output logic [31:0] tx_max_nb_req_dscs,
    output logic [31:0] tx_dma_pkt_cnt,
    output logic [31:0] rx_pkt_head_upd_cnt,
    output logic [31:0] tx_dsc_tail_upd_cnt,

    // status register bus
    input  logic        clk_status,
    input  logic [29:0] status_addr,
    input  logic        status_read,
    input  logic        status_write,
    input  logic [31:0] status_writedata,
    output logic [31:0] status_readdata,
    output logic        status_readdata_valid
);

localparam HEAD_UPD_QUEUE_LEN = 128;

logic [RB_AWIDTH:0] dsc_rb_size;
logic [RB_AWIDTH:0] pkt_rb_size;

logic [31:0] inflight_desc_limit;

logic [31:0] control_regs [NB_CONTROL_REGS];

assign disable_pcie = control_regs[0][0];
assign pkt_rb_size = control_regs[0][1 +: RB_AWIDTH+1];

// Use to reset stats from software. Must also be unset from software.
logic sw_reset_r1;
logic sw_reset_r2;
assign sw_reset_r2 = control_regs[0][27];

always @(posedge pcie_clk) begin
    sw_reset_r1 <= sw_reset_r2;
    sw_reset <= sw_reset_r1;
end

assign dsc_rb_size = control_regs[1][0 +: RB_AWIDTH+1];

assign inflight_desc_limit = control_regs[2];

logic [BRAM_TABLE_IDX_WIDTH-1:0] queue_id;
assign queue_id = pcie_address_0[12 +: BRAM_TABLE_IDX_WIDTH];

logic pkt_q_head_upd;
always_comb begin
    pkt_q_head_upd = 0;
    if (pcie_write_0 && (queue_id < MAX_NB_FLOWS)) begin
        pkt_q_head_upd =
            pcie_byteenable_0[1*REG_SIZE +: REG_SIZE] == {REG_SIZE{1'b1}};
    end
end

logic [31:0] head_upd_queue_occup;
logic head_upd_queue_almost_full;
assign head_upd_queue_almost_full =
    head_upd_queue_occup > HEAD_UPD_QUEUE_LEN - 4;

logic [FLOW_IDX_WIDTH-1:0] head_upd_queue_in_data;
logic                      head_upd_queue_in_valid;
logic                      head_upd_queue_in_ready;
logic [FLOW_IDX_WIDTH-1:0] head_upd_queue_out_data;
logic                      head_upd_queue_out_valid;
logic                      head_upd_queue_out_ready;

// Monitor PCIe writes to detect updates to a pkt queue head. When that happens,
// inject a descriptor-only metadata to check if software is missing any packet.
always @(posedge pcie_clk) begin
    head_upd_queue_in_valid <= 0;

    if (!pcie_reset_n) begin
        rx_ignored_head_cnt <= 0;
    end else begin
        // Got a PCIe write to a packet queue head.
        if (pkt_q_head_upd) begin
            if (!head_upd_queue_almost_full) begin
                head_upd_queue_in_valid <= 1;
                head_upd_queue_in_data <= queue_id[FLOW_IDX_WIDTH-1:0];
            end else begin
                // TODO(sadok): If the head is updated too often we will ignore
                // it here and may never send a descriptor.
                rx_ignored_head_cnt <= rx_ignored_head_cnt + 1;
            end
        end
    end
end

fifo_wrapper_infill_mlab #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL(FLOW_IDX_WIDTH),
    .FIFO_DEPTH(HEAD_UPD_QUEUE_LEN)
)
head_upd_queue (
    .clk           (pcie_clk),
    .reset         (!pcie_reset_n),
    .csr_address   (2'b0),
    .csr_read      (1'b1),
    .csr_write     (1'b0),
    .csr_readdata  (head_upd_queue_occup),
    .csr_writedata (32'b0),
    .in_data       (head_upd_queue_in_data),
    .in_valid      (head_upd_queue_in_valid),
    .in_ready      (head_upd_queue_in_ready),
    .out_data      (head_upd_queue_out_data),
    .out_valid     (head_upd_queue_out_valid),
    .out_ready     (head_upd_queue_out_ready)
);

logic merge_head_pkt;

logic [31:0] in_queue_occup;
logic in_queue_almost_full;
assign in_queue_almost_full = in_queue_occup > 4;

pkt_meta_with_queues_t in_queue_in_data;
logic                  in_queue_in_valid;
logic                  in_queue_in_ready;
pkt_meta_with_queues_t in_queue_out_data;
logic                  in_queue_out_valid;
logic                  in_queue_out_ready;

always_comb begin
    head_upd_queue_out_ready = 0;
    pcie_rx_meta_buf_ready = 0;
    merge_head_pkt = 0;

    // Prioritize serving head queue updates over incoming metadata. But if both
    // the head update and the next incoming packet are destined to the same
    // queue, we can merge the two and save a cycle.
    if (!in_queue_almost_full) begin
        head_upd_queue_out_ready = 1;
        if (head_upd_queue_out_valid) begin
            if (pcie_rx_meta_buf_valid) begin
                automatic logic [FLOW_IDX_WIDTH-1:0] pkt_queue_id =
                    pcie_rx_meta_buf_data.pkt_queue_id;

                merge_head_pkt = (head_upd_queue_out_data == pkt_queue_id);
                pcie_rx_meta_buf_ready = merge_head_pkt;
            end
        end else begin
            pcie_rx_meta_buf_ready = 1;
        end
    end
end

// We need to inject the descriptor-only metadata here (as opposed to injecting
// in the packet queue manager directly) to ensure that the descriptor remains
// ordered relative to all incoming packets.
always @(posedge pcie_clk) begin
    in_queue_in_valid <= 0;

    if (!pcie_reset_n) begin
        rx_pkt_head_upd_cnt <= 0;
    end else begin
        // Prioritize serving head updates over incoming metadata.
        if (head_upd_queue_out_valid & head_upd_queue_out_ready) begin
            automatic pkt_meta_with_queues_t meta;

            meta.pkt_queue_id = head_upd_queue_out_data;
            meta.size = 0;
            meta.descriptor_only = 1;
            meta.needs_dsc = 0;

            in_queue_in_data <= meta;
            in_queue_in_valid <= 1;

            rx_pkt_head_upd_cnt <= rx_pkt_head_upd_cnt + 1;
        end 

        if (pcie_rx_meta_buf_ready & pcie_rx_meta_buf_valid) begin
            automatic pkt_meta_with_queues_t meta;

            meta.dsc_queue_id = pcie_rx_meta_buf_data.dsc_queue_id;
            meta.pkt_queue_id = pcie_rx_meta_buf_data.pkt_queue_id;
            meta.size = pcie_rx_meta_buf_data.size;
            meta.descriptor_only = 0;

            // If both the head update and the incoming metadata affect the same 
            // packet queue, we merge the two and signal here that the packet
            // needs a descriptor.
            meta.needs_dsc = merge_head_pkt;

            in_queue_in_data <= meta;
            in_queue_in_valid <= 1;
        end
    end
end

fifo_wrapper_infill_mlab #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL($bits(pkt_meta_with_queues_t)),
    .FIFO_DEPTH(8)
)
in_queue (
    .clk           (pcie_clk),
    .reset         (!pcie_reset_n),
    .csr_address   (2'b0),
    .csr_read      (1'b1),
    .csr_write     (1'b0),
    .csr_readdata  (in_queue_occup),
    .csr_writedata (32'b0),
    .in_data       (in_queue_in_data),
    .in_valid      (in_queue_in_valid),
    .in_ready      (in_queue_in_ready),
    .out_data      (in_queue_out_data),
    .out_valid     (in_queue_out_valid),
    .out_ready     (in_queue_out_ready)
);

// descriptor queue table interface signals
bram_interface_io rx_dsc_q_table_tails();
bram_interface_io rx_dsc_q_table_heads();
bram_interface_io rx_dsc_q_table_l_addrs();
bram_interface_io rx_dsc_q_table_h_addrs();
bram_interface_io tx_dsc_q_table_tails();
bram_interface_io tx_dsc_q_table_heads();
bram_interface_io tx_dsc_q_table_l_addrs();
bram_interface_io tx_dsc_q_table_h_addrs();

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

jtag_mmio_arbiter #(
    .PKT_QUEUE_RD_DELAY(4)  // 2 cycle BRAM read + 2 cycle bram mux read.
)
jtag_mmio_arbiter_inst (
    .pcie_clk               (pcie_clk),
    .jtag_clk               (clk_status),
    .pcie_reset_n           (pcie_reset_n),
    .pcie_address_0         (pcie_address_0),
    .pcie_write_0           (pcie_write_0),
    .pcie_read_0            (pcie_read_0),
    .pcie_readdatavalid_0   (pcie_readdatavalid_0),
    .pcie_readdata_0        (pcie_readdata_0),
    .pcie_writedata_0       (pcie_writedata_0),
    .pcie_byteenable_0      (pcie_byteenable_0),
    .status_addr            (status_addr),
    .status_read            (status_read),
    .status_write           (status_write),
    .status_writedata       (status_writedata),
    .status_readdata        (status_readdata),
    .status_readdata_valid  (status_readdata_valid),
    .rx_dsc_q_table_tails   (rx_dsc_q_table_tails.user),
    .rx_dsc_q_table_heads   (rx_dsc_q_table_heads.user),
    .rx_dsc_q_table_l_addrs (rx_dsc_q_table_l_addrs.user),
    .rx_dsc_q_table_h_addrs (rx_dsc_q_table_h_addrs.user),
    .tx_dsc_q_table_tails   (tx_dsc_q_table_tails.user),
    .tx_dsc_q_table_heads   (tx_dsc_q_table_heads.user),
    .tx_dsc_q_table_l_addrs (tx_dsc_q_table_l_addrs.user),
    .tx_dsc_q_table_h_addrs (tx_dsc_q_table_h_addrs.user),
    .pkt_q_table_tails      (pkt_q_table_tails.user),
    .pkt_q_table_heads      (pkt_q_table_heads.user),
    .pkt_q_table_l_addrs    (pkt_q_table_l_addrs.user),
    .pkt_q_table_h_addrs    (pkt_q_table_h_addrs.user),
    .control_regs           (control_regs)
);

pkt_meta_with_queues_t pkt_q_mngr_in_meta_data   [NB_PKT_QUEUE_MANAGERS];
pkt_meta_with_queues_t pkt_q_mngr_out_meta_data  [NB_PKT_QUEUE_MANAGERS];
logic                  pkt_q_mngr_in_meta_valid  [NB_PKT_QUEUE_MANAGERS];
logic                  pkt_q_mngr_out_meta_valid [NB_PKT_QUEUE_MANAGERS];
logic                  pkt_q_mngr_in_meta_ready  [NB_PKT_QUEUE_MANAGERS];
logic                  pkt_q_mngr_out_meta_ready [NB_PKT_QUEUE_MANAGERS];

logic [31:0] pkt_full_counters [NB_PKT_QUEUE_MANAGERS];
logic [31:0] cpu_pkt_buf_full_cnt_r;

logic st_mux_ord_ready;

// use to default ranges to a single bit when using a single pkt queue manager.
localparam NON_NEG_PKT_QM_MSB = PKT_QM_ID_WIDTH ? PKT_QM_ID_WIDTH - 1 : 0;

logic [NON_NEG_PKT_QM_MSB:0] pkt_q_mngr_id;

// Direct `in_queue` output to the appropriate queue manager
always_comb begin
    in_queue_out_ready = 0;
    cpu_pkt_buf_full_cnt_r = 0;

    for (integer i = 0; i < NB_PKT_QUEUE_MANAGERS; i++) begin
        pkt_q_mngr_in_meta_data[i] = in_queue_out_data;
        pkt_q_mngr_in_meta_valid[i] = 0;
        cpu_pkt_buf_full_cnt_r += pkt_full_counters[i];
    end

    if (PKT_QM_ID_WIDTH > 0) begin
        pkt_q_mngr_id = in_queue_out_data.pkt_queue_id[NON_NEG_PKT_QM_MSB:0];
    end else begin
        pkt_q_mngr_id = 0;
    end

    if (in_queue_out_valid) begin
        in_queue_out_ready =
            st_mux_ord_ready & pkt_q_mngr_in_meta_ready[pkt_q_mngr_id];
        pkt_q_mngr_in_meta_valid[pkt_q_mngr_id] = st_mux_ord_ready;
    end
end

always @(posedge pcie_clk) begin
    cpu_pkt_buf_full_cnt <= cpu_pkt_buf_full_cnt_r;
end

// Count TX dsc tail pointer updates.
always @(posedge pcie_clk) begin
    if (!pcie_reset_n) begin
        tx_dsc_tail_upd_cnt <= 0;
    end else begin
        if (tx_dsc_q_table_tails.wr_en) begin
            tx_dsc_tail_upd_cnt <= tx_dsc_tail_upd_cnt + 1;
        end
    end
end

pkt_queue_manager #(
    .NB_QUEUES(MAX_NB_FLOWS/NB_PKT_QUEUE_MANAGERS)
) pkt_queue_manager_inst [NB_PKT_QUEUE_MANAGERS] (
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
    .DWIDTH($bits(pkt_meta_with_queues_t)),
    .DEPTH(2*NB_PKT_QUEUE_MANAGERS)
) st_mux (
    .clk         (pcie_clk),
    .rst         (!pcie_reset_n),
    .in_valid    (pkt_q_mngr_out_meta_valid),
    .in_ready    (pkt_q_mngr_out_meta_ready),
    .in_data     (pkt_q_mngr_out_meta_data),
    .out_valid   (dsc_q_mngr_in_meta_valid),
    .out_ready   (dsc_q_mngr_in_meta_ready),
    .out_data    (dsc_q_mngr_in_meta_data),
    .order_valid (in_queue_out_valid & in_queue_out_ready),
    .order_ready (st_mux_ord_ready),
    .order_data  (pkt_q_mngr_id)
);

rx_dsc_queue_manager #(
    .NB_QUEUES(MAX_NB_APPS)
) rx_dsc_queue_manager_inst (
    .clk             (pcie_clk),
    .rst             (!pcie_reset_n),
    .in_meta_data    (dsc_q_mngr_in_meta_data),
    .in_meta_valid   (dsc_q_mngr_in_meta_valid),
    .in_meta_ready   (dsc_q_mngr_in_meta_ready),
    .out_meta_data   (f2c_in_meta_data),
    .out_meta_valid  (f2c_in_meta_valid),
    .out_meta_ready  (f2c_in_meta_ready),
    .q_table_tails   (rx_dsc_q_table_tails.owner),
    .q_table_heads   (rx_dsc_q_table_heads.owner),
    .q_table_l_addrs (rx_dsc_q_table_l_addrs.owner),
    .q_table_h_addrs (rx_dsc_q_table_h_addrs.owner),
    .rb_size         (dsc_rb_size),
    .full_cnt        (cpu_dsc_buf_full_cnt)
);

tx_transfer_t tx_compl_buf_data;
logic         tx_compl_buf_valid;
logic         tx_compl_buf_ready;
logic [31:0]  tx_compl_buf_occup;

fpga_to_cpu fpga_to_cpu_inst (
    .clk                    (pcie_clk),
    .rst                    (!pcie_reset_n),
    .pkt_buf_in_data        (pcie_rx_pkt_buf_data),
    .pkt_buf_in_valid       (pcie_rx_pkt_buf_valid),
    .pkt_buf_in_ready       (pcie_rx_pkt_buf_ready),
    .pkt_buf_occup          (pcie_rx_pkt_buf_occup),
    .metadata_buf_in_data   (f2c_in_meta_data),
    .metadata_buf_in_valid  (f2c_in_meta_valid),
    .metadata_buf_in_ready  (f2c_in_meta_ready),
    .metadata_buf_occup     (pcie_rx_meta_buf_occup),
    .tx_compl_buf_in_data   (tx_compl_buf_data),
    .tx_compl_buf_in_valid  (tx_compl_buf_valid),
    .tx_compl_buf_in_ready  (tx_compl_buf_ready),
    .tx_compl_buf_occup     (tx_compl_buf_occup),
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

cpu_to_fpga #(
    .NB_QUEUES(MAX_NB_APPS)
) cpu_to_fpga_inst (
    .clk                   (pcie_clk),
    .rst                   (!pcie_reset_n),
    .out_pkt_sop           (pcie_tx_pkt_sop),
    .out_pkt_eop           (pcie_tx_pkt_eop),
    .out_pkt_valid         (pcie_tx_pkt_valid),
    .out_pkt_data          (pcie_tx_pkt_data),
    .out_pkt_empty         (pcie_tx_pkt_empty),
    .out_pkt_ready         (pcie_tx_pkt_ready),
    .out_pkt_occup         (pcie_tx_pkt_occup),
    .tx_compl_buf_data     (tx_compl_buf_data),
    .tx_compl_buf_valid    (tx_compl_buf_valid),
    .tx_compl_buf_ready    (tx_compl_buf_ready),
    .tx_compl_buf_occup    (tx_compl_buf_occup),
    .pcie_rddm_desc_ready  (pcie_rddm_desc_ready),
    .pcie_rddm_desc_valid  (pcie_rddm_desc_valid),
    .pcie_rddm_desc_data   (pcie_rddm_desc_data),
    .pcie_rddm_prio_ready  (pcie_rddm_prio_ready),
    .pcie_rddm_prio_valid  (pcie_rddm_prio_valid),
    .pcie_rddm_prio_data   (pcie_rddm_prio_data),
    .pcie_rddm_tx_valid    (pcie_rddm_tx_valid),
    .pcie_rddm_tx_data     (pcie_rddm_tx_data),
    .pcie_rddm_address     (pcie_rddm_address),
    .pcie_rddm_write       (pcie_rddm_write),
    .pcie_rddm_writedata   (pcie_rddm_writedata),
    .pcie_rddm_byteenable  (pcie_rddm_byteenable),
    .pcie_rddm_waitrequest (pcie_rddm_waitrequest),
    .q_table_tails         (tx_dsc_q_table_tails.owner),
    .q_table_heads         (tx_dsc_q_table_heads.owner),
    .q_table_l_addrs       (tx_dsc_q_table_l_addrs.owner),
    .q_table_h_addrs       (tx_dsc_q_table_h_addrs.owner),
    .rb_size               (dsc_rb_size), // TODO(sadok): use different rb size?
    .inflight_desc_limit   (inflight_desc_limit),
    .ignored_dsc_cnt       (tx_ignored_dsc_cnt),
    .queue_full_signals    (tx_q_full_signals),
    .dsc_cnt               (tx_dsc_cnt),
    .empty_tail_cnt        (tx_empty_tail_cnt),
    .dsc_read_cnt          (tx_dsc_read_cnt),
    .pkt_read_cnt          (tx_pkt_read_cnt),
    .batch_cnt             (tx_batch_cnt),
    .max_inflight_dscs     (tx_max_inflight_dscs),
    .max_nb_req_dscs       (tx_max_nb_req_dscs)
);

// Keep track of the number of packets that were successfully DMAed by software.
always @(posedge pcie_clk) begin
    if (!pcie_reset_n) begin
        tx_dma_pkt_cnt <= 0;
    end else if (pcie_tx_pkt_valid & pcie_tx_pkt_ready & pcie_tx_pkt_eop) begin
        tx_dma_pkt_cnt <= tx_dma_pkt_cnt + 1;
    end
end

// Remove these if start using WRDM.
assign pcie_wrdm_desc_valid = 0;
assign pcie_wrdm_prio_valid = 0;

endmodule
