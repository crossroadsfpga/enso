`include "./constants.sv"
module flow_director(
    input logic clk,
    input logic rst,

    input  var metadata_t in_meta_data,
    input  logic          in_meta_valid,
    output logic          in_meta_ready,

    output var metadata_t out_meta_data,
    output logic          out_meta_valid,
    input  logic          out_meta_ready
);

always_comb begin
    in_meta_ready = out_meta_ready;
    out_meta_data = in_meta_data;
    out_meta_valid = in_meta_valid;

    out_meta_data.pkt_flags = PKT_PCIE;

    if (in_meta_data.pkt_queue_id == '1) begin
        // FIXME(sadok) determine queue using the src IP address. This is
        // necessary as I temporarily removed the ability to populate the flow
        // table.
        out_meta_data.pkt_queue_id = {16'h0, in_meta_data.tuple.dIP[15:0]};

        // out_meta_data.pkt_flags = PKT_DROP;
    end
end

endmodule
