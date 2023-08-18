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
    input var fallback_queues_config_t conf_fd_data,
    input logic                        conf_fd_valid,
    output logic                       conf_fd_ready
);

logic [31:0] nb_fallback_queues;
logic [31:0] fallback_queue_mask;
logic        enable_rr;

assign conf_fd_ready = 1'b1;

logic [31:0] next_rr_queue;

always @(posedge clk) begin
    if (rst) begin
        enable_rr <= 0;
        nb_fallback_queues <= 0;
        fallback_queue_mask <= 0;
    end else begin
        // Apply configuration.
        if (conf_fd_valid) begin
            nb_fallback_queues <= conf_fd_data.nb_fallback_queues;
            fallback_queue_mask <= conf_fd_data.fallback_queue_mask;
            enable_rr <= conf_fd_data.enable_rr;
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        next_rr_queue <= 0;
    end else begin
        if (enable_rr) begin
            next_rr_queue <= (next_rr_queue + 1) & fallback_queue_mask;
        end
    end
end

always_comb begin
    in_meta_ready = out_meta_ready;
    out_meta_data = in_meta_data;
    out_meta_valid = in_meta_valid;

    out_meta_data.pkt_flags = PKT_PCIE;

    // Packets that do not match any entry in the flow table are sent to a
    // fallback queue using a hash of the 5-tuple or round robin (if enabled).
    // If no fallback queue is configured, we drop the packet.
    if (in_meta_data.pkt_queue_id == '1) begin
        if (nb_fallback_queues == 0) begin
            out_meta_data.pkt_flags = PKT_DROP;
        end else begin
            if (enable_rr) begin
                out_meta_data.pkt_queue_id = next_rr_queue;
            end else begin
                out_meta_data.pkt_queue_id =
                    in_meta_data.hash & fallback_queue_mask;
            end
        end
    end
end

endmodule
