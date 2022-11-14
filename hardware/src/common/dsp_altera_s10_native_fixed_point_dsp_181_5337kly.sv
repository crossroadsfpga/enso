// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module  dsp_altera_s10_native_fixed_point_dsp_181_5337kly  (
            ax,
            ay,
            bx,
            by,
            ena,
            resulta,
            clk0,
            clk1,
            clk2);

            input [17:0] ax;
            input [17:0] ay;
            input [17:0] bx;
            input [17:0] by;
            input [2:0] ena;
            output [36:0] resulta;
            input  clk0;
            input  clk1;
            input  clk2;

            wire [36:0] sub_wire0;
            wire [36:0] resulta = sub_wire0[36:0];

            fourteennm_mac        fourteennm_mac_component (
                                        .ax (ax),
                                        .ay (ay),
                                        .bx (bx),
                                        .by (by),
                                        .ena (ena),
                                        .clr (2'b00),
                                        .clk ({clk2,clk1,clk0}),
                                        .resulta (sub_wire0));
            defparam

					fourteennm_mac_component.ax_clock="0",
					fourteennm_mac_component.ay_scan_in_clock="0",
					fourteennm_mac_component.az_clock="none",
					fourteennm_mac_component.output_clock="0",
					fourteennm_mac_component.bx_clock="0",
					fourteennm_mac_component.accumulate_clock="none",
					fourteennm_mac_component.accum_pipeline_clock="none",
					fourteennm_mac_component.bz_clock="none",
					fourteennm_mac_component.by_clock="0",
					fourteennm_mac_component.coef_sel_a_clock="none",
					fourteennm_mac_component.coef_sel_b_clock="none",
					fourteennm_mac_component.sub_clock="none",
					fourteennm_mac_component.negate_clock="none",
					fourteennm_mac_component.accum_2nd_pipeline_clock="none",
					fourteennm_mac_component.load_const_clock="none",
					fourteennm_mac_component.load_const_pipeline_clock="none",
					fourteennm_mac_component.load_const_2nd_pipeline_clock="none",
					fourteennm_mac_component.input_pipeline_clock="0",
					fourteennm_mac_component.second_pipeline_clock="0",
					fourteennm_mac_component.input_systolic_clock="none",
					fourteennm_mac_component.preadder_subtract_a = "false",
					fourteennm_mac_component.preadder_subtract_b = "false",
					fourteennm_mac_component.delay_scan_out_ay = "false",
					fourteennm_mac_component.delay_scan_out_by = "false",
					fourteennm_mac_component.ay_use_scan_in = "false",
					fourteennm_mac_component.by_use_scan_in = "false",
					fourteennm_mac_component.operand_source_may = "input",
					fourteennm_mac_component.operand_source_mby = "input",
					fourteennm_mac_component.operand_source_max = "input",
					fourteennm_mac_component.operand_source_mbx = "input",
					fourteennm_mac_component.signed_max = "false",
					fourteennm_mac_component.signed_may = "false",
					fourteennm_mac_component.signed_mbx = "false",
					fourteennm_mac_component.signed_mby = "false",
					fourteennm_mac_component.use_chainadder = "false",
					fourteennm_mac_component.enable_double_accum = "false",
					fourteennm_mac_component.operation_mode = "m18x18_sumof2",
					fourteennm_mac_component.clear_type = "none",
					fourteennm_mac_component.ax_width = 18,
					fourteennm_mac_component.bx_width = 18,
					fourteennm_mac_component.ay_scan_in_width = 18,
					fourteennm_mac_component.by_width = 18,
					fourteennm_mac_component.result_a_width = 37,
					fourteennm_mac_component.load_const_value = 0,
					fourteennm_mac_component.coef_a_0 = 0,
					fourteennm_mac_component.coef_a_1 = 0,
					fourteennm_mac_component.coef_a_2 = 0,
					fourteennm_mac_component.coef_a_3 = 0,
					fourteennm_mac_component.coef_a_4 = 0,
					fourteennm_mac_component.coef_a_5 = 0,
					fourteennm_mac_component.coef_a_6 = 0,
					fourteennm_mac_component.coef_a_7 = 0,
					fourteennm_mac_component.coef_b_0 = 0,
					fourteennm_mac_component.coef_b_1 = 0,
					fourteennm_mac_component.coef_b_2 = 0,
					fourteennm_mac_component.coef_b_3 = 0,
					fourteennm_mac_component.coef_b_4 = 0,
					fourteennm_mac_component.coef_b_5 = 0,
					fourteennm_mac_component.coef_b_6 = 0,
					fourteennm_mac_component.coef_b_7 = 0;

endmodule
