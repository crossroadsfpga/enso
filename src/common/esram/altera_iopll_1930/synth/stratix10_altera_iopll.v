// (C) 2001-2019 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// This is a wrapper for fourteennm_pll.
// Wrappers for other families can be found in altera_pll.v (pre Arria 10) and twentynm_iopll.v

`timescale 1ps/1ps
module stratix10_altera_iopll
#(
    //Parameters
    parameter prot_mode                 = "BASIC",
    parameter reference_clock_frequency = "0 ps",
    parameter pll_type                  = "General",
    parameter pll_subtype               = "General",
    parameter number_of_clocks          = 1,
    parameter operation_mode            = "internal feedback",
    parameter output_clock_frequency0   = "0 ps",
    parameter phase_shift0              = "0 ps",
    parameter duty_cycle0               = 50,
    parameter output_clock_frequency1   = "0 ps",
    parameter phase_shift1              = "0 ps",
    parameter duty_cycle1               = 50,
    parameter output_clock_frequency2   = "0 ps",
    parameter phase_shift2              = "0 ps",
    parameter duty_cycle2               = 50,
    parameter output_clock_frequency3   = "0 ps",
    parameter phase_shift3              = "0 ps",
    parameter duty_cycle3               = 50,
    parameter output_clock_frequency4   = "0 ps",
    parameter phase_shift4              = "0 ps",
    parameter duty_cycle4               = 50,
    parameter output_clock_frequency5   = "0 ps",
    parameter phase_shift5              = "0 ps",
    parameter duty_cycle5               = 50,
    parameter output_clock_frequency6   = "0 ps",
    parameter phase_shift6              = "0 ps",
    parameter duty_cycle6               = 50,
    parameter output_clock_frequency7   = "0 ps",
    parameter phase_shift7              = "0 ps",
    parameter duty_cycle7               = 50,
    parameter output_clock_frequency8   = "0 ps",
    parameter phase_shift8              = "0 ps",
    parameter duty_cycle8               = 50,
    parameter clock_name_0              = "",
    parameter clock_name_1              = "",
    parameter clock_name_2              = "",
    parameter clock_name_3              = "",
    parameter clock_name_4              = "",
    parameter clock_name_5              = "",
    parameter clock_name_6              = "",
    parameter clock_name_7              = "",
    parameter clock_name_8              = "",
    parameter clock_name_global         = "false",
    parameter eff_m_cnt                 = 1,
    parameter m_cnt_hi_div              = 1,
    parameter m_cnt_lo_div              = 1,
    parameter m_cnt_bypass_en           = "false",
    parameter m_cnt_odd_div_duty_en     = "false",
    parameter n_cnt_hi_div              = 1,
    parameter n_cnt_lo_div              = 1,
    parameter n_cnt_bypass_en           = "false",
    parameter n_cnt_odd_div_duty_en     = "false",
    parameter c_cnt_hi_div0             = 1,
    parameter c_cnt_lo_div0             = 1,
    parameter c_cnt_bypass_en0          = "false",
    parameter c_cnt_in_src0             = "c_m_cnt_in_src_ph_mux_clk",
    parameter c_cnt_odd_div_duty_en0    = "false",
    parameter c_cnt_prst0               = 1,
    parameter c_cnt_ph_mux_prst0        = 0,
    parameter c_cnt_hi_div1             = 1,
    parameter c_cnt_lo_div1             = 1,
    parameter c_cnt_bypass_en1          = "false",
    parameter c_cnt_in_src1             = "c_m_cnt_in_src_ph_mux_clk",
    parameter c_cnt_odd_div_duty_en1    = "false",
    parameter c_cnt_prst1               = 1,
    parameter c_cnt_ph_mux_prst1        = 0,
    parameter c_cnt_hi_div2             = 1,
    parameter c_cnt_lo_div2             = 1,
    parameter c_cnt_bypass_en2          = "false",
    parameter c_cnt_in_src2             = "c_m_cnt_in_src_ph_mux_clk",
    parameter c_cnt_odd_div_duty_en2    = "false",
    parameter c_cnt_prst2               = 1,
    parameter c_cnt_ph_mux_prst2        = 0,
    parameter c_cnt_hi_div3             = 1,
    parameter c_cnt_lo_div3             = 1,
    parameter c_cnt_bypass_en3          = "false",
    parameter c_cnt_in_src3             = "c_m_cnt_in_src_ph_mux_clk",
    parameter c_cnt_odd_div_duty_en3    = "false",
    parameter c_cnt_prst3               = 1,
    parameter c_cnt_ph_mux_prst3        = 0,
    parameter c_cnt_hi_div4             = 1,
    parameter c_cnt_lo_div4             = 1,
    parameter c_cnt_bypass_en4          = "false",
    parameter c_cnt_in_src4             = "c_m_cnt_in_src_ph_mux_clk",
    parameter c_cnt_odd_div_duty_en4    = "false",
    parameter c_cnt_prst4               = 1,
    parameter c_cnt_ph_mux_prst4        = 0,
    parameter c_cnt_hi_div5             = 1,
    parameter c_cnt_lo_div5             = 1,
    parameter c_cnt_bypass_en5          = "false",
    parameter c_cnt_in_src5             = "c_m_cnt_in_src_ph_mux_clk",
    parameter c_cnt_odd_div_duty_en5    = "false",
    parameter c_cnt_prst5               = 1,
    parameter c_cnt_ph_mux_prst5        = 0,
    parameter c_cnt_hi_div6             = 1,
    parameter c_cnt_lo_div6             = 1,
    parameter c_cnt_bypass_en6          = "false",
    parameter c_cnt_in_src6             = "c_m_cnt_in_src_ph_mux_clk",
    parameter c_cnt_odd_div_duty_en6    = "false",
    parameter c_cnt_prst6               = 1,
    parameter c_cnt_ph_mux_prst6        = 0,
    parameter c_cnt_hi_div7             = 1,
    parameter c_cnt_lo_div7             = 1,
    parameter c_cnt_bypass_en7          = "false",
    parameter c_cnt_in_src7             = "c_m_cnt_in_src_ph_mux_clk",
    parameter c_cnt_odd_div_duty_en7    = "false",
    parameter c_cnt_prst7               = 1,
    parameter c_cnt_ph_mux_prst7        = 0,
    parameter c_cnt_hi_div8             = 1,
    parameter c_cnt_lo_div8             = 1,
    parameter c_cnt_bypass_en8          = "false",
    parameter c_cnt_in_src8             = "c_m_cnt_in_src_ph_mux_clk",
    parameter c_cnt_odd_div_duty_en8    = "false",
    parameter c_cnt_prst8               = 1,
    parameter c_cnt_ph_mux_prst8        = 0,
    parameter clock_to_compensate       = 0,
    parameter merging_permitted         = "false",
    parameter pll_slf_rst               = "false",
    parameter pll_output_clk_frequency  = "0 MHz",
    parameter pll_cp_current            = "pll_cp_setting0",
    parameter pll_bwctrl                = "pll_bw_res_setting0",
    parameter pll_fbclk_mux_1           = "pll_fbclk_mux_1_glb",
    parameter pll_fbclk_mux_2           = "pll_fbclk_mux_2_fb_1",
    parameter pll_m_cnt_in_src          = "c_m_cnt_in_src_ph_mux_clk",
    parameter pll_clkin_0_src           = "clk_0",
    parameter pll_clkin_1_src           = "clk_0",
    parameter pll_clk_loss_sw_en        = "false",
    parameter pll_auto_clk_sw_en        = "false",
    parameter pll_manu_clk_sw_en        = "false",
    parameter pll_clk_sw_dly            = 0,
    parameter pll_extclk_0_cnt_src      = "pll_extclk_cnt_src_vss",
    parameter pll_extclk_1_cnt_src      = "pll_extclk_cnt_src_vss",
    parameter pll_lock_fltr_cfg         = 100,
    parameter pll_unlock_fltr_cfg       = 2,
    parameter lock_mode                 = "mid_lock_time",
    parameter pll_bw_sel                = "mid_bw",
    parameter refclk1_frequency         = "0 MHz",
    parameter pll_ripplecap_ctrl        = "pll_ripplecap_setting3",
    parameter dprio_interface_sel       = 8'b00000011,
    parameter pll_freqcal_en            = "true",
    parameter pll_defer_cal_user_mode   = "false"
) ( 
    //Input signals
    input    refclk,
    input    refclk1,
    input    fbclk,
    input    rst,
    input    phase_en,
    input    updn,
    input    [2:0] num_phase_shifts,
    input    scanclk,
    input    [4:0] cntsel,
    input    [29:0] reconfig_to_pll,
    input    extswitch,
    input    adjpllin,
    input    permit_cal,
    
    //Output signals
    output    [8:0] outclk,
    output    fboutclk,
    output    locked,
    output    phase_done,
    output    [10:0] reconfig_from_pll,
    output    activeclk,
    output    [1:0] clkbad,
    output    [7:0] phout,
    output    [1:0] lvds_clk,
    output    [1:0] loaden,
    output    [1:0] extclk_out,
    output    cascade_out,

    //Inout signals
    inout     zdbfbclk
    
);

wire feedback_clk;
wire lvds_fbclk;
wire fb_clkin;
wire fb_out_clk;
wire fboutclk_wire;
wire locked_wire;
wire [10:0] reconfig_from_pll_wire;
wire gnd /* synthesis keep*/;

// For use in dps pulse gen module. 
wire final_updn;
wire final_phase_en;
wire [3:0] final_cntsel;
wire [2:0] final_num_ps;

// Generate the reconfig from pll signal depending on whether this is a reconfigurable IOPLL.
assign reconfig_from_pll[10:0] = (pll_type == "General") ? 11'b0 : reconfig_from_pll_wire;

wire adjpllin_wire = (pll_clkin_0_src == "adj_pll_clk") ? adjpllin : 1'b0;

//Calibration wires
wire cal_ok_wire;

// Reset logic:
// There are a few scenarios:
//  - Upstream PLL : 
//       - reset is anded with cal_ok_wire so that a reset signal from the
//         user can't interrupt calibration.
//       - permit_cal tied off to 1 -> rst_n_wire = ~(rst & cal_ok_wire)
//  - Downstream PLL: 
//       - connect upstream locked to downstream permit_cal
//       - until upstream PLL is locked, keep reset high so that the PLL
//         can't be calibrated.
   
wire rst_n_wire = ~((rst & cal_ok_wire) | (~permit_cal));
wire dprio_rst_n_wire = ~((~reconfig_to_pll[1] & cal_ok_wire) | (~permit_cal));

//------------- Counter enable localparams -------------------------------
localparam counter0_enable = (output_clock_frequency0 != "0 ps" && output_clock_frequency0 != "0 MHz" && output_clock_frequency0 != "0.0 MHz") ? "true" : "false";
localparam counter1_enable = (output_clock_frequency1 != "0 ps" && output_clock_frequency1 != "0 MHz" && output_clock_frequency1 != "0.0 MHz") ? "true" : "false";
localparam counter2_enable = (output_clock_frequency2 != "0 ps" && output_clock_frequency2 != "0 MHz" && output_clock_frequency2 != "0.0 MHz") ? "true" : "false";
localparam counter3_enable = (output_clock_frequency3 != "0 ps" && output_clock_frequency3 != "0 MHz" && output_clock_frequency3 != "0.0 MHz") ? "true" : "false";
localparam counter4_enable = (output_clock_frequency4 != "0 ps" && output_clock_frequency4 != "0 MHz" && output_clock_frequency4 != "0.0 MHz") ? "true" : "false";
localparam counter5_enable = (output_clock_frequency5 != "0 ps" && output_clock_frequency5 != "0 MHz" && output_clock_frequency5 != "0.0 MHz") ? "true" : "false";
localparam counter6_enable = (output_clock_frequency6 != "0 ps" && output_clock_frequency6 != "0 MHz" && output_clock_frequency6 != "0.0 MHz") ? "true" : "false";
localparam counter7_enable = (output_clock_frequency7 != "0 ps" && output_clock_frequency7 != "0 MHz" && output_clock_frequency7 != "0.0 MHz") ? "true" : "false";
localparam counter8_enable = (output_clock_frequency8 != "0 ps" && output_clock_frequency8 != "0 MHz" && output_clock_frequency8 != "0.0 MHz") ? "true" : "false";
//------------- Counter enable localparams -------------------------------

generate
    if (pll_type == "S10_Simple" || pll_type == "S10_Physical") 
    begin: s10_iopll

        // ==========================================================================================
        // If the IOPLL has reconfig or DPS enabled, instantiate the dps_pulse_gen
        // (which converts the user_phase_en to a single pulse).
        // ==========================================================================================
        if (pll_subtype == "Reconfigurable" || pll_subtype == "DPS")
        begin
            dps_pulse_gen_fourteennm_iopll dps_pulse_gen_fourteennm_iopll_inst(
                .clk           ( (pll_subtype == "DPS") ? scanclk : reconfig_to_pll[0] ),
                .rst           ( rst                                                   ),
                .user_phase_en ( (pll_subtype == "DPS") ? phase_en:reconfig_to_pll[29] ),
                .user_updn     ( (pll_subtype == "DPS") ? updn:reconfig_to_pll[28] ),
                .user_cntsel   ( (pll_subtype == "DPS") ? cntsel[3:0]:reconfig_to_pll[24:21] ),
                .user_num_ps   ( (pll_subtype == "DPS") ? num_phase_shifts:reconfig_to_pll[27:25] ),
                .phase_en      ( final_phase_en                                        ),
                .updn          ( final_updn                                            ),
                .cntsel        ( final_cntsel                                          ),
                .num_ps        ( final_num_ps                                          )
            );
        end

        // ==========================================================================================
        // Instantiate fourteennm_iopll!
        // ==========================================================================================
        fourteennm_iopll #(
            .prot_mode(prot_mode),
            .reference_clock_frequency (reference_clock_frequency),
            .vco_frequency (pll_output_clk_frequency),
            .feedback((operation_mode == "external") ? "EXT_FB": ((operation_mode == "source_synchronous") ? "SOURCE_SYNC" : ((operation_mode == "NDFB normal") ? "NON_DEDICATED_NORMAL" : ((operation_mode == "NDFB source synchronous") ? "NON_DEDICATED_SOURCE_SYNC" : operation_mode)))),  
            .output_clock_frequency_0(output_clock_frequency0),
            .output_clock_frequency_1(output_clock_frequency1),
            .output_clock_frequency_2(output_clock_frequency2),
            .output_clock_frequency_3(output_clock_frequency3),
            .output_clock_frequency_4(output_clock_frequency4),
            .output_clock_frequency_5(output_clock_frequency5),
            .output_clock_frequency_6(output_clock_frequency6),
            .output_clock_frequency_7(output_clock_frequency7),
            .output_clock_frequency_8(output_clock_frequency8),
            .phase_shift_0(phase_shift0),
            .phase_shift_1(phase_shift1),
            .phase_shift_2(phase_shift2),
            .phase_shift_3(phase_shift3),
            .phase_shift_4(phase_shift4),
            .phase_shift_5(phase_shift5),
            .phase_shift_6(phase_shift6),
            .phase_shift_7(phase_shift7),
            .phase_shift_8(phase_shift8),
            .duty_cycle_0(duty_cycle0),
            .duty_cycle_1(duty_cycle1),
            .duty_cycle_2(duty_cycle2),
            .duty_cycle_3(duty_cycle3),
            .duty_cycle_4(duty_cycle4),
            .duty_cycle_5(duty_cycle5),
            .duty_cycle_6(duty_cycle6),
            .duty_cycle_7(duty_cycle7),
            .duty_cycle_8(duty_cycle8),
            .pll_self_reset(pll_slf_rst),
            .pll_fbclk_mux_1(pll_fbclk_mux_1),
            .pll_fbclk_mux_2(pll_fbclk_mux_2),
            .pll_auto_clk_sw_en(pll_auto_clk_sw_en),
            .pll_clk_loss_sw_en(pll_clk_loss_sw_en),
            .pll_clk_sw_dly(pll_clk_sw_dly),
            .pll_manu_clk_sw_en(pll_manu_clk_sw_en),
            .pll_sw_refclk_src("pll_sw_refclk_src_clk_0"),
            .pll_clk_loss_edge("pll_clk_loss_rising_edge"),
            .pll_clkloss_det_en("true"),
            .pll_ref_clkloss_fltr_sel("pll_ref_clkloss_fltr_setting1"),
            .pll_clkin_0_src((pll_clkin_0_src == "clk_0") ? "pll_clkin_src_ioclkin_0" : (pll_clkin_0_src == "clk_1") ? "pll_clkin_src_ioclkin_1" : (pll_clkin_0_src == "adj_pll_clk") ? "pll_clkin_src_refclkin" : "pll_clkin_src_coreclkin"),
            .pll_clkin_1_src((pll_clkin_1_src == "clk_1") ? "pll_clkin_src_ioclkin_1" : (pll_clkin_1_src == "clk_0") ? "pll_clkin_src_ioclkin_0" : (pll_clkin_1_src == "adj_pll_clk") ? "pll_clkin_src_refclkin" : "pll_clkin_src_coreclkin"),
            .pll_c0_out_en(counter0_enable),
            .pll_c1_out_en(counter1_enable),
            .pll_c2_out_en(counter2_enable),
            .pll_c3_out_en(counter3_enable),
            .pll_c4_out_en(counter4_enable),
            .pll_c5_out_en(counter5_enable),
            .pll_c6_out_en(counter6_enable),
            .pll_c7_out_en(counter7_enable),
            .pll_c8_out_en(counter8_enable),
            .pll_c0_out_global_en("true"),
            .pll_c1_out_global_en("true"),
            .pll_c2_out_global_en("true"),
            .pll_c3_out_global_en("true"),
            .pll_c4_out_global_en("true"),
            .pll_c5_out_global_en("true"),
            .pll_c6_out_global_en("true"),
            .pll_c7_out_global_en("true"),
            .pll_c8_out_global_en("true"),
            .pll_c_counter_0_bypass_en (c_cnt_bypass_en0),
            .pll_c_counter_0_even_duty_en (c_cnt_odd_div_duty_en0),
            .pll_c_counter_0_high (c_cnt_hi_div0),
            .pll_c_counter_0_low (c_cnt_lo_div0),
            .pll_c_counter_0_ph_mux_prst (c_cnt_ph_mux_prst0),
            .pll_c_counter_0_prst (c_cnt_prst0),    
            .pll_c_counter_0_in_src("c_m_cnt_in_src_ph_mux_clk"),
            .pll_c_counter_1_bypass_en (c_cnt_bypass_en1),
            .pll_c_counter_1_even_duty_en (c_cnt_odd_div_duty_en1),
            .pll_c_counter_1_high (c_cnt_hi_div1),
            .pll_c_counter_1_low (c_cnt_lo_div1),
            .pll_c_counter_1_ph_mux_prst (c_cnt_ph_mux_prst1),
            .pll_c_counter_1_prst (c_cnt_prst1),
            .pll_c_counter_1_in_src("c_m_cnt_in_src_ph_mux_clk"),
            .pll_c_counter_2_bypass_en (c_cnt_bypass_en2),
            .pll_c_counter_2_even_duty_en (c_cnt_odd_div_duty_en2),
            .pll_c_counter_2_high (c_cnt_hi_div2),
            .pll_c_counter_2_low (c_cnt_lo_div2),
            .pll_c_counter_2_ph_mux_prst (c_cnt_ph_mux_prst2),
            .pll_c_counter_2_prst (c_cnt_prst2),
            .pll_c_counter_2_in_src("c_m_cnt_in_src_ph_mux_clk"),
            .pll_c_counter_3_bypass_en (c_cnt_bypass_en3),
            .pll_c_counter_3_even_duty_en (c_cnt_odd_div_duty_en3),
            .pll_c_counter_3_high (c_cnt_hi_div3),
            .pll_c_counter_3_low (c_cnt_lo_div3),
            .pll_c_counter_3_ph_mux_prst (c_cnt_ph_mux_prst3),
            .pll_c_counter_3_prst (c_cnt_prst3),
            .pll_c_counter_3_in_src("c_m_cnt_in_src_ph_mux_clk"),
            .pll_c_counter_4_bypass_en (c_cnt_bypass_en4),
            .pll_c_counter_4_even_duty_en (c_cnt_odd_div_duty_en4),
            .pll_c_counter_4_high (c_cnt_hi_div4),
            .pll_c_counter_4_low (c_cnt_lo_div4),
            .pll_c_counter_4_ph_mux_prst (c_cnt_ph_mux_prst4),
            .pll_c_counter_4_prst (c_cnt_prst4),
            .pll_c_counter_4_in_src("c_m_cnt_in_src_ph_mux_clk"),
            .pll_c_counter_5_bypass_en (c_cnt_bypass_en5),
            .pll_c_counter_5_even_duty_en (c_cnt_odd_div_duty_en5),
            .pll_c_counter_5_high (c_cnt_hi_div5),
            .pll_c_counter_5_low (c_cnt_lo_div5),
            .pll_c_counter_5_ph_mux_prst (c_cnt_ph_mux_prst5),
            .pll_c_counter_5_prst (c_cnt_prst5),
            .pll_c_counter_5_in_src("c_m_cnt_in_src_ph_mux_clk"),
            .pll_c_counter_6_bypass_en (c_cnt_bypass_en6),
            .pll_c_counter_6_even_duty_en (c_cnt_odd_div_duty_en6),
            .pll_c_counter_6_high (c_cnt_hi_div6),
            .pll_c_counter_6_low (c_cnt_lo_div6),
            .pll_c_counter_6_ph_mux_prst (c_cnt_ph_mux_prst6),
            .pll_c_counter_6_prst (c_cnt_prst6),
            .pll_c_counter_6_in_src("c_m_cnt_in_src_ph_mux_clk"),
            .pll_c_counter_7_bypass_en (c_cnt_bypass_en7),
            .pll_c_counter_7_even_duty_en (c_cnt_odd_div_duty_en7),
            .pll_c_counter_7_high (c_cnt_hi_div7),
            .pll_c_counter_7_low (c_cnt_lo_div7),
            .pll_c_counter_7_ph_mux_prst (c_cnt_ph_mux_prst7),
            .pll_c_counter_7_prst (c_cnt_prst7),
            .pll_c_counter_7_in_src("c_m_cnt_in_src_ph_mux_clk"),
            .pll_c_counter_8_bypass_en (c_cnt_bypass_en8),
            .pll_c_counter_8_even_duty_en (c_cnt_odd_div_duty_en8),
            .pll_c_counter_8_high (c_cnt_hi_div8),
            .pll_c_counter_8_low (c_cnt_lo_div8),
            .pll_c_counter_8_ph_mux_prst (c_cnt_ph_mux_prst8),
            .pll_c_counter_8_prst (c_cnt_prst8),
            .pll_c_counter_8_in_src("c_m_cnt_in_src_ph_mux_clk"),
            .pll_enable ("true"),
            .pll_ctrl_override_setting("true"),
            .pll_m_counter_bypass_en (m_cnt_bypass_en),
            .pll_m_counter_even_duty_en (m_cnt_odd_div_duty_en),
            .pll_m_counter_high(m_cnt_hi_div),
            .pll_m_counter_low(m_cnt_lo_div),
            .m_counter_scratch(eff_m_cnt),
            .pll_m_counter_in_src(pll_m_cnt_in_src),
            .pll_n_counter_bypass_en(n_cnt_bypass_en),
            .pll_n_counter_high(n_cnt_hi_div),
            .pll_n_counter_low(n_cnt_lo_div),
            .pll_n_counter_odd_div_duty_en (n_cnt_odd_div_duty_en),
            .pll_dly_0_enable("true"),
            .pll_dly_1_enable("true"),
            .pll_dly_2_enable("true"),
            .pll_dly_3_enable("true"),
            .pll_vco_ph0_en ("true"),
            .pll_vco_ph1_en ("true"),
            .pll_vco_ph2_en ("true"),
            .pll_vco_ph3_en ("true"),
            .pll_vco_ph4_en ("true"),
            .pll_vco_ph5_en ("true"),
            .pll_vco_ph6_en ("true"),
            .pll_vco_ph7_en ("true"),

            .pll_lock_fltr_cfg(pll_lock_fltr_cfg),
            .pll_unlock_fltr_cfg(pll_unlock_fltr_cfg),
            .bw_mode(pll_bw_sel),
            .pll_powerdown_mode("false"),
            .pll_vccr_pd_en("true"),
            .pll_bwctrl(pll_bwctrl),
            .pll_lockdet_sel("lckdet_setting4"),
            .pll_lockdet_hys_sel("lckdet_hys_setting4"),
            .pll_ripplecap_ctrl(pll_ripplecap_ctrl),
            .pll_cp_compensation("false"),
            .pll_cp_current_setting(pll_cp_current),
            .pll_extclk_0_cnt_src((operation_mode == "external" || operation_mode == "zdb") ? "pll_extclk_cnt_src_m_cnt": pll_extclk_0_cnt_src),
            .pll_extclk_0_enable("true"),
            .pll_extclk_1_cnt_src(pll_extclk_1_cnt_src),
            .pll_extclk_1_enable("true"),
            .pll_c0_extclk_dllout_en((pll_extclk_0_cnt_src == "pll_extclk_cnt_src_c_0_cnt" || pll_extclk_1_cnt_src == "pll_extclk_cnt_src_c_0_cnt") ? "true" : "false"),
            .pll_c1_extclk_dllout_en((pll_extclk_0_cnt_src == "pll_extclk_cnt_src_c_1_cnt" || pll_extclk_1_cnt_src == "pll_extclk_cnt_src_c_1_cnt") ? "true" : "false"),
            .pll_c2_extclk_dllout_en((pll_extclk_0_cnt_src == "pll_extclk_cnt_src_c_2_cnt" || pll_extclk_1_cnt_src == "pll_extclk_cnt_src_c_2_cnt") ? "true" : "false"),
            .pll_c3_extclk_dllout_en((pll_extclk_0_cnt_src == "pll_extclk_cnt_src_c_3_cnt" || pll_extclk_1_cnt_src == "pll_extclk_cnt_src_c_3_cnt") ? "true" : "false"),
            .clock_name_0 (clock_name_0),
            .clock_name_1 (clock_name_1),
            .clock_name_2 (clock_name_2),
            .clock_name_3 (clock_name_3),
            .clock_name_4 (clock_name_4),
            .clock_name_5 (clock_name_5),
            .clock_name_6 (clock_name_6),
            .clock_name_7 (clock_name_7),
            .clock_name_8 (clock_name_8),
            .clock_name_global_0 (clock_name_global),
            .clock_name_global_1 (clock_name_global),
            .clock_name_global_2 (clock_name_global),
            .clock_name_global_3 (clock_name_global),
            .clock_name_global_4 (clock_name_global),
            .clock_name_global_5 (clock_name_global),
            .clock_name_global_6 (clock_name_global),
            .clock_name_global_7 (clock_name_global),
            .clock_name_global_8 (clock_name_global),
            .clock_to_compensate (clock_to_compensate),
            .simple_pll ((pll_type == "S10_Simple") ? "true" : "false"),
            .merging_permitted (merging_permitted),
            .pll_reset_override_mode("false"),
            .pll_dprio_cr_dprio_interface_sel (dprio_interface_sel),
            .pll_dprio_force_inter_sel("false"),
            .cal_converge("false"),
            .cal_error("cal_clean"),
            .pll_cal_done("false"),
            .pll_defer_cal_user_mode(pll_defer_cal_user_mode),
            .pll_cal_freqcal_en("true"),
            .pll_cal_freqcal_rstb("freqcal_reset"),
            .pll_cal_offset_vreg0(0),
            .pll_cal_offset_vreg1(0),
            .pll_dprio_base_addr(0),
            .pll_uc_channel_base_addr(16'h0),
            .pll_dprio_broadcast_en("false"),
            .pll_dprio_cvp_inter_sel("false"),
            .pll_dprio_extra_csr(0),
            .pll_dprio_power_iso_en("false"),
            .pll_dprio_r_calibration_en_ctrl("r_calibration_en"),
            .pll_freqcal_biasctl("freqcal_bias_setting1"),
            .pll_freqcal_en(pll_freqcal_en),
            .pll_freqcal_req_flag("true"),
            .pll_user_handle_cal_fail("nios_control")

        ) fourteennm_pll (
            .clken(2'b00),
            .cnt_sel(pll_subtype != "General" ? final_cntsel : 4'b0),
            .core_refclk(1'b0),
            .csr_clk(1'b1),
            .csr_en(1'b1),
            .csr_in(1'b1),
            .dprio_clk(pll_subtype != "General" ? (pll_subtype == "DPS" ? scanclk : reconfig_to_pll[0]) : 1'b0),
            .dprio_rst_n(pll_subtype == "Reconfigurable" ? dprio_rst_n_wire : rst_n_wire),
            .dprio_address(pll_subtype == "Reconfigurable" ? reconfig_to_pll[12:4] : 9'b0),
            .read(pll_subtype == "Reconfigurable" ? reconfig_to_pll[2] : 1'b0),
            .write(pll_subtype == "Reconfigurable" ? reconfig_to_pll[3] : 1'b0),
            .writedata(pll_subtype == "Reconfigurable" ? reconfig_to_pll[20:13] : 8'b0),
            .dps_rst_n(rst_n_wire),
            .extswitch(extswitch),
            .fbclk_in((operation_mode == "normal" || operation_mode == "source_synchronous") ? feedback_clk :((operation_mode == "NDFB normal" || operation_mode == "NDFB source synchronous") ? outclk[clock_to_compensate] : 1'b0)),
            .fblvds_in((operation_mode == "lvds") ? lvds_fbclk : 1'b0),
            .mdio_dis(1'b0),
            .num_phase_shifts(pll_subtype != "General" ? final_num_ps : 3'b0),
            .pfden(1'b1),
            .phase_en(pll_subtype != "General" ? final_phase_en : 1'b0 ),
            .pipeline_global_en_n(1'b0),
            .pll_cascade_in(adjpllin_wire),
            .pma_csr_test_dis(1'b1),
            .refclk({2'b0,refclk1, refclk}),
            .rst_n(rst_n_wire),
            .scan_mode_n(1'b1),
            .scan_shift_n(1'b1),
            .uc_cal_addr(20'b0),
            .uc_cal_clk(1'b0),
            .uc_cal_read(1'b0),
            .uc_cal_write(1'b0),
            .uc_cal_writedata(8'b0),
            .up_dn(pll_subtype != "General" ? final_updn : 1'b0),
            .user_mode(1'b1),
            .zdb_in((operation_mode == "external") ? fb_clkin : (operation_mode == "zdb") ? fb_out_clk : 1'b0),
            .block_select(),
            .clk0_bad(clkbad[0]),
            .clk1_bad(clkbad[1]),
            .clksel(activeclk),
            .csr_out(),
            .dll_output(),
            .extclk_dft(),
            .extclk_output({extclk_out[1], fboutclk_wire}),
            .fbclk_out(feedback_clk),
            .fblvds_out(lvds_fbclk),
            .lf_reset(),
            .loaden(loaden),
            .lock(locked_wire),
            .lvds_clk(lvds_clk),
            .outclk(outclk), //Would need to tie off some of the outclks here
            .phase_done(phase_done),
            .pll_cascade_out(cascade_out),
            .pll_pd(),
            .readdata(reconfig_from_pll_wire[7:0]),
            .vcop_en(),
            .vcoph(phout),
            .cal_ok(cal_ok_wire)
        );
                    
        assign reconfig_from_pll_wire[8] = locked_wire;
        assign reconfig_from_pll_wire[9] = phase_done;
        assign reconfig_from_pll_wire[10] = cal_ok_wire;
        assign extclk_out[0] = fboutclk_wire;
    end        
endgenerate

assign fboutclk = (operation_mode == "external" || operation_mode == "zdb") ? fb_out_clk : fboutclk_wire; 
assign locked = locked_wire;

// ==================================================================================
// Create clock buffers for fbclk,  fboutclk and zdbfbclk if necessary.
// ==================================================================================
generate
    if (operation_mode == "external")
    begin: fb_ibuf
        alt_inbuf #(.enable_bus_hold("NONE")) fb_ibuf (
            .i(fbclk),
            .o(fb_clkin)
        );
    end
endgenerate

generate 
    if (operation_mode == "external")
    begin: fb_obuf
        alt_outbuf #(.enable_bus_hold("NONE"))  fb_obuf (
            .i(fboutclk_wire),
            .o(fb_out_clk)
        );
    end
endgenerate

generate
    if (operation_mode == "zdb")
    begin: fb_iobuf
        alt_iobuf #(.enable_bus_hold("NONE"))  fb_iobuf (
            .i(fboutclk_wire),
            .oe(1'b1),
            .io(zdbfbclk),
            .o(fb_out_clk)
        );
    end
    else
    begin
        assign zdbfbclk = 0;
    end
endgenerate

endmodule


// =================================================================================
// The final_phase_en signal should be a signal pulse (there was a silicon bug
// involving this problem on Arria 10. DPS pulse gen generates a singe final_phase_en
// pulse when the user_phase_en goes high.
// It also delays the other signal by one clock cycle
// =================================================================================

module dps_pulse_gen_fourteennm_iopll (
    input  wire clk,            // the DPS clock
    input  wire rst,            // active high reset
    input  wire user_phase_en,  // the user's phase_en signal
    input  wire user_updn,     
    input  wire [2:0] user_num_ps,  
    input  wire [3:0] user_cntsel,  
    output reg  phase_en,        // the phase_en signal for the IOPLL atom
    output reg updn,     
    output reg [2:0] num_ps,  
    output reg [3:0] cntsel  
 );
 
    //-------------------------------------------------------------------------
    // States
    localparam IDLE        = 0,  // Idle state: user_phase_en = 0, phase_en = 0
               PULSE       = 1,  // Activate state: phase_en = 1
               WAIT        = 2;  // Wait for user_phase_en to go low

    //-------------------------------------------------------------------------
    // FSM current and next states
    reg [1:0] state, next;     
    
    // State update
    always @(posedge clk) begin
    
        updn <= user_updn;
        cntsel <= user_cntsel;
        num_ps <= user_num_ps;
    
        if (rst)    state <= IDLE;
        else        state <= next; 
    end  

    //-------------------------------------------------------------------------    
    // Next-state and output logic
    always @(*) begin
        next     = IDLE;  // Default next state 
        phase_en = 1'b0;  // Default output
        
        case (state)
            IDLE :  begin
                        if (user_phase_en)  next = PULSE;
                        else                next = IDLE;
                    end     
                         
            PULSE : begin
                        phase_en = 1'b1;
                        next     = WAIT;
                    end
                         
            WAIT :  begin         
                        if (~user_phase_en) next = IDLE;
                        else                next = WAIT;                  
                    end  
        endcase
    end
     
 endmodule

