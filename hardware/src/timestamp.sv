`include "./constants.sv"

/// Timestamp outgoing packets and calculate RTT for incoming packets using this
/// timestamp. For incoming packets we also replace the timestamp with the RTT
/// (in number of cycles). Must be explicitly enabled using the configuration
/// interface. Otherwise this module does nothing.
module timestamp #(
    parameter TIMESTAMP_WIDTH=32
)(
    input logic clk,
    input logic rst,

    /// RX input.
    input  logic [511:0] rx_in_pkt_data,
    input  logic         rx_in_pkt_valid,
    output logic         rx_in_pkt_ready,
    input  logic         rx_in_pkt_sop,
    input  logic         rx_in_pkt_eop,
    input  logic [5:0]   rx_in_pkt_empty,

    /// RX output.
    output logic [511:0] rx_out_pkt_data,
    output logic         rx_out_pkt_valid,
    input  logic         rx_out_pkt_ready,
    output logic         rx_out_pkt_sop,
    output logic         rx_out_pkt_eop,
    output logic [5:0]   rx_out_pkt_empty,

    /// TX input.
    input  logic [511:0] tx_in_pkt_data,
    input  logic         tx_in_pkt_valid,
    output logic         tx_in_pkt_ready,
    input  logic         tx_in_pkt_sop,
    input  logic         tx_in_pkt_eop,
    input  logic [5:0]   tx_in_pkt_empty,

    /// TX output.
    output logic [511:0] tx_out_pkt_data,
    output logic         tx_out_pkt_valid,
    input  logic         tx_out_pkt_ready,
    output logic         tx_out_pkt_sop,
    output logic         tx_out_pkt_eop,
    output logic [5:0]   tx_out_pkt_empty,

    /// Configuration.
    input  var timestamp_config_t conf_ts_data,
    input  logic                  conf_ts_valid,
    output logic                  conf_ts_ready
);


logic [8:0] offset;
logic [8:0] reversed_offset;

logic [TIMESTAMP_WIDTH-1:0] timestamp_counter;
logic [TIMESTAMP_WIDTH-1:0] rtt;
logic timestamp_enabled;

assign reversed_offset = 512 - TIMESTAMP_WIDTH - offset * 8;

always @(posedge clk) begin
    if (rst) begin
        timestamp_counter <= 0;
        timestamp_enabled <= 0;
    end else begin
        timestamp_counter <= timestamp_counter + 1;

        if (conf_ts_valid) begin
            timestamp_enabled <= conf_ts_data.enable;
            offset <= conf_ts_data.offset;
            $display("Enable timestamp");
        end
    end
end

always_comb begin
    conf_ts_ready = 1'b1;

    rx_out_pkt_data = rx_in_pkt_data;
    rx_out_pkt_valid = rx_in_pkt_valid;
    rx_out_pkt_sop = rx_in_pkt_sop;
    rx_out_pkt_eop = rx_in_pkt_eop;
    rx_out_pkt_empty = rx_in_pkt_empty;

    rx_in_pkt_ready = rx_out_pkt_ready;

    tx_out_pkt_data = tx_in_pkt_data;
    tx_out_pkt_valid = tx_in_pkt_valid;
    tx_out_pkt_sop = tx_in_pkt_sop;
    tx_out_pkt_eop = tx_in_pkt_eop;
    tx_out_pkt_empty = tx_in_pkt_empty;

    tx_in_pkt_ready = tx_out_pkt_ready;

    rtt = timestamp_counter -
        rx_in_pkt_data[reversed_offset +: TIMESTAMP_WIDTH];

    if (timestamp_enabled) begin
        // Timestamp TX packets.
        if (tx_in_pkt_sop) begin
            tx_out_pkt_data[reversed_offset +: TIMESTAMP_WIDTH]
                = timestamp_counter;
        end

        // Write RTT to RX packets.
        if (rx_in_pkt_sop) begin
            rx_out_pkt_data[reversed_offset +: TIMESTAMP_WIDTH] = rtt;
        end
    end
end

endmodule
