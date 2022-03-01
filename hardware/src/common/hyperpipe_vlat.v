// Quartus Prime Verilog Template

/// Hyper-Pipelining Variable Latency Module
/// 
/// This adds a variable number of pipeline stages (up to MAX_PIPE) between din
/// and dout. The number of pipeline stages are defined at compilation time.
module hyperpipe_vlat #(
  parameter WIDTH = 1,
  parameter MAX_PIPE = 100  // Valid range for MAX_PIPE: 0 to 100 inclusive.
)(
  input clk,
  input  [WIDTH-1:0] din,
  output [WIDTH-1:0] dout
);

  // Capping the value of MAX_PIPE to 100 because MAX_PIPE > 100 could cause errors
  localparam MAX_PIPE_CAPPED =
    (MAX_PIPE > 100) ? 100 : ((MAX_PIPE < 0) ? 0 : MAX_PIPE);

  // Converting MAX_PIPE_CAPPED to string so it can be used as a string when setting altera_attribute
  localparam MAX_PIPE_STR = {
    ((MAX_PIPE_CAPPED / 100) % 10) + 8'd48,
    ((MAX_PIPE_CAPPED / 10) % 10) + 8'd48,
    (MAX_PIPE_CAPPED % 10) + 8'd48
  };

  (* altera_attribute = {
    "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name HYPER_RETIMER_ADD_PIPELINING ",
    MAX_PIPE_STR
  } *)
  reg [WIDTH-1:0] vlat_r /* synthesis preserve */;

  always @ (posedge clk) begin
    vlat_r <= din;
  end

  assign dout = vlat_r;

endmodule
