`timescale 1 ps / 1 ps
module hyper_pipe_fd (
    //clk & rst   
    input  logic         clk,  
    input  logic         rst,    

    //Ethernet In & out
    input  logic [255:0] in_meta_data,                    
    input  logic         in_meta_valid, 
    input  logic         in_meta_almost_full,
    input  logic [255:0] out_meta_data,                    
    input  logic         out_meta_valid, 
    input  logic         out_meta_almost_full,
    output logic [255:0] reg_in_meta_data,                    
    output logic         reg_in_meta_valid, 
    output logic         reg_in_meta_almost_full,
    output logic [255:0] reg_out_meta_data,                    
    output logic         reg_out_meta_valid, 
    output logic         reg_out_meta_almost_full
    
);
localparam NUM_PIPES = 1;

hyper_pipe #(
    .WIDTH (256),
    .NUM_PIPES(NUM_PIPES)
) hp_in_meta_data (
    .clk(clk),
    .din(in_meta_data),
    .dout(reg_in_meta_data)
);

hyper_pipe_rst #(
    .WIDTH (1),
    .NUM_PIPES(NUM_PIPES)
) hp_in_meta_valid (
    .clk(clk),
    .rst(rst),
    .din(in_meta_valid),
    .dout(reg_in_meta_valid)
);

hyper_pipe_rst #(
    .WIDTH (1),
    .NUM_PIPES(NUM_PIPES)
) hp_in_meta_almost_full (
    .clk(clk),
    .rst(rst),
    .din(in_meta_almost_full),
    .dout(reg_in_meta_almost_full)
);

hyper_pipe #(
    .WIDTH (256),
    .NUM_PIPES(NUM_PIPES)
) hp_out_meta_data (
    .clk(clk),
    .din(out_meta_data),
    .dout(reg_out_meta_data)
);

hyper_pipe_rst #(
    .WIDTH (1),
    .NUM_PIPES(NUM_PIPES)
) hp_out_meta_valid (
    .clk(clk),
    .rst(rst),
    .din(out_meta_valid),
    .dout(reg_out_meta_valid)
);

hyper_pipe_rst #(
    .WIDTH (1),
    .NUM_PIPES(NUM_PIPES)
) hp_out_meta_almost_full (
    .clk(clk),
    .rst(rst),
    .din(out_meta_almost_full),
    .dout(reg_out_meta_almost_full)
);

endmodule
