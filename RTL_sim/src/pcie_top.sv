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
logic [3:0]  next_core_id;
logic internal_update_valid;
logic [APP_IDX_WIDTH-1:0] page_idx;
logic [$clog2(NB_STATUS_REGS)-1:0] reg_set_idx;

// queue table
logic [APP_IDX_WIDTH-1:0] q_table_tails_addr_a;
logic [APP_IDX_WIDTH-1:0] q_table_heads_addr_a;
logic [APP_IDX_WIDTH-1:0] q_table_l_addrs_addr_a;
logic [APP_IDX_WIDTH-1:0] q_table_h_addrs_addr_a;
logic [APP_IDX_WIDTH-1:0] q_table_tails_addr_b;
logic [APP_IDX_WIDTH-1:0] q_table_heads_addr_b;
logic [APP_IDX_WIDTH-1:0] q_table_l_addrs_addr_b;
logic [APP_IDX_WIDTH-1:0] q_table_h_addrs_addr_b;
logic [QUEUE_TABLE_TAILS_DWIDTH-1:0] q_table_tails_wr_data_a;
logic [QUEUE_TABLE_HEADS_DWIDTH-1:0] q_table_heads_wr_data_a;
logic [QUEUE_TABLE_L_ADDRS_DWIDTH-1:0] q_table_l_addrs_wr_data_a;
logic [QUEUE_TABLE_H_ADDRS_DWIDTH-1:0] q_table_h_addrs_wr_data_a;
logic [QUEUE_TABLE_TAILS_DWIDTH-1:0] q_table_tails_wr_data_b;
logic [QUEUE_TABLE_HEADS_DWIDTH-1:0] q_table_heads_wr_data_b;
logic [QUEUE_TABLE_L_ADDRS_DWIDTH-1:0] q_table_l_addrs_wr_data_b;
logic [QUEUE_TABLE_H_ADDRS_DWIDTH-1:0] q_table_h_addrs_wr_data_b;
logic [QUEUE_TABLE_TAILS_DWIDTH-1:0] q_table_tails_rd_data_a;
logic [QUEUE_TABLE_HEADS_DWIDTH-1:0] q_table_heads_rd_data_a;
logic [QUEUE_TABLE_L_ADDRS_DWIDTH-1:0] q_table_l_addrs_rd_data_a;
logic [QUEUE_TABLE_H_ADDRS_DWIDTH-1:0] q_table_h_addrs_rd_data_a;
logic [QUEUE_TABLE_TAILS_DWIDTH-1:0] q_table_tails_rd_data_b;
logic [QUEUE_TABLE_HEADS_DWIDTH-1:0] q_table_heads_rd_data_b;
logic [QUEUE_TABLE_L_ADDRS_DWIDTH-1:0] q_table_l_addrs_rd_data_b;
logic [QUEUE_TABLE_H_ADDRS_DWIDTH-1:0] q_table_h_addrs_rd_data_b;
logic q_table_tails_rd_en_a;
logic q_table_heads_rd_en_a;
logic q_table_l_addrs_rd_en_a;
logic q_table_h_addrs_rd_en_a;
logic q_table_tails_rd_en_a_r1;
logic q_table_heads_rd_en_a_r1;
logic q_table_l_addrs_rd_en_a_r1;
logic q_table_h_addrs_rd_en_a_r1;
logic q_table_tails_rd_en_a_r2;
logic q_table_heads_rd_en_a_r2;
logic q_table_l_addrs_rd_en_a_r2;
logic q_table_h_addrs_rd_en_a_r2;
logic q_table_tails_rd_en_b;
logic q_table_heads_rd_en_b;
logic q_table_l_addrs_rd_en_b;
logic q_table_h_addrs_rd_en_b;
logic q_table_tails_wr_en_a;
logic q_table_heads_wr_en_a;
logic q_table_l_addrs_wr_en_a;
logic q_table_h_addrs_wr_en_a;
logic q_table_tails_wr_en_b;
logic q_table_heads_wr_en_b;
logic q_table_l_addrs_wr_en_b;
logic q_table_h_addrs_wr_en_b;

logic q_table_tails_rd_en_b_jtag;
logic q_table_heads_rd_en_b_jtag;
logic q_table_l_addrs_rd_en_b_jtag;
logic q_table_h_addrs_rd_en_b_jtag;

logic q_table_tails_rd_en_b_jtag_r1;
logic q_table_heads_rd_en_b_jtag_r1;
logic q_table_l_addrs_rd_en_b_jtag_r1;
logic q_table_h_addrs_rd_en_b_jtag_r1;

logic [APP_IDX_WIDTH-1:0] q_table_tails_addr_b_jtag;
logic [APP_IDX_WIDTH-1:0] q_table_heads_addr_b_jtag;
logic [APP_IDX_WIDTH-1:0] q_table_l_addrs_addr_b_jtag;
logic [APP_IDX_WIDTH-1:0] q_table_h_addrs_addr_b_jtag;

logic [APP_IDX_WIDTH-1:0] q_table_tails_addr_b_jtag_r1;
logic [APP_IDX_WIDTH-1:0] q_table_heads_addr_b_jtag_r1;
logic [APP_IDX_WIDTH-1:0] q_table_l_addrs_addr_b_jtag_r1;
logic [APP_IDX_WIDTH-1:0] q_table_h_addrs_addr_b_jtag_r1;

logic [QUEUE_TABLE_TAILS_DWIDTH-1:0] q_table_tails_rd_data_b_r;
logic [QUEUE_TABLE_TAILS_DWIDTH-1:0] q_table_tails_rd_data_b_jtag;

logic [QUEUE_TABLE_HEADS_DWIDTH-1:0] q_table_heads_rd_data_b_r;
logic [QUEUE_TABLE_HEADS_DWIDTH-1:0] q_table_heads_rd_data_b_jtag;

logic [QUEUE_TABLE_L_ADDRS_DWIDTH-1:0] q_table_l_addrs_rd_data_b_r;
logic [QUEUE_TABLE_L_ADDRS_DWIDTH-1:0] q_table_l_addrs_rd_data_b_jtag;

logic [QUEUE_TABLE_H_ADDRS_DWIDTH-1:0] q_table_h_addrs_rd_data_b_r;
logic [QUEUE_TABLE_H_ADDRS_DWIDTH-1:0] q_table_h_addrs_rd_data_b_jtag;

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
logic [1:0] pending_table;
logic rd_en_r;
logic rd_en_r2;
logic rd_en_jtag;
logic rd_en_jtag_r;

// JTAG
always@(posedge clk_status)begin
    status_addr_r       <= status_addr;
    status_addr_sel_r   <= status_addr[29:30-STAT_AWIDTH];

    status_read_r       <= status_read;
    status_write_r      <= status_write;
    status_writedata_r  <= status_writedata;

    status_readdata_valid <= 0;
    
    q_table_tails_rd_en_b_jtag <= 0;
    q_table_heads_rd_en_b_jtag <= 0;
    q_table_l_addrs_rd_en_b_jtag <= 0;
    q_table_h_addrs_rd_en_b_jtag <= 0;

    if (rd_en_jtag_r) begin
        case (pending_table)
            2'd0: begin
                status_readdata <= q_table_tails_rd_data_b_jtag;
            end
            2'd1: begin
                status_readdata <= q_table_heads_rd_data_b_jtag;
            end
            2'd2: begin
                status_readdata <= q_table_l_addrs_rd_data_b_jtag;
            end
            2'd3: begin
                status_readdata <= q_table_h_addrs_rd_data_b_jtag;
            end
        endcase
        status_readdata_valid <= 1;
    end

    if(status_addr_sel_r == PCIE & status_read_r) begin
        if (status_addr_r[0 +:JTAG_ADDR_WIDTH] == 0) begin
            status_readdata <= control_reg_status;
            status_readdata_valid <= 1;
        end else begin
            // status_readdata <= pcie_reg_status[
            //     {status_addr_r[0 +:JTAG_ADDR_WIDTH]-1}[0 +:STATS_REGS_WIDTH]];
            case ({status_addr_r[0 +:JTAG_ADDR_WIDTH]-1}[1:0])
                2'd0: begin
                    pending_table <= 2'd0;
                    q_table_tails_rd_en_b_jtag <= 1;
                    q_table_tails_addr_b_jtag <= {status_addr_r[
                        0 +:JTAG_ADDR_WIDTH]-1}[2 +:APP_IDX_WIDTH];
                end
                2'd1: begin
                    pending_table <= 2'd1;
                    q_table_heads_rd_en_b_jtag <= 1;
                    q_table_heads_addr_b_jtag <= {status_addr_r[
                        0 +:JTAG_ADDR_WIDTH]-1}[2 +:APP_IDX_WIDTH];
                end
                2'd2: begin
                    pending_table <= 2'd2;
                    q_table_l_addrs_rd_en_b_jtag <= 1;
                    q_table_l_addrs_addr_b_jtag <= {status_addr_r[
                        0 +:JTAG_ADDR_WIDTH]-1}[2 +:APP_IDX_WIDTH];
                end
                2'd3: begin
                    pending_table <= 2'd3;
                    q_table_h_addrs_rd_en_b_jtag <= 1;
                    q_table_h_addrs_addr_b_jtag <= {status_addr_r[
                        0 +:JTAG_ADDR_WIDTH]-1}[2 +:APP_IDX_WIDTH];
                end
            endcase
        end
    end

    if (status_addr_sel_r == PCIE & status_write_r) begin
        if (status_addr_r[0 +:JTAG_ADDR_WIDTH] == 0) begin 
            control_reg_status <= status_writedata_r;
        end
    end
end


//Clock Crossing jtag -> pcie
always @ (posedge pcie_clk)begin
    control_reg_r1 <= control_reg_status;
    control_reg <= control_reg_r1;

    q_table_tails_rd_en_b_jtag_r1 <= q_table_tails_rd_en_b_jtag;
    q_table_tails_rd_en_b <= q_table_tails_rd_en_b_jtag_r1;
    q_table_tails_addr_b_jtag_r1 <= q_table_tails_addr_b_jtag;
    q_table_tails_addr_b <= q_table_tails_addr_b_jtag_r1;

    q_table_heads_rd_en_b_jtag_r1 <= q_table_heads_rd_en_b_jtag;
    q_table_heads_rd_en_b <= q_table_heads_rd_en_b_jtag_r1;
    q_table_heads_addr_b_jtag_r1 <= q_table_heads_addr_b_jtag;
    q_table_heads_addr_b <= q_table_heads_addr_b_jtag_r1;
    
    q_table_l_addrs_rd_en_b_jtag_r1 <= q_table_l_addrs_rd_en_b_jtag;
    q_table_l_addrs_rd_en_b <= q_table_l_addrs_rd_en_b_jtag_r1;
    q_table_l_addrs_addr_b_jtag_r1 <= q_table_l_addrs_addr_b_jtag;
    q_table_l_addrs_addr_b <= q_table_l_addrs_addr_b_jtag_r1;
    
    q_table_h_addrs_rd_en_b_jtag_r1 <= q_table_h_addrs_rd_en_b_jtag;
    q_table_h_addrs_rd_en_b <= q_table_h_addrs_rd_en_b_jtag_r1;
    q_table_h_addrs_addr_b_jtag_r1 <= q_table_h_addrs_addr_b_jtag;
    q_table_h_addrs_addr_b <= q_table_h_addrs_addr_b_jtag_r1;

    rd_en_r <= q_table_tails_rd_en_b | q_table_heads_rd_en_b | 
        q_table_l_addrs_rd_en_b | q_table_h_addrs_rd_en_b;
    rd_en_r2 <= rd_en_r;
end
assign disable_pcie = control_reg[0];
assign rb_size      = control_reg[26:1];
assign total_core   = control_reg[31:27];

//Clock Crossing pcie -> jtag
always @ (posedge clk_status)begin
    integer i;
    for (i = 0; i < NB_STATUS_REGS; i = i + 1) begin
        pcie_reg_r1[i]     <= pcie_reg_pcie[i];
        pcie_reg_status[i] <= pcie_reg_r1[i];
    end

    rd_en_jtag <= rd_en_r2;
    rd_en_jtag_r <= rd_en_jtag;

    q_table_tails_rd_data_b_r <= q_table_tails_rd_data_b;
    q_table_tails_rd_data_b_jtag <= q_table_tails_rd_data_b_r;
    q_table_heads_rd_data_b_r <= q_table_heads_rd_data_b;
    q_table_heads_rd_data_b_jtag <= q_table_heads_rd_data_b_r;
    q_table_l_addrs_rd_data_b_r <= q_table_l_addrs_rd_data_b;
    q_table_l_addrs_rd_data_b_jtag <= q_table_l_addrs_rd_data_b_r;
    q_table_h_addrs_rd_data_b_r <= q_table_h_addrs_rd_data_b;
    q_table_h_addrs_rd_data_b_jtag <= q_table_h_addrs_rd_data_b_r;
end

// we choose the right set of registers based on the page (the page's index LSB
// is at bit 12 of the memory address, the MSB depends on the number of apps we
// support)
assign page_idx = pcie_address_0[12 +: APP_IDX_WIDTH];
assign reg_set_idx = page_idx * REGS_PER_PAGE;

// update PIO register
always@(posedge pcie_clk)begin
    integer i;
    // q_table_tails_wr_en_a <= 0;
    q_table_heads_wr_en_a <= 0;
    q_table_l_addrs_wr_en_a <= 0;
    q_table_h_addrs_wr_en_a <= 0;
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

        // // update BRAMs
        // // if (pcie_byteenable_0[0*REGS_PER_PAGE +:REGS_PER_PAGE] 
        // //         == {REGS_PER_PAGE{1'b1}}) begin
        // //     q_table_tails_wr_data_a <= pcie_writedata_0[0*32 +: 32];
        // //     q_table_tails_wr_en_a <= 1;
        // //     q_table_tails_addr_a <= page_idx;
        // // end
        // if (pcie_byteenable_0[1*REGS_PER_PAGE +:REGS_PER_PAGE]
        //         == {REGS_PER_PAGE{1'b1}}) begin
        //     q_table_heads_wr_data_a <= pcie_writedata_0[1*32 +: 32];
        //     q_table_heads_wr_en_a <= 1;
        //     q_table_heads_addr_a <= page_idx;
        // end
        // if (pcie_byteenable_0[2*REGS_PER_PAGE +:REGS_PER_PAGE]
        //         == {REGS_PER_PAGE{1'b1}}) begin
        //     q_table_l_addrs_wr_data_a <= pcie_writedata_0[2*32 +: 32];
        //     q_table_l_addrs_wr_en_a <= 1;
        //     q_table_l_addrs_addr_a <= page_idx;
        // end
        // if (pcie_byteenable_0[3*REGS_PER_PAGE +:REGS_PER_PAGE]
        //         == {REGS_PER_PAGE{1'b1}}) begin
        //     q_table_h_addrs_wr_data_a <= pcie_writedata_0[3*32 +: 32];
        //     q_table_h_addrs_wr_en_a <= 1;
        //     q_table_h_addrs_addr_a <= page_idx;
        // end
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

typedef enum
{
    IDLE,
    BRAM_DELAY,
    SWITCH_QUEUE
} state_t;
state_t state;

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
        next_core_id <= total_core > 1;
        q_table_tails_wr_en_a <= 0;
    end else begin
        //update core_id and tail pointer
        // if(dma_done)begin
        //     if(core_id == total_core - 1)begin
        //        core_id <= 0;
        //     end else begin
        //        core_id <= core_id + 1;
        //     end

        //     tails[core_id] <= new_tail;
        // end

        //select tail and kmem_addr
        f2c_tail      <= tails[core_id];
        f2c_head      <= heads[core_id]; // [RB_AWIDTH-1:0];
        f2c_kmem_addr <= {kmem_high[core_id],kmem_low[core_id]};
        // TODO(sadok) read from BRAM

        case (state)
            IDLE: begin
                q_table_tails_wr_en_a <= 0;
                // TODO(sadok) ring_buffer.sv has a 2-clock delay between DMAs.
                // This ensures that we have time to read the BRAM and switch
                // the queue before the new DMA starts. Eventually we should do
                // something more clever

                // retrieve next queue from queue table
                if (dma_done) begin
                    q_table_tails_addr_a <= next_core_id;
                    // TODO(sadok) uncommend and change to the right enable signal
                    // once we start using value from BRAM
                    // q_table_rd_en_a <= 1;

                    state <= BRAM_DELAY;
                    // f2c_tail <= new_tail;
                    tails[core_id] <= new_tail; // FIXME(sadok)
                end

                //select tail and kmem_addr
                // f2c_tail      <= tails[core_id];
                // f2c_head      <= heads[core_id][RB_AWIDTH-1:0];
                // f2c_kmem_addr <= {kmem_high[core_id],kmem_low[core_id]};
            end
            BRAM_DELAY: begin
                state <= SWITCH_QUEUE;
                // TODO(sadok) uncommend and change to the right enable signal
                // once we start using value from BRAM
                // q_table_rd_en_a <= 0;
                q_table_tails_wr_en_a <= 0;
            end
            SWITCH_QUEUE: begin
                // update tail pointer for core_id
                q_table_tails_addr_a <= core_id;
                // q_table_wr_data_a <= current_queue;
                q_table_tails_wr_data_a <= tails[core_id]; // FIXME(sadok) there should be only a single active queue
                q_table_tails_wr_en_a <= 1;

                core_id <= next_core_id;
                if (next_core_id == total_core - 1) begin
                    next_core_id <= 0;
                end else begin
                    next_core_id <= next_core_id + 1;
                end

                state <= IDLE;
            end
            default: state <= IDLE;
        endcase
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
        // TODO(sadok) read regs from BRAM
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

assign q_table_rd_en_a = cpu_reg_region & pcie_read_0;

bram_true2port #(
    .AWIDTH(QUEUE_TABLE_AWIDTH),
    .DWIDTH(QUEUE_TABLE_TAILS_DWIDTH),
    .DEPTH(QUEUE_TABLE_DEPTH)
)
q_table_tails (
    .address_a  (q_table_tails_addr_a),
    .address_b  (q_table_tails_addr_b),
    .clock      (pcie_clk),
    .data_a     (q_table_tails_wr_data_a),
    .data_b     (q_table_tails_wr_data_b),
    .rden_a     (q_table_tails_rd_en_a),
    .rden_b     (q_table_tails_rd_en_b),
    .wren_a     (q_table_tails_wr_en_a),
    .wren_b     (q_table_tails_wr_en_b),
    .q_a        (q_table_tails_rd_data_a),
    .q_b        (q_table_tails_rd_data_b)
);

bram_true2port #(
    .AWIDTH(QUEUE_TABLE_AWIDTH),
    .DWIDTH(QUEUE_TABLE_HEADS_DWIDTH),
    .DEPTH(QUEUE_TABLE_DEPTH)
)
q_table_heads (
    .address_a  (q_table_heads_addr_a),
    .address_b  (q_table_heads_addr_b),
    .clock      (pcie_clk),
    .data_a     (q_table_heads_wr_data_a),
    .data_b     (q_table_heads_wr_data_b),
    .rden_a     (q_table_heads_rd_en_a),
    .rden_b     (q_table_heads_rd_en_b),
    .wren_a     (q_table_heads_wr_en_a),
    .wren_b     (q_table_heads_wr_en_b),
    .q_a        (q_table_heads_rd_data_a),
    .q_b        (q_table_heads_rd_data_b)
);

bram_true2port #(
    .AWIDTH(QUEUE_TABLE_AWIDTH),
    .DWIDTH(QUEUE_TABLE_L_ADDRS_DWIDTH),
    .DEPTH(QUEUE_TABLE_DEPTH)
)
q_table_l_addrs (
    .address_a  (q_table_l_addrs_addr_a),
    .address_b  (q_table_l_addrs_addr_b),
    .clock      (pcie_clk),
    .data_a     (q_table_l_addrs_wr_data_a),
    .data_b     (q_table_l_addrs_wr_data_b),
    .rden_a     (q_table_l_addrs_rd_en_a),
    .rden_b     (q_table_l_addrs_rd_en_b),
    .wren_a     (q_table_l_addrs_wr_en_a),
    .wren_b     (q_table_l_addrs_wr_en_b),
    .q_a        (q_table_l_addrs_rd_data_a),
    .q_b        (q_table_l_addrs_rd_data_b)
);

bram_true2port #(
    .AWIDTH(QUEUE_TABLE_AWIDTH),
    .DWIDTH(QUEUE_TABLE_H_ADDRS_DWIDTH),
    .DEPTH(QUEUE_TABLE_DEPTH)
)
q_table_h_addrs (
    .address_a  (q_table_h_addrs_addr_a),
    .address_b  (q_table_h_addrs_addr_b),
    .clock      (pcie_clk),
    .data_a     (q_table_h_addrs_wr_data_a),
    .data_b     (q_table_h_addrs_wr_data_b),
    .rden_a     (q_table_h_addrs_rd_en_a),
    .rden_b     (q_table_h_addrs_rd_en_b),
    .wren_a     (q_table_h_addrs_wr_en_a),
    .wren_b     (q_table_h_addrs_wr_en_b),
    .q_a        (q_table_h_addrs_rd_data_a),
    .q_b        (q_table_h_addrs_rd_data_b)
);

endmodule
