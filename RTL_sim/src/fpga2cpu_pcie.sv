
`include "./my_struct_s.sv"

module fpga2cpu_pcie (
    input clk,
    input rst,

    //write to FPGA ring buffer.
    input  flit_lite_t              wr_data,
    input  logic [PDU_AWIDTH-1:0]   wr_addr,         
    input  logic                    wr_en,  
    output logic [PDU_AWIDTH-1:0]   wr_base_addr,    
    output logic                    wr_base_addr_valid,
    output logic                    almost_full,          
    input  logic                    update_valid,
    input  logic [PDU_AWIDTH-1:0]   update_size,

    //CPU ring buffer signals
    input  logic [RB_AWIDTH-1:0]    head,
    output logic [RB_AWIDTH-1:0]    tail,
    input  logic [63:0]             kmem_addr,

    //Write to Write data mover
    input  logic                    wrdm_desc_ready,           
    output logic                    wrdm_desc_valid,           
    output logic [173:0]            wrdm_desc_data,            

    //Write-data-mover read data 
    output logic [511:0]            frb_readdata,             
    output logic                    frb_readvalid,        
    input  logic [PDU_AWIDTH-1:0]   frb_address,              
    input  logic                    frb_read                 

	);

localparam EP_BASE_ADDR = 32'h0004_0000;
localparam DONE_ID = 8'hFE;

logic [173:0] data_desc;
logic [173:0] data_desc_low;
logic [173:0] data_desc_high;
logic [173:0] done_desc;
logic [63:0] cpu_data_addr;
logic [63:0] cpu_data_addr_low;
logic [63:0] cpu_data_addr_high;
logic [31:0] ep_data_addr_high;
logic [31:0] data_base_addr;

logic [RB_AWIDTH-1:0] free_slot;
logic [RB_AWIDTH-1:0] new_tail;

logic [PDU_AWIDTH-1:0] dma_size_r; //in 512 bits, or 16 DWORD.
logic [PDU_AWIDTH-1:0] dma_size_r_low; //in 512 bits, or 16 DWORD.
logic [PDU_AWIDTH-1:0] dma_size_r_high; //in 512 bits, or 16 DWORD.
logic [31-PDU_AWIDTH-4:0] desc_padding; //4 is for 16 DWORD
logic [31-RB_AWIDTH:0] tail_padding; //4 is for 16 DWORD
logic [PDU_AWIDTH-1:0]   frb_address_r1;              
logic [PDU_AWIDTH-1:0]   frb_address_r2;              

typedef enum
{
    IDLE,
    DESC,
    DESC_WRAP,
    DONE,
    WAIT
} state_t;

state_t state;

logic                   dma_start;
logic [PDU_AWIDTH-1:0]  dma_size;
logic [PDU_AWIDTH-1:0]  dma_base_addr;
logic                   dma_done;

//CPU side addr
assign cpu_data_addr = kmem_addr + 64*tail + 64; //the global reg

//The base addr of fpga side ring buffer. 
assign data_base_addr = EP_BASE_ADDR + (1+dma_base_addr) << 6;


assign desc_padding = 0;
//data region is the BRAM part. Note there is an offset.
assign data_desc = {14'h0,desc_padding,dma_size_r,4'b0,cpu_data_addr,32'h0,data_base_addr};

//First 16 dword is for registers
//14'h function number, 
//8'h descriptor ID,
//3'b application specific,
//1'b single destion, 
//1'b1 immediate, 
//18'd number of dwords up to 1MB. 
//64'b destionation PCIe address
//64'b src Avalon-MM address or immediate data.
assign done_desc = {14'h0,DONE_ID,3'b0,1'b0,1'b0,1'b1,18'd1,kmem_addr,32'h0,tail_padding,new_tail};

//Rounding case
assign dma_size_r_low = RB_DEPTH - tail;
assign dma_size_r_high = dma_size_r - RB_DEPTH + tail;//dma_size_r - dma_size_r_low
assign cpu_data_addr_low = cpu_data_addr;
assign cpu_data_addr_high = kmem_addr + (1 <<6); //always starts from the beginning
assign ep_data_addr_high = data_base_addr + {dma_size_r_low,6'b0};

assign data_desc_low = {14'h0,desc_padding,dma_size_r_low,4'b0,cpu_data_addr_low,32'h0,data_base_addr};
assign data_desc_high = {14'h0,desc_padding,dma_size_r_high,4'b0,cpu_data_addr_high,32'h0,ep_data_addr_high};


//Always have at least one slot not occupied.
//assign free_slot = (tail >= head) ? (RB_DEPTH - tail + head -1) : (head - tail -1);

//We need two transfter. if it is =, we only need one transfer and round the fpga_tail.
assign wrap = tail + dma_size_r > RB_DEPTH;

assign new_tail = (tail+dma_size_r >= RB_DEPTH) ? (tail+dma_size_r-RB_DEPTH) : (tail+dma_size_r);

//two cycle delay
always@(posedge clk)begin
    frb_address_r1 <= frb_address;
    frb_address_r2 <= frb_address_r1;
end

//FSM
always@(posedge clk)begin
    if(rst)begin
        state <= IDLE;
        wrdm_desc_valid <= 0;
        tail <= 0;
        dma_done <= 0;
        free_slot <= 0;
    end else begin
        case(state)
            IDLE:begin
                dma_done <= 0;
                wrdm_desc_valid <= 0;
                if (dma_start) begin
                    state <= DESC;
                    dma_size_r <= dma_size;
                    //use register instead of comb
                    if(tail >= head)begin
                        free_slot <= RB_DEPTH - tail + head -1;
                    end else begin
                        free_slot <= head - tail -1;
                    end 
                end                
            end
            DESC:begin
                //Have enough space for this transfer.
                if(free_slot >= dma_size_r) begin
                    //Need wrap around
                    if(wrap) begin
                        wrdm_desc_valid <= 1;
                        wrdm_desc_data <= data_desc_low;
                        state <= DESC_WRAP;
                    end else begin
                        wrdm_desc_valid <= 1;
                        wrdm_desc_data <= data_desc;
                        state <= DONE;
                    end
                end
            end
            DESC_WRAP:begin
                //the previous request is consumed.
                if(wrdm_desc_ready)begin
                    wrdm_desc_valid <= 1;
                    wrdm_desc_data <= data_desc_high;
                    state <= DONE;
                end   
            end
            DONE:begin
                if(wrdm_desc_ready) begin
                    wrdm_desc_valid <= 1;
                    wrdm_desc_data <= done_desc;
                    state <= WAIT;
                 
                    //update tail
                    tail <= new_tail;
                    //if(tail+dma_size_r >= RB_DEPTH)begin
                    //    tail <= tail+dma_size_r-RB_DEPTH;
                    //end else begin
                    //    tail <= tail + dma_size_r;
                    //end
                end
            end
            WAIT:begin
                //the previous request is consumed
                if(wrdm_desc_ready)begin
                    wrdm_desc_valid <= 0;
                end
                //the last data is fetched
                if(frb_readvalid & (frb_address_r2 == (dma_base_addr + dma_size_r -1))) begin
                    dma_done <= 1;
                    state <= IDLE;
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
    .dma_done       (dma_done)
);
endmodule
