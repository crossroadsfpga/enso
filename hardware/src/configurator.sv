`include "./constants.sv"
module configurator(
  input logic clk,
  input logic rst,

  input  var config_flit_t in_config_data,
  input  logic             in_config_valid,
  output logic             in_config_ready,

  output var flow_table_config_t out_conf_ft_data,
  output logic                   out_conf_ft_valid,
  input  logic                   out_conf_ft_ready
);

always_comb begin
  in_config_ready = out_conf_ft_ready;
  out_conf_ft_valid = 0;

  // TODO(sadok): will need to look into `config_id` once we have multiple
  // configuration output paths. But for now, since we only have a single one,
  // we can short circuit the input and output.
  if (in_config_valid) begin
    out_conf_ft_valid = 1;
    out_conf_ft_data = in_config_data;
  end
end

endmodule
