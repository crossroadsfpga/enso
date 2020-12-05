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

typedef enum
{
    START,
    WRITE
} state_t;

state_t state;
logic         pdu_wren_r;
logic [511:0] pdu_data_r;
logic         pdu_sop_r;
logic         pdu_eop_r;
pkt_desc_t    pcie_desc_buf_wr_data_r;

logic [511:0] pdu_data_swap;
logic swap;
logic [15:0] pdu_size;
logic [15:0] pdu_flit;
pdu_hdr_t pdu_hdr;
tuple_t tuple;
logic [31:0] prot;
logic [PDUID_WIDTH-1:0] pdu_id;

assign in_ready = (state == WRITE);

assign pdu_data_swap = {
    pdu_data_r[7:0],
    pdu_data_r[15:8],
    pdu_data_r[23:16],
    pdu_data_r[31:24],
    pdu_data_r[39:32],
    pdu_data_r[47:40],
    pdu_data_r[55:48],
    pdu_data_r[63:56],
    pdu_data_r[71:64],
    pdu_data_r[79:72],
    pdu_data_r[87:80],
    pdu_data_r[95:88],
    pdu_data_r[103:96],
    pdu_data_r[111:104],
    pdu_data_r[119:112],
    pdu_data_r[127:120],
    pdu_data_r[135:128],
    pdu_data_r[143:136],
    pdu_data_r[151:144],
    pdu_data_r[159:152],
    pdu_data_r[167:160],
    pdu_data_r[175:168],
    pdu_data_r[183:176],
    pdu_data_r[191:184],
    pdu_data_r[199:192],
    pdu_data_r[207:200],
    pdu_data_r[215:208],
    pdu_data_r[223:216],
    pdu_data_r[231:224],
    pdu_data_r[239:232],
    pdu_data_r[247:240],
    pdu_data_r[255:248],
    pdu_data_r[263:256],
    pdu_data_r[271:264],
    pdu_data_r[279:272],
    pdu_data_r[287:280],
    pdu_data_r[295:288],
    pdu_data_r[303:296],
    pdu_data_r[311:304],
    pdu_data_r[319:312],
    pdu_data_r[327:320],
    pdu_data_r[335:328],
    pdu_data_r[343:336],
    pdu_data_r[351:344],
    pdu_data_r[359:352],
    pdu_data_r[367:360],
    pdu_data_r[375:368],
    pdu_data_r[383:376],
    pdu_data_r[391:384],
    pdu_data_r[399:392],
    pdu_data_r[407:400],
    pdu_data_r[415:408],
    pdu_data_r[423:416],
    pdu_data_r[431:424],
    pdu_data_r[439:432],
    pdu_data_r[447:440],
    pdu_data_r[455:448],
    pdu_data_r[463:456],
    pdu_data_r[471:464],
    pdu_data_r[479:472],
    pdu_data_r[487:480],
    pdu_data_r[495:488],
    pdu_data_r[503:496],
    pdu_data_r[511:504]
};

// It is only safe to write if we can fit a packet with the maximum size and
// there are at least 3 slots available (due to pipeline delays).
logic almost_full;
assign almost_full = pcie_pkt_buf_occup >= (PDU_DEPTH - 2 - MAX_PKT_SIZE)
                     || pcie_desc_buf_occup >= (PDU_DEPTH - 3);

always @(posedge clk) begin
    pdu_wren_r <= 0;
    pdu_sop_r <= 0;
    pdu_eop_r <= 0;
    in_meta_ready <= 0;
    swap <= 0;

    if (rst) begin
        state <= START;
        pdu_flit <= 0;
        pdu_id <= 0;
    end else begin
        case (state)
            START: begin
                pdu_flit <= 0;
                pdu_size <= 0;
                if (in_meta_valid & !in_meta_ready & !almost_full) begin
                    state <= WRITE;
                end
            end
            WRITE: begin
                if (in_valid) begin
                    pdu_wren_r <= 1;
                    swap <= 1;
                    pdu_data_r <= in_data;

                    `hdisplay(("in_sop: %b in_eop: %b", in_sop, in_eop));

                    if (in_sop) begin
                        pdu_sop_r <= 1;
                        assert(pdu_size == 0);
                    end else begin
                        assert(pdu_size != 0);
                    end

                    pdu_size = pdu_size + 64;
                    pdu_flit = pdu_flit + 1;

                    if (in_eop) begin
                        pdu_size = pdu_size - in_empty;
                        pdu_eop_r <= 1;

                        // write descriptor
                        pcie_desc_buf_wr_data_r.queue_id <=
                            in_meta_data.queue_id;

                        // TODO(sadok) specify size in bytes instead of flits
                        pcie_desc_buf_wr_data_r.size <= pdu_flit;
                        in_meta_ready <= 1;

                        state <= START;
                    end
                end
            end
        endcase
    end
end

always @(posedge clk) begin
    pcie_pkt_buf_wr_en <= pdu_wren_r;
    pcie_pkt_buf_wr_data.data <= swap ? pdu_data_swap : pdu_data_r;
    pcie_pkt_buf_wr_data.sop <= pdu_sop_r;
    pcie_pkt_buf_wr_data.eop <= pdu_eop_r;

    pcie_desc_buf_wr_en <= in_meta_ready;
    pcie_desc_buf_wr_data <= pcie_desc_buf_wr_data_r;
end
endmodule
