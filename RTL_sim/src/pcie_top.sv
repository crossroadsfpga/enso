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
localparam C2F_HEAD_OFFSET = (5*4); // 5th dwords

// JTAG signals
logic [29:0]  status_addr_r;
logic         status_read_r;
logic         status_write_r;
logic [31:0]  status_writedata_r;
logic [STAT_AWIDTH-1:0] status_addr_sel_r;

logic [31:0] pcie_reg_status [NB_STATUS_REGS-1:0];
logic [31:0] pcie_reg_r1 [NB_STATUS_REGS-1:0];
logic [31:0] pcie_reg_pcie [NB_STATUS_REGS-1:0];
logic [31:0] pcie_reg_pcie_wr [NB_STATUS_REGS-1:0];

logic [31:0] control_reg_status;
logic [31:0] control_reg_r1;
logic [31:0] control_reg;

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
logic [APP_IDX_WIDTH-1:0] page_idx;
logic [$clog2(NB_STATUS_REGS)-1:0] reg_set_idx;

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
logic [RB_AWIDTH-1:0]    tails     [MAX_NB_APPS-1:0];
logic [RB_AWIDTH-1:0]    heads     [MAX_NB_APPS-1:0];
logic [31:0]             kmem_low  [MAX_NB_APPS-1:0];
logic [31:0]             kmem_high [MAX_NB_APPS-1:0];

logic [C2F_RB_AWIDTH-1:0]   c2f_head_1;

// JTAG
always@(posedge clk_status)begin
    status_addr_r       <= status_addr;
    status_addr_sel_r   <= status_addr[29:30-STAT_AWIDTH];

    status_read_r       <= status_read;
    status_write_r      <= status_write;
    status_writedata_r  <= status_writedata;

    status_readdata_valid <= 0;

    if(status_addr_sel_r == PCIE & status_read_r) begin
        if (status_addr_r[6:0] == 7'd64) begin // TODO(sadok) change to 0
            status_readdata <= control_reg_status;
        end else begin
            status_readdata <= pcie_reg_status[status_addr_r[5:0]]; // FIXME(sadok) should depend on the number of apps
        end
        status_readdata_valid <= 1;
    end

    if (status_addr_sel_r == PCIE & status_write_r) begin
        if (status_addr_r[6:0] == 7'd64) begin // TODO(sadok) change to 0
            control_reg_status <= status_writedata_r;
        end
    end
end


//Clock Crossing jtag -> pcie
always @ (posedge pcie_clk)begin
    control_reg_r1 <= control_reg_status;
    control_reg <= control_reg_r1;
end
assign disable_pcie = control_reg[0];
assign rb_size      = control_reg[26:1];
assign total_core   = control_reg[31:27];

//Clock Crossing pcie -> jtag
always @ (posedge clk_status)begin
    integer i;
    // last register is special
    for (i = 0; i < NB_STATUS_REGS; i = i + 1) begin
        pcie_reg_r1[i]     <= pcie_reg_pcie[i];
        pcie_reg_status[i] <= pcie_reg_r1[i];
    end
end

// we choose the right set of registers based on the page (the page's index LSB
// is at bit 12 of the memory address, the MSB depends on the number of apps we
// support)
assign page_idx = pcie_address_0[12 +: APP_IDX_WIDTH];
assign reg_set_idx = page_idx * REGS_PER_PAGE;

// update PIO register
always@(posedge pcie_clk)begin
    integer i;
    if (!pcie_reset_n) begin
        for (i = 0; i < NB_STATUS_REGS; i = i + 1) begin
            pcie_reg_pcie_wr[i] <= 0;
        end
    end else if (pcie_write_0) begin
        // the first register of every page is the tail pointer and should not
        // be updatable from the CPU, so we purposefully skip it
        for (i = 1; i < REGS_PER_PAGE; i = i + 1) begin
            if (pcie_byteenable_0[i*REGS_PER_PAGE +:REGS_PER_PAGE]
                    == {REGS_PER_PAGE{1'b1}}) begin
                pcie_reg_pcie_wr[reg_set_idx+i] <= pcie_writedata_0[i*32 +:32];
            end else begin
                pcie_reg_pcie_wr[reg_set_idx+i] <= 
                    pcie_reg_pcie_wr[reg_set_idx+i];
            end
        end
    end
end

// pio_write to jtag reg
// below is FPGA write registers. FPGA -> CPU
always_comb begin
    integer i;
    integer j;

    for (i = 0; i < MAX_NB_APPS; i = i + 1) begin
        pcie_reg_pcie[i*REGS_PER_PAGE] = tails[i];
        heads[i] = pcie_reg_pcie[i*REGS_PER_PAGE+1];
        kmem_low[i] = pcie_reg_pcie[i*REGS_PER_PAGE+2];
        kmem_high[i] = pcie_reg_pcie[i*REGS_PER_PAGE+3];
        for (j = 1; j < REGS_PER_PAGE; j = j + 1) begin
            pcie_reg_pcie[i*REGS_PER_PAGE+j] = 
                pcie_reg_pcie_wr[i*REGS_PER_PAGE+j];
        end
    end
end

assign c2f_tail = 0;
assign c2f_kmem_addr = 0;
// the first slot in f2c_kmem_addr is used as the "global reg" includes the
// C2F_head
// assign c2f_head_addr = f2c_kmem_addr + C2F_HEAD_OFFSET;
assign c2f_head_addr = 0;
// update tail pointer
// CPU side read MUX, first RB_BRAM_OFFSET*512 bits are regs, the rest is BRAM
always@(posedge pcie_clk)begin
    integer i;
    if(!pcie_reset_n)begin
        for (i = 0; i < MAX_NB_APPS; i = i + 1) begin
            tails[i] <= 0;
        end
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

            tails[core_id] <= new_tail;
        end

        //select tail and kmem_addr
        f2c_tail      <= tails[core_id];
        f2c_head      <= heads[core_id][RB_AWIDTH-1:0];
        f2c_kmem_addr <= {kmem_high[core_id],kmem_low[core_id]};
    end
end

// PDU_BUFFER
// CPU side read MUX, first RB_BRAM_OFFSET*512 bits are regs, the rest is BRAM
always@(posedge pcie_clk)begin
    if(cpu_reg_region_r2) begin
        pcie_readdata_0 <= {
            384'h0, pcie_reg_pcie[reg_set_idx+3], pcie_reg_pcie[reg_set_idx+2],
            pcie_reg_pcie[reg_set_idx+1], pcie_reg_pcie[reg_set_idx]
        };
        pcie_readdatavalid_0 <= read_0_r2;
    end else begin
        pcie_readdata_0 <= frb_readdata;
        pcie_readdatavalid_0 <= frb_readvalid;
    end
end

assign cpu_reg_region = pcie_address_0[PCIE_ADDR_WIDTH-1:6] < RB_BRAM_OFFSET;

assign frb_read     = cpu_reg_region ? 1'b0 : pcie_read_0;
assign frb_address  = pcie_address_0[PCIE_ADDR_WIDTH-1:6] - RB_BRAM_OFFSET;

// two cycle read delay
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
