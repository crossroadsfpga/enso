`timescale 1 ps / 1 ps
`include "./constants.sv"
module pdu_gen #(
    parameter OUT_PKT_Q_DEPTH=64,
    parameter OUT_META_Q_DEPTH=128,
    parameter PKT_Q_ALMOST_FULL_THRESHOLD=OUT_PKT_Q_DEPTH - MAX_PKT_SIZE * 2,
    parameter META_Q_ALMOST_FULL_THRESHOLD=OUT_META_Q_DEPTH - 8
)(
    input  logic           clk,
    input  logic           rst,
    input  logic           in_sop,
    input  logic           in_eop,
    input  logic [511:0]   in_data,
    input  logic [5:0]     in_empty,
    input  logic           in_valid,
    output logic           in_ready,
    input  logic           in_meta_valid,
    input  var metadata_t  in_meta_data,
    output logic           in_meta_ready,
    output var flit_lite_t pcie_pkt_buf_data,
    output logic           pcie_pkt_buf_valid,
    input  logic           pcie_pkt_buf_ready,
    output var pkt_meta_t  pcie_meta_buf_data,
    output logic           pcie_meta_buf_valid,
    input  logic           pcie_meta_buf_ready,

    // Counters.
    output logic [31:0] out_pkt_queue_occup,
    output logic [31:0] out_meta_queue_occup
);

logic [511:0] pdu_data;
logic [511:0] pdu_data_swap;

logic [15:0] pdu_size;
logic [15:0] pdu_flit;

// Swap endianness.
assign pdu_data_swap = swap_flit_endianness(pdu_data);

assign out_pkt_queue_data.data = pdu_data_swap;

flit_lite_t  out_pkt_queue_data;
logic        out_pkt_queue_valid;
logic        out_pkt_queue_ready;

pkt_meta_t   out_meta_queue_data;
logic        out_meta_queue_valid;
logic        out_meta_queue_ready;

metadata_t in_meta_data_r;

logic out_pkt_queue_alm_full;
assign out_pkt_queue_alm_full = 
    out_pkt_queue_occup > PKT_Q_ALMOST_FULL_THRESHOLD;

logic out_meta_queue_alm_full;
assign out_meta_queue_alm_full =
    out_meta_queue_occup > META_Q_ALMOST_FULL_THRESHOLD;

logic needs_meta;
logic almost_full;
assign almost_full = out_pkt_queue_alm_full | out_meta_queue_alm_full;
assign in_meta_ready = !almost_full & needs_meta;

// Can only receive packets if we already have a metadata or we are receiving
// one at the same time.
assign in_ready =
    !almost_full & (!needs_meta | (in_meta_valid & in_meta_ready));

always @(posedge clk) begin
    out_pkt_queue_valid <= 0;
    out_pkt_queue_data.sop <= 0;
    out_pkt_queue_data.eop <= 0;
    out_meta_queue_valid <= 0;

    if (rst) begin
        needs_meta <= 1;
    end else begin
        automatic metadata_t meta;
        automatic logic [15:0] next_pdu_size = pdu_size;
        automatic logic [15:0] next_pdu_flit = pdu_flit;

        if (in_meta_ready & in_meta_valid) begin
            in_meta_data_r <= in_meta_data;
            needs_meta <= 0;
        end

        // If we just got a new metadata, we should use it. Otherwise, use the
        // saved one.
        if (needs_meta) begin
            meta = in_meta_data;
        end else begin
            meta = in_meta_data_r;
        end

        if (in_ready & in_valid) begin
            out_pkt_queue_valid <= 1;
            pdu_data <= in_data;

            if (in_sop) begin
                out_pkt_queue_data.sop <= 1;
                next_pdu_size = 0;
                next_pdu_flit = 0;
            end

            assert(!$isunknown(next_pdu_size));
            assert(!$isunknown(next_pdu_flit));

            next_pdu_size = next_pdu_size + 16'd64;
            next_pdu_flit = next_pdu_flit + 1'b1;

            if (in_eop) begin
                next_pdu_size = next_pdu_size - in_empty;
                out_pkt_queue_data.eop <= 1;

                // Write descriptor.
                out_meta_queue_data.pkt_queue_id <=
                    meta.pkt_queue_id[FLOW_IDX_WIDTH-1:0];

                // TODO(sadok): Specify size in bytes instead of flits.
                out_meta_queue_data.size <= next_pdu_flit;
                out_meta_queue_valid <= 1;

                needs_meta <= 1;
            end

            pdu_size <= next_pdu_size;
            pdu_flit <= next_pdu_flit;
        end
    end
end

logic out_pkt_queue_out_valid;

fifo_wrapper_infill_mlab #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL($bits(pcie_pkt_buf_data)),
    .FIFO_DEPTH(OUT_PKT_Q_DEPTH)
)
out_pkt_queue (
    .clk           (clk),
    .reset         (rst),
    .csr_address   (2'b0),
    .csr_read      (1'b1),
    .csr_write     (1'b0),
    .csr_readdata  (out_pkt_queue_occup),
    .csr_writedata (32'b0),
    .in_data       (out_pkt_queue_data),
    .in_valid      (out_pkt_queue_valid),
    .in_ready      (out_pkt_queue_ready),
    .out_data      (pcie_pkt_buf_data),
    .out_valid     (out_pkt_queue_out_valid),
    .out_ready     (pcie_pkt_buf_ready)
);

assign pcie_pkt_buf_valid = out_pkt_queue_out_valid & pcie_pkt_buf_ready;

fifo_wrapper_infill_mlab #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL($bits(pcie_meta_buf_data)),
    .FIFO_DEPTH(OUT_META_Q_DEPTH)
)
out_meta_queue (
    .clk           (clk),
    .reset         (rst),
    .csr_address   (2'b0),
    .csr_read      (1'b1),
    .csr_write     (1'b0),
    .csr_readdata  (out_meta_queue_occup),
    .csr_writedata (32'b0),
    .in_data       (out_meta_queue_data),
    .in_valid      (out_meta_queue_valid),
    .in_ready      (out_meta_queue_ready),
    .out_data      (pcie_meta_buf_data),
    .out_valid     (pcie_meta_buf_valid),
    .out_ready     (pcie_meta_buf_ready)
);

endmodule
