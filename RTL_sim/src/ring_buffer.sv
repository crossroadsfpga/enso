`include "./my_struct_s.sv"
module ring_buffer(
clk,               
rst,           
wr_data,           
wr_addr,          
wr_en,  
wr_base_addr,  
wr_base_addr_valid, // TODO(sadok) check if we need this
almost_full,          
update_valid,
update_size,

rd_addr,
rd_en,
rd_valid,
rd_data,

dma_start,
dma_size,
dma_base_addr,
dma_done
);

parameter PDU_DEPTH = 512;
parameter PDU_AWIDTH = ($clog2(PDU_DEPTH));

localparam THRESHOLD = 64;    
localparam MAX_SLOT = PDU_DEPTH - THRESHOLD;

input  logic         clk;               
input  logic         rst;           

//write side
input  flit_lite_t wr_data;
input  logic [PDU_AWIDTH-1:0]  wr_addr;          
input  logic         wr_en;  
output logic [PDU_AWIDTH-1:0]  wr_base_addr;          
output logic         wr_base_addr_valid;
output logic         almost_full;          
input  logic         update_valid;
input  logic [PDU_AWIDTH-1:0]  update_size;

//fetch side
input  logic [PDU_AWIDTH-1:0]  rd_addr;
input  logic         rd_en;
output logic         rd_valid;
output logic [511:0] rd_data;

//dma signals
output logic         dma_start;
output logic [PDU_AWIDTH-1:0]  dma_size;
output logic [PDU_AWIDTH-1:0]  dma_base_addr;
input  logic         dma_done;

typedef enum
{
    IDLE,
    WAIT,
    DELAY_1,
    DELAY_2,
    DELAY_3
} state_t;
state_t state;

logic [PDU_AWIDTH-1:0] head;
logic [PDU_AWIDTH-1:0] tail;
logic [PDU_AWIDTH-1:0] free_slot;
logic [PDU_AWIDTH-1:0] occupied_slot;
logic rd_en_r;
flit_lite_t rd_flit_lite;
logic [PDU_AWIDTH-1:0]  rd_addr_r1;
logic [PDU_AWIDTH-1:0]  rd_addr_r2;
logic [PDU_AWIDTH-1:0] last_tail;
logic wrap;
logic [PDU_AWIDTH-1:0] send_slot;

assign wr_base_addr = tail;

//Always have at least one slot not occupied.
assign free_slot = PDU_DEPTH - occupied_slot - 1;
assign occupied_slot = wrap ? (last_tail-head+tail) : (tail-head);
assign send_slot = wrap ? (last_tail-head) : (tail-head);

assign wrap = (tail < head);

//update tail
always@(posedge clk)begin
    if(rst)begin
        tail <= 0;
        almost_full <= 0;
        last_tail <= 0;
        wr_base_addr_valid <= 0;
    end else begin
        if(update_valid)begin
            if(tail + update_size < MAX_SLOT)begin
                tail <= tail + update_size; 
            end else begin
                tail <= 0;
                last_tail <= tail + update_size;
            end
        end
        wr_base_addr_valid <= update_valid;

        if(free_slot >= 2*THRESHOLD)begin
            almost_full <= 0;
        end else begin
            almost_full <= 1;
        end
    end
end


//udpate head
always@(posedge clk)begin
    if(rst)begin
        head <= 0;
    end else begin
        //One block has been rd
        if(rd_valid & rd_flit_lite.eop)begin
            if(rd_addr_r2 + 1 >= MAX_SLOT)begin
                head <= 0;
            end else begin
                head <= rd_addr_r2 + 1;
            end
        end
    end
end

//dma state machine
always@(posedge clk)begin
    if(rst)begin
        state <= IDLE;
        dma_start <= 0;
        dma_size <= 0;
        dma_base_addr <= 0;
    end else begin
        case(state)
            IDLE:begin
                //We have data to send
                if (occupied_slot > 0) begin
                    dma_start <= 1;
                    dma_size <= send_slot;
                    dma_base_addr <= head;
                    state <= WAIT;
                end 
            end
            WAIT:begin
                dma_start <= 0;
                if(dma_done)begin
                    // state <= IDLE;
                    state <= DELAY_1; // FIXME(sadok) I'm introducing a delay
                                      // after DMA is done to read the BRAM. A
                                      // better strategy is to somehow prefetch
                                      // the BRAM. Once this is done, should get
                                      // rid of the DELAY state and go straight
                                      // to IDLE
                end
            end
            DELAY_1:begin
                state <= DELAY_2;
            end
            DELAY_2:begin
                state <= DELAY_3;
            end
            DELAY_3:begin
                state <= IDLE;
            end
            default: state <= IDLE;
        endcase
    end
end

//two cycles delay
always@(posedge clk)begin
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

endmodule
