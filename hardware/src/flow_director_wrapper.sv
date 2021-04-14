`include "./constants.sv"
module flow_director_wrapper(
    clk,
    rst,
    in_meta_data,
    in_meta_valid,
    in_meta_ready,
    out_meta_data,
    out_meta_valid,
    out_meta_ready
);
input clk;
input rst;
input metadata_t in_meta_data;
input in_meta_valid;
output logic in_meta_ready;
output metadata_t out_meta_data;
output logic out_meta_valid;
input out_meta_ready;

//real flow director
flow_director flow_director_inst (
    .clk               (clk),                        
    .rst               (rst),              
    .in_meta_data      (in_meta_data),                
    .in_meta_valid     (in_meta_valid),               
    .in_meta_ready     (in_meta_ready),               
    .out_meta_data     (out_meta_data),          
    .out_meta_valid    (out_meta_valid),         
    .out_meta_ready    (out_meta_ready)        
);

endmodule
