`include "./constants.sv"
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

    out_meta_data.pkt_flags = PKT_PCIE;

    // if (in_meta_data.queue_id == '1) begin
    //     out_meta_data.pkt_flags = PKT_DROP;
    // end

    // FIXME(sadok) determine queue using the src IP address. This is necessary
    // as I temporarily removed the ability to populate the flow table.
    out_meta_data.pkt_queue_id = {48'h0, in_meta_data.tuple.dIP[15:0]};
    out_meta_data.dsc_queue_id = {48'h0, in_meta_data.tuple.sIP[15:0]};

    // if (in_meta_valid) begin
    //   $display("Flow Director: Flow ID=0x%h, Queue ID=0x%h",
    //             in_meta_data.tuple, in_meta_data.queue_id);
    // end
end

endmodule