`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
`include "../src/constants.sv"
`include "../src/pcie/pcie_consts.sv"
module tb;

`ifndef PKT_FILE
`define PKT_FILE "./input_gen/m10_100.pkt"
`define PKT_FILE_NB_LINES 2400
`endif

`ifndef NB_FALLBACK_QUEUES
`define NB_FALLBACK_QUEUES 0
`endif

`ifndef NB_DSC_QUEUES
`define NB_DSC_QUEUES 4
`endif

`ifndef NB_PKT_QUEUES
`define NB_PKT_QUEUES 4
`endif

`ifndef PKT_SIZE
`define PKT_SIZE 64
`endif

`ifndef RATE
`define RATE 74 // in Gbps (without Ethernet overhead)
`endif

// `define DELAY_LAST_PKTS  // Set it to delay last packets for every queue.

`define SKIP_PCIE_RD  // Set it to skip PCIe read after simulation is done.

`define CHECK_QUEUE_HEAD_TAIL // Set it to check head and tail pointers for 
                              // every pkt queue at the end of the simulation.

// Number of cycles to delay PCIe signals.
localparam PCIE_DELAY = 125;

// Number of cycles to wait before stopping the simulation.
localparam STOP_DELAY = 2000000 + PCIE_DELAY;

// Set number of in-flight descriptor reads that are allowed in the TX path.
localparam NB_TX_CREDITS = 500;

// Number of cycles to wait before updating the head pointer for the pkt queue.
localparam UPDATE_HEAD_DELAY = 125;

// Size of the host buffer used by each queue (in flits).
localparam DSC_BUF_SIZE = 8192;
localparam PKT_BUF_SIZE = 8192;

// Ethernet port to use.
localparam ETH_PORT_NB = 1;

// Maximum number of flits that can be sent in a single TX transfer.
localparam MAX_FLITS_TX_TRANSFER = 16384;

// Rate limit configuration. Toggle `RATE_LIMIT_ENABLE` to enable/disable rate
// limiting in the TX path.
localparam RATE_LIMIT_ENABLE = 0;
localparam RATE_LIMIT_NUMERATOR = 70;
localparam RATE_LIMIT_DENOMINATOR = 100;

generate
  // We assume this during the test, it does not necessarily hold in general.
  if (((`NB_PKT_QUEUES / `NB_DSC_QUEUES) * `NB_DSC_QUEUES) != `NB_PKT_QUEUES)
  begin
    $error("NB_PKT_QUEUES must be a multiple of NB_DSC_QUEUES");
  end
endgenerate

localparam RAM_SIZE = DSC_BUF_SIZE + PKT_BUF_SIZE;
localparam RAM_ADDR_LEN = $clog2(RAM_SIZE);

// duration for each bit = 20 * timescale = 20 * 1 ns  = 20ns
localparam period = 10;
localparam period_rx = 2.56;
localparam period_tx = 2.56;
localparam period_user = 5;
localparam period_esram_ref = 10;
localparam period_esram = 5;
localparam period_pcie = 4;
localparam data_width = 528;
localparam lo = 0;
localparam hi = `PKT_FILE_NB_LINES;
localparam nb_dsc_queues = `NB_DSC_QUEUES;
localparam nb_pkt_queues = `NB_PKT_QUEUES;
localparam pkt_per_dsc_queue = nb_pkt_queues / nb_dsc_queues;

logic  clk_status;
logic  clk_rxmac;
logic  clk_txmac;
logic  clk_user;
logic  clk_datamover;
logic  clk_esram_ref;
logic  clk_esram;
logic  clk_pcie;

logic rst_datamover;

logic        rst;
logic [31:0] pkt_cnt;
logic [31:0] cnt;
logic [31:0] addr;
logic [63:0] nb_cycles;
logic [data_width -1:0] arr[lo:hi];
logic setup_finished;

// Ethernet signals.
logic  [511:0]  l8_rx_data;
logic  [5:0]    l8_rx_empty;
logic           l8_rx_valid;
logic           l8_rx_startofpacket;
logic           l8_rx_endofpacket;
logic           l8_rx_ready;

logic  [511:0]  stats_rx_data;
logic  [5:0]    stats_rx_empty;
logic           stats_rx_valid;
logic           stats_rx_startofpacket;
logic           stats_rx_endofpacket;
logic           stats_rx_ready;

logic  [511:0]  top_in_data;
logic  [5:0]    top_in_empty;
logic           top_in_valid;
logic           top_in_startofpacket;
logic           top_in_endofpacket;
logic  [511:0]  top_out_data;
logic  [5:0]    top_out_empty;
logic           top_out_valid;
logic           top_out_startofpacket;
logic           top_out_endofpacket;
logic           top_out_almost_full;

logic  [511:0]  reg_top_in_data;
logic  [5:0]    reg_top_in_empty;
logic           reg_top_in_valid;
logic           reg_top_in_startofpacket;
logic           reg_top_in_endofpacket;
logic  [511:0]  reg_top_out_data;
logic  [5:0]    reg_top_out_empty;
logic           reg_top_out_valid;
logic           reg_top_out_startofpacket;
logic           reg_top_out_endofpacket;
logic           reg_top_out_almost_full;
logic           reg_top_eth_port_nb;

logic  [511:0]  l8_tx_data;
logic  [5:0]    l8_tx_empty;
logic           l8_tx_valid;
logic           l8_tx_startofpacket;
logic           l8_tx_endofpacket;
logic           l8_tx_ready;

logic           out_fifo0_in_csr_address;
logic           out_fifo0_in_csr_read;
logic           out_fifo0_in_csr_write;
logic [31:0]    out_fifo0_in_csr_readdata;
logic [31:0]    out_fifo0_in_csr_writedata;

// Host RAM
logic [511:0] ram[nb_pkt_queues + nb_dsc_queues * 2][RAM_SIZE];

//PCIe signals
logic         delayed_pcie_wrdm_desc_valid;

logic         pcie_wrdm_desc_ready;
logic         pcie_wrdm_desc_valid;
logic [173:0] pcie_wrdm_desc_data;
logic         pcie_wrdm_prio_ready;
logic         pcie_wrdm_prio_valid;
logic [173:0] pcie_wrdm_prio_data;
logic         pcie_wrdm_tx_valid;
logic [31:0]  pcie_wrdm_tx_data;

logic         pcie_rddm_desc_ready;
logic         pcie_rddm_desc_valid;
logic [173:0] pcie_rddm_desc_data;
logic         pcie_rddm_prio_ready;
logic         pcie_rddm_prio_valid;
logic [173:0] pcie_rddm_prio_data;
logic         pcie_rddm_tx_valid;
logic [31:0]  pcie_rddm_tx_data;

logic         pcie_bas_waitrequest;
logic [63:0]  pcie_bas_address;
logic [63:0]  pcie_bas_byteenable;
logic         pcie_bas_read;
logic [511:0] pcie_bas_readdata;
logic         pcie_bas_readdatavalid;
logic         pcie_bas_write;
logic [511:0] pcie_bas_writedata;
logic [3:0]   pcie_bas_burstcount;
logic [1:0]   pcie_bas_response;
logic [PCIE_ADDR_WIDTH-1:0]  pcie_address_0;
logic         pcie_write_0;
logic         pcie_read_0;
logic         pcie_readdatavalid_0;
logic [511:0] pcie_readdata_0;
logic [511:0] pcie_writedata_0;
logic [63:0]  pcie_byteenable_0;

logic [63:0]  pcie_rddm_address;
logic         pcie_rddm_write;
logic [511:0] pcie_rddm_writedata;
logic [63:0]  pcie_rddm_byteenable;
logic         pcie_rddm_waitrequest;

logic [63:0]  top_pcie_rddm_address;
logic         top_pcie_rddm_write;
logic [511:0] top_pcie_rddm_writedata;
logic [63:0]  top_pcie_rddm_byteenable;
logic         top_pcie_rddm_waitrequest;

logic         error_termination;
logic         error_termination_r;
logic         stop;
logic [31:0]  stop_cnt;

//eSRAM signals
logic esram_pll_lock;
logic                      esram_pkt_buf_wren;
logic [PKTBUF_AWIDTH-1:0]  esram_pkt_buf_wraddress;
logic [519:0]              esram_pkt_buf_wrdata;
logic                      esram_pkt_buf_rden;
logic [PKTBUF_AWIDTH-1:0]  esram_pkt_buf_rdaddress;
logic                      esram_pkt_buf_rd_valid;
logic [519:0]              esram_pkt_buf_rddata;
logic                      reg_esram_pkt_buf_wren;
logic [PKTBUF_AWIDTH-1:0]  reg_esram_pkt_buf_wraddress;
logic [519:0]              reg_esram_pkt_buf_wrdata;
logic                      reg_esram_pkt_buf_rden;
logic [PKTBUF_AWIDTH-1:0]  reg_esram_pkt_buf_rdaddress;
logic                      reg_esram_pkt_buf_rd_valid;
logic [519:0]              reg_esram_pkt_buf_rddata;

//JTAG
logic [PCIE_ADDR_WIDTH-1:0] s_addr;
logic s_read;
logic s_write;
logic [31:0] s_writedata;
logic [31:0] s_readdata;
logic s_readdata_valid;
logic [15:0] s_cnt;
logic [31:0] top_readdata;
logic top_readdata_valid;
logic [31:0] dram_readdata;
logic dram_readdata_valid;

logic [3:0] tx_cnt;

logic [31:0] pktID;
logic [31:0] ft_pkt;

logic tx_dsc_tail_pending;
logic dma_write_pending;

logic [$bits(pcie_rddm_desc_data)-1:0] rddm_desc_queue_data;
logic        rddm_desc_queue_valid;
logic        rddm_desc_queue_ready;
logic [31:0] rddm_desc_queue_occup;

logic [$bits(pcie_rddm_desc_data)-1:0] rddm_prio_queue_data;
logic        rddm_prio_queue_valid;
logic        rddm_prio_queue_ready;
logic [31:0] rddm_prio_queue_occup;

logic [17:0] pending_dma_write_dwords;
logic [63:0] pending_dma_write_dst_addr;
logic [63:0] pending_dma_write_src_addr;

assign dma_write_pending = pending_dma_write_dwords > 0;
assign rddm_prio_queue_ready = !dma_write_pending;
assign rddm_desc_queue_ready = !dma_write_pending & !rddm_prio_queue_valid;

typedef enum{
  READ,
  WAIT
} state_t;

state_t read_state;

typedef enum{
  CONFIGURE_0,
  CONFIGURE_1,
  CONFIGURE_2,
  CONFIGURE_3,
  READ_MEMORY,
  READ_PCIE_START,
  READ_PCIE_PKT_Q,
  READ_PCIE_DSC_Q,
  IDLE,
  IN_PKT,
  OUT_PKT,
  IN_COMP_OUT_PKT,
  PARSER_OUT_PKT,
  MAX_PARSER_FIFO,
  FD_IN_PKT,
  FD_OUT_PKT,
  MAX_FD_OUT_FIFO,
  DM_IN_PKT,
  IN_EMPTYLIST_PKT,
  OUT_EMPTYLIST_PKT,
  PKT_ETH,
  PKT_DROP,
  PKT_PCIE,
  MAX_DM2PCIE_FIFO,
  MAX_DM2PCIE_META_FIFO,
  PCIE_PKT,
  PCIE_META,
  DM_PCIE_PKT,
  DM_PCIE_META,
  DM_ETH_PKT,
  RX_DMA_PKT,
  RX_PKT_HEAD_UPD,
  TX_DSC_TAIL_UPD,
  DMA_REQUEST,
  RULE_SET,
  EVICTION,
  MAX_PDUGEN_PKT_FIFO,
  MAX_PDUGEN_META_FIFO,
  PCIE_CORE_FULL,
  RX_DMA_DSC_CNT,
  RX_DMA_DSC_DROP_CNT,
  RX_DMA_PKT_FLIT_CNT,
  RX_DMA_PKT_FLIT_DROP_CNT,
  CPU_DSC_BUF_FULL,
  CPU_DSC_BUF_IN,
  CPU_DSC_BUF_OUT,
  CPU_PKT_BUF_FULL,
  CPU_PKT_BUF_IN,
  CPU_PKT_BUF_OUT,
  PCIE_ST_ORD_IN,
  PCIE_ST_ORD_OUT,
  MAX_PCIE_PKT_FIFO,
  MAX_PCIE_META_FIFO,
  PCIE_RX_IGNORED_HEAD,
  PCIE_TX_Q_FULL_SIGNALS,
  PCIE_TX_DSC_CNT,
  PCIE_TX_EMPTY_TAIL_CNT,
  PCIE_TX_DSC_READ_CNT,
  PCIE_TX_PKT_READ_CNT,
  PCIE_TX_BATCH_CNT,
  PCIE_TX_MAX_INFLIGHT_DSCS,
  PCIE_TX_MAX_NB_REQ_DSCS,
  TX_DMA_PKT,
  PCIE_FULL_SIGNALS_1,
  PCIE_FULL_SIGNALS_2
} c_state_t;

c_state_t conf_state;

initial clk_rxmac = 0;
initial clk_txmac = 1;
initial clk_user = 0;
initial clk_esram_ref = 0;
initial clk_esram = 0;
initial clk_pcie = 0;

initial clk_status = 0;
initial l8_tx_ready = 0;
initial tx_cnt = 0;

initial stop = 0;
initial stop_cnt = 0;
initial error_termination = 0;
initial setup_finished = 0;

initial rst = 1;
initial cnt = 0;
initial nb_cycles = 0;
always #(period) clk_status = ~clk_status;
always #(period_rx) clk_rxmac = ~clk_rxmac;
always #(period_tx) clk_txmac = ~clk_txmac;
always #(period_user) clk_user = ~clk_user;
always #(period_esram_ref) clk_esram_ref = ~clk_esram_ref;
always #(period_esram) clk_esram = ~clk_esram;
always #(period_pcie) clk_pcie = ~clk_pcie;

//
//read raw data
initial
  begin : init_block
    integer i;          // temporary for generate reset value
    for (i = lo; i < hi; i = i + 1) begin
      arr[i] = {((data_width + 1)/2){2'b0}};  // initial it as all zero
    end
    $readmemh(`PKT_FILE, arr, lo, hi-1); // read data from rom
  end // initial begin

assign l8_rx_startofpacket = arr[addr][524];
assign l8_rx_endofpacket = arr[addr][520];
assign l8_rx_empty = arr[addr][519:512];
assign l8_rx_data = arr[addr][511:0];
assign rst_datamover = rst | !esram_pll_lock;
assign clk_datamover = clk_esram;

always @(posedge clk_rxmac)
begin
  if (rst) begin
    pktID <= 0;
    nb_cycles <= 0;
  end else begin
    if(l8_rx_startofpacket & l8_rx_valid)begin
      pktID <= pktID + 1;
      nb_cycles <= nb_cycles + 1;
    end else if (nb_cycles != 0) begin
      // only start counting after the first packet
      nb_cycles <= nb_cycles + 1;
    end
  end
end

always @(posedge clk_txmac)
begin
  if (tx_cnt < 4'd10)begin
    tx_cnt <= tx_cnt + 1'b1;
  end else begin
    tx_cnt <= 0;
    l8_tx_ready <= ~l8_tx_ready;
  end
end

// we send a burst of packets in a window, we set the rate by limiting the size
// of the window
logic [7:0] rate_cnt;
logic started;

always @(posedge clk_rxmac)
begin
  cnt <= cnt + 1;
  l8_rx_valid <= 0;
  if (cnt == 1) begin
    rst <= 1;
    addr <= 0;
    rate_cnt <= 0;
    started <= 0;
  end else if (cnt == 35) begin
    rst <= 0;

  // Make sure the stats reset is done and the setup has finished
  end else if (cnt >= 500 && setup_finished && !started) begin
    l8_rx_valid <= 1;
    started <= 1;
  end else if (cnt >= 500 && setup_finished) begin
    if (rate_cnt < 100 * (`RATE * period_rx/(64 * 8))) begin
`ifdef DELAY_LAST_PKTS
      if (addr < (hi - nb_pkt_queues * `PKT_SIZE / 64 - 1)
          && !error_termination) begin  // Not sending last packets.
`else
      if (addr < hi-1 && !error_termination) begin
`endif
        addr <= addr + 1;
        l8_rx_valid <= 1;
      end else if (!stop && stop_cnt == 0) begin
        l8_rx_valid <= 0;
        stop_cnt <= STOP_DELAY;
        $display("Number of cycles: %d", nb_cycles);
        $display("Duration: %d", nb_cycles * period_rx);
        $display("Flits: %d", hi);
      end else if (!stop && stop_cnt < STOP_DELAY/2) begin
        // Send last packets if not already sent.
        if (addr < hi-1 && !error_termination) begin
          addr <= addr + 1;
          l8_rx_valid <= 1;
        end
      end
    end

    if (rate_cnt == 99) begin
      rate_cnt <= 0;
    end else begin
      rate_cnt <= rate_cnt + 1;
    end
  end

  if (stop_cnt != 0) begin
    stop_cnt <= stop_cnt - 1;
    if (stop_cnt == 1) begin
      stop <= 1;
      $display("STOP READING!");
      $display("Count: %d", cnt);
    end
  end
end

logic [31:0] cnt_delay;
logic [PCIE_ADDR_WIDTH-1:0] cfg_queue;
logic [63:0] nb_config_queues;

typedef enum{
  PCIE_SET_F2C_PKT_QUEUE,
  PCIE_SET_F2C_DSC_QUEUE,
  PCIE_READ_F2C_PKT_QUEUE,
  PCIE_READ_F2C_PKT_QUEUE_WAIT,
  PCIE_READ_F2C_DSC_QUEUE,
  PCIE_READ_F2C_DSC_QUEUE_WAIT,
  PCIE_RULE_INSERT,
  ENABLE_RATE_LIMIT,
  LAST_CONFIG_DELAY,
  PCIE_WAIT_DESC
} pcie_state_t;

pcie_state_t pcie_state;

logic [63:0]              rx_pdu_flit_cnt;
logic [nb_pkt_queues-1:0] pending_pkt_tails_valid;

logic [31:0] pending_pkt_tails[nb_pkt_queues];
logic [31:0] last_pkt_heads[nb_pkt_queues];
logic [31:0] tx_pkt_heads[nb_pkt_queues];
logic [31:0] tx_dsc_tails[nb_dsc_queues];
logic [31:0] tx_dsc_heads[nb_dsc_queues];
logic [31:0] last_upd_pkt_q;
logic [31:0] last_upd_dsc_q;
logic [31:0] pkt_q_consume_delay_cnt;
logic [63:0] rx_cnt;
logic [63:0] req_cnt;
logic [2:0]  burst_offset; // max of 8 flits per burst
logic [3:0]  burst_size;

logic [PCIE_ADDR_WIDTH-1:0] next_pcie_address_0;
logic [31:0]                next_upd_tail;

logic [31:0] last_rx_dsc_q_addr;

logic [63:0] total_rx_length;
logic [63:0] total_tx_length;
logic [63:0] max_tx_length;
logic [63:0] tx_queue_full_cnt;
logic [63:0] total_nb_tx_dscs;

logic         delayed_pcie_bas_waitrequest;
logic         delayed_pcie_bas_write;
logic [511:0] delayed_pcie_bas_writedata;
logic [3:0]   delayed_pcie_bas_burstcount;
logic [63:0]  delayed_pcie_bas_byteenable;
logic [63:0]  delayed_pcie_bas_address;

hyper_pipe #(
  .WIDTH ($bits(pcie_bas_waitrequest)),
  .NUM_PIPES(PCIE_DELAY)
) hp_pcie_bas_waitrequest (
  .clk  (clk_pcie),
  .din  (pcie_bas_waitrequest),
  .dout (delayed_pcie_bas_waitrequest)
);

hyper_pipe #(
  .WIDTH ($bits(pcie_bas_write)),
  .NUM_PIPES(PCIE_DELAY)
) hp_pcie_bas_write (
  .clk  (clk_pcie),
  .din  (pcie_bas_write),
  .dout (delayed_pcie_bas_write)
);

hyper_pipe #(
  .WIDTH ($bits(pcie_bas_writedata)),
  .NUM_PIPES(PCIE_DELAY)
) hp_pcie_bas_writedata (
  .clk  (clk_pcie),
  .din  (pcie_bas_writedata),
  .dout (delayed_pcie_bas_writedata)
);

hyper_pipe #(
  .WIDTH ($bits(pcie_bas_burstcount)),
  .NUM_PIPES(PCIE_DELAY)
) hp_pcie_bas_burstcount (
  .clk  (clk_pcie),
  .din  (pcie_bas_burstcount),
  .dout (delayed_pcie_bas_burstcount)
);

hyper_pipe #(
  .WIDTH ($bits(pcie_bas_byteenable)),
  .NUM_PIPES(PCIE_DELAY)
) hp_pcie_bas_byteenable (
  .clk  (clk_pcie),
  .din  (pcie_bas_byteenable),
  .dout (delayed_pcie_bas_byteenable)
);

hyper_pipe #(
  .WIDTH ($bits(pcie_bas_address)),
  .NUM_PIPES(PCIE_DELAY)
) hp_pcie_bas_address (
  .clk  (clk_pcie),
  .din  (pcie_bas_address),
  .dout (delayed_pcie_bas_address)
);


function automatic void transfer_tx_data(
  logic     [31:0] tx_dsc_buf_addr,
  ref logic [31:0] tx_dsc_buf_tail,
  logic     [63:0] tx_pkt_buf_base_addr,
  ref logic [31:0] tx_pkt_buf_head,
  logic     [31:0] nb_flits
);
  while (nb_flits > 0) begin
    automatic pcie_tx_dsc_t tx_dsc = 0;
    tx_dsc.signal = 1;
    tx_dsc.addr = tx_pkt_buf_base_addr + tx_pkt_buf_head * 64;
    if (nb_flits > MAX_FLITS_TX_TRANSFER) begin
      tx_dsc.length = MAX_FLITS_TX_TRANSFER * 64;
    end else begin
      tx_dsc.length = nb_flits * 64;
    end
    total_tx_length += tx_dsc.length;
    total_nb_tx_dscs++;

    if (tx_dsc.length > max_tx_length) begin
      max_tx_length = tx_dsc.length;
    end

    ram[tx_dsc_buf_addr][tx_dsc_buf_tail] <= tx_dsc;
    tx_dsc_buf_tail = (tx_dsc_buf_tail + 1) % DSC_BUF_SIZE;
    tx_pkt_buf_head = (tx_pkt_buf_head + nb_flits) % PKT_BUF_SIZE;
    nb_flits -= tx_dsc.length / 64;
  end
endfunction


// PCIe FPGA -> CPU -> FPGA
always @(posedge clk_pcie) begin
  automatic logic next_pcie_write_0;

  next_pcie_write_0 = 0;

  pcie_read_0 <= 0;
  pcie_address_0 <= 0;
  pcie_writedata_0 <= 0;
  pcie_byteenable_0 <= 0;

  pcie_rddm_address <= 0;
  pcie_rddm_write <= 0;

  pcie_rddm_writedata <= 0;
  pcie_rddm_byteenable <= 0;

  if (rst) begin
    automatic integer c;

    pcie_state <= PCIE_SET_F2C_PKT_QUEUE;
    cfg_queue <= 0;
    cnt_delay <= 0;
    nb_config_queues <= 0;

    pcie_bas_waitrequest <= 0;
    rx_cnt <= 0;
    req_cnt <= 0;
    rx_pdu_flit_cnt <= 0;
    burst_offset <= 0;
    burst_size <= 0;

    last_upd_pkt_q <= 0;
    last_upd_dsc_q <= 0;
    pkt_q_consume_delay_cnt <= 0;

    pending_pkt_tails_valid <= 0;

    pending_dma_write_dwords <= 0;

    total_rx_length <= 0;
    total_tx_length <= 0;
    max_tx_length <= 0;
    tx_queue_full_cnt <= 0;
    total_nb_tx_dscs <= 0;

    last_rx_dsc_q_addr <= 0;

    tx_dsc_tail_pending <= 0;

    for (c = 0; c < nb_pkt_queues; c++) begin
      pending_pkt_tails[c] <= 0;
      last_pkt_heads[c] <= 0;
      tx_pkt_heads[c] <= 0;
      tx_dsc_tails[c] <= 0;
      tx_dsc_heads[c] <= 0;
    end

  end else begin
    case (pcie_state)
      PCIE_SET_F2C_PKT_QUEUE: begin
        if (cnt >= 50) begin
          automatic logic [APP_IDX_WIDTH] dsc_queue_id;

          next_pcie_write_0 = 1;
          pcie_address_0 <= cfg_queue << 12;
          pcie_writedata_0 <= 0;
          pcie_byteenable_0 <= 0;

          dsc_queue_id = cfg_queue / pkt_per_dsc_queue;

          // Pkt queue address.
          // We also write the the corresponding descriptor queue id to the LSB.
          pcie_writedata_0[64 +: 64] <= 64'ha000000080000000 +
                                        (cfg_queue << 32) + dsc_queue_id;
          pcie_byteenable_0[8 +: 8] <= 8'hff;

          if (cfg_queue == nb_pkt_queues - 1) begin
            pcie_state <= PCIE_SET_F2C_DSC_QUEUE;
            cfg_queue <= 0;
            cnt_delay <= cnt + 10;
          end else begin
            cfg_queue <= cfg_queue + 1;
          end
        end
      end
      PCIE_SET_F2C_DSC_QUEUE: begin
        if (cnt >= cnt_delay) begin
          next_pcie_write_0 = 1;
          pcie_address_0 <= (cfg_queue + MAX_NB_FLOWS) << 12;
          pcie_writedata_0 <= 0;
          pcie_byteenable_0 <= 0;

          // RX dsc queue.
          pcie_writedata_0[64 +: 64] <= 64'hb000000080000000 +
            ((cfg_queue + nb_pkt_queues) << 32);
          pcie_byteenable_0[8 +: 8] <= 8'hff;

          // TX dsc queue (after all RX dsc queues).
          pcie_writedata_0[192 +: 64] <= 64'hb000000000000000 +
            ((cfg_queue + nb_pkt_queues + nb_dsc_queues) << 32);
          pcie_byteenable_0[24 +: 8] <= 8'hff;

          if (cfg_queue == nb_dsc_queues - 1) begin
            pcie_state <= PCIE_READ_F2C_PKT_QUEUE;
            cfg_queue <= 0;
            cnt_delay <= cnt + 10;
          end else begin
            cfg_queue <= cfg_queue + 1;
          end
        end
      end
      PCIE_READ_F2C_PKT_QUEUE: begin
        if (cnt >= cnt_delay) begin
          // read pkt queue 0
          pcie_address_0 <= 0 << 12;
          pcie_read_0 <= 1;

          pcie_state <= PCIE_READ_F2C_PKT_QUEUE_WAIT;
        end
      end
      PCIE_READ_F2C_PKT_QUEUE_WAIT: begin
        if (pcie_readdatavalid_0) begin
          assert(pcie_readdata_0[64 +: 64] == 64'ha000000080000000)
            else $fatal;

          pcie_state <= PCIE_READ_F2C_DSC_QUEUE;
          cnt_delay <= cnt + 10;
        end
      end
      PCIE_READ_F2C_DSC_QUEUE: begin
        if (cnt >= cnt_delay) begin
          // Read dsc queue 0.
          pcie_address_0 <= (0 + MAX_NB_FLOWS) << 12;
          pcie_read_0 <= 1;

          pcie_state <= PCIE_READ_F2C_DSC_QUEUE_WAIT;
        end
      end
      PCIE_READ_F2C_DSC_QUEUE_WAIT: begin
        if (pcie_readdatavalid_0) begin
          assert(pcie_readdata_0[64 +: 64] == 64'hb000000080000000
            + (nb_pkt_queues << 32));

          pcie_state <= PCIE_RULE_INSERT;
          cnt_delay <= cnt + 10;
        end
      end
      PCIE_RULE_INSERT: begin
        if (cnt >= cnt_delay) begin
          automatic flow_table_config_t flow_table_config = 0;
          automatic logic [31:0] new_dsc_tail;
          automatic logic [31:0] dsc_q = 
            nb_config_queues[31:0] / pkt_per_dsc_queue;
          automatic logic [31:0] tx_dsc_q_addr;

          flow_table_config.pkt_queue_id = nb_config_queues;
          flow_table_config.prot = 32'h11;
          flow_table_config.tuple = {
              32'h0,
              32'hc0a80000 + nb_config_queues[31:0],
              32'h00000050
          };
          flow_table_config.config_id = FLOW_TABLE_CONFIG_ID;
          flow_table_config.signal = 2;

          new_dsc_tail = (tx_dsc_tails[0] + 1) % DSC_BUF_SIZE;

          tx_dsc_tails[0] <= new_dsc_tail;

          // Use TX dsc queue 0.
          tx_dsc_q_addr = nb_pkt_queues + nb_dsc_queues + 0;
          ram[tx_dsc_q_addr][tx_dsc_tails[0]] <= flow_table_config;

          next_pcie_write_0 = 1;
          pcie_address_0 <= (MAX_NB_FLOWS) << 12;  // Use TX dsc queue 0.
          pcie_writedata_0 <= 0;
          pcie_byteenable_0 <= 0;

          pcie_writedata_0[128 +: 32] <= new_dsc_tail;
          pcie_byteenable_0[16 +: 4] <= 4'hf;

          cnt_delay <= cnt + 10;
          nb_config_queues <= nb_config_queues + 1;

          if (nb_config_queues + 1 == nb_pkt_queues) begin
            pcie_state <= ENABLE_RATE_LIMIT;
          end
        end
      end
      ENABLE_RATE_LIMIT: begin
        if (cnt >= cnt_delay) begin
          automatic rate_limit_config_t rate_limit_config = 0;
          automatic logic [31:0] new_dsc_tail;
          automatic logic [31:0] dsc_q = 
            nb_config_queues[31:0] / pkt_per_dsc_queue;
          automatic logic [31:0] tx_dsc_q_addr;

          rate_limit_config.enable = RATE_LIMIT_ENABLE;
          rate_limit_config.numerator = RATE_LIMIT_NUMERATOR;
          rate_limit_config.denominator = RATE_LIMIT_DENOMINATOR;
          rate_limit_config.config_id = RATE_LIMIT_CONFIG_ID;
          rate_limit_config.signal = 2;

          new_dsc_tail = (tx_dsc_tails[0] + 1) % DSC_BUF_SIZE;

          tx_dsc_tails[0] <= new_dsc_tail;

          // Use TX dsc queue 0.
          tx_dsc_q_addr = nb_pkt_queues + nb_dsc_queues + 0;
          ram[tx_dsc_q_addr][tx_dsc_tails[0]] <= rate_limit_config;

          next_pcie_write_0 = 1;
          pcie_address_0 <= (MAX_NB_FLOWS) << 12;  // Use TX dsc queue 0.
          pcie_writedata_0 <= 0;
          pcie_byteenable_0 <= 0;

          pcie_writedata_0[128 +: 32] <= new_dsc_tail;
          pcie_byteenable_0[16 +: 4] <= 4'hf;

          pcie_state <= LAST_CONFIG_DELAY;
          cnt_delay <= cnt + 10;
        end
      end
      LAST_CONFIG_DELAY: begin
        if (cnt >= cnt_delay) begin
          pcie_state <= PCIE_WAIT_DESC;
          setup_finished <= 1;
        end
      end
      PCIE_WAIT_DESC: begin
      end
    endcase

    if (delayed_pcie_bas_write && !delayed_pcie_bas_waitrequest) begin
      automatic logic [31:0] cur_queue;
      automatic logic [31:0] cur_address;

      if (delayed_pcie_bas_burstcount != 0) begin
        burst_offset = 0;
        burst_size <= delayed_pcie_bas_burstcount;
      end else if (burst_offset + 1 >= burst_size) begin
        $error("Requests beyond burst size.");
      end else begin
        burst_offset = burst_offset + 1;
      end

      cur_queue = delayed_pcie_bas_address[32 +: BRAM_TABLE_IDX_WIDTH];
      cur_address = delayed_pcie_bas_address[6 +: RAM_ADDR_LEN] + burst_offset;

      if (cur_queue < nb_pkt_queues) begin  // pkt queue
        rx_pdu_flit_cnt <= rx_pdu_flit_cnt + 1;
      end else if (cur_queue < nb_pkt_queues + nb_dsc_queues) begin
        // rx dsc queue
        automatic logic [31:0] pkt_per_dsc_queue;
        automatic pcie_rx_dsc_t pcie_pkt_desc = delayed_pcie_bas_writedata;

        // dsc queues can receive only one flit per burst
        assert(delayed_pcie_bas_burstcount == 1) else $fatal;

        assert(pcie_pkt_desc.signal == 1) else $fatal;

        // Update dsc queue here.
        next_pcie_write_0 = 1;
        pcie_address_0 <= (cur_queue - nb_pkt_queues + MAX_NB_FLOWS) << 12;
        pcie_writedata_0 <= 0;
        pcie_byteenable_0 <= 0;

        pcie_writedata_0[32 +: 32] <= cur_address;
        pcie_byteenable_0[4 +: 4] <= 4'hf;

        if ((nb_dsc_queues == 1) && (last_rx_dsc_q_addr != 0)) begin
          assert(cur_address == (last_rx_dsc_q_addr + 1) % DSC_BUF_SIZE)
              else $fatal;
        end

        last_rx_dsc_q_addr <= cur_address;

        // Save tail so we can advance the head later.
        pending_pkt_tails[pcie_pkt_desc.queue_id] <= pcie_pkt_desc.tail;
        pending_pkt_tails_valid[pcie_pkt_desc.queue_id] <= 1'b1;
        total_rx_length <= total_rx_length + ((
          pcie_pkt_desc.tail - pending_pkt_tails[pcie_pkt_desc.queue_id]
        ) % PKT_BUF_SIZE) * 64;
      end else begin  // tx dsc queue
        automatic logic [31:0] pkt_buf_queue;
        automatic logic [31:0] pkt_buf_head;
        automatic logic [31:0] tx_dsc_buf_queue;
        automatic pcie_tx_dsc_t tx_dsc = delayed_pcie_bas_writedata;
        automatic pcie_tx_dsc_t old_tx_dsc = ram[cur_queue][cur_address];
        
        assert(tx_dsc.signal == 0) else $fatal;

        // If config dsc, do nothing.
        if (old_tx_dsc.signal == 1) begin
          // Figure out queue and head from address.
          pkt_buf_queue = tx_dsc.addr[32 +: BRAM_TABLE_IDX_WIDTH];
          pkt_buf_head = (tx_dsc.addr[6 +: RAM_ADDR_LEN]
                  + tx_dsc.length / 64) % PKT_BUF_SIZE;

          // Advance head pointer for corresponding pkt queue.
          next_pcie_write_0 = 1;
          pcie_address_0 <= pkt_buf_queue << 12;
          pcie_writedata_0 <= 0;
          pcie_byteenable_0 <= 0;
          last_pkt_heads[pkt_buf_queue] <= pkt_buf_head;

          pcie_writedata_0[32 +: 32] <= pkt_buf_head;
          pcie_byteenable_0[4 +: 4] <= 4'hf;
        end

        // Advance corresponding TX dsc queue head.
        tx_dsc_buf_queue = cur_queue - nb_pkt_queues - nb_dsc_queues;
        tx_dsc_heads[tx_dsc_buf_queue] <=
          (tx_dsc_heads[tx_dsc_buf_queue] + 1) % DSC_BUF_SIZE;
      end

      // Check if address out of bound.
      if (cur_address > RAM_SIZE) begin
        $error("Address out of bound");
      end else begin
        ram[cur_queue][cur_address] <= delayed_pcie_bas_writedata;
      end

      rx_cnt <= rx_cnt + 1;
    end

    if (pkt_q_consume_delay_cnt != 0) begin
      pkt_q_consume_delay_cnt--;
    end

    // if not trying to write anything, we can try to advance one of the
    // pointers.
    if (next_pcie_write_0 == 0) begin
      automatic integer i;

      // A TX dsc tail pointer needs to be written.
      if (tx_dsc_tail_pending) begin
        tx_dsc_tail_pending <= 0;

        next_pcie_write_0 = 1;
        pcie_address_0 <= (MAX_NB_FLOWS + last_upd_dsc_q) << 12;
        pcie_writedata_0 <= 0;
        pcie_byteenable_0 <= 0;

        pcie_writedata_0[128 +: 32] <= tx_dsc_tails[last_upd_dsc_q];
        pcie_byteenable_0[16 +: 4] <= 4'hf;

      // Enqueue TX descriptor with latest available data for one of the queues.
      end else if (pkt_q_consume_delay_cnt == 0) begin
        for (i = 0; i < nb_pkt_queues; i++) begin
          automatic integer pkt_q = (i + last_upd_pkt_q + 1) % nb_pkt_queues;
          automatic integer dsc_q = pkt_q / pkt_per_dsc_queue;
          automatic integer free_slot =
            (tx_dsc_heads[dsc_q] - tx_dsc_tails[dsc_q] - 1) % DSC_BUF_SIZE;
          automatic logic [31:0] tx_dsc_q_addr;
          automatic logic [31:0] rx_pkt_buf_tail;
          automatic logic [31:0] rx_pkt_buf_head;
          automatic logic [31:0] tx_pkt_buf_head;
          automatic logic [31:0] tx_dsc_tail = tx_dsc_tails[dsc_q];
          automatic logic [63:0] pkt_buf_base_addr;
          automatic logic [31:0] nb_flits;

          if (!pending_pkt_tails_valid[pkt_q]) begin
            continue;
          end

          rx_pkt_buf_tail = pending_pkt_tails[pkt_q];
          rx_pkt_buf_head = last_pkt_heads[pkt_q];
          tx_pkt_buf_head = tx_pkt_heads[pkt_q];
          nb_flits = (rx_pkt_buf_tail - tx_pkt_buf_head) % PKT_BUF_SIZE;

          if (nb_flits == 0) begin
            continue;
          end

          // Check if TX dsc buffer has enough room. We add 1 in case the
          // transfer wraps around.
          if ((((nb_flits-1)/MAX_FLITS_TX_TRANSFER + 1) + 1) > free_slot) begin
            continue;
          end

          pending_pkt_tails_valid[pkt_q] <= 0;

          last_upd_pkt_q = pkt_q;
          last_upd_dsc_q <= dsc_q;

          pkt_buf_base_addr = 64'ha000000000000000 + (pkt_q << 32);
          tx_dsc_q_addr = nb_pkt_queues + nb_dsc_queues + dsc_q;

          if (rx_pkt_buf_tail == tx_pkt_buf_head) begin
            continue;
          end

          // Data wrap around buffer.
          if (rx_pkt_buf_tail < tx_pkt_buf_head) begin
            nb_flits = DSC_BUF_SIZE - tx_pkt_buf_head;
            transfer_tx_data(tx_dsc_q_addr, tx_dsc_tail, pkt_buf_base_addr,
                             tx_pkt_buf_head, nb_flits);
          end
          nb_flits = rx_pkt_buf_tail - tx_pkt_buf_head;
          transfer_tx_data(tx_dsc_q_addr, tx_dsc_tail, pkt_buf_base_addr,
                           tx_pkt_buf_head, nb_flits);

          tx_dsc_tails[dsc_q] <= tx_dsc_tail;
          tx_pkt_heads[pkt_q] <= tx_pkt_buf_head;
          tx_dsc_tail_pending <= 1'b1;

          break;
        end
        if (last_upd_pkt_q == nb_pkt_queues - 1) begin
          pkt_q_consume_delay_cnt <= UPDATE_HEAD_DELAY;
        end
      end
    end

    // RDDM Mock:

    // If DMA is larger than a flit, we need to send multiple writes. If
    // `dma_write_pending` is set, there are some writes pending.
    if (dma_write_pending) begin
      automatic logic [31:0] cur_queue;
      automatic logic [31:0] cur_address;

      cur_queue = pending_dma_write_src_addr[32 +: BRAM_TABLE_IDX_WIDTH+1];
      cur_address = pending_dma_write_src_addr[6 +: RAM_ADDR_LEN];

      // Write data using RDDM Avalon-MM interface.
      pcie_rddm_write <= 1;
      pcie_rddm_address <= pending_dma_write_dst_addr;
      pcie_rddm_byteenable <= ~64'h0;
      pcie_rddm_writedata <= ram[cur_queue][cur_address];

      if (pending_dma_write_dwords > 16) begin
        pending_dma_write_dwords <= pending_dma_write_dwords - 16;
        pending_dma_write_src_addr <= pending_dma_write_src_addr + 64;
      end else begin
        pending_dma_write_dwords <= 0;
      end
    end else if ((rddm_desc_queue_ready & rddm_desc_queue_valid)
        | (rddm_prio_queue_ready & rddm_prio_queue_valid)) begin
      automatic logic [31:0] cur_queue;
      automatic logic [31:0] cur_address;
      automatic rddm_desc_t rddm_desc;

      // `prio` queue has priority over `desc` queue.
      if (rddm_prio_queue_valid) begin
        rddm_desc = rddm_prio_queue_data;
        assert(!rddm_desc_queue_ready) else $fatal;
      end else begin
        rddm_desc = rddm_desc_queue_data;
      end

      cur_queue = rddm_desc.src_addr[32 +: BRAM_TABLE_IDX_WIDTH+1];
      cur_address = rddm_desc.src_addr[6 +: RAM_ADDR_LEN];

      // Address must be aligned to double dword but here we assume cache line
      // alignment to make things easier.
      assert(rddm_desc.src_addr[5:0] == 0) else begin
          $fatal;
      end
      assert(rddm_desc.nb_dwords[3:0] == 0) else $fatal;

      // Only single_dst is implemented in this mock.
      assert(rddm_desc.single_dst) else $fatal;

      // When setting single_dst, the dst_addr must be 64-byte aligned.
      assert(rddm_desc.dst_addr[5:0] == 0) else $fatal;

      // Write data to FPGA using RDDM Avalon-MM interface.
      pcie_rddm_write <= 1;
      pcie_rddm_address <= rddm_desc.dst_addr;  // From descriptor.
      pcie_rddm_byteenable <= ~64'h0;
      pcie_rddm_writedata <= ram[cur_queue][cur_address];

      // If DMA is larger than a flit, we need to send multiple writes.
      if (rddm_desc.nb_dwords > 16) begin
        pending_dma_write_dwords <= rddm_desc.nb_dwords - 16;
        pending_dma_write_dst_addr <= rddm_desc.dst_addr;
        pending_dma_write_src_addr <= rddm_desc.src_addr + 64;
      end else begin
        pending_dma_write_dwords <= 0;
      end
    end

    // Emulate PCIe BAS wait
    if (cnt[8]) begin
        pcie_bas_waitrequest <= !pcie_bas_waitrequest;
    end

    pcie_write_0 <= next_pcie_write_0;
  end
end

logic [31:0] rddm_write_pkt_cnt;
logic [31:0] rddm_write_dsc_cnt;

initial rddm_write_pkt_cnt = 0;
initial rddm_write_dsc_cnt = 0;

// Check TX packets.
always @(posedge clk_pcie) begin
  if (pcie_rddm_write) begin
    automatic logic [31:0] cur_queue;
    automatic rddm_desc_t rddm_desc = pcie_rddm_address;
    cur_queue = rddm_desc.src_addr[32 +: BRAM_TABLE_IDX_WIDTH+1];

    if (cur_queue >= (nb_pkt_queues + nb_dsc_queues)) begin
      rddm_write_dsc_cnt <= rddm_write_dsc_cnt + 1;
    end else begin
      rddm_write_pkt_cnt <= rddm_write_pkt_cnt + 1;
    end
  end
end

logic [31:0] nb_rx_flits;
logic [31:0] nb_tx_flits;

initial nb_rx_flits = 0;
initial nb_tx_flits = 0;

// Track all RX and TX Ethernet packets.
always @(posedge clk_rxmac) begin
  if (l8_rx_valid) begin
    nb_rx_flits <= nb_rx_flits + 1;
  end
  if (l8_tx_valid && l8_tx_ready) begin
    nb_tx_flits <= nb_tx_flits + 1;
  end
end

// Queue that holds incoming RDDM descriptors with regular prioity (desc).
fifo_wrapper_infill_mlab #(
  .SYMBOLS_PER_BEAT(1),
  .BITS_PER_SYMBOL($bits(pcie_rddm_desc_data)),
  .FIFO_DEPTH(16)
)
rddm_desc_queue (
  .clk           (clk_pcie),
  .reset         (rst),
  .csr_address   (2'b0),
  .csr_read      (1'b1),
  .csr_write     (1'b0),
  .csr_readdata  (rddm_desc_queue_occup),
  .csr_writedata (32'b0),
  .in_data       (pcie_rddm_desc_data),
  .in_valid      (pcie_rddm_desc_valid),
  .in_ready      (),
  .out_data      (rddm_desc_queue_data),
  .out_valid     (rddm_desc_queue_valid),
  .out_ready     (rddm_desc_queue_ready)
);

// Absorb ready latency of 3.
assign pcie_rddm_desc_ready = rddm_desc_queue_occup < (16 - 3);

// Queue that holds incoming RDDM descriptors with elevated priority (prio).
fifo_wrapper_infill_mlab #(
  .SYMBOLS_PER_BEAT(1),
  .BITS_PER_SYMBOL($bits(pcie_rddm_desc_data)),
  .FIFO_DEPTH(16)
)
rddm_prio_queue (
  .clk           (clk_pcie),
  .reset         (rst),
  .csr_address   (2'b0),
  .csr_read      (1'b1),
  .csr_write     (1'b0),
  .csr_readdata  (rddm_prio_queue_occup),
  .csr_writedata (32'b0),
  .in_data       (pcie_rddm_prio_data),
  .in_valid      (pcie_rddm_prio_valid),
  .in_ready      (),
  .out_data      (rddm_prio_queue_data),
  .out_valid     (rddm_prio_queue_valid),
  .out_ready     (rddm_prio_queue_ready)
);

logic pcie_rddm_queue_in_ready;
logic pcie_rddm_queue_out_valid;

// Queue that holds TX packets. To test the TX path with ratelimiting without
// backpressuring RX, we size it so that it can fit all the packets.
fifo_wrapper_infill #(
  .SYMBOLS_PER_BEAT(1),
  .BITS_PER_SYMBOL(
    $bits(pcie_rddm_writedata) +
    $bits(pcie_rddm_byteenable) +
    $bits(pcie_rddm_address)
  ),
  .FIFO_DEPTH(4 * `PKT_FILE_NB_LINES)
)
pcie_rddm_queue (
  .clk           (clk_pcie),
  .reset         (rst),
  .csr_address   (2'b0),
  .csr_read      (1'b1),
  .csr_write     (1'b0),
  .csr_readdata  (),
  .csr_writedata (32'b0),
  .in_data       ({
    pcie_rddm_writedata,
    pcie_rddm_byteenable,
    pcie_rddm_address
  }),
  .in_valid      (pcie_rddm_write),
  .in_ready      (pcie_rddm_queue_in_ready),
  .out_data      ({
    top_pcie_rddm_writedata, 
    top_pcie_rddm_byteenable,
    top_pcie_rddm_address
  }),
  .out_valid     (pcie_rddm_queue_out_valid),
  .out_ready     (!top_pcie_rddm_waitrequest)
);

assign top_pcie_rddm_write = 
  pcie_rddm_queue_out_valid && !top_pcie_rddm_waitrequest;

`ASSERT_KNOWN(PcieRddmWriteKnown, pcie_rddm_write, clk_pcie, rst)
`ASSERT_KNOWN(TopPcieRddmWaitRequestKnown, top_pcie_rddm_waitrequest, clk_pcie,
              rst)
`ASSERT_KNOWN(PcieRddmQueueInReadyKnown, pcie_rddm_queue_in_ready, clk_pcie,
              rst)
`ASSERT(PcieRddmWriteWhenReady,
        pcie_rddm_write |-> (pcie_rddm_queue_in_ready == 1), clk_pcie, rst)
`ASSERT_KNOWN(TopPcieRddmWriteKnown, top_pcie_rddm_write, clk_pcie, rst)
`ASSERT_KNOWN_IF(TopPcieWritedataKnown, top_pcie_rddm_writedata,
                 pcie_rddm_queue_out_valid, clk_pcie, rst)
`ASSERT_KNOWN_IF(TopPcieRddmByteenableKnown, top_pcie_rddm_byteenable,
                 pcie_rddm_queue_out_valid, clk_pcie, rst)
`ASSERT_KNOWN_IF(TopPcieRddmAddressKnown, top_pcie_rddm_address,
                 pcie_rddm_queue_out_valid, clk_pcie, rst)

assign pcie_rddm_prio_ready = rddm_prio_queue_occup < (16 - 3);

logic [31:0] last_tail;
logic [31:0] in_pkt;

//Configure
//Read and display pkt/flow cnts
always @(posedge clk_status) begin
  s_read <= 0;
  s_write <= 0;
  s_writedata <= 0;
  error_termination_r <= error_termination;
  if (rst) begin
    s_cnt <= 0;
    s_addr <= 0;
    conf_state <= CONFIGURE_0;
  end else begin
    case(conf_state)
      CONFIGURE_0: begin
        automatic logic [25:0] pkt_buf_size = PKT_BUF_SIZE;
        s_addr <= 30'h2A00_0000;
        s_write <= 1;

        `ifdef NO_PCIE
          // pcie disabled
          s_writedata <= {5'h0, pkt_buf_size, 1'b1};
        `else
          // pcie enabled
          s_writedata <= {5'h0, pkt_buf_size, 1'b0};
        `endif
        conf_state <= CONFIGURE_1;
      end
      CONFIGURE_1: begin
        automatic logic [25:0] dsc_buf_size = DSC_BUF_SIZE;
        s_addr <= 30'h2A00_0001;
        s_write <= 1;

        s_writedata <= {6'h0, dsc_buf_size};
        conf_state <= CONFIGURE_2;
      end
      CONFIGURE_2: begin
        automatic logic eth_port_nb = ETH_PORT_NB;
        automatic logic [30:0] nb_tx_credits = NB_TX_CREDITS;
        s_addr <= 30'h2A00_0002;
        s_write <= 1;

        s_writedata <= {eth_port_nb, nb_tx_credits};
        conf_state <= CONFIGURE_3;
      end
      CONFIGURE_3: begin
        s_addr <= 30'h2A00_0003;
        s_write <= 1;

        s_writedata <= `NB_FALLBACK_QUEUES;
        conf_state <= READ_MEMORY;
      end
      READ_MEMORY: begin
        if (stop || error_termination) begin
          integer q;
          integer pkt_q;
          integer i;
          integer j;
          integer k;

          // for (q = 0; q < nb_dsc_queues; q = q + 1) begin
          //     $display("RX Descriptor queue: %d", q);
          //     // printing only the beginning of each buffer,
          //     // may print the entire thing instead
          //     for (i = 0; i < 10; i = i + 1) begin
          //     // for (i = 0; i < RAM_SIZE; i = i + 1) begin
          //         for (j = 0; j < 8; j = j + 1) begin
          //             $write("%h:", i*64+j*8);
          //             for (k = 0; k < 8; k = k + 1) begin
          //                 $write(" %h",
          //                     ram[q+nb_pkt_queues][i][j*64+k*8 +: 8]);
          //             end
          //             $write("\n");
          //         end
          //         $write("\n");
          //     end
          //     $display("TX Descriptor queue: %d", q);
          //     for (i = 0; i < 10; i = i + 1) begin
          //         // for (i = 0; i < RAM_SIZE; i = i + 1) begin
          //         for (j = 0; j < 8; j = j + 1) begin
          //             $write("%h:", i*64+j*8);
          //             for (k = 0; k < 8; k = k + 1) begin
          //                 $write(" %h",
          //                        ram[q+nb_pkt_queues+nb_dsc_queues][
          //                            i][j*64+k*8 +: 8]);
          //             end
          //             $write("\n");
          //         end
          //     $write("\n");
          //     end

          //     $display("Packet queues:");
          //     for (pkt_q = q*pkt_per_dsc_queue;
          //         pkt_q < (q+1)*pkt_per_dsc_queue; pkt_q = pkt_q + 1)
          //     begin
          //         $display("Packet queue: %d", pkt_q);
          //         for (i = 0; i < 10; i = i + 1) begin
          //             for (j = 0; j < 8; j = j + 1) begin
          //                 $write("%h:", i*64+j*8);
          //                 for (k = 0; k < 8; k = k + 1) begin
          //                     $write(" %h",
          //                         ram[pkt_q][i][j*64+k*8 +: 8]);
          //                 end
          //                 $write("\n");
          //             end
          //             $write("\n");
          //         end
          //     end
          // end
          conf_state <= READ_PCIE_START;
        end
      end
      READ_PCIE_START: begin
        `ifdef SKIP_PCIE_RD
          conf_state <= IDLE;
        `else
          s_read <= 1;
          s_addr <= 30'h2A00_0000;
          conf_state <= READ_PCIE_PKT_Q;
          $display("read_pcie:");
          $display("status + pkt queues:");
        `endif
      end
      READ_PCIE_PKT_Q: begin
        if (top_readdata_valid) begin
          `ifdef CHECK_QUEUE_HEAD_TAIL
            if (s_addr[JTAG_ADDR_WIDTH-1:0] >= NB_CONTROL_REGS) begin
              if (((s_addr - NB_CONTROL_REGS) % 4) == 0) begin
                last_tail <= top_readdata;
              end else if (((s_addr - NB_CONTROL_REGS) % 4) == 1) begin
                automatic int queue =
                    (s_addr[JTAG_ADDR_WIDTH-1:0] - NB_CONTROL_REGS) / 4;
                assert (last_tail == top_readdata) else begin 
                  $display("queue %d: tail: %h, head: %h", queue, last_tail,
                           top_readdata);
                end
              end
            end
          `else
            $display("%d: 0x%8h", s_addr[JTAG_ADDR_WIDTH-1:0],
                top_readdata);
          `endif  // CHECK_QUEUE_HEAD_TAIL
          s_addr <= s_addr + 1;
          s_read <= 1;
          if ((s_addr + 1) == (30'h2A00_0000 + REGS_PER_PKT_Q * nb_pkt_queues
                               + NB_CONTROL_REGS)) begin
            s_addr <= 30'h2A00_0000
              + REGS_PER_PKT_Q * MAX_NB_FLOWS
              + NB_CONTROL_REGS;
            s_writedata <= 0;
            
            `ifdef CHECK_QUEUE_HEAD_TAIL
              s_read <= 0;
              conf_state <= IDLE;
            `else
              conf_state <= READ_PCIE_DSC_Q;
              $display("dsc queues:");
            `endif // CHECK_QUEUE_HEAD_TAIL
          end
        end
      end
      READ_PCIE_DSC_Q: begin
        if (top_readdata_valid) begin
          $display("%d: 0x%8h", s_addr[JTAG_ADDR_WIDTH-1:0],
               top_readdata);
          s_addr = s_addr + 1;
          if (s_addr == (30'h2A00_0000
              + REGS_PER_PKT_Q * MAX_NB_FLOWS
              + REGS_PER_DSC_Q * nb_dsc_queues
              + NB_CONTROL_REGS)
            ) begin
            conf_state <= IDLE;
          end else begin
            s_read <= 1;
          end
        end
      end
      IDLE: begin
        conf_state <= IN_PKT;
        s_read <= 1;
        s_addr <= 30'h2200_0000;

        // End of simulation assertions.
        assert(reg_top_eth_port_nb == ETH_PORT_NB);
        assert(nb_rx_flits == nb_tx_flits);
      end
      IN_PKT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("---- PRINT STATS ------");
          $display("IN_PKT:\t\t%d", top_readdata);
          in_pkt <= top_readdata;
          conf_state <= OUT_PKT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      OUT_PKT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          // Make sure all input packets were output.
          assert(in_pkt == top_readdata) begin
            $display("OUT_PKT:\t\t%d", top_readdata);
          end else begin
            $display("OUT_PKT:\t\t%d <----", top_readdata);
            $error;
          end
          conf_state <= IN_COMP_OUT_PKT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      IN_COMP_OUT_PKT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("IN_COMP_OUT_PKT:\t%d", top_readdata);
          conf_state <= PARSER_OUT_PKT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PARSER_OUT_PKT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PARSER_OUT_PKT:\t%d", top_readdata);
          conf_state <= MAX_PARSER_FIFO;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      MAX_PARSER_FIFO: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("MAX_PARSER_FIFO:\t%d", top_readdata);
          conf_state <= FD_IN_PKT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      FD_IN_PKT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("FD_IN_PKT:\t\t%d", top_readdata);
          conf_state <= FD_OUT_PKT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      FD_OUT_PKT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("FD_OUT_PKT:\t\t%d", top_readdata);
          conf_state <= MAX_FD_OUT_FIFO;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      MAX_FD_OUT_FIFO: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("MAX_FD_OUT_FIFO:\t%d", top_readdata);
          conf_state <= DM_IN_PKT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      DM_IN_PKT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("DM_IN_PKT:\t\t%d", top_readdata);
          conf_state <= IN_EMPTYLIST_PKT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end

      IN_EMPTYLIST_PKT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("IN_EMPTYLIST_PKT:\t%d", top_readdata);
          conf_state <= OUT_EMPTYLIST_PKT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      OUT_EMPTYLIST_PKT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("OUT_EMPTYLIST_PKT:\t%d", top_readdata);
          conf_state <= PKT_ETH;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PKT_ETH: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PKT_ETH:\t\t%d", top_readdata);
          conf_state <= PKT_DROP;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PKT_DROP: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PKT_DROP:\t\t%d", top_readdata);
          conf_state <= PKT_PCIE;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PKT_PCIE: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PKT_PCIE:\t\t%d", top_readdata);
          conf_state <= MAX_DM2PCIE_FIFO;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      MAX_DM2PCIE_FIFO: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("MAX_DM2PCIE_FIFO:\t%d", top_readdata);
          conf_state <= MAX_DM2PCIE_META_FIFO;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      MAX_DM2PCIE_META_FIFO: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("MAX_DM2PCIE_MET_FIFO:\t%d", top_readdata);
          conf_state <= PCIE_PKT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PCIE_PKT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PCIE_PKT:\t\t%d", top_readdata);
          conf_state <= PCIE_META;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PCIE_META: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PCIE_META:\t\t%d", top_readdata);
          conf_state <= DM_PCIE_PKT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      DM_PCIE_PKT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("DM_PCIE_PKT:\t\t%d", top_readdata);
          conf_state <= DM_PCIE_META;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      DM_PCIE_META: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("DM_PCIE_META:\t\t%d", top_readdata);
          conf_state <= DM_ETH_PKT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      DM_ETH_PKT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("DM_ETH_PKT:\t\t%d", top_readdata);
          conf_state <= RX_DMA_PKT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      RX_DMA_PKT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("RX_DMA_PKT:\t\t%d", top_readdata);
          conf_state <= RX_PKT_HEAD_UPD;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      RX_PKT_HEAD_UPD: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("RX_PKT_HEAD_UPD:\t%d", top_readdata);
          conf_state <= TX_DSC_TAIL_UPD;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      TX_DSC_TAIL_UPD: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("TX_DSC_TAIL_UPD:\t%d", top_readdata);
          conf_state <= DMA_REQUEST;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      DMA_REQUEST: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("DMA_REQUEST:\t\t%d", top_readdata);
          conf_state <= RULE_SET;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      RULE_SET: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          // Ensure that a rule was set for every packet queue.
          assert(top_readdata == nb_pkt_queues) begin
            $display("RULE_SET:\t\t%d", top_readdata);
          end else begin
            $display("RULE_SET:\t\t%d <----", top_readdata);
            $error;
          end
          conf_state <= EVICTION;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      EVICTION: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("EVICTION:\t\t%d", top_readdata);
          conf_state <= MAX_PDUGEN_PKT_FIFO;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      MAX_PDUGEN_PKT_FIFO: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("MAX_PDUGEN_PKT_FIFO:\t%d", top_readdata);
          conf_state <= MAX_PDUGEN_META_FIFO;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      MAX_PDUGEN_META_FIFO: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("MAX_PDUGEN_META_FIFO:\t%d", top_readdata);
          conf_state <= PCIE_CORE_FULL;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PCIE_CORE_FULL: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PCIE_CORE_FULL:\t%d", top_readdata);
          conf_state <= RX_DMA_DSC_CNT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      RX_DMA_DSC_CNT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("RX_DMA_DSC:\t\t%d", top_readdata);
          conf_state <= RX_DMA_DSC_DROP_CNT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      RX_DMA_DSC_DROP_CNT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("RX_DMA_DSC_DROP:\t%d", top_readdata);
          conf_state <= RX_DMA_PKT_FLIT_CNT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      RX_DMA_PKT_FLIT_CNT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("RX_DMA_PKT_FLIT:\t%d", top_readdata);
          conf_state <= RX_DMA_PKT_FLIT_DROP_CNT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      RX_DMA_PKT_FLIT_DROP_CNT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("RX_DMA_PKT_FLIT_DROP:\t%d", top_readdata);
          conf_state <= CPU_DSC_BUF_FULL;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      CPU_DSC_BUF_FULL: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("CPU_DSC_BUF_FULL:\t%d", top_readdata);
          conf_state <= CPU_DSC_BUF_IN;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      CPU_DSC_BUF_IN: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("CPU_DSC_BUF_IN:\t%d", top_readdata);
          conf_state <= CPU_DSC_BUF_OUT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      CPU_DSC_BUF_OUT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("CPU_DSC_BUF_OUT:\t%d", top_readdata);
          conf_state <= CPU_PKT_BUF_FULL;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      CPU_PKT_BUF_FULL: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("CPU_PKT_BUF_FULL:\t%d", top_readdata);
          conf_state <= CPU_PKT_BUF_IN;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      CPU_PKT_BUF_IN: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("CPU_PKT_BUF_IN:\t%d", top_readdata);
          conf_state <= CPU_PKT_BUF_OUT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      CPU_PKT_BUF_OUT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("CPU_PKT_BUF_OUT:\t%d", top_readdata);
          conf_state <= PCIE_ST_ORD_IN;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PCIE_ST_ORD_IN: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PCIE_ST_ORD_IN:\t%d", top_readdata);
          conf_state <= PCIE_ST_ORD_OUT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PCIE_ST_ORD_OUT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PCIE_ST_ORD_OUT:\t%d", top_readdata);
          conf_state <= MAX_PCIE_PKT_FIFO;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      MAX_PCIE_PKT_FIFO: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("MAX_PCIE_PKT_FIFO:\t%d", top_readdata);
          conf_state <= MAX_PCIE_META_FIFO;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      MAX_PCIE_META_FIFO: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("MAX_PCIE_META_FIFO:\t%d", top_readdata);
          conf_state <= PCIE_RX_IGNORED_HEAD;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PCIE_RX_IGNORED_HEAD: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PCIE_RX_IGNORED_HEAD:\t%d", top_readdata);
          conf_state <= PCIE_TX_Q_FULL_SIGNALS;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PCIE_TX_Q_FULL_SIGNALS: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PCIE_TX_Q_FULL_SIG:\t%d", top_readdata);
          conf_state <= PCIE_TX_DSC_CNT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PCIE_TX_DSC_CNT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PCIE_TX_DSC_CNT:\t%d", top_readdata);
          conf_state <= PCIE_TX_EMPTY_TAIL_CNT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PCIE_TX_EMPTY_TAIL_CNT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PCIE_TX_EMPTY_TAIL:\t%d", top_readdata);
          conf_state <= PCIE_TX_DSC_READ_CNT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PCIE_TX_DSC_READ_CNT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PCIE_TX_DSC_READ_CNT:\t%d", top_readdata);
          conf_state <= PCIE_TX_PKT_READ_CNT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PCIE_TX_PKT_READ_CNT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PCIE_TX_PKT_READ_CNT:\t%d", top_readdata);
          conf_state <= PCIE_TX_BATCH_CNT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PCIE_TX_BATCH_CNT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PCIE_TX_BATCH_CNT:\t%d", top_readdata);
          conf_state <= PCIE_TX_MAX_INFLIGHT_DSCS;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PCIE_TX_MAX_INFLIGHT_DSCS: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PCIE_TX_MAX_INFLIGHT:\t%d", top_readdata);
          conf_state <= PCIE_TX_MAX_NB_REQ_DSCS;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PCIE_TX_MAX_NB_REQ_DSCS: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PCIE_TX_MAX_NB_DSCS:\t%d", top_readdata);
          conf_state <= TX_DMA_PKT;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      TX_DMA_PKT: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("TX_DMA_PKT:\t\t%d", top_readdata);
          conf_state <= PCIE_FULL_SIGNALS_1;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PCIE_FULL_SIGNALS_1: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PCIE_FULL_SIGNALS_1:\t%d", top_readdata);
          conf_state <= PCIE_FULL_SIGNALS_2;
          s_read <= 1;
          s_addr <= s_addr + 1;
        end
      end
      PCIE_FULL_SIGNALS_2: begin
        s_read <= 0;
        if(top_readdata_valid)begin
          $display("PCIE_FULL_SIGNALS_2:\t%d", top_readdata);

          $display("\nTB stats:");
          $display("Flits read from memory (pkt): %d", rddm_write_pkt_cnt);
          $display("Flits read from memory (dsc): %d", rddm_write_dsc_cnt);
          $display("Total RX length (in bytes): %d", total_rx_length);
          $display("Total TX length (in bytes): %d", total_tx_length);
          $display("Total # TX descriptors: %d", total_nb_tx_dscs);
          $display("Average TX transfer size: %d",
                   total_tx_length/total_nb_tx_dscs);
          $display("Max TX transfer size: %d", max_tx_length);
          $display("RX PDU flit cnt: %d", rx_pdu_flit_cnt);
          $display("TX queue full cnt: %d", tx_queue_full_cnt);
          $finish;
        end
      end
    endcase
  end
end

`ASSERT_KNOWN_IF(TopReadDataKnown, top_readdata, top_readdata_valid, clk_status,
                 rst)

dc_fifo_wrapper input_fifo (
  .in_clk            (clk_rxmac),
  .in_reset_n        (!rst),
  .out_clk           (clk_datamover),
  .out_reset_n       (!rst),
  .in_data           (stats_rx_data),
  .in_valid          (stats_rx_valid),
  .in_ready          (stats_rx_ready),
  .in_startofpacket  (stats_rx_startofpacket),
  .in_endofpacket    (stats_rx_endofpacket),
  .in_empty          (stats_rx_empty),
  .out_data          (top_in_data),
  .out_valid         (top_in_valid),
  .out_ready         (1'b1),
  .out_startofpacket (top_in_startofpacket),
  .out_endofpacket   (top_in_endofpacket),
  .out_empty         (top_in_empty)
);

top top_inst (
  // Clk & rst.
  .clk                          (clk_user),
  .rst                          (rst),
  .clk_datamover                (clk_datamover),
  .rst_datamover                (rst_datamover),
  .clk_pcie                     (clk_pcie),
  .rst_pcie                     (rst),

  // Ethernet in & out data.
  .in_data                      (reg_top_in_data),
  .in_valid                     (reg_top_in_valid),
  .in_sop                       (reg_top_in_startofpacket),
  .in_eop                       (reg_top_in_endofpacket),
  .in_empty                     (reg_top_in_empty),
  .out_data                     (top_out_data),
  .out_valid                    (top_out_valid),
  .out_almost_full              (reg_top_out_almost_full),
  .eth_port_nb                  (reg_top_eth_port_nb),
  .out_sop                      (top_out_startofpacket),
  .out_eop                      (top_out_endofpacket),
  .out_empty                    (top_out_empty),

  // PCIe.
  .pcie_wrdm_desc_ready         (pcie_wrdm_desc_ready),
  .pcie_wrdm_desc_valid         (pcie_wrdm_desc_valid),
  .pcie_wrdm_desc_data          (pcie_wrdm_desc_data),
  .pcie_wrdm_prio_ready         (pcie_wrdm_prio_ready),
  .pcie_wrdm_prio_valid         (pcie_wrdm_prio_valid),
  .pcie_wrdm_prio_data          (pcie_wrdm_prio_data),
  .pcie_wrdm_tx_valid           (pcie_wrdm_tx_valid),
  .pcie_wrdm_tx_data            (pcie_wrdm_tx_data),
  .pcie_rddm_desc_ready         (pcie_rddm_desc_ready),
  .pcie_rddm_desc_valid         (pcie_rddm_desc_valid),
  .pcie_rddm_desc_data          (pcie_rddm_desc_data),
  .pcie_rddm_prio_ready         (pcie_rddm_prio_ready),
  .pcie_rddm_prio_valid         (pcie_rddm_prio_valid),
  .pcie_rddm_prio_data          (pcie_rddm_prio_data),
  .pcie_rddm_tx_valid           (pcie_rddm_tx_valid),
  .pcie_rddm_tx_data            (pcie_rddm_tx_data),
  .pcie_bas_waitrequest         (pcie_bas_waitrequest),
  .pcie_bas_address             (pcie_bas_address),
  .pcie_bas_byteenable          (pcie_bas_byteenable),
  .pcie_bas_read                (pcie_bas_read),
  .pcie_bas_readdata            (pcie_bas_readdata),
  .pcie_bas_readdatavalid       (pcie_bas_readdatavalid),
  .pcie_bas_write               (pcie_bas_write),
  .pcie_bas_writedata           (pcie_bas_writedata),
  .pcie_bas_burstcount          (pcie_bas_burstcount),
  .pcie_bas_response            (pcie_bas_response),
  .pcie_address_0               (pcie_address_0),
  .pcie_write_0                 (pcie_write_0),
  .pcie_read_0                  (pcie_read_0),
  .pcie_readdatavalid_0         (pcie_readdatavalid_0),
  .pcie_readdata_0              (pcie_readdata_0),
  .pcie_writedata_0             (pcie_writedata_0),
  .pcie_byteenable_0            (pcie_byteenable_0),
  .pcie_rddm_address            (top_pcie_rddm_address),
  .pcie_rddm_write              (top_pcie_rddm_write),
  .pcie_rddm_writedata          (top_pcie_rddm_writedata),
  .pcie_rddm_byteenable         (top_pcie_rddm_byteenable),
  .pcie_rddm_waitrequest        (top_pcie_rddm_waitrequest),
  //eSRAM
  .reg_esram_pkt_buf_wren       (esram_pkt_buf_wren),
  .reg_esram_pkt_buf_wraddress  (esram_pkt_buf_wraddress),
  .reg_esram_pkt_buf_wrdata     (esram_pkt_buf_wrdata),
  .reg_esram_pkt_buf_rden       (esram_pkt_buf_rden),
  .reg_esram_pkt_buf_rdaddress  (esram_pkt_buf_rdaddress),
  .esram_pkt_buf_rd_valid       (reg_esram_pkt_buf_rd_valid),
  .esram_pkt_buf_rddata         (reg_esram_pkt_buf_rddata),

  // JTAG.
  .clk_status                   (clk_status),
  .status_addr                  (s_addr),
  .status_read                  (s_read),
  .status_write                 (s_write),
  .status_writedata             (s_writedata),
  .status_readdata              (top_readdata),
  .status_readdata_valid        (top_readdata_valid)
);

hyper_pipe_root reg_io_inst (
  //clk & rst
  .clk                    (clk_user),
  .rst                    (rst),
  .clk_datamover          (clk_datamover),
  .rst_datamover          (rst_datamover),
  //Ethernet in & out data
  .in_data                (top_in_data),
  .in_valid               (top_in_valid),
  .in_sop                 (top_in_startofpacket),
  .in_eop                 (top_in_endofpacket),
  .in_empty               (top_in_empty),
  .out_data               (top_out_data),
  .out_valid              (top_out_valid),
  .out_almost_full        (top_out_almost_full),
  .out_sop                (top_out_startofpacket),
  .out_eop                (top_out_endofpacket),
  .out_empty              (top_out_empty),
  //eSRAM
  .esram_pkt_buf_wren     (esram_pkt_buf_wren),
  .esram_pkt_buf_wraddress(esram_pkt_buf_wraddress),
  .esram_pkt_buf_wrdata   (esram_pkt_buf_wrdata),
  .esram_pkt_buf_rden     (esram_pkt_buf_rden),
  .esram_pkt_buf_rdaddress(esram_pkt_buf_rdaddress),
  .esram_pkt_buf_rd_valid (esram_pkt_buf_rd_valid),
  .esram_pkt_buf_rddata   (esram_pkt_buf_rddata),
  //output
  .reg_in_data                (reg_top_in_data),
  .reg_in_valid               (reg_top_in_valid),
  .reg_in_sop                 (reg_top_in_startofpacket),
  .reg_in_eop                 (reg_top_in_endofpacket),
  .reg_in_empty               (reg_top_in_empty),
  .reg_out_data               (reg_top_out_data),
  .reg_out_valid              (reg_top_out_valid),
  .reg_out_almost_full        (reg_top_out_almost_full),
  .reg_out_sop                (reg_top_out_startofpacket),
  .reg_out_eop                (reg_top_out_endofpacket),
  .reg_out_empty              (reg_top_out_empty),
  .reg_esram_pkt_buf_wren     (reg_esram_pkt_buf_wren),
  .reg_esram_pkt_buf_wraddress(reg_esram_pkt_buf_wraddress),
  .reg_esram_pkt_buf_wrdata   (reg_esram_pkt_buf_wrdata),
  .reg_esram_pkt_buf_rden     (reg_esram_pkt_buf_rden),
  .reg_esram_pkt_buf_rdaddress(reg_esram_pkt_buf_rdaddress),
  .reg_esram_pkt_buf_rd_valid (reg_esram_pkt_buf_rd_valid),
  .reg_esram_pkt_buf_rddata   (reg_esram_pkt_buf_rddata)
);


dc_fifo_wrapper_infill out_fifo0 (
  .in_clk            (clk_user),
  .in_reset_n        (!rst),
  .out_clk           (clk_txmac),
  .out_reset_n       (!rst),
  .in_csr_address    (out_fifo0_in_csr_address),
  .in_csr_read       (out_fifo0_in_csr_read),
  .in_csr_write      (out_fifo0_in_csr_write),
  .in_csr_readdata   (out_fifo0_in_csr_readdata),
  .in_csr_writedata  (out_fifo0_in_csr_writedata),
  .in_data           (reg_top_out_data),
  .in_valid          (reg_top_out_valid),
  .in_ready          (),
  .in_startofpacket  (reg_top_out_startofpacket),
  .in_endofpacket    (reg_top_out_endofpacket),
  .in_empty          (reg_top_out_empty),
  .out_data          (l8_tx_data),
  .out_valid         (l8_tx_valid),
  .out_ready         (l8_tx_ready),
  .out_startofpacket (l8_tx_startofpacket),
  .out_endofpacket   (l8_tx_endofpacket),
  .out_empty         (l8_tx_empty)
);

dc_back_pressure #(
  .FULL_LEVEL(490)
)
dc_bp_out_fifo0 (
  .clk            (clk_user),
  .rst            (rst),
  .csr_address    (out_fifo0_in_csr_address),
  .csr_read       (out_fifo0_in_csr_read),
  .csr_write      (out_fifo0_in_csr_write),
  .csr_readdata   (out_fifo0_in_csr_readdata),
  .csr_writedata  (out_fifo0_in_csr_writedata),
  .almost_full    (top_out_almost_full)
);

my_stats stats(
  .arst(rst),

  .clk_tx(clk_txmac),
  .tx_ready(l8_tx_ready),
  .tx_valid(l8_tx_valid),
  .tx_data(l8_tx_data),
  .tx_sop(l8_tx_startofpacket),
  .tx_eop(l8_tx_endofpacket),
  .tx_empty(l8_tx_empty),

  .clk_rx(clk_rxmac),
  .rx_sop(l8_rx_startofpacket),
  .rx_eop(l8_rx_endofpacket),
  .rx_empty(l8_rx_empty),
  .rx_data(l8_rx_data),
  .rx_valid(l8_rx_valid),

  .rx_ready(stats_rx_ready),
  .o_rx_sop(stats_rx_startofpacket),
  .o_rx_eop(stats_rx_endofpacket),
  .o_rx_empty(stats_rx_empty),
  .o_rx_data(stats_rx_data),
  .o_rx_valid(stats_rx_valid),

  .clk_status(clk_status),
  .status_addr(s_addr),
  .status_read(s_read),
  .status_write(s_write),
  .status_writedata(s_writedata),
  .status_readdata(s_readdata),
  .status_readdata_valid(s_readdata_valid)
);

esram_wrapper esram_pkt_buffer(
  .clk_esram_ref  (clk_esram_ref), //100 MHz
  .esram_pll_lock (esram_pll_lock),
  .clk_esram      (clk_esram), //200 MHz
  .wren           (reg_esram_pkt_buf_wren),
  .wraddress      (reg_esram_pkt_buf_wraddress),
  .wrdata         (reg_esram_pkt_buf_wrdata),
  .rden           (reg_esram_pkt_buf_rden),
  .rdaddress      (reg_esram_pkt_buf_rdaddress),
  .rd_valid       (esram_pkt_buf_rd_valid),
  .rddata         (esram_pkt_buf_rddata)
);

endmodule
