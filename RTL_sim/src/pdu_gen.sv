`timescale 1 ps / 1 ps
`include "./my_struct_s.sv"
module pdu_gen(
		input  logic                  clk,
		input  logic                  rst,
		input  logic                  in_sop,
		input  logic                  in_eop,
		input  logic [511:0]          in_data,
		input  logic [5:0]            in_empty,
		input  logic                  in_valid,
		output logic                  in_ready,
        input  logic                  in_meta_valid,
        input  metadata_t             in_meta_data,
        output logic                  in_meta_ready,
        output flit_lite_t            pcie_pkt_buf_wr_data,
        output logic                  pcie_pkt_buf_wr_en,
        input  logic [PDU_AWIDTH-1:0] pcie_pkt_buf_occup,
        output pkt_desc_t             pcie_desc_buf_wr_data,
        output logic                  pcie_desc_buf_wr_en,
        input  logic [PDU_AWIDTH-1:0] pcie_desc_buf_occup
	);

logic         pdu_wren_r;
logic [511:0] pdu_data_r;
logic         pdu_sop_r;
logic         pdu_eop_r;
pkt_desc_t    pcie_desc_buf_wr_data_r;

logic         pdu_wren_r2;
logic [511:0] pdu_data_r2;
logic         pdu_sop_r2;
logic         pdu_eop_r2;
pkt_desc_t    pcie_desc_buf_wr_data_r2;

logic [511:0] pdu_data_swap;
logic [511:0] pdu_data_swap_r;

logic [15:0] pdu_size;
logic [15:0] pdu_flit;
pdu_hdr_t pdu_hdr;
tuple_t tuple;
logic [31:0] prot;
logic [PDUID_WIDTH-1:0] pdu_id;

logic pcie_pkt_buf_wr_en_r2;
flit_lite_t pcie_pkt_buf_wr_data_r2;

logic pcie_desc_buf_wr_en_r2;
logic pcie_desc_buf_wr_en_r;

// // swap endianess
// always_comb begin
//     automatic integer i = 0;
//     for (i = 0; i < 512/8; i = i + 1) begin
//         pdu_data_swap[512-(i+1)*8 +: 8] = pdu_data_r2[i*8 +: 8];
//     end
// end

assign pdu_data_swap_r = {
    pdu_data_r2[7:0],
    pdu_data_r2[15:8],
    pdu_data_r2[23:16],
    pdu_data_r2[31:24],
    pdu_data_r2[39:32],
    pdu_data_r2[47:40],
    pdu_data_r2[55:48],
    pdu_data_r2[63:56],
    pdu_data_r2[71:64],
    pdu_data_r2[79:72],
    pdu_data_r2[87:80],
    pdu_data_r2[95:88],
    pdu_data_r2[103:96],
    pdu_data_r2[111:104],
    pdu_data_r2[119:112],
    pdu_data_r2[127:120],
    pdu_data_r2[135:128],
    pdu_data_r2[143:136],
    pdu_data_r2[151:144],
    pdu_data_r2[159:152],
    pdu_data_r2[167:160],
    pdu_data_r2[175:168],
    pdu_data_r2[183:176],
    pdu_data_r2[191:184],
    pdu_data_r2[199:192],
    pdu_data_r2[207:200],
    pdu_data_r2[215:208],
    pdu_data_r2[223:216],
    pdu_data_r2[231:224],
    pdu_data_r2[239:232],
    pdu_data_r2[247:240],
    pdu_data_r2[255:248],
    pdu_data_r2[263:256],
    pdu_data_r2[271:264],
    pdu_data_r2[279:272],
    pdu_data_r2[287:280],
    pdu_data_r2[295:288],
    pdu_data_r2[303:296],
    pdu_data_r2[311:304],
    pdu_data_r2[319:312],
    pdu_data_r2[327:320],
    pdu_data_r2[335:328],
    pdu_data_r2[343:336],
    pdu_data_r2[351:344],
    pdu_data_r2[359:352],
    pdu_data_r2[367:360],
    pdu_data_r2[375:368],
    pdu_data_r2[383:376],
    pdu_data_r2[391:384],
    pdu_data_r2[399:392],
    pdu_data_r2[407:400],
    pdu_data_r2[415:408],
    pdu_data_r2[423:416],
    pdu_data_r2[431:424],
    pdu_data_r2[439:432],
    pdu_data_r2[447:440],
    pdu_data_r2[455:448],
    pdu_data_r2[463:456],
    pdu_data_r2[471:464],
    pdu_data_r2[479:472],
    pdu_data_r2[487:480],
    pdu_data_r2[495:488],
    pdu_data_r2[503:496],
    pdu_data_r2[511:504]
};

// It is only safe to write if we can fit a packet with the maximum size and
// there are at least 5 slots available (due to pipeline delays).
logic almost_full;
assign almost_full = pcie_pkt_buf_occup >= (PDU_DEPTH - 4 - MAX_PKT_SIZE)
                     || pcie_desc_buf_occup >= (PDU_DEPTH - 5);

assign in_ready = !almost_full;

always @(posedge clk) begin
    pdu_wren_r2 <= 0;
    pdu_sop_r2 <= 0;
    pdu_eop_r2 <= 0;
    pcie_desc_buf_wr_en_r2 <= 0;
    in_meta_ready <= 0;

    if (rst) begin
        pdu_flit <= 0;
        pdu_id <= 0;
    end else begin
        if (in_valid && in_meta_valid && !almost_full) begin
            pdu_wren_r2 <= 1;
            pdu_data_r2 <= in_data;

            if (in_sop) begin
                pdu_sop_r2 <= 1;
                pdu_size = 0;
                pdu_flit = 0;
            end

            pdu_size = pdu_size + 16'd64;
            pdu_flit = pdu_flit + 1'b1;

            if (in_eop) begin
                pdu_size = pdu_size - in_empty;
                pdu_eop_r2 <= 1;

                // write descriptor
                pcie_desc_buf_wr_data_r2.dsc_queue_id <=
                    in_meta_data.dsc_queue_id[APP_IDX_WIDTH-1:0];
                pcie_desc_buf_wr_data_r2.pkt_queue_id <=
                    in_meta_data.pkt_queue_id[FLOW_IDX_WIDTH-1:0];

                // TODO(sadok) specify size in bytes instead of flits
                pcie_desc_buf_wr_data_r2.size <= pdu_flit;
                in_meta_ready <= 1;
                pcie_desc_buf_wr_en_r2 <= 1;
            end
        end
    end
end

always @(posedge clk) begin
    pdu_wren_r <= pdu_wren_r2;
    pdu_data_swap <= pdu_data_swap_r;
    pdu_sop_r <= pdu_sop_r2;
    pdu_eop_r <= pdu_eop_r2;
    pcie_desc_buf_wr_en_r <= pcie_desc_buf_wr_en_r2;
    pcie_desc_buf_wr_data_r <= pcie_desc_buf_wr_data_r2;

    pcie_pkt_buf_wr_en <= pdu_wren_r;
    pcie_pkt_buf_wr_data.data <= pdu_data_swap;
    pcie_pkt_buf_wr_data.sop <= pdu_sop_r;
    pcie_pkt_buf_wr_data.eop <= pdu_eop_r;

    pcie_desc_buf_wr_en <= pcie_desc_buf_wr_en_r;
    pcie_desc_buf_wr_data <= pcie_desc_buf_wr_data_r;
end
endmodule
