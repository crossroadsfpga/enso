`include "./my_struct_s.sv"
module ring_buffer(
    input logic clk,
    input logic rst,

    // write side
    input  flit_lite_t            wr_data,
    input  logic [PDU_AWIDTH-1:0] wr_addr,
    input  logic                  wr_en,
    output logic [PDU_AWIDTH-1:0] wr_base_addr,
    output logic                  wr_base_addr_valid,
    output logic                  almost_full,
    input  logic                  update_valid,
    input  logic [PDU_AWIDTH-1:0] update_size,

    // fetch side
    input  logic [PDU_AWIDTH-1:0] rd_addr,
    input  logic                  rd_en,
    output logic                  rd_valid,
    output logic [511:0]          rd_data,

    // dma signals
    output logic                     dma_start,
    output logic [PDU_AWIDTH-1:0]    dma_size,
    output logic [PDU_AWIDTH-1:0]    dma_base_addr,
    output logic [APP_IDX_WIDTH-1:0] dma_queue,
    input  logic                     dma_done
);

parameter PDU_DEPTH = 512;
parameter PDU_AWIDTH = ($clog2(PDU_DEPTH));

localparam THRESHOLD = 64;
localparam MAX_SLOT = PDU_DEPTH - THRESHOLD;

typedef enum
{
    IDLE,
    WAIT
} state_t;
state_t state;

logic [PDU_AWIDTH-1:0] head;
logic [PDU_AWIDTH-1:0] tail;
logic [PDU_AWIDTH-1:0] free_slot;
logic [PDU_AWIDTH-1:0] occupied_slot;
logic [PDU_AWIDTH-1:0] last_sop_wr_addr;
logic rd_en_r;
flit_lite_t rd_flit_lite;
logic [PDU_AWIDTH-1:0] rd_addr_r1;
logic [PDU_AWIDTH-1:0] rd_addr_r2;
logic [PDU_AWIDTH-1:0] last_tail;
logic wrap;


localparam DESC_RBUF_DEPTH = PDU_DEPTH/2; // packets have a minimum of 2 flits

// for every packet inserted in the ring buffer, we keep its queue id and size
typedef struct packed {
    logic [APP_IDX_WIDTH-1:0] queue_id;
    logic [PDU_AWIDTH-1:0] size; // in number of flits
} pkt_desc_t;
localparam DESC_RBUF_DWIDTH = $bits(pkt_desc_t);
localparam DESC_RBUF_AWIDTH = $clog2(DESC_RBUF_DEPTH);

typedef logic [DESC_RBUF_AWIDTH-1:0] desc_pointer_t;

// descriptors ring buffer
pkt_desc_t desc_wr_data;
desc_pointer_t desc_rd_addr;
logic desc_rd_en;
logic desc_rd_en_r;
logic desc_rd_en_r2;
desc_pointer_t desc_wr_addr;
logic desc_wr_en;
pkt_desc_t desc_rd_data;

desc_pointer_t desc_tail;
desc_pointer_t desc_head;
desc_pointer_t nb_descs;

// We save packet descriptors to BRAM but always keep a current_desc, next_desc
// and last_desc in registers. The last_desc is the last descriptor that we
// inserted and may be susceptible to changes as new packets from the same queue
// come in. The current_desc is the descriptor that should be consumed now. The
// next_desc is prefetched from BRAM and will become current_desc once
// current_desc is consumed.
pkt_desc_t current_desc;
pkt_desc_t next_desc;
pkt_desc_t last_desc;

assign wr_base_addr = tail;
assign nb_descs = desc_tail - desc_head;

always @(posedge clk) begin
    desc_wr_en <= 0;
    desc_rd_en <= 0;
    if (rst) begin
        desc_tail <= 0;
        desc_rd_en_r <= 0;
        desc_rd_en_r2 <= 0;
        last_sop_wr_addr <= 0;
    end else begin
        if (wr_en) begin
            automatic flit_lite_t flit_lite = wr_data;
            if (flit_lite.sop) begin
                automatic pdu_hdr_t pdu_hdr = flit_lite.data;

                desc_tail <= desc_tail + 1'b1;

                // We merge DMAs to the same queue when we already have at least
                // three packets in the queue. This avoids that we modify a
                // request that is being consumed. We also only merge requests
                // when they do not wrap around in the buffer
                if (nb_descs == 0) begin
                    current_desc.queue_id <= pdu_hdr.queue_id;
                    current_desc.size <= pdu_hdr.pdu_flit;
                end else if (nb_descs == 1) begin
                    next_desc.queue_id <= pdu_hdr.queue_id;
                    next_desc.size <= pdu_hdr.pdu_flit;
                end else if (nb_descs == 2) begin
                    last_desc.queue_id <= pdu_hdr.queue_id;
                    last_desc.size <= pdu_hdr.pdu_flit;      
                end else if (pdu_hdr.queue_id == last_desc.queue_id && 
                             last_sop_wr_addr < wr_addr) begin
                    // merge descriptors
                    last_desc.size <= last_desc.size + pdu_hdr.pdu_flit;
                    desc_tail <= desc_tail; // avoid incrementing the tail
                end else begin
                    // save last_desc to bram
                    desc_wr_data <= last_desc;
                    desc_wr_addr <= desc_tail - 1;
                    desc_wr_en <= 1;

                    last_desc.queue_id <= pdu_hdr.queue_id;
                    last_desc.size <= pdu_hdr.pdu_flit;
                end
                
                last_sop_wr_addr <= wr_addr;
            end
        end

        // update current_desc and next_desc or read next_desc from BRAM
        if (dma_start && nb_descs > 0) begin
            current_desc <= next_desc;
            if (nb_descs == 2) begin
                next_desc <= last_desc;
            end else if (nb_descs > 2) begin
                // intercept write to the next_desc's address
                if (desc_wr_en && desc_wr_addr == (desc_head + 1)) begin
                    next_desc <= desc_wr_data;
                end else begin
                    desc_rd_en <= 1;
                    desc_rd_addr <= desc_head;
                end
            end
        end

        desc_rd_en_r <= desc_rd_en;
        desc_rd_en_r2 <= desc_rd_en_r;

        // update next_desc with value read from BRAM
        if (desc_rd_en_r2) begin
            next_desc <= desc_rd_data;
        end
    end
end

// Always have at least one slot not occupied.
assign free_slot = PDU_DEPTH - occupied_slot - 1;
assign occupied_slot = wrap ? (last_tail - head + tail) : (tail - head);

assign wrap = (tail < head);

// update tail
always @(posedge clk) begin
    if (rst) begin
        tail <= 0;
        almost_full <= 0;
        last_tail <= 0;
        wr_base_addr_valid <= 0;
    end else begin
        if (update_valid) begin
            if (tail + update_size < MAX_SLOT) begin
                tail <= tail + update_size;
            end else begin
                tail <= 0;
                last_tail <= tail + update_size;
            end
        end
        wr_base_addr_valid <= update_valid;

        if (free_slot >= 2*THRESHOLD) begin
            almost_full <= 0;
        end else begin
            almost_full <= 1;
        end
    end
end


// update head
always @(posedge clk) begin
    if (rst) begin
        head <= 0;
    end else begin
        // One block has been read
        if (rd_valid & rd_flit_lite.eop) begin
            if (rd_addr_r2 + 1 >= MAX_SLOT) begin
                head <= 0;
            end else begin
                head <= rd_addr_r2 + 1;
            end
        end
    end
end

// dma state machine
always @(posedge clk) begin
    dma_start <= 0;
    if (rst) begin
        state <= IDLE;
        dma_size <= 0;
        dma_base_addr <= 0;
        desc_head <= 0;
        dma_queue <= 0;
    end else begin
        case (state)
            IDLE: begin
                // We have data to send
                if ((desc_head != desc_tail) && (occupied_slot > 0)) begin
                    dma_size <= current_desc.size;
                    dma_queue <= current_desc.queue_id;

                    desc_head <= desc_head + 1'b1;
                    dma_start <= 1;
                    dma_base_addr <= head;
                    state <= WAIT;
                end
            end
            WAIT: begin
                // we are assuming that dma_done will only activate after at
                // least 3 clock cycles
                if (dma_done) begin
                    state <= IDLE;
                end
            end
            default: state <= IDLE;
        endcase
    end
end

// two cycles delay
always @(posedge clk) begin
    rd_en_r <= rd_en;
    rd_valid <= rd_en_r;
    rd_addr_r1 <= rd_addr;
    rd_addr_r2 <= rd_addr_r1;
end

assign rd_data = rd_flit_lite.data;

bram_simple2port #(
    .AWIDTH(PDU_AWIDTH),
    .DWIDTH(514),
    .DEPTH(PDU_DEPTH)
)
pdu_buffer (
    .clock      (clk),
    .data       (wr_data),
    .rdaddress  (rd_addr),
    .rden       (rd_en),
    .wraddress  (wr_addr),
    .wren       (wr_en),
    .q          (rd_flit_lite)
);

bram_simple2port #(
    .AWIDTH(DESC_RBUF_AWIDTH),
    .DWIDTH(DESC_RBUF_DWIDTH),
    .DEPTH(DESC_RBUF_DEPTH)
)
pkt_descs (
    .clock      (clk),
    .data       (desc_wr_data),
    .rdaddress  (desc_rd_addr),
    .rden       (desc_rd_en),
    .wraddress  (desc_wr_addr),
    .wren       (desc_wr_en),
    .q          (desc_rd_data)
);

endmodule
