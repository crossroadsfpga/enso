`include "./my_struct_s.sv"
module flow_director(
    clk,rst,
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
input  out_meta_ready;

/*dummy*/
assign in_meta_ready = out_meta_ready;
assign out_meta_data = in_meta_data;
assign out_meta_valid = in_meta_valid;


endmodule
