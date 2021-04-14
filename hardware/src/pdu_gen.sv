`timescale 1 ps / 1 ps
`include "./constants.sv"
module pdu_gen(
		input  logic         clk,
		input  logic         rst,
		input  logic         in_sop,
		input  logic         in_eop,
		input  logic [511:0] in_data,
		input  logic [5:0]   in_empty,
		input  logic         in_valid,
		output logic         in_ready,
        input  logic         in_meta_valid,
        input  metadata_t    in_meta_data,
        output logic         in_meta_ready,
        output flit_lite_t   pcie_pkt_buf_wr_data,
        output logic         pcie_pkt_buf_wr_en,
        input  logic         pcie_pkt_buf_in_ready,
        output pkt_desc_t    pcie_desc_buf_wr_data,
        output logic         pcie_desc_buf_wr_en,
        input  logic         pcie_desc_buf_in_ready
	);

logic [511:0] pdu_data;
logic [511:0] pdu_data_swap;

logic [15:0] pdu_size;
logic [15:0] pdu_flit;

// // swap endianess
// always_comb begin
//     automatic integer i = 0;
//     for (i = 0; i < 512/8; i = i + 1) begin
//         pdu_data_swap[512-(i+1)*8 +: 8] = pdu_data_r2[i*8 +: 8];
//     end
// end

assign pdu_data_swap = {
    pdu_data[7:0],
    pdu_data[15:8],
    pdu_data[23:16],
    pdu_data[31:24],
    pdu_data[39:32],
    pdu_data[47:40],
    pdu_data[55:48],
    pdu_data[63:56],
    pdu_data[71:64],
    pdu_data[79:72],
    pdu_data[87:80],
    pdu_data[95:88],
    pdu_data[103:96],
    pdu_data[111:104],
    pdu_data[119:112],
    pdu_data[127:120],
    pdu_data[135:128],
    pdu_data[143:136],
    pdu_data[151:144],
    pdu_data[159:152],
    pdu_data[167:160],
    pdu_data[175:168],
    pdu_data[183:176],
    pdu_data[191:184],
    pdu_data[199:192],
    pdu_data[207:200],
    pdu_data[215:208],
    pdu_data[223:216],
    pdu_data[231:224],
    pdu_data[239:232],
    pdu_data[247:240],
    pdu_data[255:248],
    pdu_data[263:256],
    pdu_data[271:264],
    pdu_data[279:272],
    pdu_data[287:280],
    pdu_data[295:288],
    pdu_data[303:296],
    pdu_data[311:304],
    pdu_data[319:312],
    pdu_data[327:320],
    pdu_data[335:328],
    pdu_data[343:336],
    pdu_data[351:344],
    pdu_data[359:352],
    pdu_data[367:360],
    pdu_data[375:368],
    pdu_data[383:376],
    pdu_data[391:384],
    pdu_data[399:392],
    pdu_data[407:400],
    pdu_data[415:408],
    pdu_data[423:416],
    pdu_data[431:424],
    pdu_data[439:432],
    pdu_data[447:440],
    pdu_data[455:448],
    pdu_data[463:456],
    pdu_data[471:464],
    pdu_data[479:472],
    pdu_data[487:480],
    pdu_data[495:488],
    pdu_data[503:496],
    pdu_data[511:504]
};

assign pcie_pkt_buf_wr_data.data = pdu_data_swap;

// It is only safe to write if we can fit a packet with the maximum size and
// there are at least 5 slots available (due to pipeline delays).
logic almost_full;
assign almost_full = !pcie_pkt_buf_in_ready | !pcie_desc_buf_in_ready;
assign in_ready = !almost_full;

always @(posedge clk) begin
    pcie_pkt_buf_wr_en <= 0;
    pcie_pkt_buf_wr_data.sop <= 0;
    pcie_pkt_buf_wr_data.eop <= 0;
    pcie_desc_buf_wr_en <= 0;
    in_meta_ready <= 0;

    if (rst) begin
        pdu_flit = 0;
    end else begin
        if (in_valid && in_meta_valid && !almost_full) begin
            pcie_pkt_buf_wr_en <= 1;
            pdu_data <= in_data;

            if (in_sop) begin
                pcie_pkt_buf_wr_data.sop <= 1;
                pdu_size = 0;
                pdu_flit = 0;
            end

            pdu_size = pdu_size + 16'd64;
            pdu_flit = pdu_flit + 1'b1;

            if (in_eop) begin
                pdu_size = pdu_size - in_empty;
                pcie_pkt_buf_wr_data.eop <= 1;

                // write descriptor
                pcie_desc_buf_wr_data.dsc_queue_id <=
                    in_meta_data.dsc_queue_id[APP_IDX_WIDTH-1:0];
                pcie_desc_buf_wr_data.pkt_queue_id <=
                    in_meta_data.pkt_queue_id[FLOW_IDX_WIDTH-1:0];

                // TODO(sadok) specify size in bytes instead of flits
                pcie_desc_buf_wr_data.size <= pdu_flit;
                in_meta_ready <= 1;
                pcie_desc_buf_wr_en <= 1;
            end
        end
    end
end

endmodule
