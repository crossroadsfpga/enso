`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
`include "../src/constants.sv"

module test_timestamp;

localparam PERIOD = 4;

localparam SAMPLE_PKT = 512'hffffffffffffac1f6bbc58b908004500002e000100004011f96dc0a80000c0a800001f900050001a5e89000000000000000000000000000000000000ffffffff;
localparam SAMPLE_PKT_EMPTY = 4;

localparam TIMESTAMP_WIDTH = 32;
localparam TIMESTAMP_OFFSET = 112 + 32;

localparam REVERSED_OFFSET = 512 - TIMESTAMP_OFFSET - TIMESTAMP_WIDTH;

localparam EMULATED_RTT = 20;

logic clk;
logic rst;
logic [63:0] cnt;

logic [511:0] rx_in_pkt_data;
logic         rx_in_pkt_valid;
logic         rx_in_pkt_sop;
logic         rx_in_pkt_eop;
logic [5:0]   rx_in_pkt_empty;

logic [511:0] delayed_rx_in_pkt_data;
logic         delayed_rx_in_pkt_valid;
logic         delayed_rx_in_pkt_sop;
logic         delayed_rx_in_pkt_eop;
logic [5:0]   delayed_rx_in_pkt_empty;

logic [511:0] rx_out_pkt_data;
logic         rx_out_pkt_valid;
logic         rx_out_pkt_ready;
logic         rx_out_pkt_sop;
logic         rx_out_pkt_eop;
logic [5:0]   rx_out_pkt_empty;

logic [511:0] tx_in_pkt_data;
logic         tx_in_pkt_valid;
logic         tx_in_pkt_ready;
logic         tx_in_pkt_sop;
logic         tx_in_pkt_eop;
logic [5:0]   tx_in_pkt_empty;

logic [511:0] tx_out_pkt_data;
logic         tx_out_pkt_valid;
logic         tx_out_pkt_ready;
logic         tx_out_pkt_sop;
logic         tx_out_pkt_eop;
logic [5:0]   tx_out_pkt_empty;

timestamp_config_t conf_ts_data;
logic              conf_ts_valid;
logic              conf_ts_ready;

initial clk = 0;
initial rst = 1;
initial cnt = 0;

always #(PERIOD) clk = ~clk;

logic [TIMESTAMP_WIDTH-1:0] last_timestamp;

always @(posedge clk) begin
  cnt <= cnt + 1;

  tx_in_pkt_valid <= 0;
  rx_in_pkt_valid <= 0;
  conf_ts_valid <= 0;

  tx_in_pkt_sop <= 0;
  tx_in_pkt_eop <= 0;
  tx_in_pkt_empty <= 0;

  if (cnt < 10) begin
    last_timestamp <= 0;
  end else if (cnt == 10) begin
    rst <= 0;

    rx_out_pkt_ready <= 1;
    tx_out_pkt_ready <= 1;
  end else if (cnt == 11) begin
    automatic timestamp_config_t configuration = 0;
    configuration.enable = 1;
    configuration.config_id = TIMESTAMP_CONFIG_ID;
    configuration.offset = TIMESTAMP_OFFSET / 8;
    conf_ts_data <= configuration;
    conf_ts_valid <= 1;
  end else if (cnt == 20) begin
    tx_in_pkt_data <= SAMPLE_PKT;
    tx_in_pkt_sop <= 1;
    tx_in_pkt_eop <= 1;
    tx_in_pkt_empty <= SAMPLE_PKT_EMPTY;
    tx_in_pkt_valid <= 1;
  end else if (cnt == 21) begin
    tx_in_pkt_data <= SAMPLE_PKT;
    tx_in_pkt_sop <= 1;
    tx_in_pkt_eop <= 1;
    tx_in_pkt_empty <= SAMPLE_PKT_EMPTY;
    tx_in_pkt_valid <= 1;
  end else if (cnt == (30 + EMULATED_RTT)) begin
    $finish;
  end

  if (tx_out_pkt_valid) begin
    automatic logic [TIMESTAMP_WIDTH-1:0] ts;
    ts = tx_out_pkt_data[REVERSED_OFFSET +: TIMESTAMP_WIDTH];

    if (last_timestamp == 0) begin
      last_timestamp <= ts;
    end else begin
      automatic logic [TIMESTAMP_WIDTH-1:0] ts_delta;
      ts_delta = ts - last_timestamp;
      assert(ts_delta == 1);
    end

    rx_in_pkt_data <= tx_out_pkt_data;
    rx_in_pkt_valid <= 1;
    rx_in_pkt_sop <= tx_out_pkt_sop;
    rx_in_pkt_eop <= tx_out_pkt_eop;
    rx_in_pkt_empty <= tx_out_pkt_empty;
  end

  if (rx_out_pkt_valid) begin
    automatic logic [TIMESTAMP_WIDTH-1:0] ts;
    ts = rx_out_pkt_data[REVERSED_OFFSET +: TIMESTAMP_WIDTH];
    assert(ts == EMULATED_RTT+1);
  end
end

hyper_pipe #(
  .WIDTH($bits(rx_in_pkt_data)),
  .NUM_PIPES(EMULATED_RTT)
) hp_in_data (
  .clk  (clk),
  .din  (rx_in_pkt_data),
  .dout (delayed_rx_in_pkt_data)
);
hyper_pipe #(
  .WIDTH($bits(rx_in_pkt_valid)),
  .NUM_PIPES(EMULATED_RTT)
) hp_in_valid (
  .clk  (clk),
  .din  (rx_in_pkt_valid),
  .dout (delayed_rx_in_pkt_valid)
);
hyper_pipe #(
  .WIDTH($bits(rx_in_pkt_sop)),
  .NUM_PIPES(EMULATED_RTT)
) hp_in_sop (
  .clk  (clk),
  .din  (rx_in_pkt_sop),
  .dout (delayed_rx_in_pkt_sop)
);
hyper_pipe #(
  .WIDTH($bits(rx_in_pkt_eop)),
  .NUM_PIPES(EMULATED_RTT)
) hp_in_eop (
  .clk  (clk),
  .din  (rx_in_pkt_eop),
  .dout (delayed_rx_in_pkt_eop)
);
hyper_pipe #(
  .WIDTH($bits(rx_in_pkt_empty)),
  .NUM_PIPES(EMULATED_RTT)
) hp_in_empty (
  .clk  (clk),
  .din  (rx_in_pkt_empty),
  .dout (delayed_rx_in_pkt_empty)
);

timestamp #(
  .TIMESTAMP_WIDTH(TIMESTAMP_WIDTH)
) timestamp_inst (
  .clk              (clk),
  .rst              (rst),
  .rx_in_pkt_data   (delayed_rx_in_pkt_data),
  .rx_in_pkt_valid  (delayed_rx_in_pkt_valid),
  .rx_in_pkt_ready  (),
  .rx_in_pkt_sop    (delayed_rx_in_pkt_sop),
  .rx_in_pkt_eop    (delayed_rx_in_pkt_eop),
  .rx_in_pkt_empty  (rx_in_pkt_empty),
  .rx_out_pkt_data  (rx_out_pkt_data),
  .rx_out_pkt_valid (rx_out_pkt_valid),
  .rx_out_pkt_ready (rx_out_pkt_ready),
  .rx_out_pkt_sop   (rx_out_pkt_sop),
  .rx_out_pkt_eop   (rx_out_pkt_eop),
  .rx_out_pkt_empty (rx_out_pkt_empty),
  .tx_in_pkt_data   (tx_in_pkt_data),
  .tx_in_pkt_valid  (tx_in_pkt_valid),
  .tx_in_pkt_ready  (tx_in_pkt_ready),
  .tx_in_pkt_sop    (tx_in_pkt_sop),
  .tx_in_pkt_eop    (tx_in_pkt_eop),
  .tx_in_pkt_empty  (tx_in_pkt_empty),
  .tx_out_pkt_data  (tx_out_pkt_data),
  .tx_out_pkt_valid (tx_out_pkt_valid),
  .tx_out_pkt_ready (tx_out_pkt_ready),
  .tx_out_pkt_sop   (tx_out_pkt_sop),
  .tx_out_pkt_eop   (tx_out_pkt_eop),
  .tx_out_pkt_empty (tx_out_pkt_empty),
  .conf_ts_data     (conf_ts_data),
  .conf_ts_valid    (conf_ts_valid),
  .conf_ts_ready    (conf_ts_ready)
);

endmodule
