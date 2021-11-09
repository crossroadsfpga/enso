`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
`include "../src/constants.sv"
`include "../src/pcie/pcie_consts.sv"

module test_cpu_to_fpga;

localparam PERIOD = 4;

localparam NB_QUEUES = 4;  // Must be at least 2.
localparam RB_SIZE = 64;

generate
    if (NB_QUEUES < 2) begin
        $error("NB_QUEUES must be at least 2");
    end
endgenerate

localparam QUEUE_ADDR_WIDTH = $clog2(NB_QUEUES);

logic clk;
logic rst;
logic [63:0] cnt;

initial clk = 0;
initial rst = 1;
initial cnt = 0;

always #(PERIOD) clk = ~clk;

// Packet buffer output.
logic         pcie_tx_pkt_sop;
logic         pcie_tx_pkt_eop;
logic         pcie_tx_pkt_valid;
logic [511:0] pcie_tx_pkt_data;
logic [5:0]   pcie_tx_pkt_empty;
logic         pcie_tx_pkt_ready;
logic [31:0]  pcie_tx_pkt_occup;

tx_transfer_t tx_compl_buf_data;
logic         tx_compl_buf_valid;
logic         tx_compl_buf_ready;
logic [31:0]  tx_compl_buf_occup;

// PCIe Read Data Mover (RDDM) signals.
logic         pcie_rddm_desc_ready;
logic         pcie_rddm_desc_valid;
logic [173:0] pcie_rddm_desc_data;
logic         pcie_rddm_prio_ready;
logic         pcie_rddm_prio_valid;
logic [173:0] pcie_rddm_prio_data;
logic         pcie_rddm_tx_valid;
logic [31:0]  pcie_rddm_tx_data;

// RDDM Avalon-MM signals.
logic [63:0]  pcie_rddm_address;
logic         pcie_rddm_write;
logic [511:0] pcie_rddm_writedata;
logic [63:0]  pcie_rddm_byteenable;

bram_interface_io #(.ADDR_WIDTH(QUEUE_ADDR_WIDTH)) tx_dsc_q_table_tails();
bram_interface_io #(.ADDR_WIDTH(QUEUE_ADDR_WIDTH)) tx_dsc_q_table_heads();
bram_interface_io #(.ADDR_WIDTH(QUEUE_ADDR_WIDTH)) tx_dsc_q_table_l_addrs();
bram_interface_io #(.ADDR_WIDTH(QUEUE_ADDR_WIDTH)) tx_dsc_q_table_h_addrs();

virtual bram_interface_io.user #(
  .ADDR_WIDTH(QUEUE_ADDR_WIDTH)
) q_table_tails_user = tx_dsc_q_table_tails.user;

virtual bram_interface_io.user #(
  .ADDR_WIDTH(QUEUE_ADDR_WIDTH)
) q_table_heads_user = tx_dsc_q_table_heads.user;

virtual bram_interface_io.user #(
  .ADDR_WIDTH(QUEUE_ADDR_WIDTH)
) q_table_l_addrs_user = tx_dsc_q_table_l_addrs.user;

virtual bram_interface_io.user #(
  .ADDR_WIDTH(QUEUE_ADDR_WIDTH)
) q_table_h_addrs_user = tx_dsc_q_table_h_addrs.user;

logic [RB_AWIDTH:0] dsc_rb_size;

logic [31:0] tx_ignored_dsc_cnt;
logic [31:0] tx_q_full_signals;
logic [31:0] tx_dsc_cnt;
logic [31:0] tx_empty_tail_cnt;
logic [31:0] tx_batch_cnt;

logic [PKT_Q_TABLE_TAILS_DWIDTH-1:0] tx_dsc_tail;
logic [PKT_Q_TABLE_TAILS_DWIDTH-1:0] expected_tx_dsc_tail;
logic [31:0] pkt_rx_cnt;
logic [31:0] pkt_tx_cnt;
logic [31:0] rx_step;
logic [31:0] tx_step;

assign dsc_rb_size = 2048;

always @(posedge clk) begin
  pcie_tx_pkt_ready <= 1;
  pcie_tx_pkt_occup <= 0;

  tx_compl_buf_ready <= 1;
  tx_compl_buf_occup <= 0;
  
  pcie_rddm_prio_ready <= 1;

  pcie_rddm_tx_valid <= 0;
  pcie_rddm_tx_data <= 32'bx;

  pcie_rddm_write <= 0; // TODO(sadok): Test this as well.

  q_table_tails_user.wr_en <= 0;
  q_table_heads_user.wr_en <= 0;
  q_table_l_addrs_user.wr_en <= 0;
  q_table_h_addrs_user.wr_en <= 0;

  q_table_tails_user.rd_en <= 0;
  q_table_heads_user.rd_en <= 0;
  q_table_l_addrs_user.rd_en <= 0;
  q_table_h_addrs_user.rd_en <= 0;

  if (cnt < 10) begin
    cnt <= cnt + 1;
  end else if (cnt == 10) begin
    rst <= 0;
    cnt <= cnt + 1;
    tx_dsc_tail <= 1;
    pkt_tx_cnt <= 0;
    pkt_rx_cnt <= 0;
    rx_step <= 0;
    tx_step <= 0;

    pcie_rddm_desc_ready <= 1;
  end else if (cnt == 11) begin
    const int nb_steps = 100;
    automatic int increm_seq[] = new[nb_steps];
    automatic int expected_tails[] = new[nb_steps];
    automatic logic [PKT_Q_TABLE_TAILS_DWIDTH-1:0] next_tail = 1;
    automatic int j = 0;
    increm_seq = '{1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 0, 0, 1,
                   0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0,
                   0, 0, 0, 0, 6, 5, 4, 3, 2, 1, 0, 2, 0, 0, 1, 1, 0, 1, 1, 1,
                   0, 1, 1, 0, 0, 2, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 0, 2, 0, 0,
                   0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 2, 3, 4, 5, 6};
    for (int i = 0; i < nb_steps; i++) begin
      if (increm_seq[i] != 0) begin
        expected_tails[j] = next_tail;
        next_tail = (next_tail + increm_seq[i]) % RB_SIZE;
        j++;
      end
    end

    if (tx_step < nb_steps) begin
      tx_step <= tx_step + 1;
      q_table_tails_user.wr_en <= 1;
      q_table_tails_user.addr <= 0;
      q_table_tails_user.wr_data <= tx_dsc_tail;
      
      tx_dsc_tail <= (tx_dsc_tail + increm_seq[tx_step]) % RB_SIZE;
      pkt_tx_cnt <= pkt_tx_cnt + increm_seq[tx_step];
      pcie_rddm_desc_ready <= ~pcie_rddm_desc_ready;
    end

    // Got a DMA read for a descriptor.
    if (pcie_rddm_desc_valid & pcie_rddm_desc_ready) begin
      automatic rddm_desc_t rddm_desc = pcie_rddm_desc_data;
      rx_step <= rx_step + 1;

      // $display("pcie_rddm_desc_data: %p", rddm_desc);
      assert(((rddm_desc.src_addr/64 + rddm_desc.nb_dwords/16) % RB_SIZE)
             == expected_tails[rx_step]) else begin
        $display("rddm_desc.src_addr: %d", rddm_desc.src_addr);
        $display("rddm_desc.nb_dwords: %d", rddm_desc.nb_dwords);
        $fatal;
      end
      pkt_rx_cnt <= pkt_rx_cnt + rddm_desc.nb_dwords/16;

      if ((rx_step + 1) == j) begin
        cnt <= cnt + 1;
      end
    end
  end else if (cnt == 12) begin
    $display("PCIE_TX_IGNORED_DSC:\t%d", tx_ignored_dsc_cnt);
    $display("PCIE_TX_Q_FULL_SIG:\t%d", tx_q_full_signals);
    $display("PCIE_TX_DSC_CNT:\t%d", tx_dsc_cnt);
    $display("PCIE_TX_EMPTY_TAIL:\t%d", tx_empty_tail_cnt);
    $display("PCIE_TX_BATCH_CNT:\t%d", tx_batch_cnt);
    $finish;
  end
end

cpu_to_fpga #(
  .NB_QUEUES(NB_QUEUES)
) cpu_to_fpga_inst (
  .clk                  (clk),
  .rst                  (rst),
  .out_pkt_sop          (pcie_tx_pkt_sop),
  .out_pkt_eop          (pcie_tx_pkt_eop),
  .out_pkt_valid        (pcie_tx_pkt_valid),
  .out_pkt_data         (pcie_tx_pkt_data),
  .out_pkt_empty        (pcie_tx_pkt_empty),
  .out_pkt_ready        (pcie_tx_pkt_ready),
  .out_pkt_occup        (pcie_tx_pkt_occup),
  .tx_compl_buf_data    (tx_compl_buf_data),
  .tx_compl_buf_valid   (tx_compl_buf_valid),
  .tx_compl_buf_ready   (tx_compl_buf_ready),
  .tx_compl_buf_occup   (tx_compl_buf_occup),
  .pcie_rddm_desc_ready (pcie_rddm_desc_ready),
  .pcie_rddm_desc_valid (pcie_rddm_desc_valid),
  .pcie_rddm_desc_data  (pcie_rddm_desc_data),
  .pcie_rddm_prio_ready (pcie_rddm_prio_ready),
  .pcie_rddm_prio_valid (pcie_rddm_prio_valid),
  .pcie_rddm_prio_data  (pcie_rddm_prio_data),
  .pcie_rddm_tx_valid   (pcie_rddm_tx_valid),
  .pcie_rddm_tx_data    (pcie_rddm_tx_data),
  .pcie_rddm_address    (pcie_rddm_address),
  .pcie_rddm_write      (pcie_rddm_write),
  .pcie_rddm_writedata  (pcie_rddm_writedata),
  .pcie_rddm_byteenable (pcie_rddm_byteenable),
  .q_table_tails        (tx_dsc_q_table_tails.owner),
  .q_table_heads        (tx_dsc_q_table_heads.owner),
  .q_table_l_addrs      (tx_dsc_q_table_l_addrs.owner),
  .q_table_h_addrs      (tx_dsc_q_table_h_addrs.owner),
  .rb_size              (dsc_rb_size),  // TODO(sadok): use different rb size?
  .ignored_dsc_cnt      (tx_ignored_dsc_cnt),
  .queue_full_signals   (tx_q_full_signals),
  .dsc_cnt              (tx_dsc_cnt),
  .empty_tail_cnt       (tx_empty_tail_cnt),
  .batch_cnt            (tx_batch_cnt)
);

endmodule
