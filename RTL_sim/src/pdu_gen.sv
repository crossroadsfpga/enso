`timescale 1 ps / 1 ps
`include "./my_struct_s.sv"
module pdu_gen(
		input  logic         clk,                                     
		input  logic         rst,                                  
		input  logic         in_sop,          
		input  logic         in_eop,            
		input  logic [511:0] in_data,                    
		input  logic [5:0]   in_empty,                    
		input  logic         in_valid, 
		output  logic        in_ready, 
        input  logic         in_meta_valid,
        input metadata_t     in_meta_data,
        output logic         in_meta_ready,
        output  flit_lite_t              pcie_rb_wr_data,
        output  logic [PDU_AWIDTH-1:0]   pcie_rb_wr_addr,          
        output  logic                    pcie_rb_wr_en,  
        input   logic [PDU_AWIDTH-1:0]   pcie_rb_wr_base_addr,          
        input   logic                    pcie_rb_almost_full,          
        output  logic                    pcie_rb_update_valid,
        output  logic [PDU_AWIDTH-1:0]   pcie_rb_update_size
	);

typedef enum
{
    START,
    WRITE,
    WRITE_HEAD
} state_t;

state_t state;
logic         pdu_wren_r;
logic [511:0] pdu_data_r;
logic         pdu_sop_r;
logic         pdu_eop_r;

logic [PDU_AWIDTH-1:0]      pdu_addr_r;
logic [511:0] last_flit;
logic [511:0] pdu_data_swap;
logic swap;
logic [5:0] offset;
logic [15:0] pdu_size;
logic [15:0] pdu_flit;
logic [PDU_AWIDTH-1:0]  rule_cnt;
pdu_hdr_t pdu_hdr;
tuple_t tuple;
logic [31:0] prot;
logic [PDUID_WIDTH-1:0] pdu_id;

assign in_ready = (state == WRITE);

assign pdu_hdr.tuple = in_meta_data.tuple;
assign pdu_hdr.prot = in_meta_data.prot;
assign pdu_hdr.pdu_id = 0;
assign pdu_hdr.num_ruleID = 0;
assign pdu_hdr.pdu_size = pdu_size;
assign pdu_hdr.pdu_flit = pdu_flit;
assign pdu_hdr.action  = ACTION_CHECK;
assign pdu_hdr.padding = 0;

assign pdu_data_swap = {pdu_data_r[7:0],pdu_data_r[15:8],pdu_data_r[23:16],pdu_data_r[31:24],pdu_data_r[39:32],pdu_data_r[47:40],pdu_data_r[55:48],pdu_data_r[63:56],pdu_data_r[71:64],pdu_data_r[79:72],pdu_data_r[87:80],pdu_data_r[95:88],pdu_data_r[103:96],pdu_data_r[111:104],pdu_data_r[119:112],pdu_data_r[127:120],pdu_data_r[135:128],pdu_data_r[143:136],pdu_data_r[151:144],pdu_data_r[159:152],pdu_data_r[167:160],pdu_data_r[175:168],pdu_data_r[183:176],pdu_data_r[191:184],pdu_data_r[199:192],pdu_data_r[207:200],pdu_data_r[215:208],pdu_data_r[223:216],pdu_data_r[231:224],pdu_data_r[239:232],pdu_data_r[247:240],pdu_data_r[255:248],pdu_data_r[263:256],pdu_data_r[271:264],pdu_data_r[279:272],pdu_data_r[287:280],pdu_data_r[295:288],pdu_data_r[303:296],pdu_data_r[311:304],pdu_data_r[319:312],pdu_data_r[327:320],pdu_data_r[335:328],pdu_data_r[343:336],pdu_data_r[351:344],pdu_data_r[359:352],pdu_data_r[367:360],pdu_data_r[375:368],pdu_data_r[383:376],pdu_data_r[391:384],pdu_data_r[399:392],pdu_data_r[407:400],pdu_data_r[415:408],pdu_data_r[423:416],pdu_data_r[431:424],pdu_data_r[439:432],pdu_data_r[447:440],pdu_data_r[455:448],pdu_data_r[463:456],pdu_data_r[471:464],pdu_data_r[479:472],pdu_data_r[487:480],pdu_data_r[495:488],pdu_data_r[503:496],pdu_data_r[511:504]};

always@(posedge clk)begin
    if(rst)begin
        state <= START;
        in_meta_ready <= 0;
        pdu_wren_r <= 0;
        pdu_sop_r <= 0;
        pdu_eop_r <= 0;
        pdu_addr_r <= 0;
        rule_cnt <= 0;
        swap <= 0;
        pcie_rb_update_valid <= 0;
        pcie_rb_update_size <= 0;
        pdu_flit <= 0;
    end else begin
        case(state)
            START:begin
                in_meta_ready <= 0;
                pdu_wren_r <= 0;
                pdu_sop_r <= 0;
                pdu_eop_r <= 0;
                pdu_addr_r <= 0;
                rule_cnt <= 0;
                swap <= 0;
                pcie_rb_update_valid <= 0;
                pcie_rb_update_size <= 0;
                pdu_flit <= 0;
                if(in_meta_valid & !in_meta_ready & !pcie_rb_almost_full)begin
                    state <= WRITE;
                end
            end
            WRITE:begin
                pdu_wren_r <= 0;
                pdu_sop_r <= 0;
                pdu_eop_r <= 0;
                if(in_valid)begin
                    swap <= 1;
                    pdu_flit <= pdu_flit + 1;
                    //regular flit
                    if(!in_eop)begin
                        pdu_wren_r <= 1;
                        pdu_data_r <= in_data;
                        if(in_sop)begin
                            pdu_addr_r <= pcie_rb_wr_base_addr + 1;
                            pdu_size <= 64;
                        end else begin
                            pdu_addr_r <= pdu_addr_r + 1;
                            pdu_size <= pdu_size + 64;
                        end
                    end else begin
                        pdu_wren_r <= 1;
                        pdu_data_r <= in_data;
                        pdu_size <= pdu_size + (64 - in_empty);
                        pdu_addr_r <= pdu_addr_r + 1;

                        state <= WRITE_HEAD;
                    end
                end
            end
            WRITE_HEAD:begin
                swap <= 0;
                pdu_wren_r <= 1;
                pdu_addr_r <= pcie_rb_wr_base_addr;
                pdu_data_r <= pdu_hdr;
                pdu_sop_r <= 1;
                pdu_eop_r <= 0;
                in_meta_ready <= 1;
                pcie_rb_update_valid <= 1;
                pcie_rb_update_size <= pdu_flit;

                state <= START;
            end
        endcase
    end
end

always@(posedge clk)begin
    pcie_rb_wr_en <= pdu_wren_r;
    if(swap)begin
        pcie_rb_wr_data.data <= pdu_data_swap;
    end else begin
        pcie_rb_wr_data.data <= pdu_data_r;
    end
    pcie_rb_wr_data.sop <= pdu_sop_r;
    pcie_rb_wr_data.eop <= pdu_eop_r;
    pcie_rb_wr_addr <= pdu_addr_r;
end
endmodule
