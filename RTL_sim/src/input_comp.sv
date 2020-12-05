// new_component.v
`include "./my_struct_s.sv"
// This file was auto-generated as a prototype implementation of a module
// created in component editor.  It ties off all outputs to ground and
// ignores all inputs.  It needs to be edited to make it do something
// useful.
// 
// This file will not be automatically regenerated.  You should check it in
// to your version control system if you want to keep it.

`timescale 1 ps / 1 ps
module input_comp (
        input  logic         clk,                   
        input  logic         rst,                   
        input  logic         eth_sop,      //       
        input  logic         eth_eop,        //     
        input  logic [511:0] eth_data,              
        input  logic [5:0]   eth_empty,
        input  logic         eth_valid,             
        output logic [PKTBUF_AWIDTH-1:0]   pkt_buffer_address,    
        output logic         pkt_buffer_write,      
        output flit_t        pkt_buffer_writedata,  
        input  logic [PKT_AWIDTH-1:0]    emptylist_out_data,
        input  logic                    emptylist_out_valid,
        output logic                    emptylist_out_ready,
        output logic         pkt_sop,
        output logic         pkt_eop,
        output logic         pkt_valid,
        output logic [511:0] pkt_data,
        output logic [5:0]   pkt_empty,
        input  logic         pkt_ready,  
        output logic         meta_valid,
        output metadata_t    meta_data,
        input  logic         meta_ready   

    );
//Every pkt struct is 2 KB, which is 32 entries. 
logic [PKTBUF_AWIDTH-1:0]   pkt_buffer_address_r;    
logic         pkt_buffer_write_r;      
flit_t        pkt_buffer_writedata_r;  

logic [PKT_AWIDTH-1:0] next_empty;
logic [PKT_AWIDTH-1:0] current_empty;
metadata_t empty_meta;
logic [4:0] flits = 5'b00001;
logic [511:0] eth_data_r;

//assert(!emptylist_out_valid); 

assign pkt_empty = 0;

//assign empty_meta = '{0,0,0,0,0,0,0,0};
assign empty_meta = 0;
always@(posedge clk)begin
    if(rst)begin
        pkt_buffer_write <= 0;
    end else begin
        pkt_buffer_address <= pkt_buffer_address_r;
        pkt_buffer_write <= pkt_buffer_write_r;
        pkt_buffer_writedata <= pkt_buffer_writedata_r;
    end
end

assign emptylist_out_ready = eth_valid & eth_sop;
always@(posedge clk)begin

    if(!rst)begin
        assert(!(!emptylist_out_valid & emptylist_out_ready))
        else begin
            hterminate("Request from empty PKT_empty list");
        end
    end
    if(rst)begin
        pkt_buffer_write_r <= 1'b0;
    end else begin
        pkt_buffer_write_r <= 1'b0;
        if (eth_valid & emptylist_out_valid)begin
            pkt_buffer_write_r <= 1'b1;
            pkt_buffer_writedata_r <= {eth_sop,eth_eop,eth_empty,eth_data};
            if(eth_sop) begin
                pkt_buffer_address_r <= (emptylist_out_data << 5);
                current_empty <= emptylist_out_data;
            end else begin
                pkt_buffer_address_r <= pkt_buffer_address_r + 1'b1;
            end
        end
    end
end

always@(posedge clk)begin
    if(rst)begin
        pkt_valid <= 0;
        meta_valid <= 0;
        flits <= 1;
    end else begin
        meta_data <= empty_meta;
        meta_valid <= 0;
        if (eth_valid & emptylist_out_valid) begin
            //TODO: only assume the first flit contains header.
            //if (eth_sop) begin
            //    //latch the data
            //    pkt_data <= eth_data;
            //end
            if (eth_eop) begin
                //Pass the header to parser.
                pkt_sop <= 1;
                pkt_eop <= 1;
                pkt_valid <= 1;
                //Pass the meta data to parser.
                meta_valid <= 1;
                if(eth_sop) begin
                    //meta_data.pktID <= next_empty;
                    meta_data.pktID <= emptylist_out_data;
                end else begin
                    meta_data.pktID <= current_empty;
                end
                meta_data.flits <= flits;
                flits <= 1;
                
            end else begin
                flits <= flits + 1;
                pkt_valid <= 0;
                pkt_sop <= 0;
                pkt_eop <= 0;
            end
        end else begin
            pkt_valid <= 0;
            pkt_sop <= 0;
            pkt_eop <= 0;
        end
    end

    if(eth_valid & eth_sop)begin
        pkt_data <= eth_data;
    end

    eth_data_r <= eth_data;
end
endmodule
