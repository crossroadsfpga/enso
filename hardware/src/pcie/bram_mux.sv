`include "pcie_consts.sv"

/*
 * Use to joing multiple BRAM blocks into one (adds 1 cycle delay for write and
 * 2 cycles for read)
 */

module bram_mux #(
    parameter NB_BRAMS
) (
    input logic clk,

    bram_interface_io.owner in,
    bram_interface_io.user  out [NB_BRAMS]
);

localparam BRAM_ID_WIDTH = $clog2(NB_BRAMS);

logic [BRAM_ID_WIDTH-1:0] bram_id_r;
logic [BRAM_ID_WIDTH-1:0] bram_id_r2;

logic rd_en_r;
logic rd_en_r2;

// We cannot use a non-constant index to index an instance array, so we use the
// following as a workaround.
logic [$bits(out[0].addr)-1:0]    out_addr    [NB_BRAMS];
logic [$bits(out[0].wr_data)-1:0] out_wr_data [NB_BRAMS];
logic [$bits(out[0].rd_data)-1:0] out_rd_data [NB_BRAMS];
logic                             out_rd_en   [NB_BRAMS];
logic                             out_wr_en   [NB_BRAMS];
generate;
    for (genvar i = 0; i < NB_BRAMS; i++) begin
        assign out[i].addr = out_addr[i];
        assign out[i].wr_data = out_wr_data[i];
        assign out[i].rd_en = out_rd_en[i];
        assign out[i].wr_en = out_wr_en[i];

        assign out_rd_data[i] = out[i].rd_data;
    end    
endgenerate

always @(posedge clk) begin
    automatic logic [BRAM_ID_WIDTH-1:0] bram_id = in.addr[0 +: BRAM_ID_WIDTH];

    for (integer i = 0; i < NB_BRAMS; i++) begin
        out_rd_en[i] <= 0;
        out_wr_en[i] <= 0;
    end

    out_addr[bram_id] <= in.addr[BRAM_ID_WIDTH +: $bits(out[0].addr)];
    out_wr_data[bram_id] <= in.wr_data;
    out_rd_en[bram_id] <= in.rd_en;
    out_wr_en[bram_id] <= in.wr_en;

    rd_en_r <= in.rd_en;
    rd_en_r2 <= rd_en_r;

    bram_id_r <= bram_id;
    bram_id_r2 <= bram_id;

    if (rd_en_r2) begin
        in.rd_data <= out_rd_data[bram_id_r2];
    end
end

endmodule
