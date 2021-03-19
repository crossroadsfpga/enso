`include "./my_struct_s.sv"

module pcie_top (
    // PCIE
    input logic pcie_clk,
    input logic pcie_reset_n,

    input  logic                       pcie_bas_waitrequest,
    output logic [63:0]                pcie_bas_address,
    output logic [63:0]                pcie_bas_byteenable,
    output logic                       pcie_bas_read,
    input  logic [511:0]               pcie_bas_readdata,
    input  logic                       pcie_bas_readdatavalid,
    output logic                       pcie_bas_write,
    output logic [511:0]               pcie_bas_writedata,
    output logic [3:0]                 pcie_bas_burstcount,
    input  logic [1:0]                 pcie_bas_response,
    input  logic [PCIE_ADDR_WIDTH-1:0] pcie_address_0,
    input  logic                       pcie_write_0,
    input  logic                       pcie_read_0,
    output logic                       pcie_readdatavalid_0,
    output logic [511:0]               pcie_readdata_0,
    input  logic [511:0]               pcie_writedata_0,
    input  logic [63:0]                pcie_byteenable_0,

    input  flit_lite_t            pcie_pkt_buf_wr_data,
    input  logic                  pcie_pkt_buf_wr_en,
    output logic [PDU_AWIDTH-1:0] pcie_pkt_buf_occup,
    input  pkt_desc_t             pcie_desc_buf_wr_data,
    input  logic                  pcie_desc_buf_wr_en,
    output logic [PDU_AWIDTH-1:0] pcie_desc_buf_occup,

    output logic                  disable_pcie,
    output logic                  sw_reset,
    output pdu_metadata_t         pdumeta_cpu_data,
    output logic                  pdumeta_cpu_valid,
    input  logic [9:0]            pdumeta_cnt,
    output logic [31:0]           dma_queue_full_cnt,
    output logic [31:0]           cpu_buf_full_cnt,

    // status register bus
    input  logic        clk_status,
    input  logic [29:0] status_addr,
    input  logic        status_read,
    input  logic        status_write,
    input  logic [31:0] status_writedata,
    output logic [31:0] status_readdata,
    output logic        status_readdata_valid
);

// JTAG signals
logic [29:0]  status_addr_r;
logic         status_read_r;
logic         status_write_r;
logic [31:0]  status_writedata_r;
logic [STAT_AWIDTH-1:0] status_addr_sel_r;

logic [31:0] control_regs    [NB_CONTROL_REGS];
logic [31:0] control_regs_r  [NB_CONTROL_REGS];
logic [31:0] control_regs_r2 [NB_CONTROL_REGS];

// internal signals
pcie_block_t pcie_block;
logic cpu_reg_region;
logic cpu_reg_region_r1;
logic cpu_reg_region_r2;
logic [25:0] dsc_rb_size;
logic [25:0] pkt_rb_size;
logic internal_update_valid;
logic [BRAM_TABLE_IDX_WIDTH-1:0] page_idx;

typedef struct
{
   logic [BRAM_TABLE_IDX_WIDTH-1:0] addr_a;
   logic [BRAM_TABLE_IDX_WIDTH-1:0] addr_b;
   logic [31:0] wr_data_a;
   logic [31:0] wr_data_b;
   logic [31:0] rd_data_a;
   logic [31:0] rd_data_b;
   logic rd_en_a;
   logic rd_en_a_r;
   logic rd_en_a_r2;
   logic rd_en_b;
   logic wr_en_a;
   logic wr_en_b;
} bram_interface_t;

// descriptor queue table interface signals
bram_interface_t dsc_q_table_tails;
bram_interface_t dsc_q_table_heads;
bram_interface_t dsc_q_table_l_addrs;
bram_interface_t dsc_q_table_h_addrs;

// packet queue tables interface signals
bram_interface_t pkt_q_table_tails;
bram_interface_t pkt_q_table_heads;
bram_interface_t pkt_q_table_l_addrs;
bram_interface_t pkt_q_table_h_addrs;

logic [BRAM_TABLE_IDX_WIDTH-1:0] q_table_addr_jtag;
logic [BRAM_TABLE_IDX_WIDTH-1:0] q_table_addr_pcie;
logic [BRAM_TABLE_IDX_WIDTH-1:0] q_table_addr_jtag_pending;
logic [BRAM_TABLE_IDX_WIDTH-1:0] q_table_addr_pcie_rd_pending;

localparam NB_TABLES = 4; // We need 4 tables for every queue
localparam AWIDTH_NB_TABLES = $clog2(NB_TABLES);
localparam C2F_HEAD_OFFSET = (NB_TABLES + 1) * REG_SIZE;

logic [AWIDTH_NB_TABLES-1:0] q_table_jtag;
logic [AWIDTH_NB_TABLES-1:0] q_table_pcie;
logic [AWIDTH_NB_TABLES-1:0] q_table_jtag_pending;
logic [AWIDTH_NB_TABLES-1:0] last_rd_b_table;
logic [AWIDTH_NB_TABLES-1:0] last_rd_b_table_r;
logic [AWIDTH_NB_TABLES-1:0] last_rd_b_table_r2;

logic [PKT_Q_TABLE_TAILS_DWIDTH-1:0] q_table_rd_data_b;
logic [PKT_Q_TABLE_TAILS_DWIDTH-1:0] q_table_rd_data_b_jtag;

logic q_table_wr;
logic q_table_rd_en_jtag;
logic q_table_wr_en_jtag;
logic q_table_rd_wr_en_pcie;
logic q_table_rd_wr_en_pcie_r;
logic q_table_data_en_pcie;
logic q_table_data_en_pcie_r;
logic q_table_jtag_rd_set;
logic q_table_jtag_wr_set;
logic q_table_jtag_wr_data_set;

logic q_table_rd_pending_from_jtag;
logic q_table_pcie_rd_set;

logic dsc_rd_en_r;
logic dsc_rd_en_r2;
logic pkt_rd_en_r;
logic pkt_rd_en_r2;

logic pcie_bram_rd;
logic pcie_bram_rd_r;
logic pcie_bram_rd_r2;

logic q_table_rd_data_b_pcie_ready;
logic q_table_rd_data_b_jtag_ready;
logic q_table_rd_data_b_ready_from_jtag;

logic [RB_AWIDTH-1:0]    f2c_dsc_head;
logic [RB_AWIDTH-1:0]    f2c_dsc_tail;
logic [63:0]             f2c_dsc_buf_addr;
logic [RB_AWIDTH-1:0]    f2c_pkt_head;
logic [RB_AWIDTH-1:0]    f2c_pkt_tail;
logic                    f2c_pkt_q_needs_dsc;
logic [63:0]             f2c_pkt_buf_addr;

logic pcie_reg_read;

logic [31:0] q_table_data;
logic [31:0] q_table_data_r;
logic [31:0] q_table_data_jtag;
logic [31:0] q_table_data_jtag_pending;

logic [31:0] c2f_head;
logic [31:0] c2f_tail;
logic [63:0] c2f_kmem_addr;
logic [63:0] c2f_head_addr;

assign c2f_head = 32'b0; // FIXME(sadok) remove when reenabling c2f path

logic                            f2c_queue_ready;
logic                            tail_wr_en;
logic                            queue_rd_en;
logic                            queue_rd_en_r;
logic [BRAM_TABLE_IDX_WIDTH-1:0] f2c_rd_pkt_queue;
logic [BRAM_TABLE_IDX_WIDTH-1:0] f2c_rd_pkt_queue_r;
logic [BRAM_TABLE_IDX_WIDTH-1:0] f2c_rd_dsc_queue;
logic [BRAM_TABLE_IDX_WIDTH-1:0] f2c_wr_pkt_queue;
logic [BRAM_TABLE_IDX_WIDTH-1:0] f2c_wr_dsc_queue;
logic [RB_AWIDTH-1:0]            dsc_q_table_heads_wr_data_b_r;
logic [RB_AWIDTH-1:0]            dsc_q_table_heads_wr_data_b_r2;
logic [RB_AWIDTH-1:0]            dsc_q_table_tails_wr_data_a_r;
logic [RB_AWIDTH-1:0]            dsc_q_table_tails_wr_data_a_r2;
logic [RB_AWIDTH-1:0]            pkt_q_table_heads_wr_data_b_r;
logic [RB_AWIDTH-1:0]            pkt_q_table_heads_wr_data_b_r2;
logic [RB_AWIDTH-1:0]            pkt_q_table_tails_wr_data_a_r;
logic [RB_AWIDTH-1:0]            pkt_q_table_tails_wr_data_a_r2;
logic [RB_AWIDTH-1:0]            new_dsc_tail;
logic [RB_AWIDTH-1:0]            new_pkt_tail;

// Bit vector holding the status of every pkt queue
// (i.e., if they need a descriptor or not).
logic [MAX_NB_FLOWS-1:0] pkt_q_status;

// JTAG
always@(posedge clk_status) begin
    automatic logic [JTAG_ADDR_WIDTH-1:0] jtag_reg = 
        status_addr_r[JTAG_ADDR_WIDTH-1:0];

    status_addr_r       <= status_addr;
    status_addr_sel_r   <= status_addr[29:30-STAT_AWIDTH];

    status_read_r       <= status_read;
    status_write_r      <= status_write;
    status_writedata_r  <= status_writedata;

    status_readdata_valid <= 0;
    q_table_rd_en_jtag <= 0;
    q_table_wr_en_jtag <= 0;

    if (!pcie_reset_n) begin
        integer i;
        for (i = 0; i < NB_CONTROL_REGS; i = i + 1) begin
            control_regs[i] <= 0;
        end
    end

    if (q_table_rd_data_b_ready_from_jtag && q_table_rd_pending_from_jtag) begin
        status_readdata <= q_table_rd_data_b_jtag;
        status_readdata_valid <= 1;
        q_table_rd_pending_from_jtag <= 0;
    end

    if (status_addr_sel_r == PCIE & status_read_r) begin
        if (jtag_reg < NB_CONTROL_REGS) begin
            status_readdata <= control_regs[jtag_reg];
            status_readdata_valid <= 1;
        end else begin
            q_table_jtag <= {jtag_reg-NB_CONTROL_REGS}[AWIDTH_NB_TABLES-1:0];
            q_table_addr_jtag <=
                {jtag_reg - NB_CONTROL_REGS}[
                    AWIDTH_NB_TABLES +:BRAM_TABLE_IDX_WIDTH];
            q_table_rd_pending_from_jtag <= 1;
            q_table_rd_en_jtag <= 1;
        end
    end else if (status_addr_sel_r == PCIE & status_write_r) begin
        if (jtag_reg < NB_CONTROL_REGS) begin
            control_regs[jtag_reg] <= status_writedata_r;
        end else begin
            q_table_jtag <= {jtag_reg-NB_CONTROL_REGS}[AWIDTH_NB_TABLES-1:0];
            q_table_data_jtag <= status_writedata_r;
            q_table_addr_jtag <=
                {jtag_reg - NB_CONTROL_REGS}[
                    AWIDTH_NB_TABLES +:BRAM_TABLE_IDX_WIDTH];
            q_table_wr_en_jtag <= 1;
        end
    end
end

assign disable_pcie = control_regs_r2[0][0];
assign pkt_rb_size = control_regs_r2[0][26:1];

// Use to reset stats from software. Must also be unset from software
assign sw_reset = control_regs_r2[0][27];

assign dsc_rb_size = control_regs_r2[1][25:0];

// Avoid short path/long path timing problem.
always @(posedge pcie_clk) begin
    integer i;
    for (i = 0; i < NB_CONTROL_REGS; i = i + 1) begin
        control_regs_r[i] <= control_regs[i];
        control_regs_r2[i] <= control_regs_r[i];
    end
end

// We choose the right set of registers based on the page (the page's index LSB
// is at bit 12 of the memory address, the MSB depends on the number of queues
// we support). The first MAX_NB_FLOWS pages hold the packet queues and the next
// MAX_NB_APPS pages hold the descriptor queues.
assign page_idx = pcie_address_0[12 +: BRAM_TABLE_IDX_WIDTH];

assign q_table_rd_data_b_pcie_ready = 
    (dsc_rd_en_r2 | pkt_rd_en_r2) & pcie_bram_rd_r2;

// We share a single BRAM port among: PCIe writes, PCIe reads and JTAG reads.
// We serve simultaneous requests following this priority. That way, we only
// serve PCIe reads when there are no PCIe writes and we only serve JTAG reads
// when there are no PCIe writes or reads.
always @(posedge pcie_clk) begin
    dsc_q_table_tails.wr_en_b <= 0;
    dsc_q_table_heads.wr_en_b <= 0;
    dsc_q_table_l_addrs.wr_en_b <= 0;
    dsc_q_table_h_addrs.wr_en_b <= 0;

    dsc_q_table_tails.rd_en_b <= 0;
    dsc_q_table_heads.rd_en_b <= 0;
    dsc_q_table_l_addrs.rd_en_b <= 0;
    dsc_q_table_h_addrs.rd_en_b <= 0;

    pkt_q_table_tails.wr_en_b <= 0;
    pkt_q_table_heads.wr_en_b <= 0;
    pkt_q_table_l_addrs.wr_en_b <= 0;
    pkt_q_table_h_addrs.wr_en_b <= 0;

    pkt_q_table_tails.rd_en_b <= 0;
    pkt_q_table_heads.rd_en_b <= 0;
    pkt_q_table_l_addrs.rd_en_b <= 0;
    pkt_q_table_h_addrs.rd_en_b <= 0;

    last_rd_b_table <= 0;

    // TODO(sadok) We assume PCIe reads only come after the previous completes.
    // If that is not true, we may need to keep a queue of requests.
    if (pcie_reg_read) begin
        q_table_addr_pcie_rd_pending <= page_idx;
        q_table_pcie_rd_set <= 1;
    end

    // We assign the JTAG read enable and the address to pending registers.
    // These are read opportunistically, when there is no operation from the
    // PCIe. This lets us share the same BRAM port for PCIe and JTAG
    if (q_table_rd_wr_en_pcie) begin
        q_table_jtag_pending <= q_table_pcie;
        if (q_table_wr) begin
            q_table_jtag_wr_set <= 1;
        end else begin
            q_table_jtag_rd_set <= 1;
        end
        q_table_addr_jtag_pending <= q_table_addr_pcie;
    end

    if (q_table_data_en_pcie) begin
        q_table_jtag_wr_data_set <= 1;
        q_table_data_jtag_pending <= q_table_data;
    end

    q_table_rd_data_b_jtag_ready <= 0;

    if (queue_rd_en_r) begin
        f2c_pkt_q_needs_dsc <= !pkt_q_status[f2c_rd_pkt_queue_r];
        pkt_q_status[f2c_rd_pkt_queue_r] <= 1'b1;
    end

    if (!pcie_reset_n) begin
        q_table_pcie_rd_set <= 0;
        q_table_jtag_wr_set <= 0;
        q_table_jtag_wr_data_set <= 0;
        q_table_jtag_rd_set <= 0;
        q_table_rd_data_b <= 0;
        c2f_kmem_addr <= 0;
        pkt_q_status <= 0;
    end else if (pcie_write_0) begin // PCIe write
        if (page_idx < MAX_NB_FLOWS) begin
            automatic logic [BRAM_TABLE_IDX_WIDTH-1:0] address = page_idx;
        
            // if (pcie_byteenable_0[0*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
            //     pkt_q_table_tails.wr_data_b <= pcie_writedata_0[0*32 +: 32];
            //     pkt_q_table_tails.wr_en_b <= 1;
            //     pkt_q_table_tails.addr_b <= address;
            // end
            if (pcie_byteenable_0[1*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
                pkt_q_table_heads.wr_data_b <= pcie_writedata_0[1*32 +: 32];
                pkt_q_table_heads.wr_en_b <= 1;
                pkt_q_table_heads.addr_b <= address;

                // update queue status so that we send a descriptor next time
                pkt_q_status[address] <= 1'b0;
                // FIXME(sadok) this will only work if the queue eventually
                // receives more packets. Otherwise, there will be some residue
                // packets that software will never know about. To fix this, we
                // need to check if the latest tail pointer is greater than the
                // new head that we received. If it is, that means that we need
                // to send an extra descriptor. The logic to send an extra
                // descriptor, however, is quite tricky. We probably need to add
                // a queue with `descriptor requests` to send to the fpga2cpu so
                // that it can send these descriptor when it has a chance -- it
                // may even ignore some of them if it receives a new packet for
                // the queue. Another tricky part is that there may be some race
                // conditions, where this part of the design thinks that the
                // queue is updated but the fpga2cpu is processing a new packet
                // and will not send a descriptor. To overcome this, fpga2cpu
                // should make sure pcie_top has the latest tail, before it
                // decides if it needs to send the descriptor.
            end
            if (pcie_byteenable_0[2*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
                pkt_q_table_l_addrs.wr_data_b <= pcie_writedata_0[2*32 +: 32];
                pkt_q_table_l_addrs.wr_en_b <= 1;
                pkt_q_table_l_addrs.addr_b <= address;
            end
            if (pcie_byteenable_0[3*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
                pkt_q_table_h_addrs.wr_data_b <= pcie_writedata_0[3*32 +: 32];
                pkt_q_table_h_addrs.wr_en_b <= 1;
                pkt_q_table_h_addrs.addr_b <= address;
            end
        end else begin
            automatic logic [BRAM_TABLE_IDX_WIDTH-1:0] address;
            address = page_idx - MAX_NB_FLOWS;

            // if (pcie_byteenable_0[0*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
            //     dsc_q_table_tails.wr_data_b <= pcie_writedata_0[0*32 +: 32];
            //     dsc_q_table_tails.wr_en_b <= 1;
            //     dsc_q_table_tails.addr_b <= address;
            // end
            if (pcie_byteenable_0[1*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
                dsc_q_table_heads.wr_data_b <= pcie_writedata_0[1*32 +: 32];
                dsc_q_table_heads.wr_en_b <= 1;
                dsc_q_table_heads.addr_b <= address;
            end
            if (pcie_byteenable_0[2*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
                dsc_q_table_l_addrs.wr_data_b <= pcie_writedata_0[2*32 +: 32];
                dsc_q_table_l_addrs.wr_en_b <= 1;
                dsc_q_table_l_addrs.addr_b <= address;
            end
            if (pcie_byteenable_0[3*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
                dsc_q_table_h_addrs.wr_data_b <= pcie_writedata_0[3*32 +: 32];
                dsc_q_table_h_addrs.wr_en_b <= 1;
                dsc_q_table_h_addrs.addr_b <= address;
            end
        end

        // TODO(sadok) implement CPU-> FPGA path
        // // CPU -> FPGA
        // // TODO(sadok) This assumes a single control queue. We also need to add
        // //             TX data queues eventually
        // if (pcie_byteenable_0[8*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
        //     c2f_tail <= pcie_writedata_0[8*32 +: 32];
        // end
        // // if (pcie_byteenable_0[9*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
        // //     c2f_head <= pcie_writedata_0[9*32 +: 32];
        // // end
        // if (pcie_byteenable_0[10*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
        //     c2f_kmem_addr[31:0] <= pcie_writedata_0[10*32 +: 32];
        // end
        // if (pcie_byteenable_0[11*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
        //     c2f_kmem_addr[63:32] <= pcie_writedata_0[11*32 +: 32];
        // end
    end else if (q_table_pcie_rd_set) begin // PCIe read
        q_table_pcie_rd_set <= 0;

        if (q_table_addr_pcie_rd_pending < MAX_NB_FLOWS) begin
            automatic logic [BRAM_TABLE_IDX_WIDTH-1:0] address = 
                q_table_addr_pcie_rd_pending;

            pkt_q_table_tails.rd_en_b <= 1;
            pkt_q_table_tails.addr_b <= address;

            pkt_q_table_heads.rd_en_b <= 1;
            pkt_q_table_heads.addr_b <= address;

            pkt_q_table_l_addrs.rd_en_b <= 1;
            pkt_q_table_l_addrs.addr_b <= address;

            pkt_q_table_h_addrs.rd_en_b <= 1;
            pkt_q_table_h_addrs.addr_b <= address;
        end else begin
            automatic logic [BRAM_TABLE_IDX_WIDTH-1:0] address = 
                q_table_addr_pcie_rd_pending - MAX_NB_FLOWS;

            dsc_q_table_tails.rd_en_b <= 1;
            dsc_q_table_tails.addr_b <= address;

            dsc_q_table_heads.rd_en_b <= 1;
            dsc_q_table_heads.addr_b <= address;

            dsc_q_table_l_addrs.rd_en_b <= 1;
            dsc_q_table_l_addrs.addr_b <= address;

            dsc_q_table_h_addrs.rd_en_b <= 1;
            dsc_q_table_h_addrs.addr_b <= address;
        end
    end else if (q_table_jtag_wr_set && q_table_jtag_wr_data_set) begin 
        // JTAG write
        q_table_jtag_wr_set <= 0;
        q_table_jtag_wr_data_set <= 0;
        if (q_table_addr_jtag_pending < MAX_NB_FLOWS) begin
            automatic logic [BRAM_TABLE_IDX_WIDTH-1:0] address = 
                q_table_addr_jtag_pending;
            case (q_table_jtag_pending)
                0: begin
                    pkt_q_table_tails.wr_data_b <= q_table_data_jtag_pending;
                    pkt_q_table_tails.wr_en_b <= 1;
                    pkt_q_table_tails.addr_b <= address;
                end
                1: begin
                    pkt_q_table_heads.wr_data_b <= q_table_data_jtag_pending;
                    pkt_q_table_heads.wr_en_b <= 1;
                    pkt_q_table_heads.addr_b <= address;
                end
                2: begin
                    pkt_q_table_l_addrs.wr_data_b <= q_table_data_jtag_pending;
                    pkt_q_table_l_addrs.wr_en_b <= 1;
                    pkt_q_table_l_addrs.addr_b <= address;
                end
                3: begin
                    pkt_q_table_h_addrs.wr_data_b <= q_table_data_jtag_pending;
                    pkt_q_table_h_addrs.wr_en_b <= 1;
                    pkt_q_table_h_addrs.addr_b <= address;
                end
            endcase
        end else begin
            automatic logic [BRAM_TABLE_IDX_WIDTH-1:0] address = 
                q_table_addr_jtag_pending - MAX_NB_FLOWS;
            case (q_table_jtag_pending)
                0: begin
                    dsc_q_table_tails.wr_data_b <= q_table_data_jtag_pending;
                    dsc_q_table_tails.wr_en_b <= 1;
                    dsc_q_table_tails.addr_b <= address;
                end
                1: begin
                    dsc_q_table_heads.wr_data_b <= q_table_data_jtag_pending;
                    dsc_q_table_heads.wr_en_b <= 1;
                    dsc_q_table_heads.addr_b <= address;
                end
                2: begin
                    dsc_q_table_l_addrs.wr_data_b <= q_table_data_jtag_pending;
                    dsc_q_table_l_addrs.wr_en_b <= 1;
                    dsc_q_table_l_addrs.addr_b <= address;
                end
                3: begin
                    dsc_q_table_h_addrs.wr_data_b <= q_table_data_jtag_pending;
                    dsc_q_table_h_addrs.wr_en_b <= 1;
                    dsc_q_table_h_addrs.addr_b <= address;
                end
            endcase
        end
    end else if (q_table_jtag_rd_set) begin // JTAG read
        q_table_jtag_rd_set <= 0;
        last_rd_b_table <= q_table_jtag_pending;

        if (q_table_addr_jtag_pending < MAX_NB_FLOWS) begin
            automatic logic [BRAM_TABLE_IDX_WIDTH-1:0] address = 
                q_table_addr_jtag_pending;
            case (q_table_jtag_pending)
                0: begin
                    pkt_q_table_tails.rd_en_b <= 1;
                    pkt_q_table_tails.addr_b <= address;
                end
                1: begin
                    pkt_q_table_heads.rd_en_b <= 1;
                    pkt_q_table_heads.addr_b <= address;
                end
                2: begin
                    pkt_q_table_l_addrs.rd_en_b <= 1;
                    pkt_q_table_l_addrs.addr_b <= address;
                end
                3: begin
                    pkt_q_table_h_addrs.rd_en_b <= 1;
                    pkt_q_table_h_addrs.addr_b <= address;
                end
            endcase
        end else begin
            automatic logic [BRAM_TABLE_IDX_WIDTH-1:0] address = 
                q_table_addr_jtag_pending - MAX_NB_FLOWS;
            case (q_table_jtag_pending)
                0: begin
                    dsc_q_table_tails.rd_en_b <= 1;
                    dsc_q_table_tails.addr_b <= address;
                end
                1: begin
                    dsc_q_table_heads.rd_en_b <= 1;
                    dsc_q_table_heads.addr_b <= address;
                end
                2: begin
                    dsc_q_table_l_addrs.rd_en_b <= 1;
                    dsc_q_table_l_addrs.addr_b <= address;
                end
                3: begin
                    dsc_q_table_h_addrs.rd_en_b <= 1;
                    dsc_q_table_h_addrs.addr_b <= address;
                end
            endcase
        end
        
    end

    last_rd_b_table_r <= last_rd_b_table;
    last_rd_b_table_r2 <= last_rd_b_table_r;

    dsc_rd_en_r <= dsc_q_table_tails.rd_en_b | dsc_q_table_heads.rd_en_b |
               dsc_q_table_l_addrs.rd_en_b | dsc_q_table_h_addrs.rd_en_b;

    pkt_rd_en_r <= pkt_q_table_tails.rd_en_b | pkt_q_table_heads.rd_en_b |
                pkt_q_table_l_addrs.rd_en_b | pkt_q_table_h_addrs.rd_en_b;

    dsc_rd_en_r2 <= dsc_rd_en_r;
    pkt_rd_en_r2 <= pkt_rd_en_r;

    // signals if this is a PCIe (1) or a JTAG (0) read
    pcie_bram_rd <= q_table_pcie_rd_set;
    pcie_bram_rd_r <= pcie_bram_rd;
    pcie_bram_rd_r2 <= pcie_bram_rd_r;

    // JTAG read is ready
    if (!pcie_bram_rd_r2) begin
        if (dsc_rd_en_r2) begin
            case (last_rd_b_table_r2)
                0: begin
                    q_table_rd_data_b <= dsc_q_table_tails.rd_data_b;
                end
                1: begin
                    q_table_rd_data_b <= dsc_q_table_heads.rd_data_b;
                end
                2: begin
                    q_table_rd_data_b <= dsc_q_table_l_addrs.rd_data_b;
                end
                3: begin
                    q_table_rd_data_b <= dsc_q_table_h_addrs.rd_data_b;
                end
            endcase
            q_table_rd_data_b_jtag_ready <= 1;
        end

        if (pkt_rd_en_r2) begin
            case (last_rd_b_table_r2)
                0: begin
                    q_table_rd_data_b <= pkt_q_table_tails.rd_data_b;
                end
                1: begin
                    q_table_rd_data_b <= pkt_q_table_heads.rd_data_b;
                end
                2: begin
                    q_table_rd_data_b <= pkt_q_table_l_addrs.rd_data_b;
                end
                3: begin
                    q_table_rd_data_b <= pkt_q_table_h_addrs.rd_data_b;
                end
            endcase
            q_table_rd_data_b_jtag_ready <= 1;
        end
    end
end

typedef enum
{
    IDLE,
    WAIT_DMA,
    BRAM_DELAY_1,
    BRAM_DELAY_2,
    SWITCH_QUEUE
} state_t;
state_t state;

always @(posedge pcie_clk)begin
    dsc_q_table_tails.rd_en_a_r <= dsc_q_table_tails.rd_en_a;
    dsc_q_table_tails.rd_en_a_r2 <= dsc_q_table_tails.rd_en_a_r;
    dsc_q_table_heads.rd_en_a_r <= dsc_q_table_heads.rd_en_a;
    dsc_q_table_heads.rd_en_a_r2 <= dsc_q_table_heads.rd_en_a_r;
    dsc_q_table_l_addrs.rd_en_a_r <= dsc_q_table_l_addrs.rd_en_a;
    dsc_q_table_l_addrs.rd_en_a_r2 <= dsc_q_table_l_addrs.rd_en_a_r;
    dsc_q_table_h_addrs.rd_en_a_r <= dsc_q_table_h_addrs.rd_en_a;
    dsc_q_table_h_addrs.rd_en_a_r2 <= dsc_q_table_h_addrs.rd_en_a_r;

    pkt_q_table_tails.rd_en_a_r <= pkt_q_table_tails.rd_en_a;
    pkt_q_table_tails.rd_en_a_r2 <= pkt_q_table_tails.rd_en_a_r;
    pkt_q_table_heads.rd_en_a_r <= pkt_q_table_heads.rd_en_a;
    pkt_q_table_heads.rd_en_a_r2 <= pkt_q_table_heads.rd_en_a_r;
    pkt_q_table_l_addrs.rd_en_a_r <= pkt_q_table_l_addrs.rd_en_a;
    pkt_q_table_l_addrs.rd_en_a_r2 <= pkt_q_table_l_addrs.rd_en_a_r;
    pkt_q_table_h_addrs.rd_en_a_r <= pkt_q_table_h_addrs.rd_en_a;
    pkt_q_table_h_addrs.rd_en_a_r2 <= pkt_q_table_h_addrs.rd_en_a_r;

    // we used the delayed wr signals for head and tail to use when there are
    // concurrent reads
    dsc_q_table_heads_wr_data_b_r <= dsc_q_table_heads.wr_data_b[RB_AWIDTH-1:0];
    dsc_q_table_heads_wr_data_b_r2 <= dsc_q_table_heads_wr_data_b_r;
    dsc_q_table_tails_wr_data_a_r <= dsc_q_table_tails.wr_data_a[RB_AWIDTH-1:0];
    dsc_q_table_tails_wr_data_a_r2 <= dsc_q_table_tails_wr_data_a_r;
    
    pkt_q_table_heads_wr_data_b_r <= pkt_q_table_heads.wr_data_b[RB_AWIDTH-1:0];
    pkt_q_table_heads_wr_data_b_r2 <= pkt_q_table_heads_wr_data_b_r;
    pkt_q_table_tails_wr_data_a_r <= pkt_q_table_tails.wr_data_a[RB_AWIDTH-1:0];
    pkt_q_table_tails_wr_data_a_r2 <= pkt_q_table_tails_wr_data_a_r;

    queue_rd_en_r <= queue_rd_en;
    f2c_rd_pkt_queue_r <= f2c_rd_pkt_queue;
end

always_comb begin
    dsc_q_table_tails.addr_a = f2c_rd_dsc_queue;
    dsc_q_table_heads.addr_a = f2c_rd_dsc_queue;
    dsc_q_table_l_addrs.addr_a = f2c_rd_dsc_queue;
    dsc_q_table_h_addrs.addr_a = f2c_rd_dsc_queue;
    pkt_q_table_tails.addr_a = f2c_rd_pkt_queue;
    pkt_q_table_heads.addr_a = f2c_rd_pkt_queue;
    pkt_q_table_l_addrs.addr_a = f2c_rd_pkt_queue;
    pkt_q_table_h_addrs.addr_a = f2c_rd_pkt_queue;

    dsc_q_table_tails.rd_en_a = 0;
    dsc_q_table_heads.rd_en_a = 0;
    dsc_q_table_l_addrs.rd_en_a = 0;
    dsc_q_table_h_addrs.rd_en_a = 0;
    pkt_q_table_tails.rd_en_a = 0;
    pkt_q_table_heads.rd_en_a = 0;
    pkt_q_table_l_addrs.rd_en_a = 0;
    pkt_q_table_h_addrs.rd_en_a = 0;

    dsc_q_table_tails.wr_en_a = 0;
    dsc_q_table_heads.wr_en_a = 0;
    dsc_q_table_l_addrs.wr_en_a = 0;
    dsc_q_table_h_addrs.wr_en_a = 0;
    pkt_q_table_tails.wr_en_a = 0;
    pkt_q_table_heads.wr_en_a = 0;
    pkt_q_table_l_addrs.wr_en_a = 0;
    pkt_q_table_h_addrs.wr_en_a = 0;

    dsc_q_table_tails.wr_data_a = new_dsc_tail;
    pkt_q_table_tails.wr_data_a = new_pkt_tail;

    if (queue_rd_en) begin
        // when reading and writing the same queue, we avoid reading the tail
        // and use the new written tail instead
        dsc_q_table_tails.rd_en_a = !tail_wr_en 
            || (f2c_rd_dsc_queue != f2c_wr_dsc_queue);
        dsc_q_table_heads.rd_en_a = 1;
        dsc_q_table_l_addrs.rd_en_a = 1;
        dsc_q_table_h_addrs.rd_en_a = 1;
        pkt_q_table_tails.rd_en_a = !tail_wr_en 
            || (f2c_rd_pkt_queue != f2c_wr_pkt_queue);
        pkt_q_table_heads.rd_en_a = 1;
        pkt_q_table_l_addrs.rd_en_a = 1;
        pkt_q_table_h_addrs.rd_en_a = 1;

        // Concurrent head write from PCIe or JTAG, we bypass the read and use
        // the new written value instead. This is done to prevent concurrent
        // read and write to the same address, which causes undefined behavior.
        if ((dsc_q_table_heads.addr_a == dsc_q_table_heads.addr_b) 
                && dsc_q_table_heads.wr_en_b) begin
            dsc_q_table_heads.rd_en_a = 0;
        end
        if ((pkt_q_table_heads.addr_a == pkt_q_table_heads.addr_b) 
                && pkt_q_table_heads.wr_en_b) begin
            pkt_q_table_heads.rd_en_a = 0;
        end
    end else if (tail_wr_en) begin
        dsc_q_table_tails.wr_en_a = 1;
        dsc_q_table_tails.addr_a = f2c_wr_dsc_queue;
        pkt_q_table_tails.wr_en_a = 1;
        pkt_q_table_tails.addr_a = f2c_wr_pkt_queue;
    end

    f2c_queue_ready = 
        dsc_q_table_tails.rd_en_a_r2   || dsc_q_table_heads.rd_en_a_r2   ||
        dsc_q_table_l_addrs.rd_en_a_r2 || dsc_q_table_h_addrs.rd_en_a_r2 ||
        pkt_q_table_tails.rd_en_a_r2   || pkt_q_table_heads.rd_en_a_r2   ||
        pkt_q_table_l_addrs.rd_en_a_r2 || pkt_q_table_h_addrs.rd_en_a_r2;

    if (dsc_q_table_tails.rd_en_a_r2) begin
        f2c_dsc_tail = dsc_q_table_tails.rd_data_a[RB_AWIDTH-1:0];
    end else begin
        f2c_dsc_tail = dsc_q_table_tails_wr_data_a_r2;
    end
    if (pkt_q_table_tails.rd_en_a_r2) begin
        f2c_pkt_tail = pkt_q_table_tails.rd_data_a[RB_AWIDTH-1:0];
    end else begin
        f2c_pkt_tail = pkt_q_table_tails_wr_data_a_r2;
    end

    if (dsc_q_table_heads.rd_en_a_r2) begin
        f2c_dsc_head = dsc_q_table_heads.rd_data_a[RB_AWIDTH-1:0];
    end else begin
        // return the delayed concurrent write
        f2c_dsc_head = dsc_q_table_heads_wr_data_b_r2;
    end
    if (pkt_q_table_heads.rd_en_a_r2) begin
        f2c_pkt_head = pkt_q_table_heads.rd_data_a[RB_AWIDTH-1:0];
    end else begin
        // return the delayed concurrent write
        f2c_pkt_head = pkt_q_table_heads_wr_data_b_r2;
    end

    f2c_dsc_buf_addr[31:0] = dsc_q_table_l_addrs.rd_data_a;
    f2c_dsc_buf_addr[63:32] = dsc_q_table_h_addrs.rd_data_a;
    f2c_pkt_buf_addr[31:0] = pkt_q_table_l_addrs.rd_data_a;
    f2c_pkt_buf_addr[63:32] = pkt_q_table_h_addrs.rd_data_a;
end

// PDU_BUFFER
// CPU side MMIO read MUX. If pkt_rd_en_r2, we return pkt queue info else, we
// return dsc queue info.
always @(posedge pcie_clk) begin
    if (!pcie_reset_n) begin
        pcie_readdata_0 <= 0;
        pcie_readdatavalid_0 <= 0;
    end else begin
        if (pkt_rd_en_r2) begin
            pcie_readdata_0 <= {
                256'h0, c2f_kmem_addr, c2f_head, c2f_tail,
                pkt_q_table_h_addrs.rd_data_b, pkt_q_table_l_addrs.rd_data_b,
                pkt_q_table_heads.rd_data_b, pkt_q_table_tails.rd_data_b
            };
        end else begin
            pcie_readdata_0 <= {
                256'h0, c2f_kmem_addr, c2f_head, c2f_tail,
                dsc_q_table_h_addrs.rd_data_b, dsc_q_table_l_addrs.rd_data_b,
                dsc_q_table_heads.rd_data_b, dsc_q_table_tails.rd_data_b
            };
        end
        
        pcie_readdatavalid_0 <= q_table_rd_data_b_pcie_ready;
    end
end

assign cpu_reg_region = pcie_address_0[PCIE_ADDR_WIDTH-1:6] < MMIO_OFFSET;
assign pcie_reg_read = cpu_reg_region & pcie_read_0;

logic [31:0] pkt_q_table_pcie_out;
logic [31:0] pkt_q_table_pcie_out_r;

always @(posedge pcie_clk) begin
    // two cycle read delay
    cpu_reg_region_r1 <= cpu_reg_region;
    cpu_reg_region_r2 <= cpu_reg_region_r1;

    // jtag_to_pcie_fifo output pipeline
    q_table_rd_wr_en_pcie <= q_table_rd_wr_en_pcie_r;
    pkt_q_table_pcie_out <= pkt_q_table_pcie_out_r;
    q_table_data_en_pcie <= q_table_data_en_pcie_r;
    q_table_data <= q_table_data_r;
end

assign q_table_addr_pcie = pkt_q_table_pcie_out[0 +: BRAM_TABLE_IDX_WIDTH];
assign q_table_pcie = 
    pkt_q_table_pcie_out[BRAM_TABLE_IDX_WIDTH +: AWIDTH_NB_TABLES];
assign q_table_wr = pkt_q_table_pcie_out[31]; // 0 = rd, 1 = wr

// PCIe and JTAG are in different clock domains, we use the following
// dual-clocked FIFOs to transfer data between the two
dc_fifo_reg_core  jtag_to_pcie_fifo (
    .wrclock               (clk_status), // jtag clock
    .wrreset_n             (pcie_reset_n),
    .rdclock               (pcie_clk),
    .rdreset_n             (pcie_reset_n),
    .avalonst_sink_valid   (q_table_rd_en_jtag | q_table_wr_en_jtag),
    .avalonst_sink_data    ({
        q_table_wr_en_jtag,
        {{32 - BRAM_TABLE_IDX_WIDTH - AWIDTH_NB_TABLES - 1}{1'b0}},
        q_table_jtag,
        q_table_addr_jtag
    }),
    .avalonst_source_valid (q_table_rd_wr_en_pcie_r),
    .avalonst_source_data  (pkt_q_table_pcie_out_r)
);
dc_fifo_reg_core  jtag_to_pcie_wr_data_fifo (
    .wrclock               (clk_status), // jtag clock
    .wrreset_n             (pcie_reset_n),
    .rdclock               (pcie_clk),
    .rdreset_n             (pcie_reset_n),
    .avalonst_sink_valid   (q_table_wr_en_jtag),
    .avalonst_sink_data    (q_table_data_jtag),
    .avalonst_source_valid (q_table_data_en_pcie_r),
    .avalonst_source_data  (q_table_data_r)
);
dc_fifo_reg_core  pcie_to_jtag_fifo (
    .wrclock               (pcie_clk),
    .wrreset_n             (pcie_reset_n),
    .rdclock               (clk_status), // jtag clock
    .rdreset_n             (pcie_reset_n),
    .avalonst_sink_valid   (q_table_rd_data_b_jtag_ready),
    .avalonst_sink_data    (q_table_rd_data_b),
    .avalonst_source_valid (q_table_rd_data_b_ready_from_jtag),
    .avalonst_source_data  (q_table_rd_data_b_jtag)
);

fpga2cpu_pcie f2c_inst (
    .clk                    (pcie_clk),
    .rst                    (!pcie_reset_n),
    .pkt_buf_wr_data        (pcie_pkt_buf_wr_data),
    .pkt_buf_wr_en          (pcie_pkt_buf_wr_en),
    .pkt_buf_occup          (pcie_pkt_buf_occup),
    .desc_buf_wr_data       (pcie_desc_buf_wr_data),
    .desc_buf_wr_en         (pcie_desc_buf_wr_en),
    .desc_buf_occup         (pcie_desc_buf_occup),
    .in_dsc_head            (f2c_dsc_head),
    .in_dsc_tail            (f2c_dsc_tail),
    .in_dsc_buf_addr        (f2c_dsc_buf_addr),
    .in_pkt_head            (f2c_pkt_head),
    .in_pkt_tail            (f2c_pkt_tail),
    .in_pkt_q_needs_dsc     (f2c_pkt_q_needs_dsc),
    .in_pkt_buf_addr        (f2c_pkt_buf_addr),
    .rd_pkt_queue           (f2c_rd_pkt_queue),
    .rd_dsc_queue           (f2c_rd_dsc_queue),
    .queue_ready            (f2c_queue_ready),
    .out_dsc_tail           (new_dsc_tail),
    .out_pkt_tail           (new_pkt_tail),
    .wr_pkt_queue           (f2c_wr_pkt_queue),
    .wr_dsc_queue           (f2c_wr_dsc_queue),
    .queue_rd_en            (queue_rd_en),
    .tail_wr_en             (tail_wr_en),
    .dsc_rb_size            ({5'b0, dsc_rb_size}),
    .pkt_rb_size            ({5'b0, pkt_rb_size}),
    .pcie_bas_waitrequest   (pcie_bas_waitrequest),
    .pcie_bas_address       (pcie_bas_address),
    .pcie_bas_byteenable    (pcie_bas_byteenable),
    .pcie_bas_read          (pcie_bas_read),
    .pcie_bas_readdata      (pcie_bas_readdata),
    .pcie_bas_readdatavalid (pcie_bas_readdatavalid),
    .pcie_bas_write         (pcie_bas_write),
    .pcie_bas_writedata     (pcie_bas_writedata),
    .pcie_bas_burstcount    (pcie_bas_burstcount),
    .pcie_bas_response      (pcie_bas_response),
    .sw_reset               (sw_reset),
    .dma_queue_full_cnt     (dma_queue_full_cnt),
    .cpu_buf_full_cnt       (cpu_buf_full_cnt)
);

// cpu2fpga_pcie c2f_inst (
//     .clk                    (pcie_clk),
//     .rst                    (!pcie_reset_n),
//     .pdumeta_cpu_data       (pdumeta_cpu_data),
//     .pdumeta_cpu_valid      (pdumeta_cpu_valid),
//     .pdumeta_cnt            (pdumeta_cnt),
//     .head                   (c2f_head[C2F_RB_AWIDTH-1:0]),
//     .tail                   (c2f_tail[C2F_RB_AWIDTH-1:0]),
//     .kmem_addr              (c2f_kmem_addr),
//     .cpu_c2f_head_addr      (c2f_head_addr),
//     .wrdm_prio_ready        (pcie_wrdm_prio_ready),
//     .wrdm_prio_valid        (pcie_wrdm_prio_valid),
//     .wrdm_prio_data         (pcie_wrdm_prio_data),
//     .rddm_desc_ready        (pcie_rddm_desc_ready),
//     .rddm_desc_valid        (pcie_rddm_desc_valid),
//     .rddm_desc_data         (pcie_rddm_desc_data),
//     .c2f_writedata          (pcie_writedata_1),
//     .c2f_write              (pcie_write_1),
//     .c2f_address            (pcie_address_1[14:6])
// );


////////////////////////
// Packet Queue BRAMs //
////////////////////////

bram_true2port #(
    .AWIDTH(PKT_Q_TABLE_AWIDTH),
    .DWIDTH(PKT_Q_TABLE_TAILS_DWIDTH),
    .DEPTH(PKT_Q_TABLE_DEPTH)
)
pkt_q_table_tails_bram (
    .address_a  (pkt_q_table_tails.addr_a[PKT_Q_TABLE_AWIDTH-1:0]),
    .address_b  (pkt_q_table_tails.addr_b[PKT_Q_TABLE_AWIDTH-1:0]),
    .clock      (pcie_clk),
    .data_a     (pkt_q_table_tails.wr_data_a),
    .data_b     (pkt_q_table_tails.wr_data_b),
    .rden_a     (pkt_q_table_tails.rd_en_a),
    .rden_b     (pkt_q_table_tails.rd_en_b),
    .wren_a     (pkt_q_table_tails.wr_en_a),
    .wren_b     (pkt_q_table_tails.wr_en_b),
    .q_a        (pkt_q_table_tails.rd_data_a),
    .q_b        (pkt_q_table_tails.rd_data_b)
);

bram_true2port #(
    .AWIDTH(PKT_Q_TABLE_AWIDTH),
    .DWIDTH(PKT_Q_TABLE_HEADS_DWIDTH),
    .DEPTH(PKT_Q_TABLE_DEPTH)
)
pkt_q_table_heads_bram (
    .address_a  (pkt_q_table_heads.addr_a[PKT_Q_TABLE_AWIDTH-1:0]),
    .address_b  (pkt_q_table_heads.addr_b[PKT_Q_TABLE_AWIDTH-1:0]),
    .clock      (pcie_clk),
    .data_a     (pkt_q_table_heads.wr_data_a),
    .data_b     (pkt_q_table_heads.wr_data_b),
    .rden_a     (pkt_q_table_heads.rd_en_a),
    .rden_b     (pkt_q_table_heads.rd_en_b),
    .wren_a     (pkt_q_table_heads.wr_en_a),
    .wren_b     (pkt_q_table_heads.wr_en_b),
    .q_a        (pkt_q_table_heads.rd_data_a),
    .q_b        (pkt_q_table_heads.rd_data_b)
);

bram_true2port #(
    .AWIDTH(PKT_Q_TABLE_AWIDTH),
    .DWIDTH(PKT_Q_TABLE_L_ADDRS_DWIDTH),
    .DEPTH(PKT_Q_TABLE_DEPTH)
)
pkt_q_table_l_addrs_bram (
    .address_a  (pkt_q_table_l_addrs.addr_a[PKT_Q_TABLE_AWIDTH-1:0]),
    .address_b  (pkt_q_table_l_addrs.addr_b[PKT_Q_TABLE_AWIDTH-1:0]),
    .clock      (pcie_clk),
    .data_a     (pkt_q_table_l_addrs.wr_data_a),
    .data_b     (pkt_q_table_l_addrs.wr_data_b),
    .rden_a     (pkt_q_table_l_addrs.rd_en_a),
    .rden_b     (pkt_q_table_l_addrs.rd_en_b),
    .wren_a     (pkt_q_table_l_addrs.wr_en_a),
    .wren_b     (pkt_q_table_l_addrs.wr_en_b),
    .q_a        (pkt_q_table_l_addrs.rd_data_a),
    .q_b        (pkt_q_table_l_addrs.rd_data_b)
);

bram_true2port #(
    .AWIDTH(PKT_Q_TABLE_AWIDTH),
    .DWIDTH(PKT_Q_TABLE_H_ADDRS_DWIDTH),
    .DEPTH(PKT_Q_TABLE_DEPTH)
)
pkt_q_table_h_addrs_bram (
    .address_a  (pkt_q_table_h_addrs.addr_a[PKT_Q_TABLE_AWIDTH-1:0]),
    .address_b  (pkt_q_table_h_addrs.addr_b[PKT_Q_TABLE_AWIDTH-1:0]),
    .clock      (pcie_clk),
    .data_a     (pkt_q_table_h_addrs.wr_data_a),
    .data_b     (pkt_q_table_h_addrs.wr_data_b),
    .rden_a     (pkt_q_table_h_addrs.rd_en_a),
    .rden_b     (pkt_q_table_h_addrs.rd_en_b),
    .wren_a     (pkt_q_table_h_addrs.wr_en_a),
    .wren_b     (pkt_q_table_h_addrs.wr_en_b),
    .q_a        (pkt_q_table_h_addrs.rd_data_a),
    .q_b        (pkt_q_table_h_addrs.rd_data_b)
);


////////////////////////////
// Descriptor Queue BRAMs //
////////////////////////////

bram_true2port #(
    .AWIDTH(DSC_Q_TABLE_AWIDTH),
    .DWIDTH(DSC_Q_TABLE_TAILS_DWIDTH),
    .DEPTH(DSC_Q_TABLE_DEPTH)
)
dsc_q_table_tails_bram (
    .address_a  (dsc_q_table_tails.addr_a[DSC_Q_TABLE_AWIDTH-1:0]),
    .address_b  (dsc_q_table_tails.addr_b[DSC_Q_TABLE_AWIDTH-1:0]),
    .clock      (pcie_clk),
    .data_a     (dsc_q_table_tails.wr_data_a),
    .data_b     (dsc_q_table_tails.wr_data_b),
    .rden_a     (dsc_q_table_tails.rd_en_a),
    .rden_b     (dsc_q_table_tails.rd_en_b),
    .wren_a     (dsc_q_table_tails.wr_en_a),
    .wren_b     (dsc_q_table_tails.wr_en_b),
    .q_a        (dsc_q_table_tails.rd_data_a),
    .q_b        (dsc_q_table_tails.rd_data_b)
);

bram_true2port #(
    .AWIDTH(DSC_Q_TABLE_AWIDTH),
    .DWIDTH(DSC_Q_TABLE_HEADS_DWIDTH),
    .DEPTH(DSC_Q_TABLE_DEPTH)
)
dsc_q_table_heads_bram (
    .address_a  (dsc_q_table_heads.addr_a[DSC_Q_TABLE_AWIDTH-1:0]),
    .address_b  (dsc_q_table_heads.addr_b[DSC_Q_TABLE_AWIDTH-1:0]),
    .clock      (pcie_clk),
    .data_a     (dsc_q_table_heads.wr_data_a),
    .data_b     (dsc_q_table_heads.wr_data_b),
    .rden_a     (dsc_q_table_heads.rd_en_a),
    .rden_b     (dsc_q_table_heads.rd_en_b),
    .wren_a     (dsc_q_table_heads.wr_en_a),
    .wren_b     (dsc_q_table_heads.wr_en_b),
    .q_a        (dsc_q_table_heads.rd_data_a),
    .q_b        (dsc_q_table_heads.rd_data_b)
);

bram_true2port #(
    .AWIDTH(DSC_Q_TABLE_AWIDTH),
    .DWIDTH(DSC_Q_TABLE_L_ADDRS_DWIDTH),
    .DEPTH(DSC_Q_TABLE_DEPTH)
)
dsc_q_table_l_addrs_bram (
    .address_a  (dsc_q_table_l_addrs.addr_a[DSC_Q_TABLE_AWIDTH-1:0]),
    .address_b  (dsc_q_table_l_addrs.addr_b[DSC_Q_TABLE_AWIDTH-1:0]),
    .clock      (pcie_clk),
    .data_a     (dsc_q_table_l_addrs.wr_data_a),
    .data_b     (dsc_q_table_l_addrs.wr_data_b),
    .rden_a     (dsc_q_table_l_addrs.rd_en_a),
    .rden_b     (dsc_q_table_l_addrs.rd_en_b),
    .wren_a     (dsc_q_table_l_addrs.wr_en_a),
    .wren_b     (dsc_q_table_l_addrs.wr_en_b),
    .q_a        (dsc_q_table_l_addrs.rd_data_a),
    .q_b        (dsc_q_table_l_addrs.rd_data_b)
);

bram_true2port #(
    .AWIDTH(DSC_Q_TABLE_AWIDTH),
    .DWIDTH(DSC_Q_TABLE_H_ADDRS_DWIDTH),
    .DEPTH(DSC_Q_TABLE_DEPTH)
)
dsc_q_table_h_addrs_bram (
    .address_a  (dsc_q_table_h_addrs.addr_a[DSC_Q_TABLE_AWIDTH-1:0]),
    .address_b  (dsc_q_table_h_addrs.addr_b[DSC_Q_TABLE_AWIDTH-1:0]),
    .clock      (pcie_clk),
    .data_a     (dsc_q_table_h_addrs.wr_data_a),
    .data_b     (dsc_q_table_h_addrs.wr_data_b),
    .rden_a     (dsc_q_table_h_addrs.rd_en_a),
    .rden_b     (dsc_q_table_h_addrs.rd_en_b),
    .wren_a     (dsc_q_table_h_addrs.wr_en_a),
    .wren_b     (dsc_q_table_h_addrs.wr_en_b),
    .q_a        (dsc_q_table_h_addrs.rd_data_a),
    .q_b        (dsc_q_table_h_addrs.rd_data_b)
);

// unused inputs
assign dsc_q_table_heads.wr_data_a = 32'bx;
assign dsc_q_table_l_addrs.wr_data_a = 32'bx;
assign dsc_q_table_h_addrs.wr_data_a = 32'bx;
assign pkt_q_table_heads.wr_data_a = 32'bx;
assign pkt_q_table_l_addrs.wr_data_a = 32'bx;
assign pkt_q_table_h_addrs.wr_data_a = 32'bx;

endmodule
