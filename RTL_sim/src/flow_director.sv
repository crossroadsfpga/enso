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

  always @(*) begin
    in_meta_ready = out_meta_ready;
    out_meta_data = in_meta_data;
    out_meta_valid = in_meta_valid;

    if (in_meta_data.tuple.dPort == 80) begin
        out_meta_data.pkt_flags = PKT_PCIE;
    end else begin
        out_meta_data.pkt_flags = PKT_DROP;
    end

    if (in_meta_valid) begin
      $display("Flow Director: Flow ID=0x%h, PCIe Address=0x%h",
               in_meta_data.tuple, in_meta_data.pcie_address);
    end
  end

/*dummy*/
// assign in_meta_ready = out_meta_ready;
// assign out_meta_data = in_meta_data;
// assign out_meta_valid = in_meta_valid;

endmodule
