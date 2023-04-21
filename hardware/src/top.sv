`timescale 1 ps / 1 ps
`include "./constants.sv"
module top (
    // clk & rst.
    input  logic clk,
    input  logic rst,
    input  logic clk_datamover,
    input  logic rst_datamover,
    input  logic clk_pcie,
    input  logic rst_pcie,

    // Ethernet In & out.
    input  logic         in_sop,
    input  logic         in_eop,
    input  logic [511:0] in_data,
    input  logic [5:0]   in_empty,
    input  logic         in_valid,
    output logic [511:0] out_data,
    output logic         out_valid,
    output logic         out_sop,
    output logic         out_eop,
    output logic [5:0]   out_empty,
    input  logic         out_almost_full,

    // Select Ethernet port.
    output logic eth_port_nb,

    // PCIe.
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

    // eSRAM.
    output  logic                     reg_esram_pkt_buf_wren,
    output  logic [PKTBUF_AWIDTH-1:0] reg_esram_pkt_buf_wraddress,
    output  logic [519:0]             reg_esram_pkt_buf_wrdata,
    output  logic                     reg_esram_pkt_buf_rden,
    output  logic [PKTBUF_AWIDTH-1:0] reg_esram_pkt_buf_rdaddress,
    input   logic                     esram_pkt_buf_rd_valid,
    input   logic [519:0]             esram_pkt_buf_rddata,

    // JTAG.
    input   logic          clk_status,
    input   logic   [29:0] status_addr,
    input   logic          status_read,
    input   logic          status_write,
    input   logic   [31:0] status_writedata,
    output  logic   [31:0] status_readdata,
    output  logic          status_readdata_valid
);

// TODO(sadok): Reenable the following assertion once we move the logic outside
// the top module inside.
// Make sure output Ethernet signals comply with Eth core spec, which requires
// that all flits from the same packet be sent without gaps.
// `ASSERT(EthOutContiguousPkt, (out_valid && !out_eop) |=> out_valid, clk, rst)

//counters
logic [31:0] in_pkt_cnt_status;
logic [31:0] out_pkt_cnt_status;
logic [31:0] out_pkt_cnt_in_comp_status;
logic [31:0] out_pkt_cnt_parser_status;
logic [31:0] max_parser_fifo_status;
logic [31:0] fd_in_pkt_cnt_status;
logic [31:0] fd_out_pkt_cnt_status;
logic [31:0] max_fd_out_fifo_status;
logic [31:0] in_pkt_cnt_datamover_status;
logic [31:0] in_pkt_cnt_emptylist_status;
logic [31:0] out_pkt_cnt_emptylist_status;
logic [31:0] pkt_eth_status;
logic [31:0] pkt_drop_status;
logic [31:0] pkt_pcie_status;
logic [31:0] max_dm2pcie_fifo_status;
logic [31:0] max_dm2pcie_meta_fifo_status;
logic [31:0] pcie_pkt_cnt_status;
logic [31:0] pcie_meta_cnt_status;
logic [31:0] dm_pcie_rx_pkt_cnt_status;
logic [31:0] dm_pcie_rx_meta_cnt_status;
logic [31:0] dm_eth_pkt_cnt_status;
logic [31:0] rx_dma_pkt_cnt_status;
logic [31:0] pcie_rx_pkt_head_upd_cnt_status;
logic [31:0] pcie_tx_dsc_tail_upd_cnt_status;
logic [31:0] pcie_top_full_signals_1_status;
logic [31:0] pcie_top_full_signals_2_status;
logic [31:0] dma_request_cnt_status;
logic [31:0] rule_set_cnt_status;
logic [31:0] eviction_cnt_status;
logic [31:0] max_pdugen_pkt_fifo_status;
logic [31:0] max_pdugen_meta_fifo_status;
logic [31:0] pcie_core_full_cnt_status;
logic [31:0] rx_dma_dsc_cnt_status;
logic [31:0] rx_dma_dsc_drop_cnt_status;
logic [31:0] rx_dma_pkt_flit_cnt_status;
logic [31:0] rx_dma_pkt_flit_drop_cnt_status;
logic [31:0] cpu_dsc_buf_full_cnt_status;
logic [31:0] cpu_dsc_buf_in_cnt_status;
logic [31:0] cpu_dsc_buf_out_cnt_status;
logic [31:0] cpu_pkt_buf_full_cnt_status;
logic [31:0] cpu_pkt_buf_in_cnt_status;
logic [31:0] cpu_pkt_buf_out_cnt_status;
logic [31:0] pcie_st_ord_in_cnt_status;
logic [31:0] pcie_st_ord_out_cnt_status;
logic [31:0] max_pcie_pkt_fifo_status;
logic [31:0] max_pcie_meta_fifo_status;
logic [31:0] pcie_rx_ignored_head_cnt_status;
logic [31:0] pcie_tx_q_full_signals_status;
logic [31:0] pcie_tx_dsc_cnt_status;
logic [31:0] pcie_tx_empty_tail_cnt_status;
logic [31:0] pcie_tx_dsc_read_cnt_status;
logic [31:0] pcie_tx_pkt_read_cnt_status;
logic [31:0] pcie_tx_batch_cnt_status;
logic [31:0] pcie_tx_max_inflight_dscs_status;
logic [31:0] pcie_tx_max_nb_req_dscs_status;
logic [31:0] pcie_tx_dma_pkt_cnt_status;

// Register I/O.
logic  [511:0]  eth_out_pkt_fifo_out_data;
logic  [5:0]    eth_out_pkt_fifo_out_empty;
logic           eth_out_pkt_fifo_out_valid;
logic           out_valid_int;
logic           eth_out_pkt_fifo_out_sop;
logic           eth_out_pkt_fifo_out_eop;

logic  [511:0]  reg_in_data;
logic  [5:0]    reg_in_empty;
logic           reg_in_valid;
logic           reg_in_sop;
logic           reg_in_eop;
logic           reg_out_almost_full;

logic           dm_disable_pcie_r1;
logic           dm_disable_pcie;

logic                     esram_pkt_buf_wren;
logic [PKTBUF_AWIDTH-1:0] esram_pkt_buf_wraddress;
logic [519:0]             esram_pkt_buf_wrdata;
logic                     esram_pkt_buf_rden;
logic [PKTBUF_AWIDTH-1:0] esram_pkt_buf_rdaddress;
logic                     reg_esram_pkt_buf_rd_valid;
logic [519:0]             reg_esram_pkt_buf_rddata;
//end of Register I/O

logic          input_comp_eth_valid;
logic  [511:0] input_comp_eth_data;
logic          input_comp_eth_sop;
logic          input_comp_eth_eop;
logic  [5:0]   input_comp_eth_empty;

logic          input_comp_metadata_valid;
metadata_t     input_comp_metadata_data;
logic          input_comp_metadata_ready;
logic          input_comp_pkt_valid;
logic  [511:0] input_comp_pkt_data;
logic          input_comp_pkt_ready;
logic          input_comp_pkt_sop;
logic          input_comp_pkt_eop;
logic  [5:0]   input_comp_pkt_empty;

logic          input_comp_metadata_out_valid;
metadata_t     input_comp_metadata_out_data;
logic          input_comp_metadata_out_ready;
logic          input_comp_pkt_out_valid;
logic  [511:0] input_comp_pkt_out_data;
logic          input_comp_pkt_out_ready;
logic          input_comp_pkt_out_sop;
logic          input_comp_pkt_out_eop;
logic  [5:0]   input_comp_pkt_out_empty;

logic [PKT_AWIDTH-1:0]   emptylist_in_data;
logic                    emptylist_in_valid;
logic                    emptylist_in_ready;

logic [PKT_AWIDTH-1:0]   emptylist_out_data;
logic                    emptylist_out_valid;
logic                    emptylist_out_ready;

logic [31:0]   parser_out_meta_csr_readdata;
logic          parser_out_meta_valid;
metadata_t     parser_out_meta_data;
logic          parser_out_meta_ready;

logic          parser_out_fifo_out_valid;
metadata_t     parser_out_fifo_out_data;
logic          parser_out_fifo_out_ready;

config_flit_t in_config_data;
logic         in_config_valid;
logic         in_config_ready;

flow_table_config_t conf_ft_data;
logic               conf_ft_valid;
logic               conf_ft_ready;

timestamp_config_t conf_ts_data;
logic              conf_ts_valid;
logic              conf_ts_ready;

rate_limit_config_t conf_rl_data;
logic               conf_rl_valid;
logic               conf_rl_ready;

config_flit_t pcie_out_config_data;
logic         pcie_out_config_valid;
logic         pcie_out_config_ready;

logic [31:0] pcie_out_config_fifo_occup;

logic          flow_table_wrapper_out_meta_valid;
metadata_t     flow_table_wrapper_out_meta_data;
logic          flow_table_wrapper_out_control_done;

logic          fdw_in_meta_valid;
metadata_t     fdw_in_meta_data;
logic          fdw_in_meta_ready;
logic          fdw_in_meta_almost_full;

logic [31:0]   fdw_out_meta_csr_readdata;
logic          fdw_out_meta_valid;
metadata_t     fdw_out_meta_data;
logic          fdw_out_meta_ready;
logic [31:0]   nb_fallback_queues;
logic          enable_rr;
logic          pcie_eth_port_nb;

logic          dm_in_meta_valid;
metadata_t     dm_in_meta_data;
logic          dm_in_meta_ready;

logic         dm_pcie_rx_pkt_valid;
logic [511:0] dm_pcie_rx_pkt_data;
logic         dm_pcie_rx_pkt_ready;
logic         dm_pcie_rx_pkt_almost_full;
logic         dm_pcie_rx_pkt_sop;
logic         dm_pcie_rx_pkt_eop;
logic  [5:0]  dm_pcie_rx_pkt_empty;
logic         dm_pcie_rx_meta_valid;
metadata_t    dm_pcie_rx_meta_data;
logic         dm_pcie_rx_meta_ready;
logic         dm_pcie_rx_meta_almost_full;
logic [31:0]  dm_pcie_rx_pkt_in_csr_readdata;
logic [31:0]  dm_pcie_rx_meta_in_csr_readdata;

logic         dm_pcie_tx_pkt_sop;
logic         dm_pcie_tx_pkt_eop;
logic         dm_pcie_tx_pkt_valid;
logic [511:0] dm_pcie_tx_pkt_data;
logic [5:0]   dm_pcie_tx_pkt_empty;
logic         dm_pcie_tx_pkt_ready;

logic         dm_eth_pkt_valid;
logic [511:0] dm_eth_pkt_data;
logic         dm_eth_pkt_ready;
logic         dm_eth_pkt_almost_full;
logic         dm_eth_pkt_sop;
logic         dm_eth_pkt_eop;
logic  [5:0]  dm_eth_pkt_empty;
logic [31:0]  dm_eth_pkt_in_csr_readdata;

logic         pcie_rx_pkt_valid;
logic [511:0] pcie_rx_pkt_data;
logic         pcie_rx_pkt_ready;
logic         pcie_rx_pkt_sop;
logic         pcie_rx_pkt_eop;
logic  [5:0]  pcie_rx_pkt_empty;
logic         pcie_rx_meta_valid;
metadata_t    pcie_rx_meta_data;
logic         pcie_rx_meta_ready;

logic [31:0]  pcie_tx_pkt_fifo_occup;
logic         pcie_tx_pkt_sop;
logic         pcie_tx_pkt_eop;
logic         pcie_tx_pkt_valid;
logic [511:0] pcie_tx_pkt_data;
logic [5:0]   pcie_tx_pkt_empty;
logic         pcie_tx_pkt_ready;

flit_lite_t             pcie_pkt_buf_data;
logic                   pcie_pkt_buf_valid;
logic                   pcie_pkt_buf_ready;
logic [F2C_RB_AWIDTH:0] pcie_pkt_buf_occup;
logic [F2C_RB_AWIDTH:0] pcie_pkt_buf_occup_r;

pkt_meta_t              pcie_meta_buf_data;
logic                   pcie_meta_buf_valid;
logic                   pcie_meta_buf_ready;
logic [F2C_RB_AWIDTH:0] pcie_meta_buf_occup;
logic [F2C_RB_AWIDTH:0] pcie_meta_buf_occup_r;

logic [31:0] out_pkt_queue_occup;
logic [31:0] out_meta_queue_occup;

logic                    disable_pcie;

logic sw_reset;

logic [7:0] status_addr_r;
logic [STAT_AWIDTH-1:0]  status_addr_sel_r;
logic status_write_r;
logic status_read_r;
logic [31:0] status_writedata_r;

logic status_readdata_valid_top;
logic [31:0] status_readdata_top;
logic status_readdata_valid_pcie;
logic [31:0] status_readdata_pcie;

logic [31:0] in_pkt_cnt;
logic [31:0] in_pkt_cnt_r1;
logic [31:0] in_pkt_cnt_r2;
logic [31:0] out_pkt_cnt;
logic [31:0] out_pkt_cnt_r1;
logic [31:0] out_pkt_cnt_r2;
logic [31:0] out_pkt_cnt_in_comp;
logic [31:0] out_pkt_cnt_in_comp_r1;
logic [31:0] out_pkt_cnt_in_comp_r2;
logic [31:0] out_pkt_cnt_parser;
logic [31:0] out_pkt_cnt_parser_r1;
logic [31:0] out_pkt_cnt_parser_r2;
logic [31:0] max_parser_fifo;
logic [31:0] max_parser_fifo_r1;
logic [31:0] max_parser_fifo_r2;
logic [31:0] fd_in_pkt_cnt;
logic [31:0] fd_in_pkt_cnt_r1;
logic [31:0] fd_in_pkt_cnt_r2;
logic [31:0] fd_out_pkt_cnt;
logic [31:0] fd_out_pkt_cnt_r1;
logic [31:0] fd_out_pkt_cnt_r2;
logic [31:0] max_fd_out_fifo;
logic [31:0] max_fd_out_fifo_r1;
logic [31:0] max_fd_out_fifo_r2;
logic [31:0] in_pkt_cnt_datamover;
logic [31:0] in_pkt_cnt_datamover_r1;
logic [31:0] in_pkt_cnt_datamover_r2;
logic [31:0] in_pkt_cnt_emptylist;
logic [31:0] in_pkt_cnt_emptylist_r1;
logic [31:0] in_pkt_cnt_emptylist_r2;
logic [31:0] out_pkt_cnt_emptylist;
logic [31:0] out_pkt_cnt_emptylist_r1;
logic [31:0] out_pkt_cnt_emptylist_r2;
logic [31:0] pkt_eth;
logic [31:0] pkt_eth_r1;
logic [31:0] pkt_eth_r2;
logic [31:0] pkt_drop;
logic [31:0] pkt_drop_r1;
logic [31:0] pkt_drop_r2;
logic [31:0] pkt_pcie;
logic [31:0] pkt_pcie_r1;
logic [31:0] pkt_pcie_r2;
logic [31:0] max_dm2pcie_fifo;
logic [31:0] max_dm2pcie_fifo_r1;
logic [31:0] max_dm2pcie_fifo_r2;
logic [31:0] max_dm2pcie_meta_fifo;
logic [31:0] max_dm2pcie_meta_fifo_r1;
logic [31:0] max_dm2pcie_meta_fifo_r2;
logic [31:0] pcie_pkt_cnt;
logic [31:0] pcie_pkt_cnt_r1;
logic [31:0] pcie_pkt_cnt_r2;
logic [31:0] pcie_meta_cnt;
logic [31:0] pcie_meta_cnt_r1;
logic [31:0] pcie_meta_cnt_r2;
logic [31:0] dm_pcie_rx_pkt_cnt;
logic [31:0] dm_pcie_rx_pkt_cnt_r1;
logic [31:0] dm_pcie_rx_pkt_cnt_r2;
logic [31:0] dm_pcie_rx_meta_cnt;
logic [31:0] dm_pcie_rx_meta_cnt_r1;
logic [31:0] dm_pcie_rx_meta_cnt_r2;
logic [31:0] dm_eth_pkt_cnt;
logic [31:0] dm_eth_pkt_cnt_r1;
logic [31:0] dm_eth_pkt_cnt_r2;
logic [31:0] rx_dma_pkt_cnt;
logic [31:0] rx_dma_pkt_cnt_r1;
logic [31:0] rx_dma_pkt_cnt_r2;
logic [31:0] pcie_rx_pkt_head_upd_cnt;
logic [31:0] pcie_rx_pkt_head_upd_cnt_r1;
logic [31:0] pcie_rx_pkt_head_upd_cnt_r2;
logic [31:0] pcie_tx_dsc_tail_upd_cnt;
logic [31:0] pcie_tx_dsc_tail_upd_cnt_r1;
logic [31:0] pcie_tx_dsc_tail_upd_cnt_r2;
logic [31:0] pcie_top_full_signals_1;
logic [31:0] pcie_top_full_signals_1_r1;
logic [31:0] pcie_top_full_signals_1_r2;
logic [31:0] pcie_top_full_signals_2;
logic [31:0] pcie_top_full_signals_2_r1;
logic [31:0] pcie_top_full_signals_2_r2;
logic [31:0] dma_request_cnt;
logic [31:0] dma_request_cnt_r1;
logic [31:0] dma_request_cnt_r2;
logic [31:0] rule_set_cnt;
logic [31:0] rule_set_cnt_r1;
logic [31:0] rule_set_cnt_r2;
logic [31:0] eviction_cnt;
logic [31:0] eviction_cnt_r1;
logic [31:0] eviction_cnt_r2;
logic [31:0] max_pdugen_pkt_fifo;
logic [31:0] max_pdugen_pkt_fifo_r1;
logic [31:0] max_pdugen_pkt_fifo_r2;
logic [31:0] max_pdugen_meta_fifo;
logic [31:0] max_pdugen_meta_fifo_r1;
logic [31:0] max_pdugen_meta_fifo_r2;
logic [31:0] pcie_core_full_cnt;
logic [31:0] pcie_core_full_cnt_r1;
logic [31:0] pcie_core_full_cnt_r2;
logic [31:0] rx_dma_dsc_cnt;
logic [31:0] rx_dma_dsc_cnt_r1;
logic [31:0] rx_dma_dsc_cnt_r2;
logic [31:0] rx_dma_dsc_drop_cnt;
logic [31:0] rx_dma_dsc_drop_cnt_r1;
logic [31:0] rx_dma_dsc_drop_cnt_r2;
logic [31:0] rx_dma_pkt_flit_cnt;
logic [31:0] rx_dma_pkt_flit_cnt_r1;
logic [31:0] rx_dma_pkt_flit_cnt_r2;
logic [31:0] rx_dma_pkt_flit_drop_cnt;
logic [31:0] rx_dma_pkt_flit_drop_cnt_r1;
logic [31:0] rx_dma_pkt_flit_drop_cnt_r2;
logic [31:0] cpu_dsc_buf_full_cnt;
logic [31:0] cpu_dsc_buf_full_cnt_r1;
logic [31:0] cpu_dsc_buf_full_cnt_r2;
logic [31:0] cpu_dsc_buf_in_cnt;
logic [31:0] cpu_dsc_buf_in_cnt_r1;
logic [31:0] cpu_dsc_buf_in_cnt_r2;
logic [31:0] cpu_dsc_buf_out_cnt;
logic [31:0] cpu_dsc_buf_out_cnt_r1;
logic [31:0] cpu_dsc_buf_out_cnt_r2;
logic [31:0] cpu_pkt_buf_full_cnt;
logic [31:0] cpu_pkt_buf_full_cnt_r1;
logic [31:0] cpu_pkt_buf_full_cnt_r2;
logic [31:0] cpu_pkt_buf_in_cnt;
logic [31:0] cpu_pkt_buf_in_cnt_r1;
logic [31:0] cpu_pkt_buf_in_cnt_r2;
logic [31:0] cpu_pkt_buf_out_cnt;
logic [31:0] cpu_pkt_buf_out_cnt_r1;
logic [31:0] cpu_pkt_buf_out_cnt_r2;
logic [31:0] pcie_st_ord_in_cnt;
logic [31:0] pcie_st_ord_in_cnt_r1;
logic [31:0] pcie_st_ord_in_cnt_r2;
logic [31:0] pcie_st_ord_out_cnt;
logic [31:0] pcie_st_ord_out_cnt_r1;
logic [31:0] pcie_st_ord_out_cnt_r2;
logic [31:0] max_pcie_pkt_fifo;
logic [31:0] max_pcie_pkt_fifo_r1;
logic [31:0] max_pcie_pkt_fifo_r2;
logic [31:0] max_pcie_meta_fifo;
logic [31:0] max_pcie_meta_fifo_r1;
logic [31:0] max_pcie_meta_fifo_r2;
logic [31:0] pcie_rx_ignored_head_cnt;
logic [31:0] pcie_rx_ignored_head_cnt_r1;
logic [31:0] pcie_rx_ignored_head_cnt_r2;
logic [31:0] pcie_tx_q_full_signals;
logic [31:0] pcie_tx_q_full_signals_r1;
logic [31:0] pcie_tx_q_full_signals_r2;
logic [31:0] pcie_tx_dsc_cnt;
logic [31:0] pcie_tx_dsc_cnt_r1;
logic [31:0] pcie_tx_dsc_cnt_r2;
logic [31:0] pcie_tx_empty_tail_cnt;
logic [31:0] pcie_tx_empty_tail_cnt_r1;
logic [31:0] pcie_tx_empty_tail_cnt_r2;
logic [31:0] pcie_tx_dsc_read_cnt;
logic [31:0] pcie_tx_dsc_read_cnt_r1;
logic [31:0] pcie_tx_dsc_read_cnt_r2;
logic [31:0] pcie_tx_pkt_read_cnt;
logic [31:0] pcie_tx_pkt_read_cnt_r1;
logic [31:0] pcie_tx_pkt_read_cnt_r2;
logic [31:0] pcie_tx_batch_cnt;
logic [31:0] pcie_tx_batch_cnt_r1;
logic [31:0] pcie_tx_batch_cnt_r2;
logic [31:0] pcie_tx_max_inflight_dscs;
logic [31:0] pcie_tx_max_inflight_dscs_r1;
logic [31:0] pcie_tx_max_inflight_dscs_r2;
logic [31:0] pcie_tx_max_nb_req_dscs;
logic [31:0] pcie_tx_max_nb_req_dscs_r1;
logic [31:0] pcie_tx_max_nb_req_dscs_r2;
logic [31:0] pcie_tx_dma_pkt_cnt;
logic [31:0] pcie_tx_dma_pkt_cnt_r1;
logic [31:0] pcie_tx_dma_pkt_cnt_r2;

logic pcie_bas_write_r;

///////////////////////////
//Read and Write registers
//////////////////////////

logic sw_reset_r1;
logic sw_reset_r2;

always @ (posedge clk) begin
    // Add pipeline stages to help with timing.
    sw_reset_r1 <= sw_reset;
    sw_reset_r2 <= sw_reset_r1;

    if (rst | sw_reset_r2) begin
        fd_in_pkt_cnt <= 0;
        fd_out_pkt_cnt <= 0;
        max_fd_out_fifo <= 0;
        out_pkt_cnt <= 0;
        rule_set_cnt <= 0;
    end else begin
        if (parser_out_fifo_out_valid & parser_out_fifo_out_ready) begin
            fd_in_pkt_cnt <= fd_in_pkt_cnt + 1;
        end
        if (fdw_out_meta_valid & fdw_out_meta_ready) begin
            fd_out_pkt_cnt <= fd_out_pkt_cnt + 1;
        end
        if (max_fd_out_fifo <= fdw_out_meta_csr_readdata) begin
            max_fd_out_fifo <= fdw_out_meta_csr_readdata;
        end
        if (eth_out_pkt_fifo_out_valid & !reg_out_almost_full
                & eth_out_pkt_fifo_out_eop) begin
            out_pkt_cnt <= out_pkt_cnt + 1;
        end
        if (conf_ft_valid & conf_ft_ready) begin
            rule_set_cnt <= rule_set_cnt + 1;
        end
    end
end

logic sw_reset_dm_r1;
logic sw_reset_dm_r2;

// Datamover clock domain.
always @(posedge clk_datamover) begin
    // Add pipeline stages to help with timing.
    sw_reset_dm_r1 <= sw_reset;
    sw_reset_dm_r2 <= sw_reset_dm_r1;

    if (rst_datamover | sw_reset_dm_r2) begin
        in_pkt_cnt <= 0;
        out_pkt_cnt_in_comp <= 0;
        out_pkt_cnt_parser <= 0;
        max_parser_fifo <= 0;
        in_pkt_cnt_emptylist <= 0;
        out_pkt_cnt_emptylist <= 0;
        in_pkt_cnt_datamover <= 0;
        pkt_eth <= 0;
        pkt_drop <= 0;
        pkt_pcie <= 0;
        max_dm2pcie_fifo <= 0;
        max_dm2pcie_meta_fifo <= 0;
        dm_pcie_rx_pkt_cnt <= 0;
        dm_pcie_rx_meta_cnt <= 0;
        dm_eth_pkt_cnt <= 0;
    end else begin
        if (input_comp_eth_valid & input_comp_eth_eop) begin
            in_pkt_cnt <= in_pkt_cnt + 1;
        end

        if (input_comp_metadata_valid & input_comp_metadata_ready) begin
            out_pkt_cnt_in_comp <= out_pkt_cnt_in_comp + 1;
        end

        if (parser_out_meta_valid & parser_out_meta_ready) begin
            out_pkt_cnt_parser <= out_pkt_cnt_parser + 1;
        end

        if (max_parser_fifo < parser_out_meta_csr_readdata) begin
            max_parser_fifo <= parser_out_meta_csr_readdata;
        end

        if (emptylist_in_valid & emptylist_in_ready) begin
            in_pkt_cnt_emptylist <= in_pkt_cnt_emptylist + 1;
        end
        if (emptylist_out_valid & emptylist_out_ready) begin
            out_pkt_cnt_emptylist <= out_pkt_cnt_emptylist + 1;
        end

        if (dm_in_meta_ready & dm_in_meta_valid) begin
            in_pkt_cnt_datamover <= in_pkt_cnt_datamover + 1;
            case (dm_in_meta_data.pkt_flags)
                PKT_ETH: pkt_eth <= pkt_eth + 1;
                PKT_DROP: pkt_drop <= pkt_drop + 1;
                PKT_PCIE: pkt_pcie <= pkt_pcie + 1;
            endcase
        end

        if (max_dm2pcie_fifo < dm_pcie_rx_pkt_in_csr_readdata) begin
            max_dm2pcie_fifo <= dm_pcie_rx_pkt_in_csr_readdata;
        end

        if (max_dm2pcie_meta_fifo < dm_pcie_rx_meta_in_csr_readdata) begin
            max_dm2pcie_meta_fifo <= dm_pcie_rx_meta_in_csr_readdata;
        end

        if (dm_pcie_rx_pkt_valid & dm_pcie_rx_pkt_ready & dm_pcie_rx_pkt_eop)
        begin
            dm_pcie_rx_pkt_cnt <= dm_pcie_rx_pkt_cnt + 1;
        end

        if (dm_pcie_rx_meta_valid & dm_pcie_rx_meta_ready) begin
            dm_pcie_rx_meta_cnt <= dm_pcie_rx_meta_cnt + 1;
        end

        if (dm_eth_pkt_valid & dm_eth_pkt_ready & dm_eth_pkt_eop) begin
            dm_eth_pkt_cnt <= dm_eth_pkt_cnt + 1;
        end
    end
end

// PCIe clock domain.
always @(posedge clk_pcie) begin
    if (rst_pcie | sw_reset) begin
        pcie_pkt_cnt <= 0;
        pcie_meta_cnt <= 0;
        rx_dma_pkt_cnt <= 0;
        dma_request_cnt <= 0;
        max_pdugen_pkt_fifo <= 0;
        max_pdugen_meta_fifo <= 0;
        max_pcie_pkt_fifo <= 0;
        max_pcie_meta_fifo <= 0;
    end else begin
        if (pcie_rx_pkt_valid & pcie_rx_pkt_ready & pcie_rx_pkt_eop) begin
            pcie_pkt_cnt <= pcie_pkt_cnt + 1;
        end
        if (pcie_rx_meta_valid & pcie_rx_meta_ready) begin
            pcie_meta_cnt <= pcie_meta_cnt + 1;
        end
        if (pcie_meta_buf_valid & pcie_meta_buf_ready) begin
            rx_dma_pkt_cnt <= rx_dma_pkt_cnt + 1;
        end
        if (!pcie_bas_waitrequest && pcie_bas_write_r) begin
            dma_request_cnt <= dma_request_cnt + 1;
        end
        if (out_pkt_queue_occup > max_pdugen_pkt_fifo) begin
            max_pdugen_pkt_fifo <= out_pkt_queue_occup;
        end
        if (out_meta_queue_occup > max_pdugen_meta_fifo) begin
            max_pdugen_meta_fifo <= out_meta_queue_occup;
        end
        if (pcie_pkt_buf_occup_r > max_pcie_pkt_fifo) begin
            max_pcie_pkt_fifo <= pcie_pkt_buf_occup_r;
        end
        if (pcie_meta_buf_occup_r > max_pcie_meta_fifo) begin
            max_pcie_meta_fifo <= pcie_meta_buf_occup_r;
        end
    end

    pcie_bas_write_r <= pcie_bas_write;
    pcie_pkt_buf_occup_r <= pcie_pkt_buf_occup;
    pcie_meta_buf_occup_r <= pcie_meta_buf_occup;
end


//sync; Not a good way, but works fine as the registers are stable when read.
always @(posedge clk_status) begin
    in_pkt_cnt_r1                    <= in_pkt_cnt;
    in_pkt_cnt_r2                    <= in_pkt_cnt_r1;
    in_pkt_cnt_status                <= in_pkt_cnt_r2;
    out_pkt_cnt_r1                   <= out_pkt_cnt;
    out_pkt_cnt_r2                   <= out_pkt_cnt_r1;
    out_pkt_cnt_status               <= out_pkt_cnt_r2;
    out_pkt_cnt_in_comp_r1           <= out_pkt_cnt_in_comp;
    out_pkt_cnt_in_comp_r2           <= out_pkt_cnt_in_comp_r1;
    out_pkt_cnt_in_comp_status       <= out_pkt_cnt_in_comp_r2;
    out_pkt_cnt_parser_r1            <= out_pkt_cnt_parser;
    out_pkt_cnt_parser_r2            <= out_pkt_cnt_parser_r1;
    out_pkt_cnt_parser_status        <= out_pkt_cnt_parser_r2;
    max_parser_fifo_r1               <= max_parser_fifo;
    max_parser_fifo_r2               <= max_parser_fifo_r1;
    max_parser_fifo_status           <= max_parser_fifo_r2;
    fd_in_pkt_cnt_r1                 <= fd_in_pkt_cnt;
    fd_in_pkt_cnt_r2                 <= fd_in_pkt_cnt_r1;
    fd_in_pkt_cnt_status             <= fd_in_pkt_cnt_r2;
    fd_out_pkt_cnt_r1                <= fd_out_pkt_cnt;
    fd_out_pkt_cnt_r2                <= fd_out_pkt_cnt_r1;
    fd_out_pkt_cnt_status            <= fd_out_pkt_cnt_r2;
    max_fd_out_fifo_r1               <= max_fd_out_fifo;
    max_fd_out_fifo_r2               <= max_fd_out_fifo_r1;
    max_fd_out_fifo_status           <= max_fd_out_fifo_r2;
    in_pkt_cnt_datamover_r1          <= in_pkt_cnt_datamover;
    in_pkt_cnt_datamover_r2          <= in_pkt_cnt_datamover_r1;
    in_pkt_cnt_datamover_status      <= in_pkt_cnt_datamover_r2;
    in_pkt_cnt_emptylist_r1          <= in_pkt_cnt_emptylist;
    in_pkt_cnt_emptylist_r2          <= in_pkt_cnt_emptylist_r1;
    in_pkt_cnt_emptylist_status      <= in_pkt_cnt_emptylist_r2;
    out_pkt_cnt_emptylist_r1         <= out_pkt_cnt_emptylist;
    out_pkt_cnt_emptylist_r2         <= out_pkt_cnt_emptylist_r1;
    out_pkt_cnt_emptylist_status     <= out_pkt_cnt_emptylist_r2;
    pkt_eth_r1                       <= pkt_eth;
    pkt_eth_r2                       <= pkt_eth_r1;
    pkt_eth_status                   <= pkt_eth_r2;
    pkt_drop_r1                      <= pkt_drop;
    pkt_drop_r2                      <= pkt_drop_r1;
    pkt_drop_status                  <= pkt_drop_r2;
    pkt_pcie_r1                      <= pkt_pcie;
    pkt_pcie_r2                      <= pkt_pcie_r1;
    pkt_pcie_status                  <= pkt_pcie_r2;
    max_dm2pcie_fifo_r1              <= max_dm2pcie_fifo;
    max_dm2pcie_fifo_r2              <= max_dm2pcie_fifo_r1;
    max_dm2pcie_fifo_status          <= max_dm2pcie_fifo_r2;
    max_dm2pcie_meta_fifo_r1         <= max_dm2pcie_meta_fifo;
    max_dm2pcie_meta_fifo_r2         <= max_dm2pcie_meta_fifo_r1;
    max_dm2pcie_meta_fifo_status     <= max_dm2pcie_meta_fifo_r2;
    pcie_pkt_cnt_r1                  <= pcie_pkt_cnt;
    pcie_pkt_cnt_r2                  <= pcie_pkt_cnt_r1;
    pcie_pkt_cnt_status              <= pcie_pkt_cnt_r2;
    pcie_meta_cnt_r1                 <= pcie_meta_cnt;
    pcie_meta_cnt_r2                 <= pcie_meta_cnt_r1;
    pcie_meta_cnt_status             <= pcie_meta_cnt_r2;
    dm_pcie_rx_pkt_cnt_r1            <= dm_pcie_rx_pkt_cnt;
    dm_pcie_rx_pkt_cnt_r2            <= dm_pcie_rx_pkt_cnt_r1;
    dm_pcie_rx_pkt_cnt_status        <= dm_pcie_rx_pkt_cnt_r2;
    dm_pcie_rx_meta_cnt_r1           <= dm_pcie_rx_meta_cnt;
    dm_pcie_rx_meta_cnt_r2           <= dm_pcie_rx_meta_cnt_r1;
    dm_pcie_rx_meta_cnt_status       <= dm_pcie_rx_meta_cnt_r2;
    dm_eth_pkt_cnt_r1                <= dm_eth_pkt_cnt;
    dm_eth_pkt_cnt_r2                <= dm_eth_pkt_cnt_r1;
    dm_eth_pkt_cnt_status            <= dm_eth_pkt_cnt_r2;
    rx_dma_pkt_cnt_r1                <= rx_dma_pkt_cnt;
    rx_dma_pkt_cnt_r2                <= rx_dma_pkt_cnt_r1;
    rx_dma_pkt_cnt_status            <= rx_dma_pkt_cnt_r2;
    pcie_rx_pkt_head_upd_cnt_r1      <= pcie_rx_pkt_head_upd_cnt;
    pcie_rx_pkt_head_upd_cnt_r2      <= pcie_rx_pkt_head_upd_cnt_r1;
    pcie_rx_pkt_head_upd_cnt_status  <= pcie_rx_pkt_head_upd_cnt_r2;
    pcie_tx_dsc_tail_upd_cnt_r1      <= pcie_tx_dsc_tail_upd_cnt;
    pcie_tx_dsc_tail_upd_cnt_r2      <= pcie_tx_dsc_tail_upd_cnt_r1;
    pcie_tx_dsc_tail_upd_cnt_status  <= pcie_tx_dsc_tail_upd_cnt_r2;
    pcie_top_full_signals_1_r1       <= pcie_top_full_signals_1;
    pcie_top_full_signals_1_r2       <= pcie_top_full_signals_1_r1;
    pcie_top_full_signals_1_status   <= pcie_top_full_signals_1_r2;
    pcie_top_full_signals_2_r1       <= pcie_top_full_signals_2;
    pcie_top_full_signals_2_r2       <= pcie_top_full_signals_2_r1;
    pcie_top_full_signals_2_status   <= pcie_top_full_signals_2_r2;
    dma_request_cnt_r1               <= dma_request_cnt;
    dma_request_cnt_r2               <= dma_request_cnt_r1;
    dma_request_cnt_status           <= dma_request_cnt_r2;
    rule_set_cnt_r1                  <= rule_set_cnt;
    rule_set_cnt_r2                  <= rule_set_cnt_r1;
    rule_set_cnt_status              <= rule_set_cnt_r2;
    eviction_cnt_r1                  <= eviction_cnt;
    eviction_cnt_r2                  <= eviction_cnt_r1;
    eviction_cnt_status              <= eviction_cnt_r2;
    max_pdugen_pkt_fifo_r1           <= max_pdugen_pkt_fifo;
    max_pdugen_pkt_fifo_r2           <= max_pdugen_pkt_fifo_r1;
    max_pdugen_pkt_fifo_status       <= max_pdugen_pkt_fifo_r2;
    max_pdugen_meta_fifo_r1          <= max_pdugen_meta_fifo;
    max_pdugen_meta_fifo_r2          <= max_pdugen_meta_fifo_r1;
    max_pdugen_meta_fifo_status      <= max_pdugen_meta_fifo_r2;
    pcie_core_full_cnt_r1            <= pcie_core_full_cnt;
    pcie_core_full_cnt_r2            <= pcie_core_full_cnt_r1;
    pcie_core_full_cnt_status        <= pcie_core_full_cnt_r2;
    rx_dma_dsc_cnt_r1                <= rx_dma_dsc_cnt;
    rx_dma_dsc_cnt_r2                <= rx_dma_dsc_cnt_r1;
    rx_dma_dsc_cnt_status            <= rx_dma_dsc_cnt_r2;
    rx_dma_dsc_drop_cnt_r1           <= rx_dma_dsc_drop_cnt;
    rx_dma_dsc_drop_cnt_r2           <= rx_dma_dsc_drop_cnt_r1;
    rx_dma_dsc_drop_cnt_status       <= rx_dma_dsc_drop_cnt_r2;
    rx_dma_pkt_flit_cnt_r1           <= rx_dma_pkt_flit_cnt;
    rx_dma_pkt_flit_cnt_r2           <= rx_dma_pkt_flit_cnt_r1;
    rx_dma_pkt_flit_cnt_status       <= rx_dma_pkt_flit_cnt_r2;
    rx_dma_pkt_flit_drop_cnt_r1      <= rx_dma_pkt_flit_drop_cnt;
    rx_dma_pkt_flit_drop_cnt_r2      <= rx_dma_pkt_flit_drop_cnt_r1;
    rx_dma_pkt_flit_drop_cnt_status  <= rx_dma_pkt_flit_drop_cnt_r2;
    cpu_dsc_buf_full_cnt_r1          <= cpu_dsc_buf_full_cnt;
    cpu_dsc_buf_full_cnt_r2          <= cpu_dsc_buf_full_cnt_r1;
    cpu_dsc_buf_full_cnt_status      <= cpu_dsc_buf_full_cnt_r2;
    cpu_dsc_buf_in_cnt_r1            <= cpu_dsc_buf_in_cnt;
    cpu_dsc_buf_in_cnt_r2            <= cpu_dsc_buf_in_cnt_r1;
    cpu_dsc_buf_in_cnt_status        <= cpu_dsc_buf_in_cnt_r2;
    cpu_dsc_buf_out_cnt_r1           <= cpu_dsc_buf_out_cnt;
    cpu_dsc_buf_out_cnt_r2           <= cpu_dsc_buf_out_cnt_r1;
    cpu_dsc_buf_out_cnt_status       <= cpu_dsc_buf_out_cnt_r2;
    cpu_pkt_buf_full_cnt_r1          <= cpu_pkt_buf_full_cnt;
    cpu_pkt_buf_full_cnt_r2          <= cpu_pkt_buf_full_cnt_r1;
    cpu_pkt_buf_full_cnt_status      <= cpu_pkt_buf_full_cnt_r2;
    cpu_pkt_buf_in_cnt_r1            <= cpu_pkt_buf_in_cnt;
    cpu_pkt_buf_in_cnt_r2            <= cpu_pkt_buf_in_cnt_r1;
    cpu_pkt_buf_in_cnt_status        <= cpu_pkt_buf_in_cnt_r2;
    cpu_pkt_buf_out_cnt_r1           <= cpu_pkt_buf_out_cnt;
    cpu_pkt_buf_out_cnt_r2           <= cpu_pkt_buf_out_cnt_r1;
    cpu_pkt_buf_out_cnt_status       <= cpu_pkt_buf_out_cnt_r2;
    pcie_st_ord_in_cnt_r1            <= pcie_st_ord_in_cnt;
    pcie_st_ord_in_cnt_r2            <= pcie_st_ord_in_cnt_r1;
    pcie_st_ord_in_cnt_status        <= pcie_st_ord_in_cnt_r2;
    pcie_st_ord_out_cnt_r1           <= pcie_st_ord_out_cnt;
    pcie_st_ord_out_cnt_r2           <= pcie_st_ord_out_cnt_r1;
    pcie_st_ord_out_cnt_status       <= pcie_st_ord_out_cnt_r2;
    max_pcie_pkt_fifo_r1             <= max_pcie_pkt_fifo;
    max_pcie_pkt_fifo_r2             <= max_pcie_pkt_fifo_r1;
    max_pcie_pkt_fifo_status         <= max_pcie_pkt_fifo_r2;
    max_pcie_meta_fifo_r1            <= max_pcie_meta_fifo;
    max_pcie_meta_fifo_r2            <= max_pcie_meta_fifo_r1;
    max_pcie_meta_fifo_status        <= max_pcie_meta_fifo_r2;
    pcie_rx_ignored_head_cnt_r1      <= pcie_rx_ignored_head_cnt;
    pcie_rx_ignored_head_cnt_r2      <= pcie_rx_ignored_head_cnt_r1;
    pcie_rx_ignored_head_cnt_status  <= pcie_rx_ignored_head_cnt_r2;
    pcie_tx_q_full_signals_r1        <= pcie_tx_q_full_signals;
    pcie_tx_q_full_signals_r2        <= pcie_tx_q_full_signals_r1;
    pcie_tx_q_full_signals_status    <= pcie_tx_q_full_signals_r2;
    pcie_tx_dsc_cnt_r1               <= pcie_tx_dsc_cnt;
    pcie_tx_dsc_cnt_r2               <= pcie_tx_dsc_cnt_r1;
    pcie_tx_dsc_cnt_status           <= pcie_tx_dsc_cnt_r2;
    pcie_tx_empty_tail_cnt_r1        <= pcie_tx_empty_tail_cnt;
    pcie_tx_empty_tail_cnt_r2        <= pcie_tx_empty_tail_cnt_r1;
    pcie_tx_empty_tail_cnt_status    <= pcie_tx_empty_tail_cnt_r2;
    pcie_tx_dsc_read_cnt_r1          <= pcie_tx_dsc_read_cnt;
    pcie_tx_dsc_read_cnt_r2          <= pcie_tx_dsc_read_cnt_r1;
    pcie_tx_dsc_read_cnt_status      <= pcie_tx_dsc_read_cnt_r2;
    pcie_tx_pkt_read_cnt_r1          <= pcie_tx_pkt_read_cnt;
    pcie_tx_pkt_read_cnt_r2          <= pcie_tx_pkt_read_cnt_r1;
    pcie_tx_pkt_read_cnt_status      <= pcie_tx_pkt_read_cnt_r2;
    pcie_tx_batch_cnt_r1             <= pcie_tx_batch_cnt;
    pcie_tx_batch_cnt_r2             <= pcie_tx_batch_cnt_r1;
    pcie_tx_batch_cnt_status         <= pcie_tx_batch_cnt_r2;
    pcie_tx_max_inflight_dscs_r1     <= pcie_tx_max_inflight_dscs;
    pcie_tx_max_inflight_dscs_r2     <= pcie_tx_max_inflight_dscs_r1;
    pcie_tx_max_inflight_dscs_status <= pcie_tx_max_inflight_dscs_r2;
    pcie_tx_max_nb_req_dscs_r1       <= pcie_tx_max_nb_req_dscs;
    pcie_tx_max_nb_req_dscs_r2       <= pcie_tx_max_nb_req_dscs_r1;
    pcie_tx_max_nb_req_dscs_status   <= pcie_tx_max_nb_req_dscs_r2;
    pcie_tx_dma_pkt_cnt_r1           <= pcie_tx_dma_pkt_cnt;
    pcie_tx_dma_pkt_cnt_r2           <= pcie_tx_dma_pkt_cnt_r1;
    pcie_tx_dma_pkt_cnt_status       <= pcie_tx_dma_pkt_cnt_r2;
end

//registers
always @(posedge clk_status) begin
    status_addr_r           <= status_addr[7:0];
    status_addr_sel_r       <= status_addr[29:30-STAT_AWIDTH];

    status_read_r           <= status_read;
    status_write_r          <= status_write;
    status_writedata_r      <= status_writedata;
    status_readdata_valid_top <= 1'b0;

    if (status_read_r) begin
        if (status_addr_sel_r == TOP_REG) begin
            status_readdata_valid_top <= 1'b1;
            case (status_addr_r)
                8'd0  : status_readdata_top <= in_pkt_cnt_status;
                8'd1  : status_readdata_top <= out_pkt_cnt_status;
                8'd2  : status_readdata_top <= out_pkt_cnt_in_comp_status;
                8'd3  : status_readdata_top <= out_pkt_cnt_parser_status;
                8'd4  : status_readdata_top <= max_parser_fifo_status;
                8'd5  : status_readdata_top <= fd_in_pkt_cnt_status;
                8'd6  : status_readdata_top <= fd_out_pkt_cnt_status;
                8'd7  : status_readdata_top <= max_fd_out_fifo_status;
                8'd8  : status_readdata_top <= in_pkt_cnt_datamover_status;
                8'd9  : status_readdata_top <= in_pkt_cnt_emptylist_status;
                8'd10 : status_readdata_top <= out_pkt_cnt_emptylist_status;
                8'd11 : status_readdata_top <= pkt_eth_status;
                8'd12 : status_readdata_top <= pkt_drop_status;
                8'd13 : status_readdata_top <= pkt_pcie_status;
                8'd14 : status_readdata_top <= max_dm2pcie_fifo_status;
                8'd15 : status_readdata_top <= max_dm2pcie_meta_fifo_status;
                8'd16 : status_readdata_top <= pcie_pkt_cnt_status;
                8'd17 : status_readdata_top <= pcie_meta_cnt_status;
                8'd18 : status_readdata_top <= dm_pcie_rx_pkt_cnt_status;
                8'd19 : status_readdata_top <= dm_pcie_rx_meta_cnt_status;
                8'd20 : status_readdata_top <= dm_eth_pkt_cnt_status;
                8'd21 : status_readdata_top <= rx_dma_pkt_cnt_status;
                8'd22 : status_readdata_top <= pcie_rx_pkt_head_upd_cnt_status;
                8'd23 : status_readdata_top <= pcie_tx_dsc_tail_upd_cnt_status;
                8'd24 : status_readdata_top <= dma_request_cnt_status;
                8'd25 : status_readdata_top <= rule_set_cnt_status;
                8'd26 : status_readdata_top <= eviction_cnt_status;
                8'd27 : status_readdata_top <= max_pdugen_pkt_fifo_status;
                8'd28 : status_readdata_top <= max_pdugen_meta_fifo_status;
                8'd29 : status_readdata_top <= pcie_core_full_cnt_status;
                8'd30 : status_readdata_top <= rx_dma_dsc_cnt_status;
                8'd31 : status_readdata_top <= rx_dma_dsc_drop_cnt_status;
                8'd32 : status_readdata_top <= rx_dma_pkt_flit_cnt_status;
                8'd33 : status_readdata_top <= rx_dma_pkt_flit_drop_cnt_status;
                8'd34 : status_readdata_top <= cpu_dsc_buf_full_cnt_status;
                8'd35 : status_readdata_top <= cpu_dsc_buf_in_cnt_status;
                8'd36 : status_readdata_top <= cpu_dsc_buf_out_cnt_status;
                8'd37 : status_readdata_top <= cpu_pkt_buf_full_cnt_status;
                8'd38 : status_readdata_top <= cpu_pkt_buf_in_cnt_status;
                8'd39 : status_readdata_top <= cpu_pkt_buf_out_cnt_status;
                8'd40 : status_readdata_top <= pcie_st_ord_in_cnt_status;
                8'd41 : status_readdata_top <= pcie_st_ord_out_cnt_status;
                8'd42 : status_readdata_top <= max_pcie_pkt_fifo_status;
                8'd43 : status_readdata_top <= max_pcie_meta_fifo_status;
                8'd44 : status_readdata_top <= pcie_rx_ignored_head_cnt_status;
                8'd45 : status_readdata_top <= pcie_tx_q_full_signals_status;
                8'd46 : status_readdata_top <= pcie_tx_dsc_cnt_status;
                8'd47 : status_readdata_top <= pcie_tx_empty_tail_cnt_status;
                8'd48 : status_readdata_top <= pcie_tx_dsc_read_cnt_status;
                8'd49 : status_readdata_top <= pcie_tx_pkt_read_cnt_status;
                8'd50 : status_readdata_top <= pcie_tx_batch_cnt_status;
                8'd51 : status_readdata_top <= pcie_tx_max_inflight_dscs_status;
                8'd52 : status_readdata_top <= pcie_tx_max_nb_req_dscs_status;
                8'd53 : status_readdata_top <= pcie_tx_dma_pkt_cnt_status;
                8'd54 : status_readdata_top <= pcie_top_full_signals_1_status;
                8'd55 : status_readdata_top <= pcie_top_full_signals_2_status;
                default : status_readdata_top <= 32'h345;
            endcase
        end
    end
end

// Top has higher priority.
always @(posedge clk_status) begin
    if (status_readdata_valid_top) begin
        status_readdata_valid <= 1'b1;
        status_readdata <= status_readdata_top;
    end else if (status_readdata_valid_pcie) begin
        status_readdata_valid <= 1'b1;
        status_readdata <= status_readdata_pcie;
    end else begin
        status_readdata_valid <= 1'b0;
    end
end


assign input_comp_eth_data  = reg_in_data;
assign input_comp_eth_valid = reg_in_valid;
assign input_comp_eth_sop   = reg_in_sop;
assign input_comp_eth_eop   = reg_in_eop;
assign input_comp_eth_empty = reg_in_empty;

assign out_valid_int = eth_out_pkt_fifo_out_valid & !reg_out_almost_full;

// Connect flow_director with flow_table_wrapper.
assign fdw_in_meta_data  = flow_table_wrapper_out_meta_data;
assign fdw_in_meta_valid = flow_table_wrapper_out_meta_valid;
assign flow_table_wrapper_out_ready = fdw_in_meta_ready;


// Sync disable_pcie to clk_datamover domain.
always @(posedge clk_datamover) begin
    dm_disable_pcie_r1 <= disable_pcie;
    dm_disable_pcie <= dm_disable_pcie_r1;
end

logic [511:0] rate_limiter_inst_out_pkt_data;
logic         rate_limiter_inst_out_pkt_valid;
logic         rate_limiter_inst_out_pkt_ready;
logic         rate_limiter_inst_out_pkt_sop;
logic         rate_limiter_inst_out_pkt_eop;
logic [5:0]   rate_limiter_inst_out_pkt_empty;

rate_limiter rate_limiter_inst (
    .clk           (clk_datamover),
    .rst           (rst_datamover),
    .in_pkt_data   (dm_eth_pkt_data),
    .in_pkt_valid  (dm_eth_pkt_valid),
    .in_pkt_ready  (dm_eth_pkt_ready),
    .in_pkt_sop    (dm_eth_pkt_sop),
    .in_pkt_eop    (dm_eth_pkt_eop),
    .in_pkt_empty  (dm_eth_pkt_empty),
    .out_pkt_data  (rate_limiter_inst_out_pkt_data),
    .out_pkt_valid (rate_limiter_inst_out_pkt_valid),
    .out_pkt_ready (rate_limiter_inst_out_pkt_ready),
    .out_pkt_sop   (rate_limiter_inst_out_pkt_sop),
    .out_pkt_eop   (rate_limiter_inst_out_pkt_eop),
    .out_pkt_empty (rate_limiter_inst_out_pkt_empty),
    .conf_rl_data  (conf_rl_data),
    .conf_rl_valid (conf_rl_valid),
    .conf_rl_ready (conf_rl_ready)
);

logic [511:0] timestamp_inst_rx_out_pkt_data;
logic         timestamp_inst_rx_out_pkt_valid;
logic         timestamp_inst_rx_out_pkt_sop;
logic         timestamp_inst_rx_out_pkt_eop;
logic [5:0]   timestamp_inst_rx_out_pkt_empty;

logic [511:0] timestamp_inst_tx_in_pkt_data;
logic         timestamp_inst_tx_in_pkt_valid;
logic         timestamp_inst_tx_in_pkt_ready;
logic         timestamp_inst_tx_in_pkt_sop;
logic         timestamp_inst_tx_in_pkt_eop;
logic [5:0]   timestamp_inst_tx_in_pkt_empty;

logic [511:0] timestamp_inst_tx_out_pkt_data;
logic         timestamp_inst_tx_out_pkt_valid;
logic         timestamp_inst_tx_out_pkt_ready;
logic         timestamp_inst_tx_out_pkt_sop;
logic         timestamp_inst_tx_out_pkt_eop;
logic [5:0]   timestamp_inst_tx_out_pkt_empty;

// FIFO to store and forward packets before they reach the Ethernet core.
// This is essential to remove any "gaps" in between flits (cycles between
// `startofpacket` and `endofpacket` where `valid` is not asserted).
// Placing `fifo_pkt_wrapper` before `timestamp_inst` also prevents inflated
// RTT measurements when sending multi-flit packets at a very low rate. As
// `fifo_pkt_wrapper` may need to wait many cycles before the remaining flits
// for the packet arrive.
fifo_pkt_wrapper #(
    .FIFO_DEPTH(64),
    .USE_STORE_FORWARD(1)  // Must use store and forward here.
) out_eth_store_forward_fifo (
    .clk               (clk_datamover),
    .reset             (rst_datamover),
    .in_data           (rate_limiter_inst_out_pkt_data),
    .in_valid          (rate_limiter_inst_out_pkt_valid),
    .in_ready          (rate_limiter_inst_out_pkt_ready),
    .in_startofpacket  (rate_limiter_inst_out_pkt_sop),
    .in_endofpacket    (rate_limiter_inst_out_pkt_eop),
    .in_empty          (rate_limiter_inst_out_pkt_empty),
    .out_data          (timestamp_inst_tx_in_pkt_data),
    .out_valid         (timestamp_inst_tx_in_pkt_valid),
    .out_ready         (timestamp_inst_tx_in_pkt_ready),
    .out_startofpacket (timestamp_inst_tx_in_pkt_sop),
    .out_endofpacket   (timestamp_inst_tx_in_pkt_eop),
    .out_empty         (timestamp_inst_tx_in_pkt_empty)
);

timestamp timestamp_inst (
    .clk              (clk_datamover),
    .rst              (rst_datamover),
    .rx_in_pkt_data   (in_data),
    .rx_in_pkt_valid  (in_valid),
    .rx_in_pkt_ready  (),
    .rx_in_pkt_sop    (in_sop),
    .rx_in_pkt_eop    (in_eop),
    .rx_in_pkt_empty  (in_empty),
    .rx_out_pkt_data  (timestamp_inst_rx_out_pkt_data),
    .rx_out_pkt_valid (timestamp_inst_rx_out_pkt_valid),
    .rx_out_pkt_ready (1'b1),
    .rx_out_pkt_sop   (timestamp_inst_rx_out_pkt_sop),
    .rx_out_pkt_eop   (timestamp_inst_rx_out_pkt_eop),
    .rx_out_pkt_empty (timestamp_inst_rx_out_pkt_empty),
    .tx_in_pkt_data   (timestamp_inst_tx_in_pkt_data),
    .tx_in_pkt_valid  (timestamp_inst_tx_in_pkt_valid),
    .tx_in_pkt_ready  (timestamp_inst_tx_in_pkt_ready),
    .tx_in_pkt_sop    (timestamp_inst_tx_in_pkt_sop),
    .tx_in_pkt_eop    (timestamp_inst_tx_in_pkt_eop),
    .tx_in_pkt_empty  (timestamp_inst_tx_in_pkt_empty),
    .tx_out_pkt_data  (timestamp_inst_tx_out_pkt_data),
    .tx_out_pkt_valid (timestamp_inst_tx_out_pkt_valid),
    .tx_out_pkt_ready (timestamp_inst_tx_out_pkt_ready),
    .tx_out_pkt_sop   (timestamp_inst_tx_out_pkt_sop),
    .tx_out_pkt_eop   (timestamp_inst_tx_out_pkt_eop),
    .tx_out_pkt_empty (timestamp_inst_tx_out_pkt_empty),
    .conf_ts_data     (conf_ts_data),
    .conf_ts_valid    (conf_ts_valid),
    .conf_ts_ready    (conf_ts_ready)
);

hyper_pipe_root reg_io_inst (
    // Clk & rst.
    .clk           (clk),
    .rst           (rst),
    .clk_datamover (clk_datamover),
    .rst_datamover (rst_datamover),

    // Ethernet in & out data.
    .in_data         (timestamp_inst_rx_out_pkt_data),
    .in_valid        (timestamp_inst_rx_out_pkt_valid),
    .in_sop          (timestamp_inst_rx_out_pkt_sop),
    .in_eop          (timestamp_inst_rx_out_pkt_eop),
    .in_empty        (timestamp_inst_rx_out_pkt_empty),
    .out_data        (eth_out_pkt_fifo_out_data),
    .out_valid       (out_valid_int),
    .out_almost_full (out_almost_full),
    .out_sop         (eth_out_pkt_fifo_out_sop),
    .out_eop         (eth_out_pkt_fifo_out_eop),
    .out_empty       (eth_out_pkt_fifo_out_empty),

    // eSRAM.
    .esram_pkt_buf_wren      (esram_pkt_buf_wren),
    .esram_pkt_buf_wraddress (esram_pkt_buf_wraddress),
    .esram_pkt_buf_wrdata    (esram_pkt_buf_wrdata),
    .esram_pkt_buf_rden      (esram_pkt_buf_rden),
    .esram_pkt_buf_rdaddress (esram_pkt_buf_rdaddress),
    .esram_pkt_buf_rd_valid  (esram_pkt_buf_rd_valid),
    .esram_pkt_buf_rddata    (esram_pkt_buf_rddata),

    // Output.
    .reg_in_data                 (reg_in_data),
    .reg_in_valid                (reg_in_valid),
    .reg_in_sop                  (reg_in_sop),
    .reg_in_eop                  (reg_in_eop),
    .reg_in_empty                (reg_in_empty),
    .reg_out_data                (out_data),
    .reg_out_valid               (out_valid),
    .reg_out_almost_full         (reg_out_almost_full),
    .reg_out_sop                 (out_sop),
    .reg_out_eop                 (out_eop),
    .reg_out_empty               (out_empty),
    .reg_esram_pkt_buf_wren      (reg_esram_pkt_buf_wren),
    .reg_esram_pkt_buf_wraddress (reg_esram_pkt_buf_wraddress),
    .reg_esram_pkt_buf_wrdata    (reg_esram_pkt_buf_wrdata),
    .reg_esram_pkt_buf_rden      (reg_esram_pkt_buf_rden),
    .reg_esram_pkt_buf_rdaddress (reg_esram_pkt_buf_rdaddress),
    .reg_esram_pkt_buf_rd_valid  (reg_esram_pkt_buf_rd_valid),
    .reg_esram_pkt_buf_rddata    (reg_esram_pkt_buf_rddata)
);

input_comp input_comp_0 (
    .clk                    (clk_datamover),
    .rst                    (rst_datamover),
    .eth_sop                (input_comp_eth_sop),
    .eth_eop                (input_comp_eth_eop),
    .eth_data               (input_comp_eth_data),
    .eth_empty              (input_comp_eth_empty),
    .eth_valid              (input_comp_eth_valid),
    .pkt_buffer_address     (esram_pkt_buf_wraddress),
    .pkt_buffer_write       (esram_pkt_buf_wren),
    .pkt_buffer_writedata   (esram_pkt_buf_wrdata),
    .emptylist_out_data     (emptylist_out_data),
    .emptylist_out_valid    (emptylist_out_valid),
    .emptylist_out_ready    (emptylist_out_ready),
    .pkt_sop                (input_comp_pkt_sop),
    .pkt_eop                (input_comp_pkt_eop),
    .pkt_valid              (input_comp_pkt_valid),
    .pkt_data               (input_comp_pkt_data),
    .pkt_empty              (input_comp_pkt_empty),
    .pkt_ready              (input_comp_pkt_ready),
    .meta_valid             (input_comp_metadata_valid),
    .meta_data              (input_comp_metadata_data),
    .meta_ready             (input_comp_metadata_ready)
);

parser parser_0 (
    .clk            (clk_datamover),
    .rst            (rst_datamover),
    .disable_pcie   (dm_disable_pcie),
    .in_pkt_data    (input_comp_pkt_data),
    .in_pkt_valid   (input_comp_pkt_valid),
    .in_pkt_ready   (input_comp_pkt_ready),
    .in_pkt_sop     (input_comp_pkt_sop),
    .in_pkt_eop     (input_comp_pkt_eop),
    .in_pkt_empty   (input_comp_pkt_empty),
    .out_pkt_data   (),
    .out_pkt_valid  (),
    .out_pkt_ready  (),
    .out_pkt_sop    (),
    .out_pkt_eop    (),
    .out_pkt_empty  (),
    .in_meta_data   (input_comp_metadata_data),
    .in_meta_valid  (input_comp_metadata_valid),
    .in_meta_ready  (input_comp_metadata_ready),
    .out_meta_data  (parser_out_meta_data),
    .out_meta_valid (parser_out_meta_valid),
    .out_meta_ready (parser_out_meta_ready)
);

// FIFO big enough to hold a metadata for every packet in the packet buffer.
dc_fifo_wrapper_infill  #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL(META_WIDTH),
    .FIFO_DEPTH(PKT_NUM),
    .USE_PACKETS(0)
)
parser_out_fifo (
    .in_clk            (clk_datamover),
    .in_reset_n        (!rst_datamover),
    .out_clk           (clk),
    .out_reset_n       (!rst),
    .in_csr_address    (1'b0),
    .in_csr_read       (1'b1),
    .in_csr_write      (1'b0),
    .in_csr_readdata   (parser_out_meta_csr_readdata),
    .in_csr_writedata  (32'b0),
    .in_data           (parser_out_meta_data),
    .in_valid          (parser_out_meta_valid),
    .in_ready          (parser_out_meta_ready),
    .in_startofpacket  (1'b0),
    .in_endofpacket    (1'b0),
    .in_empty          (6'b0),
    .out_data          (parser_out_fifo_out_data),
    .out_valid         (parser_out_fifo_out_valid),
    .out_ready         (parser_out_fifo_out_ready),
    .out_startofpacket (),
    .out_endofpacket   (),
    .out_empty         ()
);

configurator configurator_inst (
    .clk               (clk),
    .rst               (rst),
    .in_config_data    (in_config_data),
    .in_config_valid   (in_config_valid),
    .in_config_ready   (in_config_ready),
    .out_conf_ft_data  (conf_ft_data),
    .out_conf_ft_valid (conf_ft_valid),
    .out_conf_ft_ready (conf_ft_ready),
    .out_conf_ts_data  (conf_ts_data),
    .out_conf_ts_valid (conf_ts_valid),
    .out_conf_ts_ready (conf_ts_ready),
    .out_conf_rl_data  (conf_rl_data),
    .out_conf_rl_valid (conf_rl_valid),
    .out_conf_rl_ready (conf_rl_ready)
);

dc_fifo_wrapper_infill  #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL($bits(config_flit_t)),
    .FIFO_DEPTH(1024),
    .USE_PACKETS(0)
)
pcie_out_config_fifo (
    .in_clk            (clk_pcie),
    .in_reset_n        (!rst),
    .out_clk           (clk),
    .out_reset_n       (!rst),
    .in_csr_address    (1'b0),
    .in_csr_read       (1'b1),
    .in_csr_write      (1'b0),
    .in_csr_readdata   (pcie_out_config_fifo_occup),
    .in_csr_writedata  (32'b0),
    .in_data           (pcie_out_config_data),
    .in_valid          (pcie_out_config_valid),
    .in_ready          (pcie_out_config_ready),
    .in_startofpacket  (1'b0),
    .in_endofpacket    (1'b0),
    .in_empty          (6'h0),
    .out_data          (in_config_data),
    .out_valid         (in_config_valid),
    .out_ready         (in_config_ready),
    .out_startofpacket (),
    .out_endofpacket   (),
    .out_empty         ()
);

flow_table_wrapper flow_table_wrapper_0 (
    .clk              (clk),
    .rst              (rst),
    .in_meta_data     (parser_out_fifo_out_data),
    .in_meta_valid    (parser_out_fifo_out_valid),
    .in_meta_ready    (parser_out_fifo_out_ready),
    .out_meta_data    (flow_table_wrapper_out_meta_data),
    .out_meta_valid   (flow_table_wrapper_out_meta_valid),
    .out_meta_ready   (flow_table_wrapper_out_ready),
    .in_control_data  (conf_ft_data),
    .in_control_valid (conf_ft_valid),
    .in_control_ready (conf_ft_ready),
    .out_control_done (flow_table_wrapper_out_control_done),
    .eviction_cnt     (eviction_cnt)
 );

flow_director flow_director_inst (
    .clk                (clk),
    .rst                (rst),
    .in_meta_data       (fdw_in_meta_data),
    .in_meta_valid      (fdw_in_meta_valid),
    .in_meta_ready      (fdw_in_meta_ready),
    .out_meta_data      (fdw_out_meta_data),
    .out_meta_valid     (fdw_out_meta_valid),
    .out_meta_ready     (fdw_out_meta_ready),
    .nb_fallback_queues (nb_fallback_queues),
    .enable_rr          (enable_rr)
);

dc_fifo_wrapper_infill  #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL(META_WIDTH),
    .FIFO_DEPTH(PKT_NUM*2),
    .USE_PACKETS(0)
)
flow_director_out_fifo (
    .in_clk            (clk),
    .in_reset_n        (!rst),
    .out_clk           (clk_datamover),
    .out_reset_n       (!rst_datamover),
    .in_csr_address    (1'b0),
    .in_csr_read       (1'b1),
    .in_csr_write      (1'b0),
    .in_csr_readdata   (fdw_out_meta_csr_readdata),
    .in_csr_writedata  (32'b0),
    .in_data           (fdw_out_meta_data),
    .in_valid          (fdw_out_meta_valid),
    .in_ready          (fdw_out_meta_ready),
    .in_startofpacket  (1'b0),
    .in_endofpacket    (1'b0),
    .in_empty          (6'b0),
    .out_data          (dm_in_meta_data),
    .out_valid         (dm_in_meta_valid),
    .out_ready         (dm_in_meta_ready),
    .out_startofpacket (),
    .out_endofpacket   (),
    .out_empty         ()
);

basic_data_mover data_mover_0 (
    .clk                      (clk_datamover),
    .rst                      (rst_datamover),
    .meta_valid               (dm_in_meta_valid),
    .meta_data                (dm_in_meta_data),
    .meta_ready               (dm_in_meta_ready),
    .pkt_buffer_address       (esram_pkt_buf_rdaddress),
    .pkt_buffer_read          (esram_pkt_buf_rden),
    .pkt_buffer_readvalid     (reg_esram_pkt_buf_rd_valid),
    .pkt_buffer_readdata      (reg_esram_pkt_buf_rddata),
    .emptylist_in_data        (emptylist_in_data),
    .emptylist_in_valid       (emptylist_in_valid),
    .emptylist_in_ready       (emptylist_in_ready),
    .disable_pcie             (dm_disable_pcie),
    .pcie_rx_pkt_sop          (dm_pcie_rx_pkt_sop),
    .pcie_rx_pkt_eop          (dm_pcie_rx_pkt_eop),
    .pcie_rx_pkt_valid        (dm_pcie_rx_pkt_valid),
    .pcie_rx_pkt_data         (dm_pcie_rx_pkt_data),
    .pcie_rx_pkt_empty        (dm_pcie_rx_pkt_empty),
    .pcie_rx_pkt_ready        (dm_pcie_rx_pkt_ready),
    .pcie_rx_pkt_almost_full  (dm_pcie_rx_pkt_almost_full),
    .pcie_rx_meta_valid       (dm_pcie_rx_meta_valid),
    .pcie_rx_meta_data        (dm_pcie_rx_meta_data),
    .pcie_rx_meta_ready       (dm_pcie_rx_meta_ready),
    .pcie_rx_meta_almost_full (dm_pcie_rx_meta_almost_full),
    .pcie_tx_pkt_sop          (dm_pcie_tx_pkt_sop),
    .pcie_tx_pkt_eop          (dm_pcie_tx_pkt_eop),
    .pcie_tx_pkt_valid        (dm_pcie_tx_pkt_valid),
    .pcie_tx_pkt_data         (dm_pcie_tx_pkt_data),
    .pcie_tx_pkt_empty        (dm_pcie_tx_pkt_empty),
    .pcie_tx_pkt_ready        (dm_pcie_tx_pkt_ready),
    .eth_pkt_sop              (dm_eth_pkt_sop),
    .eth_pkt_eop              (dm_eth_pkt_eop),
    .eth_pkt_valid            (dm_eth_pkt_valid),
    .eth_pkt_data             (dm_eth_pkt_data),
    .eth_pkt_empty            (dm_eth_pkt_empty),
    .eth_pkt_ready            (dm_eth_pkt_ready),
    .eth_pkt_almost_full      (dm_eth_pkt_almost_full)
);

localparam DM2PCIE_FIFO_DEPTH = 512;

//////////////////// Datamover To PCIe FIFO //////////////////////////////////
dc_fifo_wrapper_infill  #(
    .SYMBOLS_PER_BEAT(64),
    .BITS_PER_SYMBOL(8),
    .FIFO_DEPTH(DM2PCIE_FIFO_DEPTH),
    .USE_PACKETS(1)
)
dm2pcie_fifo (
    .in_clk            (clk_datamover),
    .in_reset_n        (!rst_datamover),
    .out_clk           (clk_pcie),
    .out_reset_n       (!rst_pcie),
    .in_csr_address    (1'b0),
    .in_csr_read       (1'b1),
    .in_csr_write      (1'b0),
    .in_csr_readdata   (dm_pcie_rx_pkt_in_csr_readdata),
    .in_csr_writedata  (32'b0),
    .in_data           (dm_pcie_rx_pkt_data),
    .in_valid          (dm_pcie_rx_pkt_valid),
    .in_ready          (dm_pcie_rx_pkt_ready),
    .in_startofpacket  (dm_pcie_rx_pkt_sop),
    .in_endofpacket    (dm_pcie_rx_pkt_eop),
    .in_empty          (dm_pcie_rx_pkt_empty),
    .out_data          (pcie_rx_pkt_data),
    .out_valid         (pcie_rx_pkt_valid),
    .out_ready         (pcie_rx_pkt_ready),
    .out_startofpacket (pcie_rx_pkt_sop),
    .out_endofpacket   (pcie_rx_pkt_eop),
    .out_empty         (pcie_rx_pkt_empty)
);

dc_back_pressure #(
    .FULL_LEVEL(DM2PCIE_FIFO_DEPTH - (2 * MAX_PKT_SIZE))
)
bp_dm2pcie_fifo (
    .clk            (clk_datamover),
    .rst            (rst_datamover),
    .csr_address    (),
    .csr_read       (),
    .csr_write      (),
    .csr_readdata   (dm_pcie_rx_pkt_in_csr_readdata),
    .csr_writedata  (),
    .almost_full    (dm_pcie_rx_pkt_almost_full)
);

dc_fifo_wrapper_infill  #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL(META_WIDTH),
    .FIFO_DEPTH(PKT_NUM),
    .USE_PACKETS(0)
)
dm2pcie_meta_fifo (
    .in_clk            (clk_datamover),
    .in_reset_n        (!rst_datamover),
    .out_clk           (clk_pcie),
    .out_reset_n       (!rst_pcie),
    .in_csr_address    (1'b0),
    .in_csr_read       (1'b1),
    .in_csr_write      (1'b0),
    .in_csr_readdata   (dm_pcie_rx_meta_in_csr_readdata),
    .in_csr_writedata  (32'b0),
    .in_data           (dm_pcie_rx_meta_data),
    .in_valid          (dm_pcie_rx_meta_valid),
    .in_ready          (dm_pcie_rx_meta_ready),
    .in_startofpacket  (1'b0),
    .in_endofpacket    (1'b0),
    .in_empty          (6'b0),
    .out_data          (pcie_rx_meta_data),
    .out_valid         (pcie_rx_meta_valid),
    .out_ready         (pcie_rx_meta_ready),
    .out_startofpacket (),
    .out_endofpacket   (),
    .out_empty         ()
);

dc_back_pressure #(
    .FULL_LEVEL(PKT_NUM - (2 * MAX_PKT_SIZE))
)
bp_dm2pcie_meta_fifo (
    .clk            (clk_datamover),
    .rst            (rst_datamover),
    .csr_address    (),
    .csr_read       (),
    .csr_write      (),
    .csr_readdata   (dm_pcie_rx_meta_in_csr_readdata),
    .csr_writedata  (),
    .almost_full    (dm_pcie_rx_meta_almost_full)
);

dc_fifo_wrapper_infill  #(
    .SYMBOLS_PER_BEAT(64),
    .BITS_PER_SYMBOL(8),
    .FIFO_DEPTH(PCIE_TX_PKT_FIFO_DEPTH),
    .USE_PACKETS(1)
)
pcie_tx_pkt_fifo (
    .in_clk            (clk_pcie),
    .in_reset_n        (!rst),
    .out_clk           (clk_datamover),
    .out_reset_n       (!rst_datamover),
    .in_csr_address    (1'b0),
    .in_csr_read       (1'b1),
    .in_csr_write      (1'b0),
    .in_csr_readdata   (pcie_tx_pkt_fifo_occup),
    .in_csr_writedata  (32'b0),
    .in_data           (pcie_tx_pkt_data),
    .in_valid          (pcie_tx_pkt_valid),
    .in_ready          (pcie_tx_pkt_ready),
    .in_startofpacket  (pcie_tx_pkt_sop),
    .in_endofpacket    (pcie_tx_pkt_eop),
    .in_empty          (pcie_tx_pkt_empty),
    .out_data          (dm_pcie_tx_pkt_data),
    .out_valid         (dm_pcie_tx_pkt_valid),
    .out_ready         (dm_pcie_tx_pkt_ready),
    .out_startofpacket (dm_pcie_tx_pkt_sop),
    .out_endofpacket   (dm_pcie_tx_pkt_eop),
    .out_empty         (dm_pcie_tx_pkt_empty)
);
//////////////////// Datamover To PDU_GEN //////////////////////////////////

pdu_gen pdu_gen_inst(
    .clk                  (clk_pcie),
    .rst                  (rst_pcie),
    .in_sop               (pcie_rx_pkt_sop),
    .in_eop               (pcie_rx_pkt_eop),
    .in_data              (pcie_rx_pkt_data),
    .in_empty             (pcie_rx_pkt_empty),
    .in_valid             (pcie_rx_pkt_valid),
    .in_ready             (pcie_rx_pkt_ready),
    .in_meta_valid        (pcie_rx_meta_valid),
    .in_meta_data         (pcie_rx_meta_data),
    .in_meta_ready        (pcie_rx_meta_ready),
    .pcie_pkt_buf_data    (pcie_pkt_buf_data),
    .pcie_pkt_buf_valid   (pcie_pkt_buf_valid),
    .pcie_pkt_buf_ready   (pcie_pkt_buf_ready),
    .pcie_meta_buf_data   (pcie_meta_buf_data),
    .pcie_meta_buf_valid  (pcie_meta_buf_valid),
    .pcie_meta_buf_ready  (pcie_meta_buf_ready),
    .out_pkt_queue_occup  (out_pkt_queue_occup),
    .out_meta_queue_occup (out_meta_queue_occup)
);

localparam ETH_OUT_PKT_FIFO_DEPTH = 512;

//////////////////// To OUTPUT FIFO //////////////////////////////////
dc_fifo_wrapper_infill #(
    .FIFO_DEPTH(ETH_OUT_PKT_FIFO_DEPTH)
) eth_out_pkt_fifo (
    .in_clk            (clk_datamover),
    .in_reset_n        (!rst_datamover),
    .out_clk           (clk),
    .out_reset_n       (!rst),
    .in_csr_address    (1'b0),
    .in_csr_read       (1'b1),
    .in_csr_write      (1'b0),
    .in_csr_readdata   (dm_eth_pkt_in_csr_readdata),
    .in_csr_writedata  (),
    .in_data           (timestamp_inst_tx_out_pkt_data),
    .in_valid          (timestamp_inst_tx_out_pkt_valid),
    .in_ready          (timestamp_inst_tx_out_pkt_ready),
    .in_startofpacket  (timestamp_inst_tx_out_pkt_sop),
    .in_endofpacket    (timestamp_inst_tx_out_pkt_eop),
    .in_empty          (timestamp_inst_tx_out_pkt_empty),
    .out_data          (eth_out_pkt_fifo_out_data),
    .out_valid         (eth_out_pkt_fifo_out_valid),
    .out_ready         (!reg_out_almost_full),
    .out_startofpacket (eth_out_pkt_fifo_out_sop),
    .out_endofpacket   (eth_out_pkt_fifo_out_eop),
    .out_empty         (eth_out_pkt_fifo_out_empty)
);

dc_back_pressure #(
    .FULL_LEVEL(ETH_OUT_PKT_FIFO_DEPTH - (2 * MAX_PKT_SIZE))
)
dc_bp_output_pkt_fifo (
    .clk            (clk_datamover),
    .rst            (rst_datamover),
    .csr_address    (),
    .csr_read       (),
    .csr_write      (),
    .csr_readdata   (dm_eth_pkt_in_csr_readdata),
    .csr_writedata  (),
    .almost_full    (dm_eth_pkt_almost_full)
);

// We don't care about configuration delay.
hyperpipe_vlat #(
    .WIDTH($bits(eth_port_nb)),
    .MAX_PIPE(100)
) eth_port_nb_hp_vlat (
    .clk (clk_datamover),
    .din (pcie_eth_port_nb),
    .dout(eth_port_nb)
);


//////////////////// PKT BUFFER and its Emptylist //////////////////////////////
dc_fifo_wrapper #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL(PKT_AWIDTH),
    .FIFO_DEPTH(PKT_NUM),
    .USE_PACKETS(0)
)
pktbuf_emptylist (
    .in_clk                 (clk_datamover),
    .in_reset_n             (!rst_datamover),
    .out_clk                (clk_datamover),
    .out_reset_n            (!rst_datamover),
    .in_data                (emptylist_in_data),
    .in_valid               (emptylist_in_valid),
    .in_ready               (emptylist_in_ready),
    .in_startofpacket       (1'b0),
    .in_endofpacket         (1'b0),
    .in_empty               (6'b0),
    .out_data               (emptylist_out_data),
    .out_valid              (emptylist_out_valid),
    .out_ready              (emptylist_out_ready),
    .out_startofpacket      (),
    .out_endofpacket        (),
    .out_empty              ()
);

//////////////////PCIe logic ////////////////
pcie_top pcie (
    .pcie_clk                 (clk_pcie),
    .pcie_reset_n             (!rst),
    .pcie_wrdm_desc_ready     (pcie_wrdm_desc_ready),
    .pcie_wrdm_desc_valid     (pcie_wrdm_desc_valid),
    .pcie_wrdm_desc_data      (pcie_wrdm_desc_data),
    .pcie_wrdm_prio_ready     (pcie_wrdm_prio_ready),
    .pcie_wrdm_prio_valid     (pcie_wrdm_prio_valid),
    .pcie_wrdm_prio_data      (pcie_wrdm_prio_data),
    .pcie_wrdm_tx_valid       (pcie_wrdm_tx_valid),
    .pcie_wrdm_tx_data        (pcie_wrdm_tx_data),
    .pcie_rddm_desc_ready     (pcie_rddm_desc_ready),
    .pcie_rddm_desc_valid     (pcie_rddm_desc_valid),
    .pcie_rddm_desc_data      (pcie_rddm_desc_data),
    .pcie_rddm_prio_ready     (pcie_rddm_prio_ready),
    .pcie_rddm_prio_valid     (pcie_rddm_prio_valid),
    .pcie_rddm_prio_data      (pcie_rddm_prio_data),
    .pcie_rddm_tx_valid       (pcie_rddm_tx_valid),
    .pcie_rddm_tx_data        (pcie_rddm_tx_data),
    .pcie_bas_waitrequest     (pcie_bas_waitrequest),
    .pcie_bas_address         (pcie_bas_address),
    .pcie_bas_byteenable      (pcie_bas_byteenable),
    .pcie_bas_read            (pcie_bas_read),
    .pcie_bas_readdata        (pcie_bas_readdata),
    .pcie_bas_readdatavalid   (pcie_bas_readdatavalid),
    .pcie_bas_write           (pcie_bas_write),
    .pcie_bas_writedata       (pcie_bas_writedata),
    .pcie_bas_burstcount      (pcie_bas_burstcount),
    .pcie_bas_response        (pcie_bas_response),
    .pcie_address_0           (pcie_address_0),
    .pcie_write_0             (pcie_write_0),
    .pcie_read_0              (pcie_read_0),
    .pcie_readdatavalid_0     (pcie_readdatavalid_0),
    .pcie_readdata_0          (pcie_readdata_0),
    .pcie_writedata_0         (pcie_writedata_0),
    .pcie_byteenable_0        (pcie_byteenable_0),
    .pcie_rddm_address        (pcie_rddm_address),
    .pcie_rddm_write          (pcie_rddm_write),
    .pcie_rddm_writedata      (pcie_rddm_writedata),
    .pcie_rddm_byteenable     (pcie_rddm_byteenable),
    .pcie_rddm_waitrequest    (pcie_rddm_waitrequest),
    .pcie_rx_pkt_buf_data     (pcie_pkt_buf_data),
    .pcie_rx_pkt_buf_valid    (pcie_pkt_buf_valid),
    .pcie_rx_pkt_buf_ready    (pcie_pkt_buf_ready),
    .pcie_rx_pkt_buf_occup    (pcie_pkt_buf_occup),
    .pcie_rx_meta_buf_data    (pcie_meta_buf_data),
    .pcie_rx_meta_buf_valid   (pcie_meta_buf_valid),
    .pcie_rx_meta_buf_ready   (pcie_meta_buf_ready),
    .pcie_rx_meta_buf_occup   (pcie_meta_buf_occup),
    .pcie_tx_pkt_sop          (pcie_tx_pkt_sop),
    .pcie_tx_pkt_eop          (pcie_tx_pkt_eop),
    .pcie_tx_pkt_valid        (pcie_tx_pkt_valid),
    .pcie_tx_pkt_data         (pcie_tx_pkt_data),
    .pcie_tx_pkt_empty        (pcie_tx_pkt_empty),
    .pcie_tx_pkt_ready        (pcie_tx_pkt_ready),
    .pcie_tx_pkt_occup        (pcie_tx_pkt_fifo_occup),
    .out_config_data          (pcie_out_config_data),
    .out_config_valid         (pcie_out_config_valid),
    .out_config_ready         (pcie_out_config_ready),
    .disable_pcie             (disable_pcie),
    .sw_reset                 (sw_reset),
    .nb_fallback_queues       (nb_fallback_queues),
    .enable_rr                (enable_rr),
    .eth_port_nb              (pcie_eth_port_nb),
    .pcie_core_full_cnt       (pcie_core_full_cnt),
    .rx_dma_dsc_cnt           (rx_dma_dsc_cnt),
    .rx_dma_dsc_drop_cnt      (rx_dma_dsc_drop_cnt),
    .rx_dma_pkt_flit_cnt      (rx_dma_pkt_flit_cnt),
    .rx_dma_pkt_flit_drop_cnt (rx_dma_pkt_flit_drop_cnt),
    .cpu_dsc_buf_full_cnt     (cpu_dsc_buf_full_cnt),
    .cpu_dsc_buf_in_cnt       (cpu_dsc_buf_in_cnt),
    .cpu_dsc_buf_out_cnt      (cpu_dsc_buf_out_cnt),
    .cpu_pkt_buf_full_cnt     (cpu_pkt_buf_full_cnt),
    .cpu_pkt_buf_in_cnt       (cpu_pkt_buf_in_cnt),
    .cpu_pkt_buf_out_cnt      (cpu_pkt_buf_out_cnt),
    .st_ord_in_cnt            (pcie_st_ord_in_cnt),
    .st_ord_out_cnt           (pcie_st_ord_out_cnt),
    .rx_ignored_head_cnt      (pcie_rx_ignored_head_cnt),
    .tx_q_full_signals        (pcie_tx_q_full_signals),
    .tx_dsc_cnt               (pcie_tx_dsc_cnt),
    .tx_empty_tail_cnt        (pcie_tx_empty_tail_cnt),
    .tx_dsc_read_cnt          (pcie_tx_dsc_read_cnt),
    .tx_pkt_read_cnt          (pcie_tx_pkt_read_cnt),
    .tx_batch_cnt             (pcie_tx_batch_cnt),
    .tx_max_inflight_dscs     (pcie_tx_max_inflight_dscs),
    .tx_max_nb_req_dscs       (pcie_tx_max_nb_req_dscs),
    .tx_dma_pkt_cnt           (pcie_tx_dma_pkt_cnt),
    .rx_pkt_head_upd_cnt      (pcie_rx_pkt_head_upd_cnt),
    .tx_dsc_tail_upd_cnt      (pcie_tx_dsc_tail_upd_cnt),
    .top_full_signals_1       (pcie_top_full_signals_1),
    .top_full_signals_2       (pcie_top_full_signals_2),
    .clk_status               (clk_status),
    .status_addr              (status_addr),
    .status_read              (status_read),
    .status_write             (status_write),
    .status_writedata         (status_writedata),
    .status_readdata          (status_readdata_pcie),
    .status_readdata_valid    (status_readdata_valid_pcie)
);

endmodule
