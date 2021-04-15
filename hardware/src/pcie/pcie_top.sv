`include "../constants.sv"
`include "pcie_consts.sv"

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

    input  var flit_lite_t           pcie_pkt_buf_wr_data,
    input  logic                     pcie_pkt_buf_wr_en,
    output logic                     pcie_pkt_buf_in_ready,
    output logic [F2C_RB_AWIDTH-1:0] pcie_pkt_buf_occup,
    input  var pkt_dsc_t             pcie_desc_buf_wr_data,
    input  logic                     pcie_desc_buf_wr_en,
    output logic                     pcie_desc_buf_in_ready,
    output logic [F2C_RB_AWIDTH-1:0] pcie_desc_buf_occup,

    output logic                  disable_pcie,
    output logic                  sw_reset,
    output var pdu_metadata_t     pdumeta_cpu_data,
    output logic                  pdumeta_cpu_valid,
    input  logic [9:0]            pdumeta_cnt,
    output logic [31:0]           dma_queue_full_cnt,
    output logic [31:0]           cpu_dsc_buf_full_cnt,
    output logic [31:0]           cpu_pkt_buf_full_cnt,
    output logic [31:0]           pending_prefetch_cnt,

    // status register bus
    input  logic        clk_status,
    input  logic [29:0] status_addr,
    input  logic        status_read,
    input  logic        status_write,
    input  logic [31:0] status_writedata,
    output logic [31:0] status_readdata,
    output logic        status_readdata_valid
);

logic [25:0] dsc_rb_size;
logic [25:0] pkt_rb_size;

// descriptor queue table interface signals
queue_interface_t dsc_q_table_a;
queue_interface_t dsc_q_table_b;

// bram_interface_t dsc_q_table_tails;
// bram_interface_t dsc_q_table_heads;
// bram_interface_t dsc_q_table_l_addrs;
// bram_interface_t dsc_q_table_h_addrs;

// packet queue tables interface signals
queue_interface_t pkt_q_table_a;
queue_interface_t pkt_q_table_b;
// bram_interface_t pkt_q_table_tails;
// bram_interface_t pkt_q_table_heads;
// bram_interface_t pkt_q_table_l_addrs;
// bram_interface_t pkt_q_table_h_addrs;

logic [RB_AWIDTH-1:0]    f2c_dsc_head;
logic [RB_AWIDTH-1:0]    f2c_dsc_tail;
logic [63:0]             f2c_dsc_buf_addr;
logic [RB_AWIDTH-1:0]    f2c_pkt_head;
logic [RB_AWIDTH-1:0]    f2c_pkt_tail;
logic                    f2c_pkt_q_needs_dsc;
logic [63:0]             f2c_pkt_buf_addr;

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

logic [31:0] control_regs [NB_CONTROL_REGS];

assign disable_pcie = control_regs[0][0];
assign pkt_rb_size = control_regs[0][26:1];

// Use to reset stats from software. Must also be unset from software
assign sw_reset = control_regs[0][27];

assign dsc_rb_size = control_regs[1][25:0];

typedef enum
{
    IDLE,
    WAIT_DMA,
    BRAM_DELAY_1,
    BRAM_DELAY_2,
    SWITCH_QUEUE
} state_t;
state_t state;

logic [BRAM_TABLE_IDX_WIDTH-1:0] page_idx;
assign page_idx = pcie_address_0[12 +: BRAM_TABLE_IDX_WIDTH];

always @(posedge pcie_clk) begin
    if (queue_rd_en_r) begin
        f2c_pkt_q_needs_dsc <= !pkt_q_status[f2c_rd_pkt_queue_r];
        pkt_q_status[f2c_rd_pkt_queue_r] <= 1'b1;
    end

    if (!pcie_reset_n) begin
        pkt_q_status <= 0;
    end else if (pcie_write_0 && page_idx < MAX_NB_FLOWS 
            && pcie_byteenable_0[1*REG_SIZE +:REG_SIZE] == {REG_SIZE{1'b1}})
            // Got a PCIe write to a packet queue head.
    begin
        // update queue status so that we send a descriptor next time
        pkt_q_status[page_idx] <= 1'b0;
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
        
end

always @(posedge pcie_clk)begin
    dsc_q_table_a.tails.rd_en_r <= dsc_q_table_a.tails.rd_en;
    dsc_q_table_a.tails.rd_en_r2 <= dsc_q_table_a.tails.rd_en_r;
    dsc_q_table_a.heads.rd_en_r <= dsc_q_table_a.heads.rd_en;
    dsc_q_table_a.heads.rd_en_r2 <= dsc_q_table_a.heads.rd_en_r;
    dsc_q_table_a.l_addrs.rd_en_r <= dsc_q_table_a.l_addrs.rd_en;
    dsc_q_table_a.l_addrs.rd_en_r2 <= dsc_q_table_a.l_addrs.rd_en_r;
    dsc_q_table_a.h_addrs.rd_en_r <= dsc_q_table_a.h_addrs.rd_en;
    dsc_q_table_a.h_addrs.rd_en_r2 <= dsc_q_table_a.h_addrs.rd_en_r;

    pkt_q_table_a.tails.rd_en_r <= pkt_q_table_a.tails.rd_en;
    pkt_q_table_a.tails.rd_en_r2 <= pkt_q_table_a.tails.rd_en_r;
    pkt_q_table_a.heads.rd_en_r <= pkt_q_table_a.heads.rd_en;
    pkt_q_table_a.heads.rd_en_r2 <= pkt_q_table_a.heads.rd_en_r;
    pkt_q_table_a.l_addrs.rd_en_r <= pkt_q_table_a.l_addrs.rd_en;
    pkt_q_table_a.l_addrs.rd_en_r2 <= pkt_q_table_a.l_addrs.rd_en_r;
    pkt_q_table_a.h_addrs.rd_en_r <= pkt_q_table_a.h_addrs.rd_en;
    pkt_q_table_a.h_addrs.rd_en_r2 <= pkt_q_table_a.h_addrs.rd_en_r;

    // we used the delayed wr signals for head and tail to use when there are
    // concurrent reads
    dsc_q_table_heads_wr_data_b_r <= dsc_q_table_b.heads.wr_data[RB_AWIDTH-1:0];
    dsc_q_table_heads_wr_data_b_r2 <= dsc_q_table_heads_wr_data_b_r;
    dsc_q_table_tails_wr_data_a_r <= dsc_q_table_a.tails.wr_data[RB_AWIDTH-1:0];
    dsc_q_table_tails_wr_data_a_r2 <= dsc_q_table_tails_wr_data_a_r;
    
    pkt_q_table_heads_wr_data_b_r <= pkt_q_table_b.heads.wr_data[RB_AWIDTH-1:0];
    pkt_q_table_heads_wr_data_b_r2 <= pkt_q_table_heads_wr_data_b_r;
    pkt_q_table_tails_wr_data_a_r <= pkt_q_table_a.tails.wr_data[RB_AWIDTH-1:0];
    pkt_q_table_tails_wr_data_a_r2 <= pkt_q_table_tails_wr_data_a_r;

    queue_rd_en_r <= queue_rd_en;
    f2c_rd_pkt_queue_r <= f2c_rd_pkt_queue;
end

always_comb begin
    dsc_q_table_a.tails.addr = f2c_rd_dsc_queue;
    dsc_q_table_a.heads.addr = f2c_rd_dsc_queue;
    dsc_q_table_a.l_addrs.addr = f2c_rd_dsc_queue;
    dsc_q_table_a.h_addrs.addr = f2c_rd_dsc_queue;
    pkt_q_table_a.tails.addr = f2c_rd_pkt_queue;
    pkt_q_table_a.heads.addr = f2c_rd_pkt_queue;
    pkt_q_table_a.l_addrs.addr = f2c_rd_pkt_queue;
    pkt_q_table_a.h_addrs.addr = f2c_rd_pkt_queue;

    dsc_q_table_a.tails.rd_en = 0;
    dsc_q_table_a.heads.rd_en = 0;
    dsc_q_table_a.l_addrs.rd_en = 0;
    dsc_q_table_a.h_addrs.rd_en = 0;
    pkt_q_table_a.tails.rd_en = 0;
    pkt_q_table_a.heads.rd_en = 0;
    pkt_q_table_a.l_addrs.rd_en = 0;
    pkt_q_table_a.h_addrs.rd_en = 0;

    dsc_q_table_a.tails.wr_en = 0;
    dsc_q_table_a.heads.wr_en = 0;
    dsc_q_table_a.l_addrs.wr_en = 0;
    dsc_q_table_a.h_addrs.wr_en = 0;
    pkt_q_table_a.tails.wr_en = 0;
    pkt_q_table_a.heads.wr_en = 0;
    pkt_q_table_a.l_addrs.wr_en = 0;
    pkt_q_table_a.h_addrs.wr_en = 0;

    dsc_q_table_a.tails.wr_data = new_dsc_tail;
    pkt_q_table_a.tails.wr_data = new_pkt_tail;

    if (queue_rd_en) begin
        // when reading and writing the same queue, we avoid reading the tail
        // and use the new written tail instead
        dsc_q_table_a.tails.rd_en = !tail_wr_en 
            || (f2c_rd_dsc_queue != f2c_wr_dsc_queue);
        dsc_q_table_a.heads.rd_en = 1;
        dsc_q_table_a.l_addrs.rd_en = 1;
        dsc_q_table_a.h_addrs.rd_en = 1;
        pkt_q_table_a.tails.rd_en = !tail_wr_en 
            || (f2c_rd_pkt_queue != f2c_wr_pkt_queue);
        pkt_q_table_a.heads.rd_en = 1;
        pkt_q_table_a.l_addrs.rd_en = 1;
        pkt_q_table_a.h_addrs.rd_en = 1;

        // Concurrent head write from PCIe or JTAG, we bypass the read and use
        // the new written value instead. This is done to prevent concurrent
        // read and write to the same address, which causes undefined behavior.
        if ((dsc_q_table_a.heads.addr == dsc_q_table_b.heads.addr) 
                && dsc_q_table_b.heads.wr_en) begin
            dsc_q_table_a.heads.rd_en = 0;
        end
        if ((pkt_q_table_a.heads.addr == pkt_q_table_b.heads.addr) 
                && pkt_q_table_b.heads.wr_en) begin
            pkt_q_table_a.heads.rd_en = 0;
        end
    end else if (tail_wr_en) begin
        dsc_q_table_a.tails.wr_en = 1;
        dsc_q_table_a.tails.addr = f2c_wr_dsc_queue;
        pkt_q_table_a.tails.wr_en = 1;
        pkt_q_table_a.tails.addr = f2c_wr_pkt_queue;
    end

    f2c_queue_ready = 
        dsc_q_table_a.tails.rd_en_r2   || dsc_q_table_a.heads.rd_en_r2   ||
        dsc_q_table_a.l_addrs.rd_en_r2 || dsc_q_table_a.h_addrs.rd_en_r2 ||
        pkt_q_table_a.tails.rd_en_r2   || pkt_q_table_a.heads.rd_en_r2   ||
        pkt_q_table_a.l_addrs.rd_en_r2 || pkt_q_table_a.h_addrs.rd_en_r2;

    if (dsc_q_table_a.tails.rd_en_r2) begin
        f2c_dsc_tail = dsc_q_table_a.tails.rd_data[RB_AWIDTH-1:0];
    end else begin
        f2c_dsc_tail = dsc_q_table_tails_wr_data_a_r2;
    end
    if (pkt_q_table_a.tails.rd_en_r2) begin
        f2c_pkt_tail = pkt_q_table_a.tails.rd_data[RB_AWIDTH-1:0];
    end else begin
        f2c_pkt_tail = pkt_q_table_tails_wr_data_a_r2;
    end

    if (dsc_q_table_a.heads.rd_en_r2) begin
        f2c_dsc_head = dsc_q_table_a.heads.rd_data[RB_AWIDTH-1:0];
    end else begin
        // return the delayed concurrent write
        f2c_dsc_head = dsc_q_table_heads_wr_data_b_r2;
    end
    if (pkt_q_table_a.heads.rd_en_r2) begin
        f2c_pkt_head = pkt_q_table_a.heads.rd_data[RB_AWIDTH-1:0];
    end else begin
        // return the delayed concurrent write
        f2c_pkt_head = pkt_q_table_heads_wr_data_b_r2;
    end

    f2c_dsc_buf_addr[31:0] = dsc_q_table_a.l_addrs.rd_data;
    f2c_dsc_buf_addr[63:32] = dsc_q_table_a.h_addrs.rd_data;
    f2c_pkt_buf_addr[31:0] = pkt_q_table_a.l_addrs.rd_data;
    f2c_pkt_buf_addr[63:32] = pkt_q_table_a.h_addrs.rd_data;
end

jtag_mmio_arbiter jtag_mmio_arbiter_inst (
    .pcie_clk                    (pcie_clk),
    .jtag_clk                    (clk_status),
    .pcie_reset_n                (pcie_reset_n),
    .pcie_address_0              (pcie_address_0),
    .pcie_write_0                (pcie_write_0),
    .pcie_read_0                 (pcie_read_0),
    .pcie_readdatavalid_0        (pcie_readdatavalid_0),
    .pcie_readdata_0             (pcie_readdata_0),
    .pcie_writedata_0            (pcie_writedata_0),
    .pcie_byteenable_0           (pcie_byteenable_0),
    .status_addr                 (status_addr),
    .status_read                 (status_read),
    .status_write                (status_write),
    .status_writedata            (status_writedata),
    .status_readdata             (status_readdata),
    .status_readdata_valid       (status_readdata_valid),
    .dsc_q_table_tails_addr      (dsc_q_table_b.tails.addr),
    .dsc_q_table_tails_wr_data   (dsc_q_table_b.tails.wr_data),
    .dsc_q_table_tails_rd_data   (dsc_q_table_b.tails.rd_data),
    .dsc_q_table_tails_rd_en     (dsc_q_table_b.tails.rd_en),
    .dsc_q_table_tails_wr_en     (dsc_q_table_b.tails.wr_en),
    .dsc_q_table_heads_addr      (dsc_q_table_b.heads.addr),
    .dsc_q_table_heads_wr_data   (dsc_q_table_b.heads.wr_data),
    .dsc_q_table_heads_rd_data   (dsc_q_table_b.heads.rd_data),
    .dsc_q_table_heads_rd_en     (dsc_q_table_b.heads.rd_en),
    .dsc_q_table_heads_wr_en     (dsc_q_table_b.heads.wr_en),
    .dsc_q_table_l_addrs_addr    (dsc_q_table_b.l_addrs.addr),
    .dsc_q_table_l_addrs_wr_data (dsc_q_table_b.l_addrs.wr_data),
    .dsc_q_table_l_addrs_rd_data (dsc_q_table_b.l_addrs.rd_data),
    .dsc_q_table_l_addrs_rd_en   (dsc_q_table_b.l_addrs.rd_en),
    .dsc_q_table_l_addrs_wr_en   (dsc_q_table_b.l_addrs.wr_en),
    .dsc_q_table_h_addrs_addr    (dsc_q_table_b.h_addrs.addr),
    .dsc_q_table_h_addrs_wr_data (dsc_q_table_b.h_addrs.wr_data),
    .dsc_q_table_h_addrs_rd_data (dsc_q_table_b.h_addrs.rd_data),
    .dsc_q_table_h_addrs_rd_en   (dsc_q_table_b.h_addrs.rd_en),
    .dsc_q_table_h_addrs_wr_en   (dsc_q_table_b.h_addrs.wr_en),
    .pkt_q_table_tails_addr      (pkt_q_table_b.tails.addr),
    .pkt_q_table_tails_wr_data   (pkt_q_table_b.tails.wr_data),
    .pkt_q_table_tails_rd_data   (pkt_q_table_b.tails.rd_data),
    .pkt_q_table_tails_rd_en     (pkt_q_table_b.tails.rd_en),
    .pkt_q_table_tails_wr_en     (pkt_q_table_b.tails.wr_en),
    .pkt_q_table_heads_addr      (pkt_q_table_b.heads.addr),
    .pkt_q_table_heads_wr_data   (pkt_q_table_b.heads.wr_data),
    .pkt_q_table_heads_rd_data   (pkt_q_table_b.heads.rd_data),
    .pkt_q_table_heads_rd_en     (pkt_q_table_b.heads.rd_en),
    .pkt_q_table_heads_wr_en     (pkt_q_table_b.heads.wr_en),
    .pkt_q_table_l_addrs_addr    (pkt_q_table_b.l_addrs.addr),
    .pkt_q_table_l_addrs_wr_data (pkt_q_table_b.l_addrs.wr_data),
    .pkt_q_table_l_addrs_rd_data (pkt_q_table_b.l_addrs.rd_data),
    .pkt_q_table_l_addrs_rd_en   (pkt_q_table_b.l_addrs.rd_en),
    .pkt_q_table_l_addrs_wr_en   (pkt_q_table_b.l_addrs.wr_en),
    .pkt_q_table_h_addrs_addr    (pkt_q_table_b.h_addrs.addr),
    .pkt_q_table_h_addrs_wr_data (pkt_q_table_b.h_addrs.wr_data),
    .pkt_q_table_h_addrs_rd_data (pkt_q_table_b.h_addrs.rd_data),
    .pkt_q_table_h_addrs_rd_en   (pkt_q_table_b.h_addrs.rd_en),
    .pkt_q_table_h_addrs_wr_en   (pkt_q_table_b.h_addrs.wr_en),
    .control_regs                (control_regs)
);

fpga2cpu_pcie f2c_inst (
    .clk                    (pcie_clk),
    .rst                    (!pcie_reset_n),
    .pkt_buf_wr_data        (pcie_pkt_buf_wr_data),
    .pkt_buf_wr_en          (pcie_pkt_buf_wr_en),
    .pkt_buf_in_ready       (pcie_pkt_buf_in_ready),
    .pkt_buf_occup          (pcie_pkt_buf_occup),
    .desc_buf_wr_data       (pcie_desc_buf_wr_data),
    .desc_buf_wr_en         (pcie_desc_buf_wr_en),
    .desc_buf_in_ready      (pcie_desc_buf_in_ready),
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
    .cpu_dsc_buf_full_cnt   (cpu_dsc_buf_full_cnt),
    .cpu_pkt_buf_full_cnt   (cpu_pkt_buf_full_cnt),
    .pending_prefetch_cnt   (pending_prefetch_cnt)
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
    .address_a  (pkt_q_table_a.tails.addr[PKT_Q_TABLE_AWIDTH-1:0]),
    .address_b  (pkt_q_table_b.tails.addr[PKT_Q_TABLE_AWIDTH-1:0]),
    .clock      (pcie_clk),
    .data_a     (pkt_q_table_a.tails.wr_data),
    .data_b     (pkt_q_table_b.tails.wr_data),
    .rden_a     (pkt_q_table_a.tails.rd_en),
    .rden_b     (pkt_q_table_b.tails.rd_en),
    .wren_a     (pkt_q_table_a.tails.wr_en),
    .wren_b     (pkt_q_table_b.tails.wr_en),
    .q_a        (pkt_q_table_a.tails.rd_data),
    .q_b        (pkt_q_table_b.tails.rd_data)
);

bram_true2port #(
    .AWIDTH(PKT_Q_TABLE_AWIDTH),
    .DWIDTH(PKT_Q_TABLE_HEADS_DWIDTH),
    .DEPTH(PKT_Q_TABLE_DEPTH)
)
pkt_q_table_heads_bram (
    .address_a  (pkt_q_table_a.heads.addr[PKT_Q_TABLE_AWIDTH-1:0]),
    .address_b  (pkt_q_table_b.heads.addr[PKT_Q_TABLE_AWIDTH-1:0]),
    .clock      (pcie_clk),
    .data_a     (pkt_q_table_a.heads.wr_data),
    .data_b     (pkt_q_table_b.heads.wr_data),
    .rden_a     (pkt_q_table_a.heads.rd_en),
    .rden_b     (pkt_q_table_b.heads.rd_en),
    .wren_a     (pkt_q_table_a.heads.wr_en),
    .wren_b     (pkt_q_table_b.heads.wr_en),
    .q_a        (pkt_q_table_a.heads.rd_data),
    .q_b        (pkt_q_table_b.heads.rd_data)
);

bram_true2port #(
    .AWIDTH(PKT_Q_TABLE_AWIDTH),
    .DWIDTH(PKT_Q_TABLE_L_ADDRS_DWIDTH),
    .DEPTH(PKT_Q_TABLE_DEPTH)
)
pkt_q_table_l_addrs_bram (
    .address_a  (pkt_q_table_a.l_addrs.addr[PKT_Q_TABLE_AWIDTH-1:0]),
    .address_b  (pkt_q_table_b.l_addrs.addr[PKT_Q_TABLE_AWIDTH-1:0]),
    .clock      (pcie_clk),
    .data_a     (pkt_q_table_a.l_addrs.wr_data),
    .data_b     (pkt_q_table_b.l_addrs.wr_data),
    .rden_a     (pkt_q_table_a.l_addrs.rd_en),
    .rden_b     (pkt_q_table_b.l_addrs.rd_en),
    .wren_a     (pkt_q_table_a.l_addrs.wr_en),
    .wren_b     (pkt_q_table_b.l_addrs.wr_en),
    .q_a        (pkt_q_table_a.l_addrs.rd_data),
    .q_b        (pkt_q_table_b.l_addrs.rd_data)
);

bram_true2port #(
    .AWIDTH(PKT_Q_TABLE_AWIDTH),
    .DWIDTH(PKT_Q_TABLE_H_ADDRS_DWIDTH),
    .DEPTH(PKT_Q_TABLE_DEPTH)
)
pkt_q_table_h_addrs_bram (
    .address_a  (pkt_q_table_a.h_addrs.addr[PKT_Q_TABLE_AWIDTH-1:0]),
    .address_b  (pkt_q_table_b.h_addrs.addr[PKT_Q_TABLE_AWIDTH-1:0]),
    .clock      (pcie_clk),
    .data_a     (pkt_q_table_a.h_addrs.wr_data),
    .data_b     (pkt_q_table_b.h_addrs.wr_data),
    .rden_a     (pkt_q_table_a.h_addrs.rd_en),
    .rden_b     (pkt_q_table_b.h_addrs.rd_en),
    .wren_a     (pkt_q_table_a.h_addrs.wr_en),
    .wren_b     (pkt_q_table_b.h_addrs.wr_en),
    .q_a        (pkt_q_table_a.h_addrs.rd_data),
    .q_b        (pkt_q_table_b.h_addrs.rd_data)
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
    .address_a  (dsc_q_table_a.tails.addr[DSC_Q_TABLE_AWIDTH-1:0]),
    .address_b  (dsc_q_table_b.tails.addr[DSC_Q_TABLE_AWIDTH-1:0]),
    .clock      (pcie_clk),
    .data_a     (dsc_q_table_a.tails.wr_data),
    .data_b     (dsc_q_table_b.tails.wr_data),
    .rden_a     (dsc_q_table_a.tails.rd_en),
    .rden_b     (dsc_q_table_b.tails.rd_en),
    .wren_a     (dsc_q_table_a.tails.wr_en),
    .wren_b     (dsc_q_table_b.tails.wr_en),
    .q_a        (dsc_q_table_a.tails.rd_data),
    .q_b        (dsc_q_table_b.tails.rd_data)
);

bram_true2port #(
    .AWIDTH(DSC_Q_TABLE_AWIDTH),
    .DWIDTH(DSC_Q_TABLE_HEADS_DWIDTH),
    .DEPTH(DSC_Q_TABLE_DEPTH)
)
dsc_q_table_heads_bram (
    .address_a  (dsc_q_table_a.heads.addr[DSC_Q_TABLE_AWIDTH-1:0]),
    .address_b  (dsc_q_table_b.heads.addr[DSC_Q_TABLE_AWIDTH-1:0]),
    .clock      (pcie_clk),
    .data_a     (dsc_q_table_a.heads.wr_data),
    .data_b     (dsc_q_table_b.heads.wr_data),
    .rden_a     (dsc_q_table_a.heads.rd_en),
    .rden_b     (dsc_q_table_b.heads.rd_en),
    .wren_a     (dsc_q_table_a.heads.wr_en),
    .wren_b     (dsc_q_table_b.heads.wr_en),
    .q_a        (dsc_q_table_a.heads.rd_data),
    .q_b        (dsc_q_table_b.heads.rd_data)
);

bram_true2port #(
    .AWIDTH(DSC_Q_TABLE_AWIDTH),
    .DWIDTH(DSC_Q_TABLE_L_ADDRS_DWIDTH),
    .DEPTH(DSC_Q_TABLE_DEPTH)
)
dsc_q_table_l_addrs_bram (
    .address_a  (dsc_q_table_a.l_addrs.addr[DSC_Q_TABLE_AWIDTH-1:0]),
    .address_b  (dsc_q_table_b.l_addrs.addr[DSC_Q_TABLE_AWIDTH-1:0]),
    .clock      (pcie_clk),
    .data_a     (dsc_q_table_a.l_addrs.wr_data),
    .data_b     (dsc_q_table_b.l_addrs.wr_data),
    .rden_a     (dsc_q_table_a.l_addrs.rd_en),
    .rden_b     (dsc_q_table_b.l_addrs.rd_en),
    .wren_a     (dsc_q_table_a.l_addrs.wr_en),
    .wren_b     (dsc_q_table_b.l_addrs.wr_en),
    .q_a        (dsc_q_table_a.l_addrs.rd_data),
    .q_b        (dsc_q_table_b.l_addrs.rd_data)
);

bram_true2port #(
    .AWIDTH(DSC_Q_TABLE_AWIDTH),
    .DWIDTH(DSC_Q_TABLE_H_ADDRS_DWIDTH),
    .DEPTH(DSC_Q_TABLE_DEPTH)
)
dsc_q_table_h_addrs_bram (
    .address_a  (dsc_q_table_a.h_addrs.addr[DSC_Q_TABLE_AWIDTH-1:0]),
    .address_b  (dsc_q_table_b.h_addrs.addr[DSC_Q_TABLE_AWIDTH-1:0]),
    .clock      (pcie_clk),
    .data_a     (dsc_q_table_a.h_addrs.wr_data),
    .data_b     (dsc_q_table_b.h_addrs.wr_data),
    .rden_a     (dsc_q_table_a.h_addrs.rd_en),
    .rden_b     (dsc_q_table_b.h_addrs.rd_en),
    .wren_a     (dsc_q_table_a.h_addrs.wr_en),
    .wren_b     (dsc_q_table_b.h_addrs.wr_en),
    .q_a        (dsc_q_table_a.h_addrs.rd_data),
    .q_b        (dsc_q_table_b.h_addrs.rd_data)
);

// unused inputs
assign dsc_q_table_a.heads.wr_data = 32'bx;
assign dsc_q_table_a.l_addrs.wr_data = 32'bx;
assign dsc_q_table_a.h_addrs.wr_data = 32'bx;
assign pkt_q_table_a.heads.wr_data = 32'bx;
assign pkt_q_table_a.l_addrs.wr_data = 32'bx;
assign pkt_q_table_a.h_addrs.wr_data = 32'bx;

endmodule
