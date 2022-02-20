`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
`include "../src/constants.sv"

module test_rate_limiter;

localparam PERIOD = 4;

localparam SAMPLE_PKT = 512'hffffffffffffac1f6bbc58b908004500002e000100004011f96dc0a80000c0a800001f900050001a5e89000000000000000000000000000000000000ffffffff;
localparam SAMPLE_PKT_EMPTY = 4;

localparam NUMERATOR = 1;  // Must be 1 for the assertions to work.
localparam DENOMINATOR = 20;

logic clk;
logic rst;
logic [63:0] cnt;

logic [511:0] in_pkt_data;
logic         in_pkt_valid;
logic         in_pkt_ready;
logic         in_pkt_sop;
logic         in_pkt_eop;
logic [5:0]   in_pkt_empty;

logic [511:0] out_pkt_data;
logic         out_pkt_valid;
logic         out_pkt_ready;
logic         out_pkt_sop;
logic         out_pkt_eop;
logic [5:0]   out_pkt_empty;

logic [511:0] in_fifo_pkt_data;
logic         in_fifo_pkt_valid;
logic         in_fifo_pkt_ready;
logic         in_fifo_pkt_sop;
logic         in_fifo_pkt_eop;
logic [5:0]   in_fifo_pkt_empty;

rate_limit_config_t conf_rl_data;
logic               conf_rl_valid;
logic               conf_rl_ready;

logic [63:0] last_flit_cnt;
logic [31:0] nb_flits;

initial clk = 0;
initial rst = 1;
initial cnt = 0;

always #(PERIOD) clk = ~clk;

always @(posedge clk) begin
  cnt <= cnt + 1;
  conf_rl_valid <= 0;
  in_fifo_pkt_valid <= 0;
  out_pkt_ready <= 1;

  if (cnt < 10) begin
    last_flit_cnt <= 0;
    nb_flits <= 0;
  end else if (cnt == 10) begin
    rst <= 0;
  end else if (cnt == 11) begin
    automatic rate_limit_config_t configuration = 0;
    configuration.enable = 1;
    configuration.config_id = RATE_LIMIT_CONFIG_ID;
    configuration.numerator = NUMERATOR;
    configuration.denominator = DENOMINATOR;
    conf_rl_data <= configuration;
    conf_rl_valid <= 1;
  end else if (cnt == 20) begin
    in_fifo_pkt_data <= SAMPLE_PKT;
    in_fifo_pkt_data[31:0] <= 0;
    in_fifo_pkt_sop <= 1;
    in_fifo_pkt_eop <= 1;
    in_fifo_pkt_empty <= SAMPLE_PKT_EMPTY;
    in_fifo_pkt_valid <= 1;
  end else if (cnt == 21) begin
    in_fifo_pkt_data <= SAMPLE_PKT;
    in_fifo_pkt_data[31:0] <= 1;
    in_fifo_pkt_sop <= 1;
    in_fifo_pkt_eop <= 1;
    in_fifo_pkt_empty <= SAMPLE_PKT_EMPTY;
    in_fifo_pkt_valid <= 1;
  end else if (cnt == 22) begin
    in_fifo_pkt_data <= SAMPLE_PKT;
    in_fifo_pkt_data[31:0] <= 2;
    in_fifo_pkt_sop <= 1;
    in_fifo_pkt_eop <= 1;
    in_fifo_pkt_empty <= SAMPLE_PKT_EMPTY;
    in_fifo_pkt_valid <= 1;
  end else if (cnt == 23) begin
    in_fifo_pkt_data <= SAMPLE_PKT;
    in_fifo_pkt_data[31:0] <= 3;
    in_fifo_pkt_sop <= 1;
    in_fifo_pkt_eop <= 1;
    in_fifo_pkt_empty <= SAMPLE_PKT_EMPTY;
    in_fifo_pkt_valid <= 1;
  end else if (cnt == 30 + DENOMINATOR*4) begin
    $finish;
  end

  if (out_pkt_valid) begin
    last_flit_cnt <= cnt;
    nb_flits <= nb_flits + 1;
    assert(nb_flits == out_pkt_data[31:0]);
    if (last_flit_cnt != 0) begin
      assert(cnt == last_flit_cnt + DENOMINATOR);
    end
  end
end

fifo_pkt_wrapper_infill #(
  .SYMBOLS_PER_BEAT(1),
  .BITS_PER_SYMBOL(512),
  .FIFO_DEPTH(16)
) fifo (
  .clk               (clk),
  .reset             (rst),
  .csr_address       (2'b0),
  .csr_read          (1'b1),
  .csr_write         (1'b0),
  .csr_readdata      (),
  .csr_writedata     (32'b0),
  .in_data           (in_fifo_pkt_data),
  .in_valid          (in_fifo_pkt_valid),
  .in_ready          (in_fifo_pkt_ready),
  .in_startofpacket  (in_fifo_pkt_sop),
  .in_endofpacket    (in_fifo_pkt_eop),
  .in_empty          (in_fifo_pkt_empty),
  .out_data          (in_pkt_data),
  .out_valid         (in_pkt_valid),
  .out_ready         (in_pkt_ready),
  .out_startofpacket (in_pkt_sop),
  .out_endofpacket   (in_pkt_eop),
  .out_empty         (in_pkt_empty)
);

rate_limiter rate_limiter_inst (
  .clk           (clk),
  .rst           (rst),
  .in_pkt_data   (in_pkt_data),
  .in_pkt_valid  (in_pkt_valid),
  .in_pkt_ready  (in_pkt_ready),
  .in_pkt_sop    (in_pkt_sop),
  .in_pkt_eop    (in_pkt_eop),
  .in_pkt_empty  (in_pkt_empty),
  .out_pkt_data  (out_pkt_data),
  .out_pkt_valid (out_pkt_valid),
  .out_pkt_ready (out_pkt_ready),
  .out_pkt_sop   (out_pkt_sop),
  .out_pkt_eop   (out_pkt_eop),
  .out_pkt_empty (out_pkt_empty),
  .conf_rl_data  (conf_rl_data),
  .conf_rl_valid (conf_rl_valid),
  .conf_rl_ready (conf_rl_ready)
);

endmodule
