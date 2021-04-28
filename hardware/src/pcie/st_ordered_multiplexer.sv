`include "pcie_consts.sv"

/*
 * Streaming multiplexer that takes an "order" stream that indicates that order
 * that it should serve each stream.
 */

module st_ordered_multiplexer #(
    parameter NB_IN,
    parameter DWIDTH=250,
    parameter DEPTH=16
) (
    input logic clk,
    input logic rst,

    // Interface: in
    input  var logic              in_valid [NB_IN],
    output var logic              in_ready [NB_IN],
    input  var logic [DWIDTH-1:0] in_data  [NB_IN],

    // Interface: out
    output logic              out_valid,
    input  logic              out_ready,
    output logic [DWIDTH-1:0] out_data,

    // Order stream
    input  logic                     order_valid,
    output logic                     order_ready,
    input  logic [$clog2(NB_IN)-1:0] order_data
);

generate
    if ((1 << $clog2(NB_IN)) != NB_IN) begin
        $error("NB_IN must be a power of two");
    end
endgenerate

logic [$clog2(NB_IN)-1:0] out_order_data;
logic                     out_order_valid;
logic                     out_order_ready;

// Even though the signals below are named like a stream they are not one.
// I could not pick a less misleading name...
logic [$clog2(NB_IN)-1:0] next_stream_id;
logic                     next_stream_id_valid;
logic                     next_stream_is_ready;

always_comb begin
    next_stream_is_ready = 
        out_ready & next_stream_id_valid & in_valid[next_stream_id];
    out_order_ready = !next_stream_id_valid | next_stream_is_ready;
    for (integer i = 0; i < NB_IN; i++) begin
        in_ready[i] = out_ready & next_stream_id_valid & (i == next_stream_id); 
    end
end

always @(posedge clk) begin
    next_stream_id_valid <= 0;

    if (out_ready) begin
        out_valid <= 0;
    end

    if (rst) begin
        out_valid <= 0;
    end else begin
        if (next_stream_is_ready) begin
            out_data <= in_data[next_stream_id];
            out_valid <= 1;
            next_stream_id_valid <= 0;
        end

        if (out_order_valid & out_order_ready) begin
            next_stream_id <= out_order_data;
            next_stream_id_valid <= 1;
        end
    end
end

logic [31:0] occup;

fifo_wrapper_infill_mlab #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL($clog2(NB_IN)),
    .FIFO_DEPTH(DEPTH)
)
order_queue (
    .clk           (clk),
    .reset         (rst),
    .csr_address   (2'b0),
    .csr_read      (1'b1),
    .csr_write     (1'b0),
    .csr_readdata  (occup),
    .csr_writedata (32'b0),
    .in_data       (order_data),
    .in_valid      (order_valid),
    .in_ready      (order_ready),
    .out_data      (out_order_data),
    .out_valid     (out_order_valid),
    .out_ready     (out_order_ready)
);

endmodule
