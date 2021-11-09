`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
`include "../src/constants.sv"

module module_name; // Change me!

localparam PERIOD = 4;

logic clk;
logic rst;
logic [63:0] cnt;

initial clk = 0;
initial rst = 1;
initial cnt = 0;

always #(PERIOD) clk = ~clk;

always @(posedge clk) begin
  if (cnt < 10) begin
    cnt <= cnt + 1;
  end else if (cnt == 10) begin
    rst <= 0;
    cnt <= cnt + 1;
  end else if (cnt == 11) begin
    /* Insert logic here */
  end
  
end

endmodule
