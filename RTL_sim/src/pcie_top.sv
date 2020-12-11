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
    output pdu_metadata_t         pdumeta_cpu_data,
    output logic                  pdumeta_cpu_valid,
    input  logic [9:0]            pdumeta_cnt,
    output logic [31:0]           dma_queue_full_cnt,
    output logic [31:0]           cpu_buf_full_cnt,
    output logic [31:0]           pcie_max_rb,

    // status register bus
    input  logic        clk_status,
    input  logic [29:0] status_addr,
    input  logic        status_read,
    input  logic        status_write,
    input  logic [31:0] status_writedata,
    output logic [31:0] status_readdata,
    output logic        status_readdata_valid
);

localparam C2F_HEAD_OFFSET = 5 * REG_SIZE;

// JTAG signals
logic [29:0]  status_addr_r;
logic         status_read_r;
logic         status_write_r;
logic [31:0]  status_writedata_r;
logic [STAT_AWIDTH-1:0] status_addr_sel_r;

logic [31:0] control_reg;
logic [31:0] control_reg_r;

// internal signals
pcie_block_t pcie_block;
logic cpu_reg_region;
logic cpu_reg_region_r1;
logic cpu_reg_region_r2;
logic [25:0] rb_size;
logic internal_update_valid;
logic [APP_IDX_WIDTH-1:0] page_idx;

typedef struct
{
   logic [APP_IDX_WIDTH-1:0] addr_a;
   logic [APP_IDX_WIDTH-1:0] addr_b;
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

// packet queue table
bram_interface_t pkt_q_table_tails;
bram_interface_t pkt_q_table_heads;
bram_interface_t pkt_q_table_l_addrs;
bram_interface_t pkt_q_table_h_addrs;

logic [APP_IDX_WIDTH-1:0] q_table_addr_jtag;
logic [APP_IDX_WIDTH-1:0] q_table_addr_pcie;
logic [APP_IDX_WIDTH-1:0] q_table_addr_jtag_rd_pending;
logic [APP_IDX_WIDTH-1:0] q_table_addr_pcie_rd_pending;

logic [1:0] q_table_jtag;
logic [1:0] q_table_pcie;
logic [1:0] q_table_jtag_rd_pending;
logic [1:0] last_rd_b_table;
logic [1:0] last_rd_b_table_r;
logic [1:0] last_rd_b_table_r2;

logic [PKT_Q_TABLE_TAILS_DWIDTH-1:0] pkt_q_table_rd_data_b;
logic [PKT_Q_TABLE_TAILS_DWIDTH-1:0] pkt_q_table_rd_data_b_jtag;

logic q_table_rd_en_jtag;
logic q_table_data_rd_en_pcie;
logic q_table_addr_rd_en_pcie;
logic q_table_jtag_rd_set;

logic q_table_data_jtag_rd_set;
logic q_table_addr_jtag_rd_set;
logic q_table_rd_pending_from_jtag;
logic q_table_pcie_rd_set;

logic rd_en_r;
logic rd_en_r2;

logic pcie_bram_rd;
logic pcie_bram_rd_r;
logic pcie_bram_rd_r2;

logic q_table_rd_data_b_pcie_ready;
logic q_table_rd_data_b_jtag_ready;
logic q_table_rd_data_b_ready_from_jtag;

logic [RB_AWIDTH-1:0]    f2c_head;
logic [RB_AWIDTH-1:0]    f2c_tail;
logic [63:0]             f2c_kmem_addr;
// logic [511:0]            frb_readdata;
// logic                    frb_readvalid;
// logic [PDU_AWIDTH-1:0]   frb_address;
// logic                    frb_read;

logic pcie_reg_read;

logic [31:0]   c2f_head;
logic [31:0]   c2f_tail;
logic [63:0]                c2f_kmem_addr;
logic [63:0]                c2f_head_addr;

logic                     f2c_queue_ready;
logic                     tail_wr_en;
logic                     queue_rd_en;
logic [APP_IDX_WIDTH-1:0] f2c_rd_queue;
logic [APP_IDX_WIDTH-1:0] f2c_wr_queue;
logic [RB_AWIDTH-1:0]     pkt_q_table_heads_wr_data_b_r;
logic [RB_AWIDTH-1:0]     pkt_q_table_heads_wr_data_b_r2;
logic [RB_AWIDTH-1:0]     hold_tail;
logic [RB_AWIDTH-1:0]     new_tail;

// JTAG
always@(posedge clk_status) begin
    status_addr_r       <= status_addr;
    status_addr_sel_r   <= status_addr[29:30-STAT_AWIDTH];

    status_read_r       <= status_read;
    status_write_r      <= status_write;
    status_writedata_r  <= status_writedata;

    status_readdata_valid <= 0;
    q_table_rd_en_jtag <= 0;

    if (!pcie_reset_n) begin
        control_reg <= 0;
    end

    if (q_table_rd_data_b_ready_from_jtag && q_table_rd_pending_from_jtag) begin
        status_readdata <= pkt_q_table_rd_data_b_jtag;
        status_readdata_valid <= 1;
        q_table_rd_pending_from_jtag <= 0;
    end

    if (status_addr_sel_r == PCIE & status_read_r) begin
        if (status_addr_r[0 +:JTAG_ADDR_WIDTH] == 0) begin
            status_readdata <= control_reg;
            status_readdata_valid <= 1;
        end else begin
            q_table_jtag <= {status_addr_r[0 +:JTAG_ADDR_WIDTH]-1}[1:0];
            q_table_addr_jtag <= {status_addr_r[0 +:JTAG_ADDR_WIDTH]-1}[
                2 +:APP_IDX_WIDTH];
            q_table_rd_pending_from_jtag <= 1;
            q_table_rd_en_jtag <= 1;
        end
    end

    if (status_addr_sel_r == PCIE & status_write_r) begin
        if (status_addr_r[0 +:JTAG_ADDR_WIDTH] == 0) begin
            control_reg <= status_writedata_r;
        end
    end
end

assign disable_pcie = control_reg_r[0];
assign rb_size = control_reg_r[26:1];

// Avoid short path/long path timing problem.
always @(posedge pcie_clk) begin
    control_reg_r <= control_reg;
end

// we choose the right set of registers based on the page (the page's index LSB
// is at bit 12 of the memory address, the MSB depends on the number of apps we
// support)
assign page_idx = pcie_address_0[12 +: APP_IDX_WIDTH];

assign q_table_jtag_rd_set= q_table_data_jtag_rd_set & q_table_addr_jtag_rd_set;
assign q_table_rd_data_b_pcie_ready = rd_en_r2 & pcie_bram_rd_r2;

// We share a single BRAM port among: PCIe writes, PCIe reads and JTAG reads.
// We serve simultaneous requests following this priority. That way, we only
// serve PCIe reads when there are no PCIe writes and we only serve JTAG reads
// when there are no PCIe writes or reads
always@(posedge pcie_clk) begin
    pkt_q_table_tails.wr_en_b <= 0;
    pkt_q_table_heads.wr_en_b <= 0;
    pkt_q_table_l_addrs.wr_en_b <= 0;
    pkt_q_table_h_addrs.wr_en_b <= 0;

    pkt_q_table_tails.rd_en_b <= 0;
    pkt_q_table_heads.rd_en_b <= 0;
    pkt_q_table_l_addrs.rd_en_b <= 0;
    pkt_q_table_h_addrs.rd_en_b <= 0;

    last_rd_b_table <= 0;

    // TODO(sadok) we assume PCIe reads only come after the previous completes,
    // If that is not true, we may need to keep a queue of requests
    if (pcie_reg_read) begin
        q_table_addr_pcie_rd_pending <= page_idx;
        q_table_pcie_rd_set <= 1;
    end

    // We assign the JTAG read enable and the address to pending registers.
    // These are read opportunistically, when there is no operation from the
    // PCIe. This lets us share the same BRAM port for PCIe and JTAG
    if (q_table_data_rd_en_pcie) begin
        q_table_jtag_rd_pending <= q_table_pcie;
        q_table_data_jtag_rd_set <= 1;
    end
    if (q_table_addr_rd_en_pcie) begin
        q_table_addr_jtag_rd_pending <= q_table_addr_pcie;
        q_table_addr_jtag_rd_set <= 1;
    end

    q_table_rd_data_b_jtag_ready <= 0;

    if (!pcie_reset_n) begin
        q_table_pcie_rd_set <= 0;
        q_table_data_jtag_rd_set <= 0;
        q_table_addr_jtag_rd_set <= 0;
        pkt_q_table_rd_data_b <= 0;
        c2f_kmem_addr <= 0;
    end else if (pcie_write_0) begin
        // update BRAMs
        // if (pcie_byteenable_0[0*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
        //     pkt_q_table_tails.wr_data_b <= pcie_writedata_0[0*32 +: 32];
        //     pkt_q_table_tails.wr_en_b <= 1;
        //     pkt_q_table_tails.addr_b <= page_idx;
        // end
        if (pcie_byteenable_0[1*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
            pkt_q_table_heads.wr_data_b <= pcie_writedata_0[1*32 +: 32];
            pkt_q_table_heads.wr_en_b <= 1;
            pkt_q_table_heads.addr_b <= page_idx;
        end
        if (pcie_byteenable_0[2*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
            pkt_q_table_l_addrs.wr_data_b <= pcie_writedata_0[2*32 +: 32];
            pkt_q_table_l_addrs.wr_en_b <= 1;
            pkt_q_table_l_addrs.addr_b <= page_idx;
        end
        if (pcie_byteenable_0[3*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
            pkt_q_table_h_addrs.wr_data_b <= pcie_writedata_0[3*32 +: 32];
            pkt_q_table_h_addrs.wr_en_b <= 1;
            pkt_q_table_h_addrs.addr_b <= page_idx;
        end

        // CPU -> FPGA
        // TODO(sadok) This assumes a single control queue. We also need to add
        //             TX data queues eventually
        if (pcie_byteenable_0[4*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
            c2f_tail <= pcie_writedata_0[4*32 +: 32];
        end
        // if (pcie_byteenable_0[5*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
        //     c2f_head <= pcie_writedata_0[5*32 +: 32];
        // end
        if (pcie_byteenable_0[6*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
            c2f_kmem_addr[31:0] <= pcie_writedata_0[6*32 +: 32];
        end
        if (pcie_byteenable_0[7*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}}) begin
            c2f_kmem_addr[63:32] <= pcie_writedata_0[7*32 +: 32];
        end
    end else if (q_table_pcie_rd_set) begin
        q_table_pcie_rd_set <= 0;

        pkt_q_table_tails.rd_en_b <= 1;
        pkt_q_table_tails.addr_b <= q_table_addr_pcie_rd_pending;

        pkt_q_table_heads.rd_en_b <= 1;
        pkt_q_table_heads.addr_b <= q_table_addr_pcie_rd_pending;

        pkt_q_table_l_addrs.rd_en_b <= 1;
        pkt_q_table_l_addrs.addr_b <= q_table_addr_pcie_rd_pending;

        pkt_q_table_h_addrs.rd_en_b <= 1;
        pkt_q_table_h_addrs.addr_b <= q_table_addr_pcie_rd_pending;
    end else if (q_table_jtag_rd_set) begin
        q_table_data_jtag_rd_set <= 0;
        q_table_addr_jtag_rd_set <= 0;
        last_rd_b_table <= q_table_jtag_rd_pending;
        case (q_table_jtag_rd_pending)
            2'd0: begin
                pkt_q_table_tails.rd_en_b <= 1;
                pkt_q_table_tails.addr_b <= q_table_addr_jtag_rd_pending;
            end
            2'd1: begin
                pkt_q_table_heads.rd_en_b <= 1;
                pkt_q_table_heads.addr_b <= q_table_addr_jtag_rd_pending;
            end
            2'd2: begin
                pkt_q_table_l_addrs.rd_en_b <= 1;
                pkt_q_table_l_addrs.addr_b <= q_table_addr_jtag_rd_pending;
            end
            2'd3: begin
                pkt_q_table_h_addrs.rd_en_b <= 1;
                pkt_q_table_h_addrs.addr_b <= q_table_addr_jtag_rd_pending;
            end
        endcase
    end

    last_rd_b_table_r <= last_rd_b_table;
    last_rd_b_table_r2 <= last_rd_b_table_r;

    rd_en_r <= pkt_q_table_tails.rd_en_b | pkt_q_table_heads.rd_en_b |
        pkt_q_table_l_addrs.rd_en_b | pkt_q_table_h_addrs.rd_en_b;
    rd_en_r2 <= rd_en_r;

    // signals if this is a PCIe (1) or a JTAG (0) read
    pcie_bram_rd <= q_table_pcie_rd_set;
    pcie_bram_rd_r <= pcie_bram_rd;
    pcie_bram_rd_r2 <= pcie_bram_rd_r;

    // JTAG read is ready
    if (rd_en_r2 & !pcie_bram_rd_r2) begin
        case (last_rd_b_table_r2)
            2'd0: begin
                pkt_q_table_rd_data_b <= pkt_q_table_tails.rd_data_b;
            end
            2'd1: begin
                pkt_q_table_rd_data_b <= pkt_q_table_heads.rd_data_b;
            end
            2'd2: begin
                pkt_q_table_rd_data_b <= pkt_q_table_l_addrs.rd_data_b;
            end
            2'd3: begin
                pkt_q_table_rd_data_b <= pkt_q_table_h_addrs.rd_data_b;
            end
        endcase
        q_table_rd_data_b_jtag_ready <= 1;
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

// the first slot in f2c_kmem_addr is used as the "global reg" includes the
// C2F_head
assign c2f_head_addr = f2c_kmem_addr + C2F_HEAD_OFFSET;

always@(posedge pcie_clk)begin
    pkt_q_table_tails.rd_en_a_r <= pkt_q_table_tails.rd_en_a;
    pkt_q_table_tails.rd_en_a_r2 <= pkt_q_table_tails.rd_en_a_r;
    pkt_q_table_heads.rd_en_a_r <= pkt_q_table_heads.rd_en_a;
    pkt_q_table_heads.rd_en_a_r2 <= pkt_q_table_heads.rd_en_a_r;
    pkt_q_table_l_addrs.rd_en_a_r <= pkt_q_table_l_addrs.rd_en_a;
    pkt_q_table_l_addrs.rd_en_a_r2 <= pkt_q_table_l_addrs.rd_en_a_r;
    pkt_q_table_h_addrs.rd_en_a_r <= pkt_q_table_h_addrs.rd_en_a;
    pkt_q_table_h_addrs.rd_en_a_r2 <= pkt_q_table_h_addrs.rd_en_a_r;

    pkt_q_table_heads_wr_data_b_r <= pkt_q_table_heads.wr_data_b;
    pkt_q_table_heads_wr_data_b_r2 <= pkt_q_table_heads.wr_data_b;

    if (tail_wr_en) begin
        hold_tail <= new_tail;
    end
end

always_comb begin
    pkt_q_table_tails.addr_a = f2c_rd_queue;
    pkt_q_table_heads.addr_a = f2c_rd_queue;
    pkt_q_table_l_addrs.addr_a = f2c_rd_queue;
    pkt_q_table_h_addrs.addr_a = f2c_rd_queue;

    pkt_q_table_tails.rd_en_a = 0;
    pkt_q_table_heads.rd_en_a = 0;
    pkt_q_table_l_addrs.rd_en_a = 0;
    pkt_q_table_h_addrs.rd_en_a = 0;

    pkt_q_table_tails.wr_en_a = 0;
    pkt_q_table_heads.wr_en_a = 0;
    pkt_q_table_l_addrs.wr_en_a = 0;
    pkt_q_table_h_addrs.wr_en_a = 0;

    pkt_q_table_tails.wr_data_a = new_tail;

    if (queue_rd_en) begin
        // when reading and writing the same queue, we avoid reading the tail
        // and instead hold its value in hold_tail
        pkt_q_table_tails.rd_en_a = !tail_wr_en || (f2c_rd_queue != f2c_wr_queue);
        pkt_q_table_heads.rd_en_a = 1;
        pkt_q_table_l_addrs.rd_en_a = 1;
        pkt_q_table_h_addrs.rd_en_a = 1;

        // Concurrent head write from PCIe or JTAG, we bypass the read and use
        // the new written value instead. This is done to prevent concurrent
        // read and write to the same address, which causes undefined behavior.
        if ((pkt_q_table_heads.addr_a == pkt_q_table_heads.addr_b) 
                && pkt_q_table_heads.wr_en_b) begin
            pkt_q_table_heads.rd_en_a = 0;
        end
    end else if (tail_wr_en) begin
        pkt_q_table_tails.wr_en_a = 1;
        pkt_q_table_tails.addr_a = f2c_wr_queue;
    end

    f2c_queue_ready = pkt_q_table_tails.rd_en_a_r2 || pkt_q_table_heads.rd_en_a_r2 
        || pkt_q_table_l_addrs.rd_en_a_r2 || pkt_q_table_h_addrs.rd_en_a_r2;

    if (pkt_q_table_tails.rd_en_a_r2) begin
        f2c_tail = pkt_q_table_tails.rd_data_a;
    end else begin
        f2c_tail = hold_tail;
    end

    if (pkt_q_table_heads.rd_en_a_r2) begin
        f2c_head = pkt_q_table_heads.rd_data_a;
    end else begin
        // return the delayed concurrent write
        f2c_head = pkt_q_table_heads_wr_data_b_r2;
    end

    f2c_kmem_addr[31:0] = pkt_q_table_l_addrs.rd_data_a;
    f2c_kmem_addr[63:32] = pkt_q_table_h_addrs.rd_data_a;
end

// PDU_BUFFER
// CPU side read MUX, first RB_BRAM_OFFSET*512 bits are regs, the rest is BRAM
always@(posedge pcie_clk) begin
    if (!pcie_reset_n) begin
        pcie_readdata_0 <= 0;
        pcie_readdatavalid_0 <= 0;
    end else begin // if (cpu_reg_region_r2) begin
        pcie_readdata_0 <= {
            256'h0, c2f_kmem_addr, c2f_head, c2f_tail,
            pkt_q_table_h_addrs.rd_data_b, pkt_q_table_l_addrs.rd_data_b,
            pkt_q_table_heads.rd_data_b, pkt_q_table_tails.rd_data_b
        };
        pcie_readdatavalid_0 <= q_table_rd_data_b_pcie_ready;
    end
    // else begin
    //     pcie_readdata_0 <= frb_readdata;
    //     pcie_readdatavalid_0 <= frb_readvalid;
    // end
end

assign cpu_reg_region = pcie_address_0[PCIE_ADDR_WIDTH-1:6] < RB_BRAM_OFFSET;

assign pcie_reg_read = cpu_reg_region & pcie_read_0;
// assign frb_read = !cpu_reg_region & pcie_read_0;
// assign frb_address = pcie_address_0[PCIE_ADDR_WIDTH-1:6] - RB_BRAM_OFFSET;

// two cycle read delay
always@(posedge pcie_clk) begin
    cpu_reg_region_r1 <= cpu_reg_region;
    cpu_reg_region_r2 <= cpu_reg_region_r1;
end

// explicitly truncating outputs
logic [31:0] pkt_q_table_pcie_out;
logic [31:0] pkt_q_table_addr_pcie_out;

assign q_table_pcie = pkt_q_table_pcie_out[1:0];
assign q_table_addr_pcie = pkt_q_table_addr_pcie_out[APP_IDX_WIDTH-1:0];

// PCIe and JTAG are in different clock domains, we use the following
// dual-clocked FIFOs to transfer data between the two
dc_fifo_reg_core  jtag_to_pcie_data_fifo (
    .wrclock               (clk_status), // jtag clock
    .wrreset_n             (pcie_reset_n),
    .rdclock               (pcie_clk),
    .rdreset_n             (pcie_reset_n),
    .avalonst_sink_valid   (q_table_rd_en_jtag),
    .avalonst_sink_data    ({ 30'b0, q_table_jtag }),
    .avalonst_source_valid (q_table_data_rd_en_pcie),
    .avalonst_source_data  (pkt_q_table_pcie_out)
);
dc_fifo_reg_core  jtag_to_pcie_addr_fifo (
    .wrclock               (clk_status), // jtag clock
    .wrreset_n             (pcie_reset_n),
    .rdclock               (pcie_clk),
    .rdreset_n             (pcie_reset_n),
    .avalonst_sink_valid   (q_table_rd_en_jtag),
    .avalonst_sink_data    ({ {{32-APP_IDX_WIDTH}{1'b0}}, q_table_addr_jtag }),
    .avalonst_source_valid (q_table_addr_rd_en_pcie),
    .avalonst_source_data  (pkt_q_table_addr_pcie_out)
);
dc_fifo_reg_core  pcie_to_jtag_fifo (
    .wrclock               (pcie_clk),
    .wrreset_n             (pcie_reset_n),
    .rdclock               (clk_status), // jtag clock
    .rdreset_n             (pcie_reset_n),
    .avalonst_sink_valid   (q_table_rd_data_b_jtag_ready),
    .avalonst_sink_data    (pkt_q_table_rd_data_b),
    .avalonst_source_valid (q_table_rd_data_b_ready_from_jtag),
    .avalonst_source_data  (pkt_q_table_rd_data_b_jtag)
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
    .in_head                (f2c_head),
    .in_tail                (f2c_tail),
    .in_kmem_addr           (f2c_kmem_addr),
    .rd_queue               (f2c_rd_queue),
    .queue_ready            (f2c_queue_ready),
    .out_tail               (new_tail),
    .wr_queue               (f2c_wr_queue),
    .queue_rd_en            (queue_rd_en),
    .tail_wr_en             (tail_wr_en),
    .rb_size                ({5'b0, rb_size}),
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
    .dma_queue_full_cnt     (dma_queue_full_cnt),
    .cpu_buf_full_cnt       (cpu_buf_full_cnt),
    .max_rb                 (pcie_max_rb)
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
    .address_a  (pkt_q_table_tails.addr_a),
    .address_b  (pkt_q_table_tails.addr_b),
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
    .address_a  (pkt_q_table_heads.addr_a),
    .address_b  (pkt_q_table_heads.addr_b),
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
    .address_a  (pkt_q_table_l_addrs.addr_a),
    .address_b  (pkt_q_table_l_addrs.addr_b),
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
    .address_a  (pkt_q_table_h_addrs.addr_a),
    .address_b  (pkt_q_table_h_addrs.addr_b),
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

endmodule
