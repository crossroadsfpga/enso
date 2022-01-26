`include "./constants.sv"
module flow_director(
    input logic clk,
    input logic rst,

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

logic [31:0] fallback_q_mask;
assign fallback_q_mask = nb_fallback_queues - 1;

always_comb begin
    in_meta_ready = out_meta_ready;
    out_meta_data = in_meta_data;
    out_meta_valid = in_meta_valid;

    out_meta_data.pkt_flags = PKT_PCIE;

    // Packets that do not match any entry in the flow table are sent to a
    // fallback queue using a hash of the 5-tuple. If no fallback queue is
    // configured, we drop the packet.
    if (in_meta_data.pkt_queue_id == '1) begin
        if (nb_fallback_queues == 0) begin
            out_meta_data.pkt_flags = PKT_DROP;
        end else begin
            out_meta_data.pkt_queue_id = in_meta_data.hash & fallback_q_mask;
        end
    end
end

endmodule
