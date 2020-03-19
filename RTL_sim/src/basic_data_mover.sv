`include "./my_struct_s.sv"
module basic_data_mover (
		input  logic         clk,                    //        clk.clk
		input  logic         rst,                    //        rst.reset
        input  logic         meta_valid,
        input  metadata_t    meta_data,
        output logic         meta_ready,  
		output logic [PKTBUF_AWIDTH-1:0]   pkt_buffer_address,     // pkt_buffer.address
		output logic         pkt_buffer_read,       //           .read
		input  logic         pkt_buffer_readvalid,       //           .read
		input flit_t         pkt_buffer_readdata,   //           .writedata
        output logic [PKT_AWIDTH-1:0]   emptylist_in_data,
        output logic                    emptylist_in_valid,
        input  logic                    emptylist_in_ready,
        input  logic         disable_pcie,
        output logic         pcie_pkt_sop,
        output logic         pcie_pkt_eop,
        output logic         pcie_pkt_valid,
        output logic [511:0] pcie_pkt_data,
        output logic [5:0]   pcie_pkt_empty,
        input  logic         pcie_pkt_ready,  
        input  logic         pcie_pkt_almost_full,  
        output  logic        pcie_meta_valid,
        output  metadata_t   pcie_meta_data,
        input logic          pcie_meta_ready,   
        output logic         eth_pkt_sop,
        output logic         eth_pkt_eop,
        output logic         eth_pkt_valid,
        output logic [511:0] eth_pkt_data,
        output logic [5:0]   eth_pkt_empty,
        input  logic         eth_pkt_ready,  
        input  logic         eth_pkt_almost_full
	);

logic [PKT_AWIDTH-1:0] pktID;    
logic [4:0] flits;

logic [4:0] flits_cnt;
logic [2:0] pkt_flags;
logic [2:0] pkt_flags_r1;
logic [2:0] pkt_flags_r2;
logic [2:0] pkt_flags_r3;
logic [2:0] pkt_flags_r4;
logic [2:0] pkt_flags_r5;
logic [2:0] pkt_flags_r6;
logic [2:0] pkt_flags_r7;
logic [2:0] pkt_flags_r8;
logic [2:0] pkt_flags_r9;
logic [2:0] pkt_flags_r10;
logic [2:0] pkt_flags_r11;
logic [2:0] pkt_flags_r12;
logic [2:0] pkt_flags_r13;


logic first_ready;
logic middle_ready;
logic almost_full;

logic [15:0] statable_cnt;

typedef enum
{
    WAIT_STATABLE,
    INIT,
    IDLE,
    FIRST,
    MIDDLE
} state_t;


state_t state;

assign meta_ready = ((state == IDLE) | first_ready | middle_ready) & !almost_full;
assign first_ready = (state == FIRST) & ((pkt_flags == PKT_DROP)|(flits==1));
assign middle_ready = (state == MIDDLE) & (flits_cnt == flits-1);
assign almost_full = eth_pkt_almost_full | pcie_pkt_almost_full;

//Quick and Dirty tweak for PDU flag
always@(posedge clk)begin
    if(rst)begin
        pcie_meta_valid <= 0;
    end else begin
        pcie_meta_valid <= 0;
        if(meta_valid & meta_ready & (meta_data.pkt_flags == PKT_PCIE) & !disable_pcie)begin
            pcie_meta_valid <= 1;
        end
    end
    pcie_meta_data <= meta_data;
end

//capture the meta_data
always@(posedge clk)begin
    if(rst)begin
        pktID <= 0;
        flits <= 0;
        pkt_flags <= 0;
    end else begin
        if(meta_valid & meta_ready)begin
            pktID <= meta_data.pktID;
            flits <= meta_data.flits;
            if(disable_pcie)begin
                pkt_flags <= PKT_ETH;
            end else begin
                pkt_flags <= meta_data.pkt_flags;
            end
        end
    end
end

//DEBUG
always@(posedge clk)begin
    if(!emptylist_in_ready & emptylist_in_valid)begin
        $display("PKT emptylist is full!");
        $finish;
    end
    `ifdef DEBUG
    if(meta_valid & meta_ready)begin
        $display("pkt:%d,length:%d,flag:%d",
            meta_data.pktID,meta_data.len,meta_data.pkt_flags);
    end
    `endif
end


//Read Logic
always@(posedge clk)begin
    if(rst)begin
        flits_cnt <= 0;
        state <= WAIT_STATABLE;
        emptylist_in_data <= 0;
        emptylist_in_valid <= 0;
        statable_cnt <= 0;
        pkt_buffer_read <= 0;
    end else begin
        case(state)
            WAIT_STATABLE:begin
                statable_cnt <= statable_cnt + 1;
                if(statable_cnt == 50)begin
                    state <= INIT;
                    emptylist_in_valid <= 1'b1;
                end
            end
            //Init the emptylist
            INIT:begin
                if(emptylist_in_valid & emptylist_in_ready)begin
                    emptylist_in_data <= emptylist_in_data + 1'b1;
                    if (emptylist_in_data == PKT_NUM-1)begin
                        emptylist_in_valid <= 1'b0;
                        state <= IDLE;
                        $display("Finish PKT emptylist init");
                    end
                end
            end
            IDLE:begin
                //clear
                pkt_buffer_address <= 0;
                pkt_buffer_read <= 0;
                flits_cnt <= 0;
                emptylist_in_valid <= 1'b0;
                if(meta_valid & !almost_full)begin
                //Quick and dirty pdu, skip pkt 3
                //if(meta_valid & !almost_full & meta_data.pktID!=3)begin
                    state <= FIRST;
                end
            end
            FIRST:begin
                emptylist_in_valid <= 0;
                if(pkt_flags == PKT_DROP)begin
                    pkt_buffer_read <= 0;
                    emptylist_in_valid <= 1'b1;
                    emptylist_in_data <= pktID;
                    if(meta_valid & !almost_full)begin
                        state <= FIRST;
                    end else begin
                        state <= IDLE;
                    end
                end else begin
                    pkt_buffer_read <= 1;
                    pkt_buffer_address <= (pktID << 5);
                    //last flit
                    if(flits == 1) begin
                        emptylist_in_valid <= 1'b1;
                        emptylist_in_data <= pktID;

                        if(meta_valid & !almost_full)begin
                            state <= FIRST;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        state <= MIDDLE;
                        flits_cnt <= flits_cnt + 1;
                    end
                end
            end
            MIDDLE:begin
                emptylist_in_valid <= 1'b0;
                //last flit
                if(flits_cnt == flits - 1) begin
                    pkt_buffer_address <= pkt_buffer_address + 1;
                    flits_cnt <= 0;

                    emptylist_in_valid <= 1'b1;
                    emptylist_in_data <= pktID;

                    //wait
                    if(meta_valid & !almost_full)begin
                        state <= FIRST;
                    end else begin
                        state <= IDLE;
                    end
                end else begin
                    pkt_buffer_read <= 1;
                    pkt_buffer_address <= pkt_buffer_address + 1;
                    flits_cnt <= flits_cnt + 1;
                end
            end
        endcase            
    end
end

//On-chip memory read latency is 12 cycles.
always@(posedge clk)begin
    if(rst)begin
        pkt_flags_r1  <= 0;
        pkt_flags_r2  <= 0;
        pkt_flags_r3  <= 0;
        pkt_flags_r4  <= 0;
        pkt_flags_r5  <= 0;
        pkt_flags_r6  <= 0;
        pkt_flags_r7  <= 0;
        pkt_flags_r8  <= 0;
        pkt_flags_r9  <= 0;
        pkt_flags_r10 <= 0;
        pkt_flags_r11 <= 0;
        pkt_flags_r12 <= 0;
        pkt_flags_r13 <= 0;
    end else begin
        pkt_flags_r1  <= pkt_flags;
        pkt_flags_r2  <= pkt_flags_r1;
        pkt_flags_r3  <= pkt_flags_r2;
        pkt_flags_r4  <= pkt_flags_r3;
        pkt_flags_r5  <= pkt_flags_r4;
        pkt_flags_r6  <= pkt_flags_r5;
        pkt_flags_r7  <= pkt_flags_r6;
        pkt_flags_r8  <= pkt_flags_r7;
        pkt_flags_r9  <= pkt_flags_r8;
        pkt_flags_r10 <= pkt_flags_r9;
        pkt_flags_r11 <= pkt_flags_r10;
        pkt_flags_r12 <= pkt_flags_r11;
        pkt_flags_r13 <= pkt_flags_r12;
    end
end

//Write logic
//No backpressure yet
always@(posedge clk)begin
    if(rst)begin
        eth_pkt_valid <= 0;
        pcie_pkt_valid <= 0;
    end else begin
        pcie_pkt_data <= pkt_buffer_readdata.data;
        pcie_pkt_sop <= 0;
        pcie_pkt_eop <= 0;
        pcie_pkt_empty <= 0;
        pcie_pkt_valid <= 0;

        eth_pkt_data <= pkt_buffer_readdata.data;
        eth_pkt_sop <= 0;
        eth_pkt_eop <= 0;
        eth_pkt_empty <= 0;
        eth_pkt_valid <= 0;

        if (pkt_buffer_readvalid) begin
            //send check_pkt to data_fifo
            `ifdef SIM
            if(pkt_flags_r2 == PKT_PCIE) begin
            `else
            if(pkt_flags_r13 == PKT_PCIE) begin
            `endif
                pcie_pkt_sop <= pkt_buffer_readdata.sop;
                pcie_pkt_eop <= pkt_buffer_readdata.eop;
                pcie_pkt_valid <= 1;
                pcie_pkt_empty <= pkt_buffer_readdata.empty;
            end else begin
                eth_pkt_sop <= pkt_buffer_readdata.sop;
                eth_pkt_eop <= pkt_buffer_readdata.eop;
                eth_pkt_valid <= 1;
                eth_pkt_empty <= pkt_buffer_readdata.empty;
            end
        end
    end
end

endmodule
