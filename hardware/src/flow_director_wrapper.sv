`include "./constants.sv"
module flow_director_wrapper(
    input clk,
    input rst,

    // Input.
    input  var metadata_t in_meta_data,
    input  logic          in_meta_valid,
    output logic          in_meta_ready,

    // Output.
    output var metadata_t out_meta_data,
    output logic          out_meta_valid,
    input  logic          out_meta_ready,

    // Configuration.
    input logic [31:0] nb_fallback_queues
);

flow_director flow_director_inst (
    .clk                (clk),                        
    .rst                (rst),              
    .in_meta_data       (in_meta_data),                
    .in_meta_valid      (in_meta_valid),               
    .in_meta_ready      (in_meta_ready),               
    .out_meta_data      (out_meta_data),          
    .out_meta_valid     (out_meta_valid),         
    .out_meta_ready     (out_meta_ready),
    .nb_fallback_queues (nb_fallback_queues)
);

endmodule
