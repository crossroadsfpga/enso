`timescale 1 ps / 1 ps
`include "./my_struct_s.sv"
module hyper_pipe_root (
    //clk & rst   
    input  logic         clk,  
    input  logic         rst,    
    input  logic         clk_datamover,      
    input  logic         rst_datamover,

    //Ethernet In & out
    input  logic         in_sop,          
    input  logic         in_eop,            
    input  logic [511:0] in_data,                    
    input  logic [5:0]   in_empty,                    
    input  logic         in_valid, 
    input  logic [511:0] out_data,       
    input  logic         out_valid,       
    input  logic         out_sop,       
    input  logic         out_eop,       
    input  logic [5:0]   out_empty,       
    input  logic         out_almost_full,       
    
    //eSRAM
    input  logic                     esram_pkt_buf_wren,
    input  logic [PKTBUF_AWIDTH-1:0] esram_pkt_buf_wraddress,
    input  logic [519:0]             esram_pkt_buf_wrdata,
    input  logic                     esram_pkt_buf_rden,
    input  logic [PKTBUF_AWIDTH-1:0] esram_pkt_buf_rdaddress,
    input  logic                     esram_pkt_buf_rd_valid,
    input  logic [519:0]             esram_pkt_buf_rddata,

    output  logic                     reg_in_sop,          
    output  logic                     reg_in_eop,            
    output  logic [511:0]             reg_in_data,                    
    output  logic [5:0]               reg_in_empty,                    
    output  logic                     reg_in_valid, 
    output  logic [511:0]             reg_out_data,       
    output  logic                     reg_out_valid,       
    output  logic                     reg_out_sop,       
    output  logic                     reg_out_eop,       
    output  logic [5:0]               reg_out_empty,       
    output  logic                     reg_out_almost_full,       
    output  logic                     reg_esram_pkt_buf_wren,
    output  logic [PKTBUF_AWIDTH-1:0] reg_esram_pkt_buf_wraddress,
    output  logic [519:0]             reg_esram_pkt_buf_wrdata,
    output  logic                     reg_esram_pkt_buf_rden,
    output  logic [PKTBUF_AWIDTH-1:0] reg_esram_pkt_buf_rdaddress,
    output  logic                     reg_esram_pkt_buf_rd_valid,
    output  logic [519:0]             reg_esram_pkt_buf_rddata
);
localparam NUM_PIPES = 1;

//eth in
hyper_pipe #(
    .WIDTH (1),
    .NUM_PIPES(NUM_PIPES)
) hp_in_sop (
    .clk(clk_datamover),
    .din(in_sop),
    .dout(reg_in_sop)
);
hyper_pipe #(
    .WIDTH (1),
    .NUM_PIPES(NUM_PIPES)
) hp_in_eop (
    .clk(clk_datamover),
    .din(in_eop),
    .dout(reg_in_eop)
);
hyper_pipe #(
    .WIDTH (512),
    .NUM_PIPES(NUM_PIPES)
) hp_in_data (
    .clk(clk_datamover),
    .din(in_data),
    .dout(reg_in_data)
);
hyper_pipe #(
    .WIDTH (6),
    .NUM_PIPES(NUM_PIPES)
) hp_in_empty (
    .clk(clk_datamover),
    .din(in_empty),
    .dout(reg_in_empty)
);
hyper_pipe_rst #(
    .WIDTH (1),
    .NUM_PIPES(NUM_PIPES)
) hp_in_valid (
    .clk(clk_datamover),
    .rst(rst_datamover),
    .din(in_valid),
    .dout(reg_in_valid)
);
//eth out
hyper_pipe #(
    .WIDTH (512),
    .NUM_PIPES(NUM_PIPES)
) hp_out_data (
    .clk(clk),
    .din(out_data),
    .dout(reg_out_data)
);
hyper_pipe_rst #(
    .WIDTH (1),
    .NUM_PIPES(NUM_PIPES)
) hp_out_valid (
    .clk(clk),
    .rst(rst),
    .din(out_valid),
    .dout(reg_out_valid)
);
hyper_pipe #(
    .WIDTH (1),
    .NUM_PIPES(NUM_PIPES)
) hp_out_sop (
    .clk(clk),
    .din(out_sop),
    .dout(reg_out_sop)
);
hyper_pipe #(
    .WIDTH (1),
    .NUM_PIPES(NUM_PIPES)
) hp_out_eop (
    .clk(clk),
    .din(out_eop),
    .dout(reg_out_eop)
);
hyper_pipe #(
    .WIDTH (6),
    .NUM_PIPES(NUM_PIPES)
) hp_out_empty (
    .clk(clk),
    .din(out_empty),
    .dout(reg_out_empty)
);
hyper_pipe_rst #(
    .WIDTH (1),
    .NUM_PIPES(NUM_PIPES)
) hp_out_almost_full (
    .clk(clk),
    .rst(rst),
    .din(out_almost_full),
    .dout(reg_out_almost_full)
);

//esram
hyper_pipe_rst #(
    .WIDTH (1),
    .NUM_PIPES(NUM_PIPES)
) hp_esram_pkt_buf_wren (
    .clk(clk_datamover),
    .rst(rst_datamover),
    .din     (esram_pkt_buf_wren),
    .dout(reg_esram_pkt_buf_wren)
);
hyper_pipe #(
    .WIDTH (PKTBUF_AWIDTH),
    .NUM_PIPES(NUM_PIPES)
) hp_esram_pkt_buf_wraddress (
    .clk(clk_datamover),
    .din     (esram_pkt_buf_wraddress),
    .dout(reg_esram_pkt_buf_wraddress)
);
hyper_pipe #(
    .WIDTH (520),
    .NUM_PIPES(NUM_PIPES)
) hp_esram_pkt_buf_wrdata (
    .clk(clk_datamover),
    .din     (esram_pkt_buf_wrdata),
    .dout(reg_esram_pkt_buf_wrdata)
);
hyper_pipe_rst #(
    .WIDTH (1),
    .NUM_PIPES(NUM_PIPES)
) hp_esram_pkt_buf_rden (
    .clk(clk_datamover),
    .rst(rst_datamover),
    .din     (esram_pkt_buf_rden),
    .dout(reg_esram_pkt_buf_rden)
);
hyper_pipe #(
    .WIDTH (PKTBUF_AWIDTH),
    .NUM_PIPES(NUM_PIPES)
) hp_esram_pkt_buf_rdaddress (
    .clk(clk_datamover),
    .din     (esram_pkt_buf_rdaddress),
    .dout(reg_esram_pkt_buf_rdaddress)
);
hyper_pipe_rst #(
    .WIDTH (1),
    .NUM_PIPES(NUM_PIPES)
) hp_esram_pkt_buf_rd_valid (
    .clk(clk_datamover),
    .rst(rst_datamover),
    .din     (esram_pkt_buf_rd_valid),
    .dout(reg_esram_pkt_buf_rd_valid)
);
hyper_pipe #(
    .WIDTH (520),
    .NUM_PIPES(NUM_PIPES)
) hp_esram_pkt_buf_rddata (
    .clk(clk_datamover),
    .din     (esram_pkt_buf_rddata),
    .dout(reg_esram_pkt_buf_rddata)
);

endmodule
