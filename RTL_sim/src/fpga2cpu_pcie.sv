
`include "./my_struct_s.sv"

module fpga2cpu_pcie (
    input clk,
    input rst,

    // write to FPGA ring buffer.
    input  flit_lite_t               wr_data,
    input  logic [PDU_AWIDTH-1:0]    wr_addr,
    input  logic                     wr_en,
    output logic [PDU_AWIDTH-1:0]    wr_base_addr,
    output logic                     wr_base_addr_valid,
    output logic                     almost_full,
    input  logic                     update_valid,
    input  logic [PDU_AWIDTH-1:0]    update_size,

    // CPU ring buffer signals
    input  logic [RB_AWIDTH-1:0]     head,
    input  logic [RB_AWIDTH-1:0]     tail,
    input  logic [63:0]              kmem_addr,
    input  logic                     queue_ready,
    output logic [RB_AWIDTH-1:0]     out_tail,
    output logic                     dma_done,
    output logic [APP_IDX_WIDTH-1:0] dma_queue,
    output logic                     dma_start,
    input  logic [30:0]              rb_size,

    // Write to Write data mover
    input  logic                     wrdm_desc_ready,
    output logic                     wrdm_desc_valid,
    output logic [173:0]             wrdm_desc_data,

    // Write-data-mover read data
    output logic [511:0]             frb_readdata,
    output logic                     frb_readvalid,
    input  logic [PDU_AWIDTH-1:0]    frb_address,
    input  logic                     frb_read,

    // counters
    output logic [31:0]              dma_queue_full_cnt,
    output logic [31:0]              cpu_buf_full_cnt
);

localparam EP_BASE_ADDR = 32'h0004_0000;
localparam DONE_ID = 8'hFE;

pcie_desc_t data_desc;
pcie_desc_t data_desc_low;
pcie_desc_t data_desc_high;
pcie_desc_t done_desc;
logic [63:0] cpu_data_addr;
logic [63:0] cpu_data_addr_low;
logic [63:0] cpu_data_addr_high;
logic [31:0] ep_data_addr_high;
logic [31:0] data_base_addr;

logic [RB_AWIDTH-1:0] free_slot;
logic [RB_AWIDTH-1:0] new_tail;

logic [PDU_AWIDTH-1:0] dma_size_r; // in 512 bits, or 16 DWORD.
logic [PDU_AWIDTH-1:0] dma_size_r_low; // in 512 bits, or 16 DWORD.
logic [PDU_AWIDTH-1:0] dma_size_r_high; // in 512 bits, or 16 DWORD.
// logic [31-PDU_AWIDTH-4:0] desc_padding; // 4 is for 16 DWORD
logic [31-RB_AWIDTH:0] tail_padding; // 4 is for 16 DWORD
logic [PDU_AWIDTH-1:0] frb_address_r1;
logic [PDU_AWIDTH-1:0] frb_address_r2;

logic wrdm_desc_ready_r1;
logic wrdm_desc_ready_r2;

assign tail_padding = 0;

typedef enum
{
    IDLE,
    WAIT_QUEUE_STATE,
    DESC,
    DESC_WRAP,
    DONE
} state_t;

state_t state;

logic [PDU_AWIDTH-1:0]  dma_size;
logic [PDU_AWIDTH-1:0]  dma_base_addr;

// CPU side addr
assign cpu_data_addr = kmem_addr + 64*tail + 64; // the global reg

// The base addr of fpga side ring buffer. BRAM starts with an offset
assign data_base_addr = EP_BASE_ADDR + (RB_BRAM_OFFSET + dma_base_addr) << 6;

// Rounding case
assign dma_size_r_low = rb_size - tail;
assign dma_size_r_high = dma_size_r - rb_size + tail; // dma_size_r - dma_size_r_low
assign cpu_data_addr_low = cpu_data_addr;
assign cpu_data_addr_high = kmem_addr + (1<<6); // always starts from the beginning
assign ep_data_addr_high = data_base_addr + {dma_size_r_low, 6'b0};

assign done_desc = '{
    func_nb: 0,
    desc_id: DONE_ID,
    app_spec: 0,
    reserved: 0,
    single_src: 0,
    immediate: 1,
    nb_dwords: 18'd1,
    dst_addr: kmem_addr,
    saddr_data: {32'h0, tail_padding, new_tail} // data
};

assign data_desc = '{
    func_nb: 0,
    desc_id: 0,
    app_spec: 0,
    reserved: 0,
    single_src: 0,
    immediate: 0,
    // dma_size_r is in #512-bit flits, we shift 4 bits to be in #dwords
    nb_dwords: {dma_size_r, 4'h0},
    dst_addr: cpu_data_addr,
    saddr_data: {32'h0, data_base_addr}
};

// When the data wraps around the ring buffer we use two DMAs: one for the first
// part (until the end of the buffer) and the other for the second part. For
// such case, we use the following two write data mover descriptors.
assign data_desc_low = '{
    func_nb: 0,
    desc_id: 0,
    app_spec: 0,
    reserved: 0,
    single_src: 0,
    immediate: 0,
    nb_dwords: {dma_size_r_low, 4'h0},
    dst_addr: cpu_data_addr_low,
    saddr_data: {32'h0, data_base_addr}
};

assign data_desc_high = '{
    func_nb: 0,
    desc_id: 0,
    app_spec: 0,
    reserved: 0,
    single_src: 0,
    immediate: 0,
    nb_dwords: {dma_size_r_high, 4'h0},
    dst_addr: cpu_data_addr_high,
    saddr_data: {32'h0, ep_data_addr_high}
};

// Always have at least one slot not occupied
assign free_slot = (tail >= head) ? (rb_size-tail+head-1) : (head-tail-1);

// We need two transfers. iIf it is equal, we only need one transfer and to
// round the fpga_tail
assign wrap = tail + dma_size_r > rb_size;

assign new_tail = (tail + dma_size_r >= rb_size) ? 
                        (tail + dma_size_r - rb_size) :
                        (tail + dma_size_r);

// two cycle delay
always @(posedge clk)begin
    frb_address_r1 <= frb_address;
    frb_address_r2 <= frb_address_r1;
end

always @ (posedge clk) begin
    // wrdm_desc_ready has a 3-cycle latency, wrdm_desc_ready_r2 is active, we
    // can write in the following cycle
    wrdm_desc_ready_r1 <= wrdm_desc_ready;
    wrdm_desc_ready_r2 <= wrdm_desc_ready_r1;
end

// FSM
always @ (posedge clk) begin
    wrdm_desc_valid <= 0;
    if (rst) begin
        state <= IDLE;
        out_tail <= 0;
        dma_done <= 0;
        dma_queue_full_cnt <= 0;
        cpu_buf_full_cnt <= 0;
    end else begin
        automatic logic dma_ctrl_ready = wrdm_desc_ready && wrdm_desc_ready_r2;
        case (state)
            IDLE: begin
                dma_done <= 0;
                wrdm_desc_valid <= 0;
                if (dma_start) begin
                    state <= WAIT_QUEUE_STATE;
                    dma_size_r <= dma_size;
                end
            end
            WAIT_QUEUE_STATE: begin
                if (queue_ready) begin
                    state <= DESC;
                end
            end
            DESC: begin
                // Have enough space for this transfer.
                if (dma_ctrl_ready && free_slot >= dma_size_r) begin
                    // Need wrap around
                    if (wrap) begin
                        wrdm_desc_valid <= 1;
                        wrdm_desc_data <= data_desc_low;
                        state <= DESC_WRAP;
                    end else begin
                        wrdm_desc_valid <= 1;
                        wrdm_desc_data <= data_desc;
                        state <= DONE;
                    end
                end
                if (!dma_ctrl_ready) begin
                    dma_queue_full_cnt <= dma_queue_full_cnt + 1;
                end
                if (free_slot < dma_size_r) begin
                    cpu_buf_full_cnt <= cpu_buf_full_cnt + 1;
                end
            end
            DESC_WRAP: begin
                // the previous request is consumed.
                if (dma_ctrl_ready) begin
                    wrdm_desc_valid <= 1;
                    wrdm_desc_data <= data_desc_high;
                    state <= DONE;
                end else begin
                    dma_queue_full_cnt <= dma_queue_full_cnt + 1;
                end
            end
            DONE: begin
                if (dma_ctrl_ready) begin
                    wrdm_desc_valid <= 1;
                    wrdm_desc_data <= done_desc;

                    // update tail
                    out_tail <= new_tail;
                    dma_done <= 1;
                    state <= IDLE;
                end else begin
                    dma_queue_full_cnt <= dma_queue_full_cnt + 1;
                end
            end
            default: state <= IDLE;
        endcase
    end
end

ring_buffer #(
    .PDU_DEPTH(PDU_DEPTH),
    .PDU_AWIDTH(PDU_AWIDTH)
)
ring_buffer_inst (
    .clk            (clk),
    .rst            (rst),
    .wr_data        (wr_data),
    .wr_addr        (wr_addr),
    .wr_en          (wr_en),
    .wr_base_addr   (wr_base_addr),
    .wr_base_addr_valid(wr_base_addr_valid),
    .almost_full    (almost_full),
    .update_valid   (update_valid),
    .update_size    (update_size),
    .rd_addr        (frb_address),
    .rd_en          (frb_read),
    .rd_valid       (frb_readvalid),
    .rd_data        (frb_readdata),
    .dma_start      (dma_start),
    .dma_size       (dma_size),
    .dma_base_addr  (dma_base_addr),
    .dma_queue      (dma_queue),
    .dma_done       (dma_done)
);
endmodule
