`include "./my_struct_s.sv"
module pcie_top (
    //PCIE
    input  logic           pcie_clk,
    input  logic           pcie_reset_n,

    input  logic           pcie_rddm_desc_ready,
    output logic           pcie_rddm_desc_valid,
    output logic [173:0]   pcie_rddm_desc_data,
    input  logic           pcie_wrdm_desc_ready,
    output logic           pcie_wrdm_desc_valid,
    output logic [173:0]   pcie_wrdm_desc_data,
    input  logic           pcie_wrdm_prio_ready,
    output logic           pcie_wrdm_prio_valid,
    output logic [173:0]   pcie_wrdm_prio_data,
    input  logic [PCIE_ADDR_WIDTH-1:0]    pcie_address_0,    
    input  logic           pcie_write_0,      
    input  logic           pcie_read_0,       
    output logic           pcie_readdatavalid_0,    
    output logic [511:0]   pcie_readdata_0,  
    input  logic [511:0]   pcie_writedata_0, 
    input  logic [63:0]    pcie_byteenable_0,
    input  logic [PCIE_ADDR_WIDTH-1:0]    pcie_address_1,   
    input  logic           pcie_write_1,     
    input  logic           pcie_read_1,      
    output logic           pcie_readdatavalid_1,    
    output logic [511:0]   pcie_readdata_1, 
    input  logic [511:0]   pcie_writedata_1,
    input  logic [63:0]    pcie_byteenable_1,

    //internal signals
    input  flit_lite_t              pcie_rb_wr_data,
    input  logic [PDU_AWIDTH-1:0]   pcie_rb_wr_addr,          
    input  logic                    pcie_rb_wr_en,  
    output logic [PDU_AWIDTH-1:0]   pcie_rb_wr_base_addr,          
    output logic                    pcie_rb_wr_base_addr_valid,
    output logic                    pcie_rb_almost_full,          
    input  logic                    pcie_rb_update_valid,
    input  logic [PDU_AWIDTH-1:0]   pcie_rb_update_size,
    output logic                    disable_pcie,
    output pdu_metadata_t           pdumeta_cpu_data,
    output logic                    pdumeta_cpu_valid,
    input  logic   [9:0]            pdumeta_cnt,

    // status register bus
    input  logic           clk_status,
    input  logic   [29:0]  status_addr,
    input  logic           status_read,
    input  logic           status_write,
    input  logic   [31:0]  status_writedata,
    output logic   [31:0]  status_readdata,
    output logic           status_readdata_valid
    );
    
localparam JTAG_REG_SIZE = 20;
localparam C2F_HEAD_OFFSET = (5*4); //5th dwords

//JTAG signals
logic [29:0]  status_addr_r;
logic         status_read_r;
logic         status_write_r;
logic [31:0]  status_writedata_r;
logic [STAT_AWIDTH-1:0] status_addr_sel_r;

logic [31:0] pcie_reg0_status;
logic [31:0] pcie_reg1_status;
logic [31:0] pcie_reg2_status;
logic [31:0] pcie_reg3_status;
logic [31:0] pcie_reg4_status;
logic [31:0] pcie_reg5_status;
logic [31:0] pcie_reg6_status;
logic [31:0] pcie_reg7_status;
logic [31:0] pcie_reg8_status;
logic [31:0] pcie_reg9_status;
logic [31:0] pcie_reg10_status;
logic [31:0] pcie_reg11_status;
logic [31:0] pcie_reg12_status;
logic [31:0] pcie_reg13_status;
logic [31:0] pcie_reg14_status;
logic [31:0] pcie_reg15_status;
logic [31:0] pcie_reg16_status;
logic [31:0] pcie_reg17_status;
logic [31:0] pcie_reg18_status;
logic [31:0] pcie_reg19_status;
logic [31:0] pcie_reg20_status;
logic [31:0] pcie_reg21_status;
logic [31:0] pcie_reg22_status;
logic [31:0] pcie_reg23_status;
logic [31:0] pcie_reg24_status;
logic [31:0] pcie_reg25_status;
logic [31:0] pcie_reg26_status;
logic [31:0] pcie_reg27_status;
logic [31:0] pcie_reg28_status;
logic [31:0] pcie_reg29_status;
logic [31:0] pcie_reg30_status;
logic [31:0] pcie_reg31_status;
logic [31:0] pcie_reg32_status;
logic [31:0] pcie_reg33_status;
logic [31:0] pcie_reg34_status;
logic [31:0] pcie_reg35_status;
logic [31:0] pcie_reg36_status;
logic [31:0] pcie_reg37_status;
logic [31:0] pcie_reg38_status;
logic [31:0] pcie_reg39_status;
logic [31:0] pcie_reg40_status;
logic [31:0] pcie_reg41_status;
logic [31:0] pcie_reg42_status;
logic [31:0] pcie_reg43_status;
logic [31:0] pcie_reg44_status;
logic [31:0] pcie_reg45_status;
logic [31:0] pcie_reg46_status;
logic [31:0] pcie_reg47_status;
logic [31:0] pcie_reg48_status;
logic [31:0] pcie_reg49_status;
logic [31:0] pcie_reg50_status;
logic [31:0] pcie_reg51_status;
logic [31:0] pcie_reg52_status;
logic [31:0] pcie_reg53_status;
logic [31:0] pcie_reg54_status;
logic [31:0] pcie_reg55_status;
logic [31:0] pcie_reg56_status;
logic [31:0] pcie_reg57_status;
logic [31:0] pcie_reg58_status;
logic [31:0] pcie_reg59_status;
logic [31:0] pcie_reg60_status;
logic [31:0] pcie_reg61_status;
logic [31:0] pcie_reg62_status;
logic [31:0] pcie_reg63_status;
logic [31:0] pcie_reg64_status;

logic [31:0] pcie_reg0_r1;
logic [31:0] pcie_reg1_r1;
logic [31:0] pcie_reg2_r1;
logic [31:0] pcie_reg3_r1;
logic [31:0] pcie_reg4_r1;
logic [31:0] pcie_reg5_r1;
logic [31:0] pcie_reg6_r1;
logic [31:0] pcie_reg7_r1;
logic [31:0] pcie_reg8_r1;
logic [31:0] pcie_reg9_r1;
logic [31:0] pcie_reg10_r1;
logic [31:0] pcie_reg11_r1;
logic [31:0] pcie_reg12_r1;
logic [31:0] pcie_reg13_r1;
logic [31:0] pcie_reg14_r1;
logic [31:0] pcie_reg15_r1;
logic [31:0] pcie_reg16_r1;
logic [31:0] pcie_reg17_r1;
logic [31:0] pcie_reg18_r1;
logic [31:0] pcie_reg19_r1;
logic [31:0] pcie_reg20_r1;
logic [31:0] pcie_reg21_r1;
logic [31:0] pcie_reg22_r1;
logic [31:0] pcie_reg23_r1;
logic [31:0] pcie_reg24_r1;
logic [31:0] pcie_reg25_r1;
logic [31:0] pcie_reg26_r1;
logic [31:0] pcie_reg27_r1;
logic [31:0] pcie_reg28_r1;
logic [31:0] pcie_reg29_r1;
logic [31:0] pcie_reg30_r1;
logic [31:0] pcie_reg31_r1;
logic [31:0] pcie_reg32_r1;
logic [31:0] pcie_reg33_r1;
logic [31:0] pcie_reg34_r1;
logic [31:0] pcie_reg35_r1;
logic [31:0] pcie_reg36_r1;
logic [31:0] pcie_reg37_r1;
logic [31:0] pcie_reg38_r1;
logic [31:0] pcie_reg39_r1;
logic [31:0] pcie_reg40_r1;
logic [31:0] pcie_reg41_r1;
logic [31:0] pcie_reg42_r1;
logic [31:0] pcie_reg43_r1;
logic [31:0] pcie_reg44_r1;
logic [31:0] pcie_reg45_r1;
logic [31:0] pcie_reg46_r1;
logic [31:0] pcie_reg47_r1;
logic [31:0] pcie_reg48_r1;
logic [31:0] pcie_reg49_r1;
logic [31:0] pcie_reg50_r1;
logic [31:0] pcie_reg51_r1;
logic [31:0] pcie_reg52_r1;
logic [31:0] pcie_reg53_r1;
logic [31:0] pcie_reg54_r1;
logic [31:0] pcie_reg55_r1;
logic [31:0] pcie_reg56_r1;
logic [31:0] pcie_reg57_r1;
logic [31:0] pcie_reg58_r1;
logic [31:0] pcie_reg59_r1;
logic [31:0] pcie_reg60_r1;
logic [31:0] pcie_reg61_r1;
logic [31:0] pcie_reg62_r1;
logic [31:0] pcie_reg63_r1;
logic [31:0] pcie_reg64_r1;

logic [31:0] pcie_reg0_pcie;
logic [31:0] pcie_reg1_pcie;
logic [31:0] pcie_reg2_pcie;
logic [31:0] pcie_reg3_pcie;
logic [31:0] pcie_reg4_pcie;
logic [31:0] pcie_reg5_pcie;
logic [31:0] pcie_reg6_pcie;
logic [31:0] pcie_reg7_pcie;
logic [31:0] pcie_reg8_pcie;
logic [31:0] pcie_reg9_pcie;
logic [31:0] pcie_reg10_pcie;
logic [31:0] pcie_reg11_pcie;
logic [31:0] pcie_reg12_pcie;
logic [31:0] pcie_reg13_pcie;
logic [31:0] pcie_reg14_pcie;
logic [31:0] pcie_reg15_pcie;
logic [31:0] pcie_reg16_pcie;
logic [31:0] pcie_reg17_pcie;
logic [31:0] pcie_reg18_pcie;
logic [31:0] pcie_reg19_pcie;
logic [31:0] pcie_reg20_pcie;
logic [31:0] pcie_reg21_pcie;
logic [31:0] pcie_reg22_pcie;
logic [31:0] pcie_reg23_pcie;
logic [31:0] pcie_reg24_pcie;
logic [31:0] pcie_reg25_pcie;
logic [31:0] pcie_reg26_pcie;
logic [31:0] pcie_reg27_pcie;
logic [31:0] pcie_reg28_pcie;
logic [31:0] pcie_reg29_pcie;
logic [31:0] pcie_reg30_pcie;
logic [31:0] pcie_reg31_pcie;
logic [31:0] pcie_reg32_pcie;
logic [31:0] pcie_reg33_pcie;
logic [31:0] pcie_reg34_pcie;
logic [31:0] pcie_reg35_pcie;
logic [31:0] pcie_reg36_pcie;
logic [31:0] pcie_reg37_pcie;
logic [31:0] pcie_reg38_pcie;
logic [31:0] pcie_reg39_pcie;
logic [31:0] pcie_reg40_pcie;
logic [31:0] pcie_reg41_pcie;
logic [31:0] pcie_reg42_pcie;
logic [31:0] pcie_reg43_pcie;
logic [31:0] pcie_reg44_pcie;
logic [31:0] pcie_reg45_pcie;
logic [31:0] pcie_reg46_pcie;
logic [31:0] pcie_reg47_pcie;
logic [31:0] pcie_reg48_pcie;
logic [31:0] pcie_reg49_pcie;
logic [31:0] pcie_reg50_pcie;
logic [31:0] pcie_reg51_pcie;
logic [31:0] pcie_reg52_pcie;
logic [31:0] pcie_reg53_pcie;
logic [31:0] pcie_reg54_pcie;
logic [31:0] pcie_reg55_pcie;
logic [31:0] pcie_reg56_pcie;
logic [31:0] pcie_reg57_pcie;
logic [31:0] pcie_reg58_pcie;
logic [31:0] pcie_reg59_pcie;
logic [31:0] pcie_reg60_pcie;
logic [31:0] pcie_reg61_pcie;
logic [31:0] pcie_reg62_pcie;
logic [31:0] pcie_reg63_pcie;
logic [31:0] pcie_reg64_pcie;

//internal signals
pcie_block_t pcie_block;
logic cpu_reg_region;
logic cpu_reg_region_r1;
logic cpu_reg_region_r2;
logic read_0_r1;
logic read_0_r2;
logic [25:0] rb_size;
logic [4:0]  total_core;
logic [3:0]  core_id;
logic internal_update_valid;

logic [RB_AWIDTH-1:0]    f2c_head;
logic [RB_AWIDTH-1:0]    f2c_tail;
logic [63:0]             f2c_kmem_addr;
logic [511:0]            frb_readdata;            
logic                    frb_readvalid;        
logic [PDU_AWIDTH-1:0]   frb_address;              
logic                    frb_read;                 

logic [C2F_RB_AWIDTH-1:0]   c2f_head;
logic [C2F_RB_AWIDTH-1:0]   c2f_tail;
logic [63:0]                c2f_kmem_addr;
logic [63:0]                c2f_head_addr;

logic                    dma_done;
logic [RB_AWIDTH-1:0]    new_tail;
logic [RB_AWIDTH-1:0]    tail_0;
logic [RB_AWIDTH-1:0]    tail_1;
logic [RB_AWIDTH-1:0]    tail_2;
logic [RB_AWIDTH-1:0]    tail_3;
logic [RB_AWIDTH-1:0]    tail_4;
logic [RB_AWIDTH-1:0]    tail_5;
logic [RB_AWIDTH-1:0]    tail_6;
logic [RB_AWIDTH-1:0]    tail_7;
logic [RB_AWIDTH-1:0]    tail_8;
logic [RB_AWIDTH-1:0]    tail_9;
logic [RB_AWIDTH-1:0]    tail_10;
logic [RB_AWIDTH-1:0]    tail_11;
logic [RB_AWIDTH-1:0]    tail_12;
logic [RB_AWIDTH-1:0]    tail_13;
logic [RB_AWIDTH-1:0]    tail_14;
logic [RB_AWIDTH-1:0]    tail_15;
logic [RB_AWIDTH-1:0]    head_0;
logic [RB_AWIDTH-1:0]    head_1;
logic [RB_AWIDTH-1:0]    head_2;
logic [RB_AWIDTH-1:0]    head_3;
logic [RB_AWIDTH-1:0]    head_4;
logic [RB_AWIDTH-1:0]    head_5;
logic [RB_AWIDTH-1:0]    head_6;
logic [RB_AWIDTH-1:0]    head_7;
logic [RB_AWIDTH-1:0]    head_8;
logic [RB_AWIDTH-1:0]    head_9;
logic [RB_AWIDTH-1:0]    head_10;
logic [RB_AWIDTH-1:0]    head_11;
logic [RB_AWIDTH-1:0]    head_12;
logic [RB_AWIDTH-1:0]    head_13;
logic [RB_AWIDTH-1:0]    head_14;
logic [RB_AWIDTH-1:0]    head_15;
logic [31:0]             kmem_low_0;
logic [31:0]             kmem_low_1;
logic [31:0]             kmem_low_2;
logic [31:0]             kmem_low_3;
logic [31:0]             kmem_low_4;
logic [31:0]             kmem_low_5;
logic [31:0]             kmem_low_6;
logic [31:0]             kmem_low_7;
logic [31:0]             kmem_low_8;
logic [31:0]             kmem_low_9;
logic [31:0]             kmem_low_10;
logic [31:0]             kmem_low_11;
logic [31:0]             kmem_low_12;
logic [31:0]             kmem_low_13;
logic [31:0]             kmem_low_14;
logic [31:0]             kmem_low_15;
logic [31:0]             kmem_high_0;
logic [31:0]             kmem_high_1;
logic [31:0]             kmem_high_2;
logic [31:0]             kmem_high_3;
logic [31:0]             kmem_high_4;
logic [31:0]             kmem_high_5;
logic [31:0]             kmem_high_6;
logic [31:0]             kmem_high_7;
logic [31:0]             kmem_high_8;
logic [31:0]             kmem_high_9;
logic [31:0]             kmem_high_10;
logic [31:0]             kmem_high_11;
logic [31:0]             kmem_high_12;
logic [31:0]             kmem_high_13;
logic [31:0]             kmem_high_14;
logic [31:0]             kmem_high_15;
logic [C2F_RB_AWIDTH-1:0]   c2f_head_1;
//JTAG
always@(posedge clk_status)begin
    status_addr_r       <= status_addr;
    status_addr_sel_r   <= status_addr[29:30-STAT_AWIDTH];

    status_read_r       <= status_read;
    status_write_r      <= status_write;
    status_writedata_r  <= status_writedata;

    status_readdata_valid <= 0;

    if(status_addr_sel_r == PCIE & status_read_r) begin
        case(status_addr_r[6:0])
            7'd0:  status_readdata <= pcie_reg0_status;
            7'd1:  status_readdata <= pcie_reg1_status;
            7'd2:  status_readdata <= pcie_reg2_status;
            7'd3:  status_readdata <= pcie_reg3_status;
            7'd4:  status_readdata <= pcie_reg4_status;
            7'd5:  status_readdata <= pcie_reg5_status;
            7'd6:  status_readdata <= pcie_reg6_status;
            7'd7:  status_readdata <= pcie_reg7_status;
            7'd8:  status_readdata <= pcie_reg8_status;
            7'd9:  status_readdata <= pcie_reg9_status;
            7'd10: status_readdata <= pcie_reg10_status;
            7'd11: status_readdata <= pcie_reg11_status;
            7'd12: status_readdata <= pcie_reg12_status;
            7'd13: status_readdata <= pcie_reg13_status;
            7'd14: status_readdata <= pcie_reg14_status;
            7'd15: status_readdata <= pcie_reg15_status;
            7'd16: status_readdata <= pcie_reg16_status;
            7'd17: status_readdata <= pcie_reg17_status;
            7'd18: status_readdata <= pcie_reg18_status;
            7'd19: status_readdata <= pcie_reg19_status;
            7'd20: status_readdata <= pcie_reg20_status;
            7'd21: status_readdata <= pcie_reg21_status;
            7'd22: status_readdata <= pcie_reg22_status;
            7'd23: status_readdata <= pcie_reg23_status;
            7'd24: status_readdata <= pcie_reg24_status;
            7'd25: status_readdata <= pcie_reg25_status;
            7'd26: status_readdata <= pcie_reg26_status;
            7'd27: status_readdata <= pcie_reg27_status;
            7'd28: status_readdata <= pcie_reg28_status;
            7'd29: status_readdata <= pcie_reg29_status;
            7'd30: status_readdata <= pcie_reg30_status;
            7'd31: status_readdata <= pcie_reg31_status;
            7'd32: status_readdata <= pcie_reg32_status;
            7'd33: status_readdata <= pcie_reg33_status;
            7'd34: status_readdata <= pcie_reg34_status;
            7'd35: status_readdata <= pcie_reg35_status;
            7'd36: status_readdata <= pcie_reg36_status;
            7'd37: status_readdata <= pcie_reg37_status;
            7'd38: status_readdata <= pcie_reg38_status;
            7'd39: status_readdata <= pcie_reg39_status;
            7'd40: status_readdata <= pcie_reg40_status;
            7'd41: status_readdata <= pcie_reg41_status;
            7'd42: status_readdata <= pcie_reg42_status;
            7'd43: status_readdata <= pcie_reg43_status;
            7'd44: status_readdata <= pcie_reg44_status;
            7'd45: status_readdata <= pcie_reg45_status;
            7'd46: status_readdata <= pcie_reg46_status;
            7'd47: status_readdata <= pcie_reg47_status;
            7'd48: status_readdata <= pcie_reg48_status;
            7'd49: status_readdata <= pcie_reg49_status;
            7'd50: status_readdata <= pcie_reg50_status;
            7'd51: status_readdata <= pcie_reg51_status;
            7'd52: status_readdata <= pcie_reg52_status;
            7'd53: status_readdata <= pcie_reg53_status;
            7'd54: status_readdata <= pcie_reg54_status;
            7'd55: status_readdata <= pcie_reg55_status;
            7'd56: status_readdata <= pcie_reg56_status;
            7'd57: status_readdata <= pcie_reg57_status;
            7'd58: status_readdata <= pcie_reg58_status;
            7'd59: status_readdata <= pcie_reg59_status;
            7'd60: status_readdata <= pcie_reg60_status;
            7'd61: status_readdata <= pcie_reg61_status;
            7'd62: status_readdata <= pcie_reg62_status;
            7'd63: status_readdata <= pcie_reg63_status;
            //6'd32: status_readdata <= {rb_size_status,disable_pcie_status};
            7'd64: status_readdata <= pcie_reg64_status;
        endcase

        status_readdata_valid <= 1;
    end

    if(status_addr_sel_r == PCIE & status_write_r) begin
        case (status_addr_r[6:0])
            7'd64: begin
                pcie_reg64_status   <= status_writedata_r;
                //disable_pcie_status <= status_writedata_r[0];
                //rb_size_status      <= status_writedata_r[31:1];
            end
        endcase
    end
end


//Clock Crossing jtag -> pcie
always @ (posedge pcie_clk)begin
    //disable_pcie_r1 <= disable_pcie_status;
    //disable_pcie    <= disable_pcie_r1;
    //rb_size_r1      <= rb_size_status;
    //rb_size         <= rb_size_r1;
    pcie_reg64_r1   <= pcie_reg64_status;
    pcie_reg64_pcie <= pcie_reg64_r1;
end
assign disable_pcie = pcie_reg64_pcie[0];
assign rb_size      = pcie_reg64_pcie[26:1];
assign total_core   = pcie_reg64_pcie[31:27];
//Clock Crossing pcie -> jtag
always @ (posedge clk_status)begin
    pcie_reg0_r1        <= pcie_reg0_pcie;
    pcie_reg0_status    <= pcie_reg0_r1;
    pcie_reg1_r1        <= pcie_reg1_pcie;
    pcie_reg1_status    <= pcie_reg1_r1;
    pcie_reg2_r1        <= pcie_reg2_pcie;
    pcie_reg2_status    <= pcie_reg2_r1;
    pcie_reg3_r1        <= pcie_reg3_pcie;
    pcie_reg3_status    <= pcie_reg3_r1;
    pcie_reg4_r1        <= pcie_reg4_pcie;
    pcie_reg4_status    <= pcie_reg4_r1;
    pcie_reg5_r1        <= pcie_reg5_pcie;
    pcie_reg5_status    <= pcie_reg5_r1;
    pcie_reg6_r1        <= pcie_reg6_pcie;
    pcie_reg6_status    <= pcie_reg6_r1;
    pcie_reg7_r1        <= pcie_reg7_pcie;
    pcie_reg7_status    <= pcie_reg7_r1;
    pcie_reg8_r1        <= pcie_reg8_pcie;
    pcie_reg8_status    <= pcie_reg8_r1;
    pcie_reg9_r1        <= pcie_reg9_pcie;
    pcie_reg9_status    <= pcie_reg9_r1;
    pcie_reg10_r1       <= pcie_reg10_pcie;
    pcie_reg10_status   <= pcie_reg10_r1;
    pcie_reg11_r1       <= pcie_reg11_pcie;
    pcie_reg11_status   <= pcie_reg11_r1;
    pcie_reg12_r1       <= pcie_reg12_pcie;
    pcie_reg12_status   <= pcie_reg12_r1;
    pcie_reg13_r1       <= pcie_reg13_pcie;
    pcie_reg13_status   <= pcie_reg13_r1;
    pcie_reg14_r1       <= pcie_reg14_pcie;
    pcie_reg14_status   <= pcie_reg14_r1;
    pcie_reg15_r1       <= pcie_reg15_pcie;
    pcie_reg15_status   <= pcie_reg15_r1;
    pcie_reg16_r1       <= pcie_reg16_pcie;
    pcie_reg16_status   <= pcie_reg16_r1;
    pcie_reg17_r1       <= pcie_reg17_pcie;
    pcie_reg17_status   <= pcie_reg17_r1;
    pcie_reg18_r1       <= pcie_reg18_pcie;
    pcie_reg18_status   <= pcie_reg18_r1;
    pcie_reg19_r1       <= pcie_reg19_pcie;
    pcie_reg19_status   <= pcie_reg19_r1;
    pcie_reg20_r1       <= pcie_reg20_pcie;
    pcie_reg20_status   <= pcie_reg20_r1;
    pcie_reg21_r1       <= pcie_reg21_pcie;
    pcie_reg21_status   <= pcie_reg21_r1;
    pcie_reg22_r1       <= pcie_reg22_pcie;
    pcie_reg22_status   <= pcie_reg22_r1;
    pcie_reg23_r1       <= pcie_reg23_pcie;
    pcie_reg23_status   <= pcie_reg23_r1;
    pcie_reg24_r1       <= pcie_reg24_pcie;
    pcie_reg24_status   <= pcie_reg24_r1;
    pcie_reg25_r1       <= pcie_reg25_pcie;
    pcie_reg25_status   <= pcie_reg25_r1;
    pcie_reg26_r1       <= pcie_reg26_pcie;
    pcie_reg26_status   <= pcie_reg26_r1;
    pcie_reg27_r1       <= pcie_reg27_pcie;
    pcie_reg27_status   <= pcie_reg27_r1;
    pcie_reg28_r1       <= pcie_reg28_pcie;
    pcie_reg28_status   <= pcie_reg28_r1;
    pcie_reg29_r1       <= pcie_reg29_pcie;
    pcie_reg29_status   <= pcie_reg29_r1;
    pcie_reg30_r1       <= pcie_reg30_pcie;
    pcie_reg30_status   <= pcie_reg30_r1;
    pcie_reg31_r1       <= pcie_reg31_pcie;
    pcie_reg31_status   <= pcie_reg31_r1;
    pcie_reg32_r1       <= pcie_reg32_pcie;
    pcie_reg32_status   <= pcie_reg32_r1;
    pcie_reg33_r1       <= pcie_reg33_pcie;
    pcie_reg33_status   <= pcie_reg33_r1;
    pcie_reg34_r1       <= pcie_reg34_pcie;
    pcie_reg34_status   <= pcie_reg34_r1;
    pcie_reg35_r1       <= pcie_reg35_pcie;
    pcie_reg35_status   <= pcie_reg35_r1;
    pcie_reg36_r1       <= pcie_reg36_pcie;
    pcie_reg36_status   <= pcie_reg36_r1;
    pcie_reg37_r1       <= pcie_reg37_pcie;
    pcie_reg37_status   <= pcie_reg37_r1;
    pcie_reg38_r1       <= pcie_reg38_pcie;
    pcie_reg38_status   <= pcie_reg38_r1;
    pcie_reg39_r1       <= pcie_reg39_pcie;
    pcie_reg39_status   <= pcie_reg39_r1;
    pcie_reg40_r1       <= pcie_reg40_pcie;
    pcie_reg40_status   <= pcie_reg40_r1;
    pcie_reg41_r1       <= pcie_reg41_pcie;
    pcie_reg41_status   <= pcie_reg41_r1;
    pcie_reg42_r1       <= pcie_reg42_pcie;
    pcie_reg42_status   <= pcie_reg42_r1;
    pcie_reg43_r1       <= pcie_reg43_pcie;
    pcie_reg43_status   <= pcie_reg43_r1;
    pcie_reg44_r1       <= pcie_reg44_pcie;
    pcie_reg44_status   <= pcie_reg44_r1;
    pcie_reg45_r1       <= pcie_reg45_pcie;
    pcie_reg45_status   <= pcie_reg45_r1;
    pcie_reg46_r1       <= pcie_reg46_pcie;
    pcie_reg46_status   <= pcie_reg46_r1;
    pcie_reg47_r1       <= pcie_reg47_pcie;
    pcie_reg47_status   <= pcie_reg47_r1;
    pcie_reg48_r1       <= pcie_reg48_pcie;
    pcie_reg48_status   <= pcie_reg48_r1;
    pcie_reg49_r1       <= pcie_reg49_pcie;
    pcie_reg49_status   <= pcie_reg49_r1;
    pcie_reg50_r1       <= pcie_reg50_pcie;
    pcie_reg50_status   <= pcie_reg50_r1;
    pcie_reg51_r1       <= pcie_reg51_pcie;
    pcie_reg51_status   <= pcie_reg51_r1;
    pcie_reg52_r1       <= pcie_reg52_pcie;
    pcie_reg52_status   <= pcie_reg52_r1;
    pcie_reg53_r1       <= pcie_reg53_pcie;
    pcie_reg53_status   <= pcie_reg53_r1;
    pcie_reg54_r1       <= pcie_reg54_pcie;
    pcie_reg54_status   <= pcie_reg54_r1;
    pcie_reg55_r1       <= pcie_reg55_pcie;
    pcie_reg55_status   <= pcie_reg55_r1;
    pcie_reg56_r1       <= pcie_reg56_pcie;
    pcie_reg56_status   <= pcie_reg56_r1;
    pcie_reg57_r1       <= pcie_reg57_pcie;
    pcie_reg57_status   <= pcie_reg57_r1;
    pcie_reg58_r1       <= pcie_reg58_pcie;
    pcie_reg58_status   <= pcie_reg58_r1;
    pcie_reg59_r1       <= pcie_reg59_pcie;
    pcie_reg59_status   <= pcie_reg59_r1;
    pcie_reg60_r1       <= pcie_reg60_pcie;
    pcie_reg60_status   <= pcie_reg60_r1;
    pcie_reg61_r1       <= pcie_reg61_pcie;
    pcie_reg61_status   <= pcie_reg61_r1;
    pcie_reg62_r1       <= pcie_reg62_pcie;
    pcie_reg62_status   <= pcie_reg62_r1;
    pcie_reg63_r1       <= pcie_reg63_pcie;
    pcie_reg63_status   <= pcie_reg63_r1;
end

//update PIO register
always@(posedge pcie_clk)begin
    if(!pcie_reset_n)begin
        //pio_write_data <= 0;
        pcie_reg1_pcie <= 0;
        pcie_reg2_pcie <= 0;
        pcie_reg3_pcie <= 0;
        pcie_reg5_pcie <= 0;
        pcie_reg6_pcie <= 0;
        pcie_reg7_pcie <= 0;
        pcie_reg9_pcie <= 0;
        pcie_reg10_pcie <= 0;
        pcie_reg11_pcie <= 0;
        pcie_reg13_pcie <= 0;
        pcie_reg14_pcie <= 0;
        pcie_reg15_pcie <= 0;
        pcie_reg17_pcie <= 0;
        pcie_reg18_pcie <= 0;
        pcie_reg19_pcie <= 0;
        pcie_reg21_pcie <= 0;
        pcie_reg22_pcie <= 0;
        pcie_reg23_pcie <= 0;
        pcie_reg25_pcie <= 0;
        pcie_reg26_pcie <= 0;
        pcie_reg27_pcie <= 0;
        pcie_reg29_pcie <= 0;
        pcie_reg30_pcie <= 0;
        pcie_reg31_pcie <= 0;
        pcie_reg33_pcie <= 0;
        pcie_reg34_pcie <= 0;
        pcie_reg35_pcie <= 0;
        pcie_reg37_pcie <= 0;
        pcie_reg38_pcie <= 0;
        pcie_reg39_pcie <= 0;
        pcie_reg41_pcie <= 0;
        pcie_reg42_pcie <= 0;
        pcie_reg43_pcie <= 0;
        pcie_reg45_pcie <= 0;
        pcie_reg46_pcie <= 0;
        pcie_reg47_pcie <= 0;
        pcie_reg49_pcie <= 0;
        pcie_reg50_pcie <= 0;
        pcie_reg51_pcie <= 0;
        pcie_reg53_pcie <= 0;
        pcie_reg54_pcie <= 0;
        pcie_reg55_pcie <= 0;
        pcie_reg57_pcie <= 0;
        pcie_reg58_pcie <= 0;
        pcie_reg59_pcie <= 0;
        pcie_reg61_pcie <= 0;
        pcie_reg62_pcie <= 0;
        pcie_reg63_pcie <= 0;
    end else begin
        if(pcie_write_0) begin
            // case(pcie_address_0[12+APP_IDX_WIDTH-1:12])
            case(pcie_address_0[12])
            //tail cannot be updated by CPU.
                1'd0:begin
                    // pcie_reg0_pcie  <=  (pcie_byteenable_0[3:0]   == 4'b1111) ? pcie_writedata_0[31:0]    : pcie_reg0_pcie;
                    pcie_reg1_pcie  <=  (pcie_byteenable_0[7:4]   == 4'b1111) ? pcie_writedata_0[63:32]   : pcie_reg1_pcie;
                    pcie_reg2_pcie  <=  (pcie_byteenable_0[11:8]  == 4'b1111) ? pcie_writedata_0[95:64]   : pcie_reg2_pcie;
                    pcie_reg3_pcie  <=  (pcie_byteenable_0[16:12] == 4'b1111) ? pcie_writedata_0[127:96]  : pcie_reg3_pcie;
                end
                1'd1:begin
                    // pcie_reg4_pcie <=  (pcie_byteenable_0[3:0]   == 4'b1111) ? pcie_writedata_0[31:0]    : pcie_reg4_pcie; 
                    pcie_reg5_pcie <=  (pcie_byteenable_0[7:4]   == 4'b1111) ? pcie_writedata_0[63:32]   : pcie_reg5_pcie; 
                    pcie_reg6_pcie <=  (pcie_byteenable_0[11:8]  == 4'b1111) ? pcie_writedata_0[95:64]   : pcie_reg6_pcie; 
                    pcie_reg7_pcie <=  (pcie_byteenable_0[16:12] == 4'b1111) ? pcie_writedata_0[127:96]  : pcie_reg7_pcie; 
                end
                // 2'd2:begin
                //     // pcie_reg8_pcie  <=  (pcie_byteenable_0[3:0]   == 4'b1111) ? pcie_writedata_0[31:0]    : pcie_reg8_pcie; 
                //     pcie_reg9_pcie  <=  (pcie_byteenable_0[7:4]   == 4'b1111) ? pcie_writedata_0[63:32]   : pcie_reg9_pcie; 
                //     pcie_reg10_pcie  <=  (pcie_byteenable_0[11:8]  == 4'b1111) ? pcie_writedata_0[95:64]   : pcie_reg10_pcie; 
                //     pcie_reg11_pcie  <=  (pcie_byteenable_0[16:12] == 4'b1111) ? pcie_writedata_0[127:96]  : pcie_reg11_pcie;
                // end
                // 2'd3:begin
                //     // pcie_reg12_pcie <=  (pcie_byteenable_0[3:0]   == 4'b1111) ? pcie_writedata_0[31:0]    : pcie_reg16_pcie; 
                //     pcie_reg13_pcie <=  (pcie_byteenable_0[7:4]   == 4'b1111) ? pcie_writedata_0[63:32]   : pcie_reg13_pcie; 
                //     pcie_reg14_pcie <=  (pcie_byteenable_0[11:8]  == 4'b1111) ? pcie_writedata_0[95:64]   : pcie_reg14_pcie; 
                //     pcie_reg15_pcie <=  (pcie_byteenable_0[16:12] == 4'b1111) ? pcie_writedata_0[127:96]  : pcie_reg15_pcie; 
                // end
            endcase
        end
    end
end

//pio_write to jtag reg
//below is FPGA write registers. FPGA -> CPU
assign pcie_reg0_pcie   = tail_0;
assign pcie_reg4_pcie   = tail_1;
assign pcie_reg8_pcie   = tail_2;
assign pcie_reg12_pcie  = tail_3;
assign pcie_reg16_pcie  = tail_4;
assign pcie_reg20_pcie  = tail_5;
assign pcie_reg24_pcie  = tail_6;
assign pcie_reg28_pcie  = tail_7;
assign pcie_reg32_pcie   = tail_8;
assign pcie_reg36_pcie   = tail_9;
assign pcie_reg40_pcie   = tail_10;
assign pcie_reg44_pcie  = tail_11;
assign pcie_reg48_pcie  = tail_12;
assign pcie_reg52_pcie  = tail_13;
assign pcie_reg56_pcie  = tail_14;
assign pcie_reg60_pcie  = tail_15;

assign head_0 = pcie_reg1_pcie;
assign head_1 = pcie_reg5_pcie;
assign head_2 = pcie_reg9_pcie;
assign head_3 = pcie_reg13_pcie;
assign head_4 = pcie_reg17_pcie;
assign head_5 = pcie_reg21_pcie;
assign head_6 = pcie_reg25_pcie;
assign head_7 = pcie_reg29_pcie;
assign head_8 = pcie_reg33_pcie;
assign head_9 = pcie_reg37_pcie;
assign head_10 = pcie_reg41_pcie;
assign head_11 = pcie_reg45_pcie;
assign head_12 = pcie_reg49_pcie;
assign head_13 = pcie_reg53_pcie;
assign head_14 = pcie_reg57_pcie;
assign head_15 = pcie_reg61_pcie;

assign kmem_low_0 = pcie_reg2_pcie;
assign kmem_low_1 = pcie_reg6_pcie;
assign kmem_low_2 = pcie_reg10_pcie;
assign kmem_low_3 = pcie_reg14_pcie;
assign kmem_low_4 = pcie_reg18_pcie;
assign kmem_low_5 = pcie_reg22_pcie;
assign kmem_low_6 = pcie_reg26_pcie;
assign kmem_low_7 = pcie_reg30_pcie;
assign kmem_low_8 = pcie_reg34_pcie;
assign kmem_low_9 = pcie_reg38_pcie;
assign kmem_low_10 = pcie_reg42_pcie;
assign kmem_low_11 = pcie_reg46_pcie;
assign kmem_low_12 = pcie_reg50_pcie;
assign kmem_low_13 = pcie_reg54_pcie;
assign kmem_low_14 = pcie_reg58_pcie;
assign kmem_low_15 = pcie_reg62_pcie;

assign kmem_high_0 = pcie_reg3_pcie;
assign kmem_high_1 = pcie_reg7_pcie;
assign kmem_high_2 = pcie_reg11_pcie;
assign kmem_high_3 = pcie_reg15_pcie;
assign kmem_high_4 = pcie_reg19_pcie;
assign kmem_high_5 = pcie_reg23_pcie;
assign kmem_high_6 = pcie_reg27_pcie;
assign kmem_high_7 = pcie_reg31_pcie;
assign kmem_high_8 = pcie_reg35_pcie;
assign kmem_high_9 = pcie_reg39_pcie;
assign kmem_high_10 = pcie_reg43_pcie;
assign kmem_high_11 = pcie_reg47_pcie;
assign kmem_high_12 = pcie_reg51_pcie;
assign kmem_high_13 = pcie_reg55_pcie;
assign kmem_high_14 = pcie_reg59_pcie;
assign kmem_high_15 = pcie_reg63_pcie;

//assign c2f_tail = !flip ? pcie_block.c2f_tail[C2F_RB_AWIDTH-1:0] : pcie_block.c2f_tail_1[C2F_RB_AWIDTH-1:0];
assign c2f_tail = 0;
//assign c2f_kmem_addr = !flip ? {pcie_block.c2f_kmem_high,pcie_block.c2f_kmem_low} : {pcie_block.c2f_kmem_high_1,pcie_block.c2f_kmem_low_1};
assign c2f_kmem_addr = 0;
//the first slot in f2c_kmem_addr is used as the "global reg" includes the
//C2F_head
//assign c2f_head_addr = f2c_kmem_addr + C2F_HEAD_OFFSET;
assign c2f_head_addr = 0;
//update tail pointer
//CPU side read MUX, first RB_BRAM_OFFSET*512 bits are registers, the rest is BRAM.
always@(posedge pcie_clk)begin
    if(!pcie_reset_n)begin
        tail_0 <= 0;
        tail_1 <= 0;
        tail_2 <= 0;
        tail_3 <= 0;
        tail_4 <= 0;
        tail_5 <= 0;
        tail_6 <= 0;
        tail_7 <= 0;
        tail_8 <= 0;
        tail_9 <= 0;
        tail_10 <= 0;
        tail_11 <= 0;
        tail_12 <= 0;
        tail_13 <= 0;
        tail_14 <= 0;
        tail_15 <= 0;
        f2c_tail <= 0;
        f2c_head <= 0;
        f2c_kmem_addr <= 0;
        core_id <= 0;
    end else begin

        //update core_id and tail pointer
        if(dma_done)begin
            if(core_id == total_core - 1)begin
               core_id <= 0;
            end else begin
               core_id <= core_id + 1;
            end

            case(core_id)
                4'd0: tail_0 <= new_tail;
                4'd1: tail_1 <= new_tail;
                4'd2: tail_2 <= new_tail;
                4'd3: tail_3 <= new_tail;
                4'd4: tail_4 <= new_tail;
                4'd5: tail_5 <= new_tail;
                4'd6: tail_6 <= new_tail;
                4'd7: tail_7 <= new_tail;
                4'd8: tail_8 <= new_tail;
                4'd9: tail_9 <= new_tail;
                4'd10: tail_10 <= new_tail;
                4'd11: tail_11 <= new_tail;
                4'd12: tail_12 <= new_tail;
                4'd13: tail_13 <= new_tail;
                4'd14: tail_14 <= new_tail;
                4'd15: tail_15 <= new_tail;
            endcase
        end

        //select tail and kmem_addr
        case(core_id)
            4'd0: begin 
                f2c_tail      <= tail_0;
                f2c_head      <= head_0[RB_AWIDTH-1:0];
                f2c_kmem_addr <= {kmem_high_0,kmem_low_0};
            end
            4'd1: begin 
                f2c_tail      <= tail_1;
                f2c_head      <= head_1[RB_AWIDTH-1:0];
                f2c_kmem_addr <= {kmem_high_1,kmem_low_1};
            end
            4'd2: begin 
                f2c_tail      <= tail_2;
                f2c_head      <= head_2[RB_AWIDTH-1:0];
                f2c_kmem_addr <= {kmem_high_2,kmem_low_2};
            end
            4'd3: begin 
                f2c_tail      <= tail_3;
                f2c_head      <= head_3[RB_AWIDTH-1:0];
                f2c_kmem_addr <= {kmem_high_3,kmem_low_3};
            end
            4'd4: begin 
                f2c_tail      <= tail_4;
                f2c_head      <= head_4[RB_AWIDTH-1:0];
                f2c_kmem_addr <= {kmem_high_4,kmem_low_4};
            end
            4'd5: begin 
                f2c_tail      <= tail_5;
                f2c_head      <= head_5[RB_AWIDTH-1:0];
                f2c_kmem_addr <= {kmem_high_5,kmem_low_5};
            end
            4'd6: begin 
                f2c_tail      <= tail_6;
                f2c_head      <= head_6[RB_AWIDTH-1:0];
                f2c_kmem_addr <= {kmem_high_6,kmem_low_6};
            end
            4'd7: begin 
                f2c_tail      <= tail_7;
                f2c_head      <= head_7[RB_AWIDTH-1:0];
                f2c_kmem_addr <= {kmem_high_7,kmem_low_7};
            end
            4'd8: begin 
                f2c_tail      <= tail_8;
                f2c_head      <= head_8[RB_AWIDTH-1:0];
                f2c_kmem_addr <= {kmem_high_8,kmem_low_8};
            end
            4'd9: begin 
                f2c_tail      <= tail_9;
                f2c_head      <= head_9[RB_AWIDTH-1:0];
                f2c_kmem_addr <= {kmem_high_9,kmem_low_9};
            end
            4'd10: begin 
                f2c_tail      <= tail_10;
                f2c_head      <= head_10[RB_AWIDTH-1:0];
                f2c_kmem_addr <= {kmem_high_10,kmem_low_10};
            end
            4'd11: begin 
                f2c_tail      <= tail_11;
                f2c_head      <= head_11[RB_AWIDTH-1:0];
                f2c_kmem_addr <= {kmem_high_11,kmem_low_11};
            end
            4'd12: begin 
                f2c_tail      <= tail_12;
                f2c_head      <= head_12[RB_AWIDTH-1:0];
                f2c_kmem_addr <= {kmem_high_12,kmem_low_12};
            end
            4'd13: begin 
                f2c_tail      <= tail_13;
                f2c_head      <= head_13[RB_AWIDTH-1:0];
                f2c_kmem_addr <= {kmem_high_13,kmem_low_13};
            end
            4'd14: begin 
                f2c_tail      <= tail_14;
                f2c_head      <= head_14[RB_AWIDTH-1:0];
                f2c_kmem_addr <= {kmem_high_14,kmem_low_14};
            end
            4'd15: begin 
                f2c_tail      <= tail_15;
                f2c_head      <= head_15[RB_AWIDTH-1:0];
                f2c_kmem_addr <= {kmem_high_15,kmem_low_15};
            end
        endcase
    end
end

//PDU_BUFFER
//CPU side read MUX, first RB_BRAM_OFFSET*512 bits are registers, the rest is BRAM.
always@(posedge pcie_clk)begin
    if(cpu_reg_region_r2) begin
        // case(pcie_address_0[12+APP_IDX_WIDTH-1:12])
        case(pcie_address_0[12])
            1'd0:begin
                pcie_readdata_0 <= {
                    384'h0, pcie_reg3_pcie, pcie_reg2_pcie, pcie_reg1_pcie,
                    pcie_reg0_pcie
                };
            end
            1'd1:begin
                pcie_readdata_0 <= {
                    384'h0, pcie_reg7_pcie, pcie_reg6_pcie, pcie_reg5_pcie,
                    pcie_reg4_pcie
                };
            end
            // 2'd2:begin
            //     pcie_readdata_0 <= {
            //         384'h0, pcie_reg11_pcie, pcie_reg10_pcie, pcie_reg9_pcie,
            //         pcie_reg8_pcie
            //     };
            // end
            // 2'd3:begin
            //     pcie_readdata_0 <= {
            //         384'h0, pcie_reg15_pcie, pcie_reg14_pcie,
            //         pcie_reg13_pcie, pcie_reg12_pcie
            //     };
            // end
        endcase
        pcie_readdatavalid_0 <= read_0_r2;
    end else begin
        pcie_readdata_0 <= frb_readdata;
        pcie_readdatavalid_0 <= frb_readvalid;
    end
end

assign cpu_reg_region = pcie_address_0[PCIE_ADDR_WIDTH-1:6] < RB_BRAM_OFFSET;

assign frb_read     = cpu_reg_region ? 1'b0 : pcie_read_0;
assign frb_address  = pcie_address_0[PCIE_ADDR_WIDTH-1:6] - RB_BRAM_OFFSET;
//two cycle read delay
always@(posedge pcie_clk)begin
    cpu_reg_region_r1 <= cpu_reg_region;
    cpu_reg_region_r2 <= cpu_reg_region_r1;

    read_0_r1 <= pcie_read_0;
    read_0_r2 <= read_0_r1;
end

fpga2cpu_pcie f2c_inst (
    .clk            (pcie_clk),               
    .rst            (!pcie_reset_n),           
    .wr_data        (pcie_rb_wr_data),           
    .wr_addr        (pcie_rb_wr_addr),          
    .wr_en          (pcie_rb_wr_en),  
    .wr_base_addr   (pcie_rb_wr_base_addr),  
    .wr_base_addr_valid(pcie_rb_wr_base_addr_valid),
    .almost_full    (pcie_rb_almost_full),          
    .update_valid   (pcie_rb_update_valid),
    .update_size    (pcie_rb_update_size),
    .head           (f2c_head), 
    .tail           (f2c_tail),
    .kmem_addr      (f2c_kmem_addr),
    .out_tail       (new_tail),
    .dma_done       (dma_done),
    .rb_size        (rb_size),
    .wrdm_desc_ready(pcie_wrdm_desc_ready),
    .wrdm_desc_valid(pcie_wrdm_desc_valid),
    .wrdm_desc_data (pcie_wrdm_desc_data),
    .frb_readdata   (frb_readdata),
    .frb_readvalid  (frb_readvalid),
    .frb_address    (frb_address),
    .frb_read       (frb_read)
);

cpu2fpga_pcie c2f_inst (
    .clk                    (pcie_clk),
    .rst                    (!pcie_reset_n),
    .pdumeta_cpu_data       (pdumeta_cpu_data),
    .pdumeta_cpu_valid      (pdumeta_cpu_valid),
    .pdumeta_cnt            (pdumeta_cnt),
    .head                   (c2f_head),
    .tail                   (c2f_tail),
    .kmem_addr              (c2f_kmem_addr),
    .cpu_c2f_head_addr      (c2f_head_addr),
    .wrdm_prio_ready        (pcie_wrdm_prio_ready),
    .wrdm_prio_valid        (pcie_wrdm_prio_valid),
    .wrdm_prio_data         (pcie_wrdm_prio_data),
    .rddm_desc_ready        (pcie_rddm_desc_ready),
    .rddm_desc_valid        (pcie_rddm_desc_valid),
    .rddm_desc_data         (pcie_rddm_desc_data),
    .c2f_writedata          (pcie_writedata_1),
    .c2f_write              (pcie_write_1),
    .c2f_address            (pcie_address_1[14:6])
);


endmodule
