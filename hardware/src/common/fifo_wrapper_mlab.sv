// input_parser_st_sc_fifo_0.v

// Generated using ACDS version 18.1 222

`timescale 1 ps / 1 ps

`include "prim_assert.sv"

module fifo_wrapper_mlab #(
		parameter SYMBOLS_PER_BEAT    = 64,
		parameter BITS_PER_SYMBOL     = 8,
		parameter FIFO_DEPTH          = 32,
		parameter CHANNEL_WIDTH       = 0,
		parameter ERROR_WIDTH         = 0,
		parameter USE_PACKETS         = 0,
		parameter USE_FILL_LEVEL      = 0,
		parameter EMPTY_LATENCY       = 3,
		parameter USE_MEMORY_BLOCKS   = 1,
		parameter USE_STORE_FORWARD   = 0,
		parameter USE_ALMOST_FULL_IF  = 0,
		parameter USE_ALMOST_EMPTY_IF = 0
	) (
		input  wire         clk,       //       clk.clk
		input  wire         reset,     // clk_reset.reset
		input  wire [SYMBOLS_PER_BEAT*BITS_PER_SYMBOL-1:0] in_data,   //        in.data
		input  wire         in_valid,  //          .valid
		output wire         in_ready,  //          .ready
		output wire [SYMBOLS_PER_BEAT*BITS_PER_SYMBOL-1:0] out_data,  //       out.data
		output wire         out_valid, //          .valid
		input  wire         out_ready  //          .ready
	);

	fifo_core_mlab #(
		.SYMBOLS_PER_BEAT    (SYMBOLS_PER_BEAT),
		.BITS_PER_SYMBOL     (BITS_PER_SYMBOL),
		.FIFO_DEPTH          (FIFO_DEPTH),
		.CHANNEL_WIDTH       (CHANNEL_WIDTH),
		.ERROR_WIDTH         (ERROR_WIDTH),
		.USE_PACKETS         (USE_PACKETS),
		.USE_FILL_LEVEL      (USE_FILL_LEVEL),
		.EMPTY_LATENCY       (EMPTY_LATENCY),
		.USE_MEMORY_BLOCKS   (USE_MEMORY_BLOCKS),
		.USE_STORE_FORWARD   (USE_STORE_FORWARD),
		.USE_ALMOST_FULL_IF  (USE_ALMOST_FULL_IF),
		.USE_ALMOST_EMPTY_IF (USE_ALMOST_EMPTY_IF)
	) fifo_core_0 (
		.clk               (clk),                                  //   input,    width = 1,       clk.clk
		.reset             (reset),                                //   input,    width = 1, clk_reset.reset
		.in_data           (in_data),                              //   input,  width = 512,        in.data
		.in_valid          (in_valid),                             //   input,    width = 1,          .valid
		.in_ready          (in_ready),                             //  output,    width = 1,          .ready
		.out_data          (out_data),                             //  output,  width = 512,       out.data
		.out_valid         (out_valid),                            //  output,    width = 1,          .valid
		.out_ready         (out_ready),                            //   input,    width = 1,          .ready
		.csr_address       (2'b00),                                // (terminated),                         
		.csr_read          (1'b0),                                 // (terminated),                         
		.csr_write         (1'b0),                                 // (terminated),                         
		.csr_readdata      (),                                     // (terminated),                         
		.csr_writedata     (32'b00000000000000000000000000000000), // (terminated),                         
		.almost_full_data  (),                                     // (terminated),                         
		.almost_empty_data (),                                     // (terminated),                         
		.in_startofpacket  (1'b0),                                 // (terminated),                         
		.in_endofpacket    (1'b0),                                 // (terminated),                         
		.out_startofpacket (),                                     // (terminated),                         
		.out_endofpacket   (),                                     // (terminated),                         
		.in_empty          (1'b0),                                 // (terminated),                         
		.out_empty         (),                                     // (terminated),                         
		.in_error          (1'b0),                                 // (terminated),                         
		.out_error         (),                                     // (terminated),                         
		.in_channel        (1'b0),                                 // (terminated),                         
		.out_channel       ()                                      // (terminated),                         
	);

	`ASSERT(FifoWrapperMlabEnqueueWhenFull, !in_ready |-> !in_valid, clk, reset)

endmodule