`include "./constants.sv"

/*
 * Rate-limit packets according to configuration.
 * Rate is configured to `numerator`/`denominator`.
 * This means that we send `numerator` flits every `denominator` cycles.
 */
module rate_limiter #(
)(
    input logic clk,
    input logic rst,

    // Input.
    input  logic [511:0] in_pkt_data,
    input  logic         in_pkt_valid,
    output logic         in_pkt_ready,
    input  logic         in_pkt_sop,
    input  logic         in_pkt_eop,
    input  logic [5:0]   in_pkt_empty,

    // Output.
    output logic [511:0] out_pkt_data,
    output logic         out_pkt_valid,
    input  logic         out_pkt_ready,
    output logic         out_pkt_sop,
    output logic         out_pkt_eop,
    output logic [5:0]   out_pkt_empty,

    // Configuration.
    input  var rate_limit_config_t conf_rl_data,
    input  logic                   conf_rl_valid,
    output logic                   conf_rl_ready
);

logic rate_limit_enabled;

logic [$bits(conf_rl_data.numerator)-1:0]   numerator;
logic [$bits(conf_rl_data.denominator)-1:0] denominator;
logic [$bits(conf_rl_data.numerator)-1:0]   period_counter;
logic [$bits(conf_rl_data.numerator)-1:0]   incr_period_counter;

logic pause;

always @(posedge clk) begin
    if (rst) begin
        rate_limit_enabled <= 0;
    end else begin
        // Apply configuration.
        if (conf_rl_valid) begin
            rate_limit_enabled <= conf_rl_data.enable;
            if (conf_rl_data.enable) begin
                numerator <= conf_rl_data.numerator;
                denominator <= conf_rl_data.denominator;
                period_counter <= 0;
            end
        end

        if (rate_limit_enabled) begin
            period_counter <= incr_period_counter;
            if (incr_period_counter >= denominator) begin
                period_counter <= 0;
            end
        end
    end
end

always_comb begin
    conf_rl_ready = 1'b1;
    out_pkt_data = in_pkt_data;
    out_pkt_sop = in_pkt_sop;
    out_pkt_eop = in_pkt_eop;
    out_pkt_empty = in_pkt_empty;

    incr_period_counter = period_counter + 1;

    pause = 0;

    if (rate_limit_enabled) begin
        if (period_counter >= numerator) begin
            pause = 1;
        end
    end

    in_pkt_ready = out_pkt_ready & !pause;
    out_pkt_valid = in_pkt_valid & !pause;
end

endmodule
