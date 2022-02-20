`include "./constants.sv"
module configurator(
  input logic clk,
  input logic rst,

  input  var config_flit_t in_config_data,
  input  logic             in_config_valid,
  output logic             in_config_ready,

  output var flow_table_config_t out_conf_ft_data,
  output logic                   out_conf_ft_valid,
  input  logic                   out_conf_ft_ready,

  output var timestamp_config_t out_conf_ts_data,
  output logic                  out_conf_ts_valid,
  input  logic                  out_conf_ts_ready
);

always_comb begin
  in_config_ready = out_conf_ft_ready & out_conf_ts_ready;

  out_conf_ft_valid = 0;
  out_conf_ts_valid = 0;

  out_conf_ft_data = in_config_data;
  out_conf_ts_data = in_config_data;

  if (in_config_valid) begin
    case (in_config_data.config_id)
      FLOW_TABLE_CONFIG_ID: begin
        out_conf_ft_valid = 1;
      end
      TIMESTAMP_CONFIG_ID: begin
        out_conf_ts_valid = 1;
      end
    endcase
  end
end

endmodule
