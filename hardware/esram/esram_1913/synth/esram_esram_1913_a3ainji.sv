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


// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

module esram_esram_1913_a3ainji
    #(
        //==========================//
        // Channel 0 Parameters     //
        //==========================//
        parameter       c0_disable          = "FALSE",              //FALSE - Channel 0 is enabled; TRUE - Channel 0 is disabled
        parameter       c0_bank_enable      = "C0_EN_1BANK",        //C0_EN_<number of bank>BANK - Indicate number of bank in channel 0
        parameter       c0_ecc_enable       = "FALSE",              //FALSE - ECC is disabled for Channel 0; TRUE - ECC is enabled for channel 0
        parameter       c0_ecc_byp_enable   = "FALSE",              //FALSE - ECC bypass is disabled for Channel 0; TRUE - ECC bypass is enabled for channel 0
        parameter       c0_wr_fwd_enable    = "FALSE",              //FALSE - Write Forwarding is disabled for Channel 0; TRUE - Write Forwarding is enabled for channel 0
        parameter       c0_lpmode_enable    = "FALSE",              //FALSE - Low Power Mode is disabled for Channel 0; TRUE - Low Power Mode is enabled for channel 0
        parameter       c0_data_width       = 72,                   //1 to 72 - The width for both data and output.
        parameter       c0_address_width    = 17,                   //11 to 17 - The address width for both write and read, calculated from number of words.

        //==========================//
        // Channel 1 Parameters     //
        //==========================//
        parameter       c1_disable          = "TRUE",               //FALSE - Channel 1 is enabled; TRUE - Channel 1 is disabled
        parameter       c1_bank_enable      = "C1_EN_0BANK",        //C0_EN_<number of bank>BANK - Indicate number of bank in channel 1
        parameter       c1_ecc_enable       = "FALSE",              //FALSE - ECC is disabled for Channel 1; TRUE - ECC is enabled for channel 1
        parameter       c1_ecc_byp_enable   = "FALSE",              //FALSE - ECC bypass is disabled for Channel 1; TRUE - ECC bypass is enabled for channel 1
        parameter       c1_wr_fwd_enable    = "FALSE",              //FALSE - Write Forwarding is disabled for Channel 1; TRUE - Write Forwarding is enabled for channel 1
        parameter       c1_lpmode_enable    = "FALSE",              //FALSE - Low Power Mode is disabled for Channel 1; TRUE - Low Power Mode is enabled for channel 1
        parameter       c1_data_width       = 72,                   //1 to 72 - The width for both data and output.
        parameter       c1_address_width    = 17,                   //11 to 17 - The address width for both write and read, calculated from number of words.

        //==========================//
        // Channel 2 Parameters     //
        //==========================//
        parameter       c2_disable          = "TRUE",               //FALSE - Channel 2 is enabled; TRUE - Channel 2 is disabled
        parameter       c2_bank_enable      = "C2_EN_0BANK",        //C2_EN_<number of bank>BANK - Indicate number of bank in channel 2
        parameter       c2_ecc_enable       = "FALSE",              //FALSE - ECC is disabled for Channel 2; TRUE - ECC is enabled for channel 2
        parameter       c2_ecc_byp_enable   = "FALSE",              //FALSE - ECC bypass is disabled for Channel 2; TRUE - ECC bypass is enabled for channel 2
        parameter       c2_wr_fwd_enable    = "FALSE",              //FALSE - Write Forwarding is disabled for Channel 2; TRUE - Write Forwarding is enabled for channel 2
        parameter       c2_lpmode_enable    = "FALSE",              //FALSE - Low Power Mode is disabled for Channel 2; TRUE - Low Power Mode is enabled for channel 2
        parameter       c2_data_width       = 72,                   //1 to 72 - The width for both data and output.
        parameter       c2_address_width    = 17,                   //11 to 17 - The address width for both write and read, calculated from number of words.

        //==========================//
        // Channel 3 Parameters     //
        //==========================//
        parameter       c3_disable          = "TRUE",               //FALSE - Channel 3 is enabled; TRUE - Channel 3 is disabled
        parameter       c3_bank_enable      = "C3_EN_0BANK",        //C3_EN_<number of bank>BANK - Indicate number of bank in channel 3
        parameter       c3_ecc_enable       = "FALSE",              //FALSE - ECC is disabled for Channel 3; TRUE - ECC is enabled for channel 3
        parameter       c3_ecc_byp_enable   = "FALSE",              //FALSE - ECC bypass is disabled for Channel 3; TRUE - ECC bypass is enabled for channel 3
        parameter       c3_wr_fwd_enable    = "FALSE",              //FALSE - Write Forwarding is disabled for Channel 3; TRUE - Write Forwarding is enabled for channel 3
        parameter       c3_lpmode_enable    = "FALSE",              //FALSE - Low Power Mode is disabled for Channel 3; TRUE - Low Power Mode is enabled for channel 3
        parameter       c3_data_width       = 72,                   //1 to 72 - The width for both data and output.
        parameter       c3_address_width    = 17,                   //11 to 17 - The address width for both write and read, calculated from number of words.

        //==========================//
        // Channel 4 Parameters     //
        //==========================//
        parameter       c4_disable          = "TRUE",               //FALSE - Channel 4 is enabled; TRUE - Channel 4 is disabled
        parameter       c4_bank_enable      = "C4_EN_0BANK",        //C4_EN_<number of bank>BANK - Indicate number of bank in channel 4
        parameter       c4_ecc_enable       = "FALSE",              //FALSE - ECC is disabled for Channel 4; TRUE - ECC is enabled for channel 4
        parameter       c4_ecc_byp_enable   = "FALSE",              //FALSE - ECC bypass is disabled for Channel 4; TRUE - ECC bypass is enabled for channel 4
        parameter       c4_wr_fwd_enable    = "FALSE",              //FALSE - Write Forwarding is disabled for Channel 4; TRUE - Write Forwarding is enabled for channel 4
        parameter       c4_lpmode_enable    = "FALSE",              //FALSE - Low Power Mode is disabled for Channel 4; TRUE - Low Power Mode is enabled for channel 4
        parameter       c4_data_width       = 72,                   //1 to 72 - The width for both data and output.
        parameter       c4_address_width    = 17,                   //11 to 17 - The address width for both write and read, calculated from number of words.

        //==========================//
        // Channel 5 Parameters     //
        //==========================//
        parameter       c5_disable          = "TRUE",               //FALSE - Channel 5 is enabled; TRUE - Channel 5 is disabled
        parameter       c5_bank_enable      = "C5_EN_0BANK",        //C5_EN_<number of bank>BANK - Indicate number of bank in channel 5
        parameter       c5_ecc_enable       = "FALSE",              //FALSE - ECC is disabled for Channel 5; TRUE - ECC is enabled for channel 5
        parameter       c5_ecc_byp_enable   = "FALSE",              //FALSE - ECC bypass is disabled for Channel 5; TRUE - ECC bypass is enabled for channel 5
        parameter       c5_wr_fwd_enable    = "FALSE",              //FALSE - Write Forwarding is disabled for Channel 5; TRUE - Write Forwarding is enabled for channel 5
        parameter       c5_lpmode_enable    = "FALSE",              //FALSE - Low Power Mode is disabled for Channel 5; TRUE - Low Power Mode is enabled for channel 5
        parameter       c5_data_width       = 72,                   //1 to 72 - The width for both data and output.
        parameter       c5_address_width    = 17,                   //11 to 17 - The address width for both write and read, calculated from number of words.

        //==========================//
        // Channel 6 Parameters     //
        //==========================//
        parameter       c6_disable          = "TRUE",               //FALSE - Channel 6 is enabled; TRUE - Channel 6 is disabled
        parameter       c6_bank_enable      = "C6_EN_0BANK",        //C6_EN_<number of bank>BANK - Indicate number of bank in channel 6
        parameter       c6_ecc_enable       = "FALSE",              //FALSE - ECC is disabled for Channel 6; TRUE - ECC is enabled for channel 6
        parameter       c6_ecc_byp_enable   = "FALSE",              //FALSE - ECC bypass is disabled for Channel 6; TRUE - ECC bypass is enabled for channel 6
        parameter       c6_wr_fwd_enable    = "FALSE",              //FALSE - Write Forwarding is disabled for Channel 6; TRUE - Write Forwarding is enabled for channel 6
        parameter       c6_lpmode_enable    = "FALSE",              //FALSE - Low Power Mode is disabled for Channel 6; TRUE - Low Power Mode is enabled for channel 6
        parameter       c6_data_width       = 72,                   //1 to 72 - The width for both data and output.
        parameter       c6_address_width    = 17,                   //11 to 17 - The address width for both write and read, calculated from number of words.

        //==========================//
        // Channel 7 Parameters     //
        //==========================//
        parameter       c7_disable          = "TRUE",               //FALSE - Channel 7 is enabled; TRUE - Channel 7 is disabled
        parameter       c7_bank_enable      = "C7_EN_0BANK",        //C7_EN_<number of bank>BANK - Indicate number of bank in channel 7
        parameter       c7_ecc_enable       = "FALSE",              //FALSE - ECC is disabled for Channel 7; TRUE - ECC is enabled for channel 7
        parameter       c7_ecc_byp_enable   = "FALSE",              //FALSE - ECC bypass is disabled for Channel 7; TRUE - ECC bypass is enabled for channel 7
        parameter       c7_wr_fwd_enable    = "FALSE",              //FALSE - Write Forwarding is disabled for Channel 7; TRUE - Write Forwarding is enabled for channel 7
        parameter       c7_lpmode_enable    = "FALSE",              //FALSE - Low Power Mode is disabled for Channel 7; TRUE - Low Power Mode is enabled for channel 7
        parameter       c7_data_width       = 72,                   //1 to 72 - The width for both data and output.
        parameter       c7_address_width    = 17,                   //11 to 17 - The address width for both write and read, calculated from number of words.

        //==========================//
        // eSRAM General Parameters //
        //==========================//
        parameter   clock_rate              = "FULLRATE",

        //=======================================================//
        // Please DO NOT change the value of each Parameter here,//
        // THEY are auto set according to clock_rate             //
        //=======================================================//

        parameter   c2p_ptr_dly     = "C2P_ONE_CYCLE_DLY",
        parameter   p2c_ptr_dly     = "P2C_ONE_CYCLE_DLY",
        parameter   xs0_dcm_ufimux32to1_dolsgn_rc_dolsgn_0_a_sel_11_0 = "C2PCLK0_D0",
        parameter   xs0_dcm_ufimux32to1_dolsgn_rc_dolsgn_1_a_sel_11_0 = "C2PCLK0_D0"
    )(
    //======================//
    //  Declaration of port //
    //======================//
    input                           refclk,
    //Full rate port
    //channel 0
    input   [c0_data_width-1:0]     c0_data_0,
    input   [c0_address_width-1:0]     c0_rdaddress_0,
    input                           c0_rden_n_0,
    input                           c0_sd_n_0,
    input   [c0_address_width-1:0]     c0_wraddress_0,
    input                           c0_wren_n_0,
    output  [c0_data_width-1:0]     c0_q_0,
    //channel 1
    input   [c1_data_width-1:0]     c1_data_0,
    input   [c1_address_width-1:0]     c1_rdaddress_0,
    input                           c1_rden_n_0,
    input                           c1_sd_n_0,
    input   [c1_address_width-1:0]     c1_wraddress_0,
    input                           c1_wren_n_0,
    output  [c1_data_width-1:0]     c1_q_0,
    //channel 2
    input   [c2_data_width-1:0]     c2_data_0,
    input   [c2_address_width-1:0]     c2_rdaddress_0,
    input                           c2_rden_n_0,
    input                           c2_sd_n_0,
    input   [c2_address_width-1:0]     c2_wraddress_0,
    input                           c2_wren_n_0,
    output  [c2_data_width-1:0]     c2_q_0,
    //channel 3
    input   [c3_data_width-1:0]     c3_data_0,
    input   [c3_address_width-1:0]     c3_rdaddress_0,
    input                           c3_rden_n_0,
    input                           c3_sd_n_0,
    input   [c3_address_width-1:0]     c3_wraddress_0,
    input                           c3_wren_n_0,
    output  [c3_data_width-1:0]     c3_q_0,
    //channel 4
    input   [c4_data_width-1:0]     c4_data_0,
    input   [c4_address_width-1:0]     c4_rdaddress_0,
    input                           c4_rden_n_0,
    input                           c4_sd_n_0,
    input   [c4_address_width-1:0]     c4_wraddress_0,
    input                           c4_wren_n_0,
    output  [c4_data_width-1:0]     c4_q_0,
    //channel 5
    input   [c5_data_width-1:0]     c5_data_0,
    input   [c5_address_width-1:0]     c5_rdaddress_0,
    input                           c5_rden_n_0,
    input                           c5_sd_n_0,
    input   [c5_address_width-1:0]     c5_wraddress_0,
    input                           c5_wren_n_0,
    output  [c5_data_width-1:0]     c5_q_0,
    //channel 6
    input   [c6_data_width-1:0]     c6_data_0,
    input   [c6_address_width-1:0]     c6_rdaddress_0,
    input                           c6_rden_n_0,
    input                           c6_sd_n_0,
    input   [c6_address_width-1:0]     c6_wraddress_0,
    input                           c6_wren_n_0,
    output  [c6_data_width-1:0]     c6_q_0,
    //channel 7
    input   [c7_data_width-1:0]     c7_data_0,
    input   [c7_address_width-1:0]     c7_rdaddress_0,
    input                           c7_rden_n_0,
    input                           c7_sd_n_0,
    input   [c7_address_width-1:0]     c7_wraddress_0,
    input                           c7_wren_n_0,
    output  [c7_data_width-1:0]     c7_q_0,
    output                          iopll_lock2core,
    output                          esram2f_clk
    );

    // start of reg and wire

    wire [1:0]  esram2f_clk_w;
    wire        iopll_lock2core_ufi;

    // iopll lock status reg and wire declaration
    wire        iopll_lock2core_w;
    reg iopll_lock2core_reg/* synthesis dont_merge */;

    //Full rate wire and reg
    //channel 0
    wire   [c0_data_width-1:0]     c0_data_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c0_data_width-1:0]     c0_data_0_reg/* synthesis dont_merge */;
    wire   [c0_address_width-1:0]     c0_rdaddress_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c0_address_width-1:0]     c0_rdaddress_0_reg/* synthesis dont_merge */;
    wire                           c0_rden_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c0_rden_n_0_reg/* synthesis dont_merge */;
    wire                           c0_sd_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c0_sd_n_0_reg/* synthesis dont_merge */;
    wire   [c0_address_width-1:0]     c0_wraddress_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c0_address_width-1:0]     c0_wraddress_0_reg/* synthesis dont_merge */;
    wire                           c0_wren_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c0_wren_n_0_reg/* synthesis dont_merge */;
    wire                           c0_eccdecbypass_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c0_eccdecbypass_0_reg/* synthesis dont_merge */;
    reg c0_eccdecbypass_0_align_0_reg;
    reg c0_eccdecbypass_0_align_1_reg;
    wire                           c0_eccencbypass_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c0_eccencbypass_0_reg/* synthesis dont_merge */;
    wire  [c0_data_width-1:0]     c0_q_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  [c0_data_width-1:0]     c0_q_0_reg/* synthesis dont_merge */;
    wire                          c0_error_correct_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  c0_error_correct_0_reg/* synthesis dont_merge */;
    wire                          c0_error_detect_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  c0_error_detect_0_reg/* synthesis dont_merge */;
    //channel 1
    wire   [c1_data_width-1:0]     c1_data_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c1_data_width-1:0]     c1_data_0_reg/* synthesis dont_merge */;
    wire   [c1_address_width-1:0]     c1_rdaddress_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c1_address_width-1:0]     c1_rdaddress_0_reg/* synthesis dont_merge */;
    wire                           c1_rden_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c1_rden_n_0_reg/* synthesis dont_merge */;
    wire                           c1_sd_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c1_sd_n_0_reg/* synthesis dont_merge */;
    wire   [c1_address_width-1:0]     c1_wraddress_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c1_address_width-1:0]     c1_wraddress_0_reg/* synthesis dont_merge */;
    wire                           c1_wren_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c1_wren_n_0_reg/* synthesis dont_merge */;
    wire                           c1_eccdecbypass_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c1_eccdecbypass_0_reg/* synthesis dont_merge */;
    reg c1_eccdecbypass_0_align_0_reg;
    reg c1_eccdecbypass_0_align_1_reg;
    wire                           c1_eccencbypass_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c1_eccencbypass_0_reg/* synthesis dont_merge */;
    wire  [c1_data_width-1:0]     c1_q_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  [c1_data_width-1:0]     c1_q_0_reg/* synthesis dont_merge */;
    wire                          c1_error_correct_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  c1_error_correct_0_reg/* synthesis dont_merge */;
    wire                          c1_error_detect_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  c1_error_detect_0_reg/* synthesis dont_merge */;
    //channel 2
    wire   [c2_data_width-1:0]     c2_data_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c2_data_width-1:0]     c2_data_0_reg/* synthesis dont_merge */;
    wire   [c2_address_width-1:0]     c2_rdaddress_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c2_address_width-1:0]     c2_rdaddress_0_reg/* synthesis dont_merge */;
    wire                           c2_rden_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c2_rden_n_0_reg/* synthesis dont_merge */;
    wire                           c2_sd_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c2_sd_n_0_reg/* synthesis dont_merge */;
    wire   [c2_address_width-1:0]     c2_wraddress_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c2_address_width-1:0]     c2_wraddress_0_reg/* synthesis dont_merge */;
    wire                           c2_wren_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c2_wren_n_0_reg/* synthesis dont_merge */;
    wire                           c2_eccdecbypass_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c2_eccdecbypass_0_reg/* synthesis dont_merge */;
    reg c2_eccdecbypass_0_align_0_reg;
    reg c2_eccdecbypass_0_align_1_reg;
    wire                           c2_eccencbypass_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c2_eccencbypass_0_reg/* synthesis dont_merge */;
    wire  [c2_data_width-1:0]     c2_q_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  [c2_data_width-1:0]     c2_q_0_reg/* synthesis dont_merge */;
    wire                          c2_error_correct_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  c2_error_correct_0_reg/* synthesis dont_merge */;
    wire                          c2_error_detect_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  c2_error_detect_0_reg/* synthesis dont_merge */;
    //channel 3
    wire   [c3_data_width-1:0]     c3_data_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c3_data_width-1:0]     c3_data_0_reg/* synthesis dont_merge */;
    wire   [c3_address_width-1:0]     c3_rdaddress_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c3_address_width-1:0]     c3_rdaddress_0_reg/* synthesis dont_merge */;
    wire                           c3_rden_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c3_rden_n_0_reg/* synthesis dont_merge */;
    wire                           c3_sd_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c3_sd_n_0_reg/* synthesis dont_merge */;
    wire   [c3_address_width-1:0]     c3_wraddress_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c3_address_width-1:0]     c3_wraddress_0_reg/* synthesis dont_merge */;
    wire                           c3_wren_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c3_wren_n_0_reg/* synthesis dont_merge */;
    wire                           c3_eccdecbypass_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c3_eccdecbypass_0_reg/* synthesis dont_merge */;
    reg c3_eccdecbypass_0_align_0_reg;
    reg c3_eccdecbypass_0_align_1_reg;
    wire                           c3_eccencbypass_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c3_eccencbypass_0_reg/* synthesis dont_merge */;
    wire  [c3_data_width-1:0]     c3_q_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  [c3_data_width-1:0]     c3_q_0_reg/* synthesis dont_merge */;
    wire                          c3_error_correct_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  c3_error_correct_0_reg/* synthesis dont_merge */;
    wire                          c3_error_detect_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  c3_error_detect_0_reg/* synthesis dont_merge */;
    //channel 4
    wire   [c4_data_width-1:0]     c4_data_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c4_data_width-1:0]     c4_data_0_reg/* synthesis dont_merge */;
    wire   [c4_address_width-1:0]     c4_rdaddress_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c4_address_width-1:0]     c4_rdaddress_0_reg/* synthesis dont_merge */;
    wire                           c4_rden_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c4_rden_n_0_reg/* synthesis dont_merge */;
    wire                           c4_sd_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c4_sd_n_0_reg/* synthesis dont_merge */;
    wire   [c4_address_width-1:0]     c4_wraddress_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c4_address_width-1:0]     c4_wraddress_0_reg/* synthesis dont_merge */;
    wire                           c4_wren_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c4_wren_n_0_reg/* synthesis dont_merge */;
    wire                           c4_eccdecbypass_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c4_eccdecbypass_0_reg/* synthesis dont_merge */;
    reg c4_eccdecbypass_0_align_0_reg;
    reg c4_eccdecbypass_0_align_1_reg;
    wire                           c4_eccencbypass_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c4_eccencbypass_0_reg/* synthesis dont_merge */;
    wire  [c4_data_width-1:0]     c4_q_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  [c4_data_width-1:0]     c4_q_0_reg/* synthesis dont_merge */;
    wire                          c4_error_correct_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  c4_error_correct_0_reg/* synthesis dont_merge */;
    wire                          c4_error_detect_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  c4_error_detect_0_reg/* synthesis dont_merge */;
    //channel 5
    wire   [c5_data_width-1:0]     c5_data_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c5_data_width-1:0]     c5_data_0_reg/* synthesis dont_merge */;
    wire   [c5_address_width-1:0]     c5_rdaddress_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c5_address_width-1:0]     c5_rdaddress_0_reg/* synthesis dont_merge */;
    wire                           c5_rden_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c5_rden_n_0_reg/* synthesis dont_merge */;
    wire                           c5_sd_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c5_sd_n_0_reg/* synthesis dont_merge */;
    wire   [c5_address_width-1:0]     c5_wraddress_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c5_address_width-1:0]     c5_wraddress_0_reg/* synthesis dont_merge */;
    wire                           c5_wren_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c5_wren_n_0_reg/* synthesis dont_merge */;
    wire                           c5_eccdecbypass_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c5_eccdecbypass_0_reg/* synthesis dont_merge */;
    reg c5_eccdecbypass_0_align_0_reg;
    reg c5_eccdecbypass_0_align_1_reg;
    wire                           c5_eccencbypass_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c5_eccencbypass_0_reg/* synthesis dont_merge */;
    wire  [c5_data_width-1:0]     c5_q_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  [c5_data_width-1:0]     c5_q_0_reg/* synthesis dont_merge */;
    wire                          c5_error_correct_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  c5_error_correct_0_reg/* synthesis dont_merge */;
    wire                          c5_error_detect_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  c5_error_detect_0_reg/* synthesis dont_merge */;
    //channel 6
    wire   [c6_data_width-1:0]     c6_data_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c6_data_width-1:0]     c6_data_0_reg/* synthesis dont_merge */;
    wire   [c6_address_width-1:0]     c6_rdaddress_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c6_address_width-1:0]     c6_rdaddress_0_reg/* synthesis dont_merge */;
    wire                           c6_rden_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c6_rden_n_0_reg/* synthesis dont_merge */;
    wire                           c6_sd_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c6_sd_n_0_reg/* synthesis dont_merge */;
    wire   [c6_address_width-1:0]     c6_wraddress_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c6_address_width-1:0]     c6_wraddress_0_reg/* synthesis dont_merge */;
    wire                           c6_wren_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c6_wren_n_0_reg/* synthesis dont_merge */;
    wire                           c6_eccdecbypass_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c6_eccdecbypass_0_reg/* synthesis dont_merge */;
    reg c6_eccdecbypass_0_align_0_reg;
    reg c6_eccdecbypass_0_align_1_reg;
    wire                           c6_eccencbypass_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c6_eccencbypass_0_reg/* synthesis dont_merge */;
    wire  [c6_data_width-1:0]     c6_q_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  [c6_data_width-1:0]     c6_q_0_reg/* synthesis dont_merge */;
    wire                          c6_error_correct_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  c6_error_correct_0_reg/* synthesis dont_merge */;
    wire                          c6_error_detect_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  c6_error_detect_0_reg/* synthesis dont_merge */;
    //channel 7
    wire   [c7_data_width-1:0]     c7_data_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c7_data_width-1:0]     c7_data_0_reg/* synthesis dont_merge */;
    wire   [c7_address_width-1:0]     c7_rdaddress_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c7_address_width-1:0]     c7_rdaddress_0_reg/* synthesis dont_merge */;
    wire                           c7_rden_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c7_rden_n_0_reg/* synthesis dont_merge */;
    wire                           c7_sd_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c7_sd_n_0_reg/* synthesis dont_merge */;
    wire   [c7_address_width-1:0]     c7_wraddress_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  [c7_address_width-1:0]     c7_wraddress_0_reg/* synthesis dont_merge */;
    wire                           c7_wren_n_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c7_wren_n_0_reg/* synthesis dont_merge */;
    wire                           c7_eccdecbypass_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c7_eccdecbypass_0_reg/* synthesis dont_merge */;
    reg c7_eccdecbypass_0_align_0_reg;
    reg c7_eccdecbypass_0_align_1_reg;
    wire                           c7_eccencbypass_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"*)  logic  c7_eccencbypass_0_reg/* synthesis dont_merge */;
    wire  [c7_data_width-1:0]     c7_q_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  [c7_data_width-1:0]     c7_q_0_reg/* synthesis dont_merge */;
    wire                          c7_error_correct_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  c7_error_correct_0_reg/* synthesis dont_merge */;
    wire                          c7_error_detect_0_w;
    (* altera_attribute = "-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"*)  logic  c7_error_detect_0_reg/* synthesis dont_merge */;

    always @(posedge esram2f_clk_w[0])
    begin
        //Full rate
        //channel 0
        c0_data_0_reg     <= c0_data_0_w;
        c0_rdaddress_0_reg     <= c0_rdaddress_0_w;
        c0_rden_n_0_reg     <= c0_rden_n_0_w;
        c0_sd_n_0_reg     <= c0_sd_n_0_w;
        c0_wraddress_0_reg     <= c0_wraddress_0_w;
        c0_wren_n_0_reg     <= c0_wren_n_0_w;
        c0_eccdecbypass_0_align_0_reg     <= c0_eccdecbypass_0_w;
        c0_eccdecbypass_0_align_1_reg     <= c0_eccdecbypass_0_align_0_reg;
        c0_eccdecbypass_0_reg             <= c0_eccdecbypass_0_align_1_reg;
        c0_eccencbypass_0_reg     <= c0_eccencbypass_0_w;
        c0_q_0_reg    <= c0_q_0_w;
        c0_error_correct_0_reg    <= c0_error_correct_0_w;
        c0_error_detect_0_reg    <= c0_error_detect_0_w;
        //channel 1
        c1_data_0_reg     <= c1_data_0_w;
        c1_rdaddress_0_reg     <= c1_rdaddress_0_w;
        c1_rden_n_0_reg     <= c1_rden_n_0_w;
        c1_sd_n_0_reg     <= c1_sd_n_0_w;
        c1_wraddress_0_reg     <= c1_wraddress_0_w;
        c1_wren_n_0_reg     <= c1_wren_n_0_w;
        c1_eccdecbypass_0_align_0_reg     <= c1_eccdecbypass_0_w;
        c1_eccdecbypass_0_align_1_reg     <= c1_eccdecbypass_0_align_0_reg;
        c1_eccdecbypass_0_reg             <= c1_eccdecbypass_0_align_1_reg;
        c1_eccencbypass_0_reg     <= c1_eccencbypass_0_w;
        c1_q_0_reg    <= c1_q_0_w;
        c1_error_correct_0_reg    <= c1_error_correct_0_w;
        c1_error_detect_0_reg    <= c1_error_detect_0_w;
        //channel 2
        c2_data_0_reg     <= c2_data_0_w;
        c2_rdaddress_0_reg     <= c2_rdaddress_0_w;
        c2_rden_n_0_reg     <= c2_rden_n_0_w;
        c2_sd_n_0_reg     <= c2_sd_n_0_w;
        c2_wraddress_0_reg     <= c2_wraddress_0_w;
        c2_wren_n_0_reg     <= c2_wren_n_0_w;
        c2_eccdecbypass_0_align_0_reg     <= c2_eccdecbypass_0_w;
        c2_eccdecbypass_0_align_1_reg     <= c2_eccdecbypass_0_align_0_reg;
        c2_eccdecbypass_0_reg             <= c2_eccdecbypass_0_align_1_reg;
        c2_eccencbypass_0_reg     <= c2_eccencbypass_0_w;
        c2_q_0_reg    <= c2_q_0_w;
        c2_error_correct_0_reg    <= c2_error_correct_0_w;
        c2_error_detect_0_reg    <= c2_error_detect_0_w;
        //channel 3
        c3_data_0_reg     <= c3_data_0_w;
        c3_rdaddress_0_reg     <= c3_rdaddress_0_w;
        c3_rden_n_0_reg     <= c3_rden_n_0_w;
        c3_sd_n_0_reg     <= c3_sd_n_0_w;
        c3_wraddress_0_reg     <= c3_wraddress_0_w;
        c3_wren_n_0_reg     <= c3_wren_n_0_w;
        c3_eccdecbypass_0_align_0_reg     <= c3_eccdecbypass_0_w;
        c3_eccdecbypass_0_align_1_reg     <= c3_eccdecbypass_0_align_0_reg;
        c3_eccdecbypass_0_reg             <= c3_eccdecbypass_0_align_1_reg;
        c3_eccencbypass_0_reg     <= c3_eccencbypass_0_w;
        c3_q_0_reg    <= c3_q_0_w;
        c3_error_correct_0_reg    <= c3_error_correct_0_w;
        c3_error_detect_0_reg    <= c3_error_detect_0_w;
        //channel 4
        c4_data_0_reg     <= c4_data_0_w;
        c4_rdaddress_0_reg     <= c4_rdaddress_0_w;
        c4_rden_n_0_reg     <= c4_rden_n_0_w;
        c4_sd_n_0_reg     <= c4_sd_n_0_w;
        c4_wraddress_0_reg     <= c4_wraddress_0_w;
        c4_wren_n_0_reg     <= c4_wren_n_0_w;
        c4_eccdecbypass_0_align_0_reg     <= c4_eccdecbypass_0_w;
        c4_eccdecbypass_0_align_1_reg     <= c4_eccdecbypass_0_align_0_reg;
        c4_eccdecbypass_0_reg             <= c4_eccdecbypass_0_align_1_reg;
        c4_eccencbypass_0_reg     <= c4_eccencbypass_0_w;
        c4_q_0_reg    <= c4_q_0_w;
        c4_error_correct_0_reg    <= c4_error_correct_0_w;
        c4_error_detect_0_reg    <= c4_error_detect_0_w;
        //channel 5
        c5_data_0_reg     <= c5_data_0_w;
        c5_rdaddress_0_reg     <= c5_rdaddress_0_w;
        c5_rden_n_0_reg     <= c5_rden_n_0_w;
        c5_sd_n_0_reg     <= c5_sd_n_0_w;
        c5_wraddress_0_reg     <= c5_wraddress_0_w;
        c5_wren_n_0_reg     <= c5_wren_n_0_w;
        c5_eccdecbypass_0_align_0_reg     <= c5_eccdecbypass_0_w;
        c5_eccdecbypass_0_align_1_reg     <= c5_eccdecbypass_0_align_0_reg;
        c5_eccdecbypass_0_reg             <= c5_eccdecbypass_0_align_1_reg;
        c5_eccencbypass_0_reg     <= c5_eccencbypass_0_w;
        c5_q_0_reg    <= c5_q_0_w;
        c5_error_correct_0_reg    <= c5_error_correct_0_w;
        c5_error_detect_0_reg    <= c5_error_detect_0_w;
        //channel 6
        c6_data_0_reg     <= c6_data_0_w;
        c6_rdaddress_0_reg     <= c6_rdaddress_0_w;
        c6_rden_n_0_reg     <= c6_rden_n_0_w;
        c6_sd_n_0_reg     <= c6_sd_n_0_w;
        c6_wraddress_0_reg     <= c6_wraddress_0_w;
        c6_wren_n_0_reg     <= c6_wren_n_0_w;
        c6_eccdecbypass_0_align_0_reg     <= c6_eccdecbypass_0_w;
        c6_eccdecbypass_0_align_1_reg     <= c6_eccdecbypass_0_align_0_reg;
        c6_eccdecbypass_0_reg             <= c6_eccdecbypass_0_align_1_reg;
        c6_eccencbypass_0_reg     <= c6_eccencbypass_0_w;
        c6_q_0_reg    <= c6_q_0_w;
        c6_error_correct_0_reg    <= c6_error_correct_0_w;
        c6_error_detect_0_reg    <= c6_error_detect_0_w;
        //channel 7
        c7_data_0_reg     <= c7_data_0_w;
        c7_rdaddress_0_reg     <= c7_rdaddress_0_w;
        c7_rden_n_0_reg     <= c7_rden_n_0_w;
        c7_sd_n_0_reg     <= c7_sd_n_0_w;
        c7_wraddress_0_reg     <= c7_wraddress_0_w;
        c7_wren_n_0_reg     <= c7_wren_n_0_w;
        c7_eccdecbypass_0_align_0_reg     <= c7_eccdecbypass_0_w;
        c7_eccdecbypass_0_align_1_reg     <= c7_eccdecbypass_0_align_0_reg;
        c7_eccdecbypass_0_reg             <= c7_eccdecbypass_0_align_1_reg;
        c7_eccencbypass_0_reg     <= c7_eccencbypass_0_w;
        c7_q_0_reg    <= c7_q_0_w;
        c7_error_correct_0_reg    <= c7_error_correct_0_w;
        c7_error_detect_0_reg    <= c7_error_detect_0_w;
        iopll_lock2core_reg     <= iopll_lock2core_w;
    end
    //Full rate
    //channel 0
    assign c0_data_0_w     = c0_data_0;
    assign c0_rdaddress_0_w     = c0_rdaddress_0;
    assign c0_rden_n_0_w     = c0_rden_n_0;
    assign c0_sd_n_0_w     = c0_sd_n_0;
    assign c0_wraddress_0_w     = c0_wraddress_0;
    assign c0_wren_n_0_w     = c0_wren_n_0;
    assign c0_q_0    = c0_q_0_reg;
    //channel 1
    assign c1_data_0_w     = c1_data_0;
    assign c1_rdaddress_0_w     = c1_rdaddress_0;
    assign c1_rden_n_0_w     = c1_rden_n_0;
    assign c1_sd_n_0_w     = c1_sd_n_0;
    assign c1_wraddress_0_w     = c1_wraddress_0;
    assign c1_wren_n_0_w     = c1_wren_n_0;
    assign c1_q_0    = c1_q_0_reg;
    //channel 2
    assign c2_data_0_w     = c2_data_0;
    assign c2_rdaddress_0_w     = c2_rdaddress_0;
    assign c2_rden_n_0_w     = c2_rden_n_0;
    assign c2_sd_n_0_w     = c2_sd_n_0;
    assign c2_wraddress_0_w     = c2_wraddress_0;
    assign c2_wren_n_0_w     = c2_wren_n_0;
    assign c2_q_0    = c2_q_0_reg;
    //channel 3
    assign c3_data_0_w     = c3_data_0;
    assign c3_rdaddress_0_w     = c3_rdaddress_0;
    assign c3_rden_n_0_w     = c3_rden_n_0;
    assign c3_sd_n_0_w     = c3_sd_n_0;
    assign c3_wraddress_0_w     = c3_wraddress_0;
    assign c3_wren_n_0_w     = c3_wren_n_0;
    assign c3_q_0    = c3_q_0_reg;
    //channel 4
    assign c4_data_0_w     = c4_data_0;
    assign c4_rdaddress_0_w     = c4_rdaddress_0;
    assign c4_rden_n_0_w     = c4_rden_n_0;
    assign c4_sd_n_0_w     = c4_sd_n_0;
    assign c4_wraddress_0_w     = c4_wraddress_0;
    assign c4_wren_n_0_w     = c4_wren_n_0;
    assign c4_q_0    = c4_q_0_reg;
    //channel 5
    assign c5_data_0_w     = c5_data_0;
    assign c5_rdaddress_0_w     = c5_rdaddress_0;
    assign c5_rden_n_0_w     = c5_rden_n_0;
    assign c5_sd_n_0_w     = c5_sd_n_0;
    assign c5_wraddress_0_w     = c5_wraddress_0;
    assign c5_wren_n_0_w     = c5_wren_n_0;
    assign c5_q_0    = c5_q_0_reg;
    //channel 6
    assign c6_data_0_w     = c6_data_0;
    assign c6_rdaddress_0_w     = c6_rdaddress_0;
    assign c6_rden_n_0_w     = c6_rden_n_0;
    assign c6_sd_n_0_w     = c6_sd_n_0;
    assign c6_wraddress_0_w     = c6_wraddress_0;
    assign c6_wren_n_0_w     = c6_wren_n_0;
    assign c6_q_0    = c6_q_0_reg;
    //channel 7
    assign c7_data_0_w     = c7_data_0;
    assign c7_rdaddress_0_w     = c7_rdaddress_0;
    assign c7_rden_n_0_w     = c7_rden_n_0;
    assign c7_sd_n_0_w     = c7_sd_n_0;
    assign c7_wraddress_0_w     = c7_wraddress_0;
    assign c7_wren_n_0_w     = c7_wren_n_0;
    assign c7_q_0    = c7_q_0_reg;
    assign  esram2f_clk     = esram2f_clk_w[0];
    assign  iopll_lock2core = iopll_lock2core_reg;
    //end if reg and wire

    wire [1:0] esram__esram2f_clk;
    wire [1:0] esram__f2esram_clk;
    wire [16:0] esram__s2c0_adra_ua0;
    wire [16:0] esram__s2c0_adra_ua1;
    wire [16:0] esram__s2c0_adra_ua2;
    wire [16:0] esram__s2c0_adra_ua3;
    wire [16:0] esram__s2c0_adrb_ua0;
    wire [16:0] esram__s2c0_adrb_ua1;
    wire [16:0] esram__s2c0_adrb_ua2;
    wire [16:0] esram__s2c0_adrb_ua3;
    wire [71:0] esram__s2c0_da_ua0;
    wire [71:0] esram__s2c0_da_ua1;
    wire [71:0] esram__s2c0_da_ua2;
    wire [71:0] esram__s2c0_da_ua3;
    wire [71:0] esram__s2c0_qb_ua0;
    wire [71:0] esram__s2c0_qb_ua1;
    wire [71:0] esram__s2c0_qb_ua2;
    wire [71:0] esram__s2c0_qb_ua3;
    wire [16:0] esram__s2c1_adra_ua0;
    wire [16:0] esram__s2c1_adra_ua1;
    wire [16:0] esram__s2c1_adra_ua2;
    wire [16:0] esram__s2c1_adra_ua3;
    wire [16:0] esram__s2c1_adrb_ua0;
    wire [16:0] esram__s2c1_adrb_ua1;
    wire [16:0] esram__s2c1_adrb_ua2;
    wire [16:0] esram__s2c1_adrb_ua3;
    wire [71:0] esram__s2c1_da_ua0;
    wire [71:0] esram__s2c1_da_ua1;
    wire [71:0] esram__s2c1_da_ua2;
    wire [71:0] esram__s2c1_da_ua3;
    wire [71:0] esram__s2c1_qb_ua0;
    wire [71:0] esram__s2c1_qb_ua1;
    wire [71:0] esram__s2c1_qb_ua2;
    wire [71:0] esram__s2c1_qb_ua3;
    wire [16:0] esram__s2c2_adra_ua0;
    wire [16:0] esram__s2c2_adra_ua1;
    wire [16:0] esram__s2c2_adra_ua2;
    wire [16:0] esram__s2c2_adra_ua3;
    wire [16:0] esram__s2c2_adrb_ua0;
    wire [16:0] esram__s2c2_adrb_ua1;
    wire [16:0] esram__s2c2_adrb_ua2;
    wire [16:0] esram__s2c2_adrb_ua3;
    wire [71:0] esram__s2c2_da_ua0;
    wire [71:0] esram__s2c2_da_ua1;
    wire [71:0] esram__s2c2_da_ua2;
    wire [71:0] esram__s2c2_da_ua3;
    wire [71:0] esram__s2c2_qb_ua0;
    wire [71:0] esram__s2c2_qb_ua1;
    wire [71:0] esram__s2c2_qb_ua2;
    wire [71:0] esram__s2c2_qb_ua3;
    wire [16:0] esram__s2c3_adra_ua0;
    wire [16:0] esram__s2c3_adra_ua1;
    wire [16:0] esram__s2c3_adra_ua2;
    wire [16:0] esram__s2c3_adra_ua3;
    wire [16:0] esram__s2c3_adrb_ua0;
    wire [16:0] esram__s2c3_adrb_ua1;
    wire [16:0] esram__s2c3_adrb_ua2;
    wire [16:0] esram__s2c3_adrb_ua3;
    wire [71:0] esram__s2c3_da_ua0;
    wire [71:0] esram__s2c3_da_ua1;
    wire [71:0] esram__s2c3_da_ua2;
    wire [71:0] esram__s2c3_da_ua3;
    wire [71:0] esram__s2c3_qb_ua0;
    wire [71:0] esram__s2c3_qb_ua1;
    wire [71:0] esram__s2c3_qb_ua2;
    wire [71:0] esram__s2c3_qb_ua3;
    wire [16:0] esram__s2c4_adra_ua0;
    wire [16:0] esram__s2c4_adra_ua1;
    wire [16:0] esram__s2c4_adra_ua2;
    wire [16:0] esram__s2c4_adra_ua3;
    wire [16:0] esram__s2c4_adrb_ua0;
    wire [16:0] esram__s2c4_adrb_ua1;
    wire [16:0] esram__s2c4_adrb_ua2;
    wire [16:0] esram__s2c4_adrb_ua3;
    wire [71:0] esram__s2c4_da_ua0;
    wire [71:0] esram__s2c4_da_ua1;
    wire [71:0] esram__s2c4_da_ua2;
    wire [71:0] esram__s2c4_da_ua3;
    wire [71:0] esram__s2c4_qb_ua0;
    wire [71:0] esram__s2c4_qb_ua1;
    wire [71:0] esram__s2c4_qb_ua2;
    wire [71:0] esram__s2c4_qb_ua3;
    wire [16:0] esram__s2c5_adra_ua0;
    wire [16:0] esram__s2c5_adra_ua1;
    wire [16:0] esram__s2c5_adra_ua2;
    wire [16:0] esram__s2c5_adra_ua3;
    wire [16:0] esram__s2c5_adrb_ua0;
    wire [16:0] esram__s2c5_adrb_ua1;
    wire [16:0] esram__s2c5_adrb_ua2;
    wire [16:0] esram__s2c5_adrb_ua3;
    wire [71:0] esram__s2c5_da_ua0;
    wire [71:0] esram__s2c5_da_ua1;
    wire [71:0] esram__s2c5_da_ua2;
    wire [71:0] esram__s2c5_da_ua3;
    wire [71:0] esram__s2c5_qb_ua0;
    wire [71:0] esram__s2c5_qb_ua1;
    wire [71:0] esram__s2c5_qb_ua2;
    wire [71:0] esram__s2c5_qb_ua3;
    wire [16:0] esram__s2c6_adra_ua0;
    wire [16:0] esram__s2c6_adra_ua1;
    wire [16:0] esram__s2c6_adra_ua2;
    wire [16:0] esram__s2c6_adra_ua3;
    wire [16:0] esram__s2c6_adrb_ua0;
    wire [16:0] esram__s2c6_adrb_ua1;
    wire [16:0] esram__s2c6_adrb_ua2;
    wire [16:0] esram__s2c6_adrb_ua3;
    wire [71:0] esram__s2c6_da_ua0;
    wire [71:0] esram__s2c6_da_ua1;
    wire [71:0] esram__s2c6_da_ua2;
    wire [71:0] esram__s2c6_da_ua3;
    wire [71:0] esram__s2c6_qb_ua0;
    wire [71:0] esram__s2c6_qb_ua1;
    wire [71:0] esram__s2c6_qb_ua2;
    wire [71:0] esram__s2c6_qb_ua3;
    wire [16:0] esram__s2c7_adra_ua0;
    wire [16:0] esram__s2c7_adra_ua1;
    wire [16:0] esram__s2c7_adra_ua2;
    wire [16:0] esram__s2c7_adra_ua3;
    wire [16:0] esram__s2c7_adrb_ua0;
    wire [16:0] esram__s2c7_adrb_ua1;
    wire [16:0] esram__s2c7_adrb_ua2;
    wire [16:0] esram__s2c7_adrb_ua3;
    wire [71:0] esram__s2c7_da_ua0;
    wire [71:0] esram__s2c7_da_ua1;
    wire [71:0] esram__s2c7_da_ua2;
    wire [71:0] esram__s2c7_da_ua3;
    wire [71:0] esram__s2c7_qb_ua0;
    wire [71:0] esram__s2c7_qb_ua1;
    wire [71:0] esram__s2c7_qb_ua2;
    wire [71:0] esram__s2c7_qb_ua3;
    wire esram__s2c0_ecca_byp_ua0;
    wire esram__s2c0_ecca_byp_ua1;
    wire esram__s2c0_ecca_byp_ua2;
    wire esram__s2c0_ecca_byp_ua3;
    wire esram__s2c0_eccb_byp_ua0;
    wire esram__s2c0_eccb_byp_ua1;
    wire esram__s2c0_eccb_byp_ua2;
    wire esram__s2c0_eccb_byp_ua3;
    wire esram__s2c0_err_correct_ua0;
    wire esram__s2c0_err_correct_ua1;
    wire esram__s2c0_err_correct_ua2;
    wire esram__s2c0_err_correct_ua3;
    wire esram__s2c0_err_detect_ua0;
    wire esram__s2c0_err_detect_ua1;
    wire esram__s2c0_err_detect_ua2;
    wire esram__s2c0_err_detect_ua3;
    wire esram__s2c0_mea_n_ua0;
    wire esram__s2c0_mea_n_ua1;
    wire esram__s2c0_mea_n_ua2;
    wire esram__s2c0_mea_n_ua3;
    wire esram__s2c0_meb_n_ua0;
    wire esram__s2c0_meb_n_ua1;
    wire esram__s2c0_meb_n_ua2;
    wire esram__s2c0_meb_n_ua3;
    wire esram__s2c0_sd_n_ua0;
    wire esram__s2c0_sd_n_ua1;
    wire esram__s2c0_sd_n_ua2;
    wire esram__s2c0_sd_n_ua3;
    wire esram__s2c1_ecca_byp_ua0;
    wire esram__s2c1_ecca_byp_ua1;
    wire esram__s2c1_ecca_byp_ua2;
    wire esram__s2c1_ecca_byp_ua3;
    wire esram__s2c1_eccb_byp_ua0;
    wire esram__s2c1_eccb_byp_ua1;
    wire esram__s2c1_eccb_byp_ua2;
    wire esram__s2c1_eccb_byp_ua3;
    wire esram__s2c1_err_correct_ua0;
    wire esram__s2c1_err_correct_ua1;
    wire esram__s2c1_err_correct_ua2;
    wire esram__s2c1_err_correct_ua3;
    wire esram__s2c1_err_detect_ua0;
    wire esram__s2c1_err_detect_ua1;
    wire esram__s2c1_err_detect_ua2;
    wire esram__s2c1_err_detect_ua3;
    wire esram__s2c1_mea_n_ua0;
    wire esram__s2c1_mea_n_ua1;
    wire esram__s2c1_mea_n_ua2;
    wire esram__s2c1_mea_n_ua3;
    wire esram__s2c1_meb_n_ua0;
    wire esram__s2c1_meb_n_ua1;
    wire esram__s2c1_meb_n_ua2;
    wire esram__s2c1_meb_n_ua3;
    wire esram__s2c1_sd_n_ua0;
    wire esram__s2c1_sd_n_ua1;
    wire esram__s2c1_sd_n_ua2;
    wire esram__s2c1_sd_n_ua3;
    wire esram__s2c2_ecca_byp_ua0;
    wire esram__s2c2_ecca_byp_ua1;
    wire esram__s2c2_ecca_byp_ua2;
    wire esram__s2c2_ecca_byp_ua3;
    wire esram__s2c2_eccb_byp_ua0;
    wire esram__s2c2_eccb_byp_ua1;
    wire esram__s2c2_eccb_byp_ua2;
    wire esram__s2c2_eccb_byp_ua3;
    wire esram__s2c2_err_correct_ua0;
    wire esram__s2c2_err_correct_ua1;
    wire esram__s2c2_err_correct_ua2;
    wire esram__s2c2_err_correct_ua3;
    wire esram__s2c2_err_detect_ua0;
    wire esram__s2c2_err_detect_ua1;
    wire esram__s2c2_err_detect_ua2;
    wire esram__s2c2_err_detect_ua3;
    wire esram__s2c2_mea_n_ua0;
    wire esram__s2c2_mea_n_ua1;
    wire esram__s2c2_mea_n_ua2;
    wire esram__s2c2_mea_n_ua3;
    wire esram__s2c2_meb_n_ua0;
    wire esram__s2c2_meb_n_ua1;
    wire esram__s2c2_meb_n_ua2;
    wire esram__s2c2_meb_n_ua3;
    wire esram__s2c2_sd_n_ua0;
    wire esram__s2c2_sd_n_ua1;
    wire esram__s2c2_sd_n_ua2;
    wire esram__s2c2_sd_n_ua3;
    wire esram__s2c3_ecca_byp_ua0;
    wire esram__s2c3_ecca_byp_ua1;
    wire esram__s2c3_ecca_byp_ua2;
    wire esram__s2c3_ecca_byp_ua3;
    wire esram__s2c3_eccb_byp_ua0;
    wire esram__s2c3_eccb_byp_ua1;
    wire esram__s2c3_eccb_byp_ua2;
    wire esram__s2c3_eccb_byp_ua3;
    wire esram__s2c3_err_correct_ua0;
    wire esram__s2c3_err_correct_ua1;
    wire esram__s2c3_err_correct_ua2;
    wire esram__s2c3_err_correct_ua3;
    wire esram__s2c3_err_detect_ua0;
    wire esram__s2c3_err_detect_ua1;
    wire esram__s2c3_err_detect_ua2;
    wire esram__s2c3_err_detect_ua3;
    wire esram__s2c3_mea_n_ua0;
    wire esram__s2c3_mea_n_ua1;
    wire esram__s2c3_mea_n_ua2;
    wire esram__s2c3_mea_n_ua3;
    wire esram__s2c3_meb_n_ua0;
    wire esram__s2c3_meb_n_ua1;
    wire esram__s2c3_meb_n_ua2;
    wire esram__s2c3_meb_n_ua3;
    wire esram__s2c3_sd_n_ua0;
    wire esram__s2c3_sd_n_ua1;
    wire esram__s2c3_sd_n_ua2;
    wire esram__s2c3_sd_n_ua3;
    wire esram__s2c4_ecca_byp_ua0;
    wire esram__s2c4_ecca_byp_ua1;
    wire esram__s2c4_ecca_byp_ua2;
    wire esram__s2c4_ecca_byp_ua3;
    wire esram__s2c4_eccb_byp_ua0;
    wire esram__s2c4_eccb_byp_ua1;
    wire esram__s2c4_eccb_byp_ua2;
    wire esram__s2c4_eccb_byp_ua3;
    wire esram__s2c4_err_correct_ua0;
    wire esram__s2c4_err_correct_ua1;
    wire esram__s2c4_err_correct_ua2;
    wire esram__s2c4_err_correct_ua3;
    wire esram__s2c4_err_detect_ua0;
    wire esram__s2c4_err_detect_ua1;
    wire esram__s2c4_err_detect_ua2;
    wire esram__s2c4_err_detect_ua3;
    wire esram__s2c4_mea_n_ua0;
    wire esram__s2c4_mea_n_ua1;
    wire esram__s2c4_mea_n_ua2;
    wire esram__s2c4_mea_n_ua3;
    wire esram__s2c4_meb_n_ua0;
    wire esram__s2c4_meb_n_ua1;
    wire esram__s2c4_meb_n_ua2;
    wire esram__s2c4_meb_n_ua3;
    wire esram__s2c4_sd_n_ua0;
    wire esram__s2c4_sd_n_ua1;
    wire esram__s2c4_sd_n_ua2;
    wire esram__s2c4_sd_n_ua3;
    wire esram__s2c5_ecca_byp_ua0;
    wire esram__s2c5_ecca_byp_ua1;
    wire esram__s2c5_ecca_byp_ua2;
    wire esram__s2c5_ecca_byp_ua3;
    wire esram__s2c5_eccb_byp_ua0;
    wire esram__s2c5_eccb_byp_ua1;
    wire esram__s2c5_eccb_byp_ua2;
    wire esram__s2c5_eccb_byp_ua3;
    wire esram__s2c5_err_correct_ua0;
    wire esram__s2c5_err_correct_ua1;
    wire esram__s2c5_err_correct_ua2;
    wire esram__s2c5_err_correct_ua3;
    wire esram__s2c5_err_detect_ua0;
    wire esram__s2c5_err_detect_ua1;
    wire esram__s2c5_err_detect_ua2;
    wire esram__s2c5_err_detect_ua3;
    wire esram__s2c5_mea_n_ua0;
    wire esram__s2c5_mea_n_ua1;
    wire esram__s2c5_mea_n_ua2;
    wire esram__s2c5_mea_n_ua3;
    wire esram__s2c5_meb_n_ua0;
    wire esram__s2c5_meb_n_ua1;
    wire esram__s2c5_meb_n_ua2;
    wire esram__s2c5_meb_n_ua3;
    wire esram__s2c5_sd_n_ua0;
    wire esram__s2c5_sd_n_ua1;
    wire esram__s2c5_sd_n_ua2;
    wire esram__s2c5_sd_n_ua3;
    wire esram__s2c6_ecca_byp_ua0;
    wire esram__s2c6_ecca_byp_ua1;
    wire esram__s2c6_ecca_byp_ua2;
    wire esram__s2c6_ecca_byp_ua3;
    wire esram__s2c6_eccb_byp_ua0;
    wire esram__s2c6_eccb_byp_ua1;
    wire esram__s2c6_eccb_byp_ua2;
    wire esram__s2c6_eccb_byp_ua3;
    wire esram__s2c6_err_correct_ua0;
    wire esram__s2c6_err_correct_ua1;
    wire esram__s2c6_err_correct_ua2;
    wire esram__s2c6_err_correct_ua3;
    wire esram__s2c6_err_detect_ua0;
    wire esram__s2c6_err_detect_ua1;
    wire esram__s2c6_err_detect_ua2;
    wire esram__s2c6_err_detect_ua3;
    wire esram__s2c6_mea_n_ua0;
    wire esram__s2c6_mea_n_ua1;
    wire esram__s2c6_mea_n_ua2;
    wire esram__s2c6_mea_n_ua3;
    wire esram__s2c6_meb_n_ua0;
    wire esram__s2c6_meb_n_ua1;
    wire esram__s2c6_meb_n_ua2;
    wire esram__s2c6_meb_n_ua3;
    wire esram__s2c6_sd_n_ua0;
    wire esram__s2c6_sd_n_ua1;
    wire esram__s2c6_sd_n_ua2;
    wire esram__s2c6_sd_n_ua3;
    wire esram__s2c7_ecca_byp_ua0;
    wire esram__s2c7_ecca_byp_ua1;
    wire esram__s2c7_ecca_byp_ua2;
    wire esram__s2c7_ecca_byp_ua3;
    wire esram__s2c7_eccb_byp_ua0;
    wire esram__s2c7_eccb_byp_ua1;
    wire esram__s2c7_eccb_byp_ua2;
    wire esram__s2c7_eccb_byp_ua3;
    wire esram__s2c7_err_correct_ua0;
    wire esram__s2c7_err_correct_ua1;
    wire esram__s2c7_err_correct_ua2;
    wire esram__s2c7_err_correct_ua3;
    wire esram__s2c7_err_detect_ua0;
    wire esram__s2c7_err_detect_ua1;
    wire esram__s2c7_err_detect_ua2;
    wire esram__s2c7_err_detect_ua3;
    wire esram__s2c7_mea_n_ua0;
    wire esram__s2c7_mea_n_ua1;
    wire esram__s2c7_mea_n_ua2;
    wire esram__s2c7_mea_n_ua3;
    wire esram__s2c7_meb_n_ua0;
    wire esram__s2c7_meb_n_ua1;
    wire esram__s2c7_meb_n_ua2;
    wire esram__s2c7_meb_n_ua3;
    wire esram__s2c7_sd_n_ua0;
    wire esram__s2c7_sd_n_ua1;
    wire esram__s2c7_sd_n_ua2;
    wire esram__s2c7_sd_n_ua3;
    wire [1:0]   esram2f_clk_wire;
    wire [1:0]   f2esram_clk_wire;
    wire [27:0] esram__scan_in;
    wire [27:0] esram__scan_out;
    wire [3:0]  esram__cjtag_id_in_l;
    wire [3:0]  esram__cjtag_id_in_r;

    //iopll
    wire            locked_iopll;
    wire            refclk_out;
    wire            extclk0;
    wire            extclk1;
    wire    [7:0]   vcoph;
    wire    [8:0]   pllcout_sig;
    wire    [3:0]   test_debug_in;
    assign          low_sig  = 1'b0;
    assign          vccl_sig = 1'b1;
    assign          test_debug_in = {1'b0, 1'b0, extclk1, extclk0};

    //cpa
    wire            csr_clk;
    wire            test_csr_in_to_cpa;
    wire            test_csr_out_from_cpa;
    wire            scan_enable1_n;
    wire            scan_enable0_n;
    wire            cpa_scan_mode_n;
    wire            atpg_mode_n;
    wire            testin_coreclk;
    wire            cfg_cpa_mdio_dis;
    wire            pipeline_enable_n;
    wire            iopll_pma_csr_test_dis_mux;
    wire            iocpa_testclk;
    wire            test_reset_n;
    wire            nfrzdrv_mux;
    wire            usermode_mux;
    wire            iocpa_dft_ctrl_to_core;
    wire            cpa_latch_en;
    wire            dprio_cpa_clk;
    wire            dprio_cpa_rst_n;
    wire            dprio_cpa_read;
    wire            dprio_cpa_write;
    wire            csr_in_cpaaux;
    wire    [8:0]   dprio_cpa_addr;
    wire    [1:0]   cpa_slave_locked;
    wire    [7:0]   dprio_cpa_writedata;
    wire    [7:0]   dprio_cpa_readdata;
    wire    [1:0]   test_so_pa_from_cpa;
    wire    [3:0]   test_debug_out_int;
    wire    [1:0]   f2esram_clk_to_cip;
    wire    [1:0]   esram2f_clk_from_cip;
    wire            ptr_en_sync;
    wire            ptr_en;
    wire            ptr_rst_n_wire;
    wire            esram_clk_fb;
    wire    [1:0]  esram2f_clk_ufi;

    assign esram2f_clk_w = esram2f_clk_ufi;

    // Esram
    fourteennm_esram  fourteennm_esram_component (
        .cfg_ufi_ptren(locked_iopll),
        .iopll_lock2iohmc_from_cip(locked_iopll),               //lock signal from iopll to esram
        .iopll_lock2iohmc(iopll_lock2core_ufi),                 //output iopll lock signal to ufi
        .f2esram_clk(f2esram_clk_wire),                         //esram input from ufi
        .f2esram_clk_to_cip(f2esram_clk_to_cip),                //esram output to cpa
        .esram2f_clk(esram2f_clk_wire),
        .esram2f_clk_from_cip(esram2f_clk_from_cip),            //esram input from cpa
        .pllcout_sig(pllcout_sig),
        .esram_clk(esram_clk_fb),
        .s2c0_adra_ua0(esram__s2c0_adra_ua0),
        .s2c0_adra_ua1(esram__s2c0_adra_ua1),
        .s2c0_adra_ua2(esram__s2c0_adra_ua2),
        .s2c0_adra_ua3(esram__s2c0_adra_ua3),
        .s2c0_adrb_ua0(esram__s2c0_adrb_ua0),
        .s2c0_adrb_ua1(esram__s2c0_adrb_ua1),
        .s2c0_adrb_ua2(esram__s2c0_adrb_ua2),
        .s2c0_adrb_ua3(esram__s2c0_adrb_ua3),
        .s2c0_da_ua0(esram__s2c0_da_ua0),
        .s2c0_da_ua1(esram__s2c0_da_ua1),
        .s2c0_da_ua2(esram__s2c0_da_ua2),
        .s2c0_da_ua3(esram__s2c0_da_ua3),
        .s2c0_qb_ua0(esram__s2c0_qb_ua0),
        .s2c0_qb_ua1(esram__s2c0_qb_ua1),
        .s2c0_qb_ua2(esram__s2c0_qb_ua2),
        .s2c0_qb_ua3(esram__s2c0_qb_ua3),
        .s2c0_ecca_byp_ua0(esram__s2c0_ecca_byp_ua0),
        .s2c0_ecca_byp_ua1(esram__s2c0_ecca_byp_ua1),
        .s2c0_ecca_byp_ua2(esram__s2c0_ecca_byp_ua2),
        .s2c0_ecca_byp_ua3(esram__s2c0_ecca_byp_ua3),
        .s2c0_eccb_byp_ua0(esram__s2c0_eccb_byp_ua0),
        .s2c0_eccb_byp_ua1(esram__s2c0_eccb_byp_ua1),
        .s2c0_eccb_byp_ua2(esram__s2c0_eccb_byp_ua2),
        .s2c0_eccb_byp_ua3(esram__s2c0_eccb_byp_ua3),
        .s2c0_err_correct_ua0(esram__s2c0_err_correct_ua0),
        .s2c0_err_correct_ua1(esram__s2c0_err_correct_ua1),
        .s2c0_err_correct_ua2(esram__s2c0_err_correct_ua2),
        .s2c0_err_correct_ua3(esram__s2c0_err_correct_ua3),
        .s2c0_err_detect_ua0(esram__s2c0_err_detect_ua0),
        .s2c0_err_detect_ua1(esram__s2c0_err_detect_ua1),
        .s2c0_err_detect_ua2(esram__s2c0_err_detect_ua2),
        .s2c0_err_detect_ua3(esram__s2c0_err_detect_ua3),
        .s2c0_mea_n_ua0(esram__s2c0_mea_n_ua0),
        .s2c0_mea_n_ua1(esram__s2c0_mea_n_ua1),
        .s2c0_mea_n_ua2(esram__s2c0_mea_n_ua2),
        .s2c0_mea_n_ua3(esram__s2c0_mea_n_ua3),
        .s2c0_meb_n_ua0(esram__s2c0_meb_n_ua0),
        .s2c0_meb_n_ua1(esram__s2c0_meb_n_ua1),
        .s2c0_meb_n_ua2(esram__s2c0_meb_n_ua2),
        .s2c0_meb_n_ua3(esram__s2c0_meb_n_ua3),
        .s2c0_sd_n_ua0(esram__s2c0_sd_n_ua0),
        .s2c0_sd_n_ua1(esram__s2c0_sd_n_ua1),
        .s2c0_sd_n_ua2(esram__s2c0_sd_n_ua2),
        .s2c0_sd_n_ua3(esram__s2c0_sd_n_ua3),
        .s2c1_adra_ua0(esram__s2c1_adra_ua0),
        .s2c1_adra_ua1(esram__s2c1_adra_ua1),
        .s2c1_adra_ua2(esram__s2c1_adra_ua2),
        .s2c1_adra_ua3(esram__s2c1_adra_ua3),
        .s2c1_adrb_ua0(esram__s2c1_adrb_ua0),
        .s2c1_adrb_ua1(esram__s2c1_adrb_ua1),
        .s2c1_adrb_ua2(esram__s2c1_adrb_ua2),
        .s2c1_adrb_ua3(esram__s2c1_adrb_ua3),
        .s2c1_da_ua0(esram__s2c1_da_ua0),
        .s2c1_da_ua1(esram__s2c1_da_ua1),
        .s2c1_da_ua2(esram__s2c1_da_ua2),
        .s2c1_da_ua3(esram__s2c1_da_ua3),
        .s2c1_qb_ua0(esram__s2c1_qb_ua0),
        .s2c1_qb_ua1(esram__s2c1_qb_ua1),
        .s2c1_qb_ua2(esram__s2c1_qb_ua2),
        .s2c1_qb_ua3(esram__s2c1_qb_ua3),
        .s2c1_ecca_byp_ua0(esram__s2c1_ecca_byp_ua0),
        .s2c1_ecca_byp_ua1(esram__s2c1_ecca_byp_ua1),
        .s2c1_ecca_byp_ua2(esram__s2c1_ecca_byp_ua2),
        .s2c1_ecca_byp_ua3(esram__s2c1_ecca_byp_ua3),
        .s2c1_eccb_byp_ua0(esram__s2c1_eccb_byp_ua0),
        .s2c1_eccb_byp_ua1(esram__s2c1_eccb_byp_ua1),
        .s2c1_eccb_byp_ua2(esram__s2c1_eccb_byp_ua2),
        .s2c1_eccb_byp_ua3(esram__s2c1_eccb_byp_ua3),
        .s2c1_err_correct_ua0(esram__s2c1_err_correct_ua0),
        .s2c1_err_correct_ua1(esram__s2c1_err_correct_ua1),
        .s2c1_err_correct_ua2(esram__s2c1_err_correct_ua2),
        .s2c1_err_correct_ua3(esram__s2c1_err_correct_ua3),
        .s2c1_err_detect_ua0(esram__s2c1_err_detect_ua0),
        .s2c1_err_detect_ua1(esram__s2c1_err_detect_ua1),
        .s2c1_err_detect_ua2(esram__s2c1_err_detect_ua2),
        .s2c1_err_detect_ua3(esram__s2c1_err_detect_ua3),
        .s2c1_mea_n_ua0(esram__s2c1_mea_n_ua0),
        .s2c1_mea_n_ua1(esram__s2c1_mea_n_ua1),
        .s2c1_mea_n_ua2(esram__s2c1_mea_n_ua2),
        .s2c1_mea_n_ua3(esram__s2c1_mea_n_ua3),
        .s2c1_meb_n_ua0(esram__s2c1_meb_n_ua0),
        .s2c1_meb_n_ua1(esram__s2c1_meb_n_ua1),
        .s2c1_meb_n_ua2(esram__s2c1_meb_n_ua2),
        .s2c1_meb_n_ua3(esram__s2c1_meb_n_ua3),
        .s2c1_sd_n_ua0(esram__s2c1_sd_n_ua0),
        .s2c1_sd_n_ua1(esram__s2c1_sd_n_ua1),
        .s2c1_sd_n_ua2(esram__s2c1_sd_n_ua2),
        .s2c1_sd_n_ua3(esram__s2c1_sd_n_ua3),
        .s2c2_adra_ua0(esram__s2c2_adra_ua0),
        .s2c2_adra_ua1(esram__s2c2_adra_ua1),
        .s2c2_adra_ua2(esram__s2c2_adra_ua2),
        .s2c2_adra_ua3(esram__s2c2_adra_ua3),
        .s2c2_adrb_ua0(esram__s2c2_adrb_ua0),
        .s2c2_adrb_ua1(esram__s2c2_adrb_ua1),
        .s2c2_adrb_ua2(esram__s2c2_adrb_ua2),
        .s2c2_adrb_ua3(esram__s2c2_adrb_ua3),
        .s2c2_da_ua0(esram__s2c2_da_ua0),
        .s2c2_da_ua1(esram__s2c2_da_ua1),
        .s2c2_da_ua2(esram__s2c2_da_ua2),
        .s2c2_da_ua3(esram__s2c2_da_ua3),
        .s2c2_qb_ua0(esram__s2c2_qb_ua0),
        .s2c2_qb_ua1(esram__s2c2_qb_ua1),
        .s2c2_qb_ua2(esram__s2c2_qb_ua2),
        .s2c2_qb_ua3(esram__s2c2_qb_ua3),
        .s2c2_ecca_byp_ua0(esram__s2c2_ecca_byp_ua0),
        .s2c2_ecca_byp_ua1(esram__s2c2_ecca_byp_ua1),
        .s2c2_ecca_byp_ua2(esram__s2c2_ecca_byp_ua2),
        .s2c2_ecca_byp_ua3(esram__s2c2_ecca_byp_ua3),
        .s2c2_eccb_byp_ua0(esram__s2c2_eccb_byp_ua0),
        .s2c2_eccb_byp_ua1(esram__s2c2_eccb_byp_ua1),
        .s2c2_eccb_byp_ua2(esram__s2c2_eccb_byp_ua2),
        .s2c2_eccb_byp_ua3(esram__s2c2_eccb_byp_ua3),
        .s2c2_err_correct_ua0(esram__s2c2_err_correct_ua0),
        .s2c2_err_correct_ua1(esram__s2c2_err_correct_ua1),
        .s2c2_err_correct_ua2(esram__s2c2_err_correct_ua2),
        .s2c2_err_correct_ua3(esram__s2c2_err_correct_ua3),
        .s2c2_err_detect_ua0(esram__s2c2_err_detect_ua0),
        .s2c2_err_detect_ua1(esram__s2c2_err_detect_ua1),
        .s2c2_err_detect_ua2(esram__s2c2_err_detect_ua2),
        .s2c2_err_detect_ua3(esram__s2c2_err_detect_ua3),
        .s2c2_mea_n_ua0(esram__s2c2_mea_n_ua0),
        .s2c2_mea_n_ua1(esram__s2c2_mea_n_ua1),
        .s2c2_mea_n_ua2(esram__s2c2_mea_n_ua2),
        .s2c2_mea_n_ua3(esram__s2c2_mea_n_ua3),
        .s2c2_meb_n_ua0(esram__s2c2_meb_n_ua0),
        .s2c2_meb_n_ua1(esram__s2c2_meb_n_ua1),
        .s2c2_meb_n_ua2(esram__s2c2_meb_n_ua2),
        .s2c2_meb_n_ua3(esram__s2c2_meb_n_ua3),
        .s2c2_sd_n_ua0(esram__s2c2_sd_n_ua0),
        .s2c2_sd_n_ua1(esram__s2c2_sd_n_ua1),
        .s2c2_sd_n_ua2(esram__s2c2_sd_n_ua2),
        .s2c2_sd_n_ua3(esram__s2c2_sd_n_ua3),
        .s2c3_adra_ua0(esram__s2c3_adra_ua0),
        .s2c3_adra_ua1(esram__s2c3_adra_ua1),
        .s2c3_adra_ua2(esram__s2c3_adra_ua2),
        .s2c3_adra_ua3(esram__s2c3_adra_ua3),
        .s2c3_adrb_ua0(esram__s2c3_adrb_ua0),
        .s2c3_adrb_ua1(esram__s2c3_adrb_ua1),
        .s2c3_adrb_ua2(esram__s2c3_adrb_ua2),
        .s2c3_adrb_ua3(esram__s2c3_adrb_ua3),
        .s2c3_da_ua0(esram__s2c3_da_ua0),
        .s2c3_da_ua1(esram__s2c3_da_ua1),
        .s2c3_da_ua2(esram__s2c3_da_ua2),
        .s2c3_da_ua3(esram__s2c3_da_ua3),
        .s2c3_qb_ua0(esram__s2c3_qb_ua0),
        .s2c3_qb_ua1(esram__s2c3_qb_ua1),
        .s2c3_qb_ua2(esram__s2c3_qb_ua2),
        .s2c3_qb_ua3(esram__s2c3_qb_ua3),
        .s2c3_ecca_byp_ua0(esram__s2c3_ecca_byp_ua0),
        .s2c3_ecca_byp_ua1(esram__s2c3_ecca_byp_ua1),
        .s2c3_ecca_byp_ua2(esram__s2c3_ecca_byp_ua2),
        .s2c3_ecca_byp_ua3(esram__s2c3_ecca_byp_ua3),
        .s2c3_eccb_byp_ua0(esram__s2c3_eccb_byp_ua0),
        .s2c3_eccb_byp_ua1(esram__s2c3_eccb_byp_ua1),
        .s2c3_eccb_byp_ua2(esram__s2c3_eccb_byp_ua2),
        .s2c3_eccb_byp_ua3(esram__s2c3_eccb_byp_ua3),
        .s2c3_err_correct_ua0(esram__s2c3_err_correct_ua0),
        .s2c3_err_correct_ua1(esram__s2c3_err_correct_ua1),
        .s2c3_err_correct_ua2(esram__s2c3_err_correct_ua2),
        .s2c3_err_correct_ua3(esram__s2c3_err_correct_ua3),
        .s2c3_err_detect_ua0(esram__s2c3_err_detect_ua0),
        .s2c3_err_detect_ua1(esram__s2c3_err_detect_ua1),
        .s2c3_err_detect_ua2(esram__s2c3_err_detect_ua2),
        .s2c3_err_detect_ua3(esram__s2c3_err_detect_ua3),
        .s2c3_mea_n_ua0(esram__s2c3_mea_n_ua0),
        .s2c3_mea_n_ua1(esram__s2c3_mea_n_ua1),
        .s2c3_mea_n_ua2(esram__s2c3_mea_n_ua2),
        .s2c3_mea_n_ua3(esram__s2c3_mea_n_ua3),
        .s2c3_meb_n_ua0(esram__s2c3_meb_n_ua0),
        .s2c3_meb_n_ua1(esram__s2c3_meb_n_ua1),
        .s2c3_meb_n_ua2(esram__s2c3_meb_n_ua2),
        .s2c3_meb_n_ua3(esram__s2c3_meb_n_ua3),
        .s2c3_sd_n_ua0(esram__s2c3_sd_n_ua0),
        .s2c3_sd_n_ua1(esram__s2c3_sd_n_ua1),
        .s2c3_sd_n_ua2(esram__s2c3_sd_n_ua2),
        .s2c3_sd_n_ua3(esram__s2c3_sd_n_ua3),
        .s2c4_adra_ua0(esram__s2c4_adra_ua0),
        .s2c4_adra_ua1(esram__s2c4_adra_ua1),
        .s2c4_adra_ua2(esram__s2c4_adra_ua2),
        .s2c4_adra_ua3(esram__s2c4_adra_ua3),
        .s2c4_adrb_ua0(esram__s2c4_adrb_ua0),
        .s2c4_adrb_ua1(esram__s2c4_adrb_ua1),
        .s2c4_adrb_ua2(esram__s2c4_adrb_ua2),
        .s2c4_adrb_ua3(esram__s2c4_adrb_ua3),
        .s2c4_da_ua0(esram__s2c4_da_ua0),
        .s2c4_da_ua1(esram__s2c4_da_ua1),
        .s2c4_da_ua2(esram__s2c4_da_ua2),
        .s2c4_da_ua3(esram__s2c4_da_ua3),
        .s2c4_qb_ua0(esram__s2c4_qb_ua0),
        .s2c4_qb_ua1(esram__s2c4_qb_ua1),
        .s2c4_qb_ua2(esram__s2c4_qb_ua2),
        .s2c4_qb_ua3(esram__s2c4_qb_ua3),
        .s2c4_ecca_byp_ua0(esram__s2c4_ecca_byp_ua0),
        .s2c4_ecca_byp_ua1(esram__s2c4_ecca_byp_ua1),
        .s2c4_ecca_byp_ua2(esram__s2c4_ecca_byp_ua2),
        .s2c4_ecca_byp_ua3(esram__s2c4_ecca_byp_ua3),
        .s2c4_eccb_byp_ua0(esram__s2c4_eccb_byp_ua0),
        .s2c4_eccb_byp_ua1(esram__s2c4_eccb_byp_ua1),
        .s2c4_eccb_byp_ua2(esram__s2c4_eccb_byp_ua2),
        .s2c4_eccb_byp_ua3(esram__s2c4_eccb_byp_ua3),
        .s2c4_err_correct_ua0(esram__s2c4_err_correct_ua0),
        .s2c4_err_correct_ua1(esram__s2c4_err_correct_ua1),
        .s2c4_err_correct_ua2(esram__s2c4_err_correct_ua2),
        .s2c4_err_correct_ua3(esram__s2c4_err_correct_ua3),
        .s2c4_err_detect_ua0(esram__s2c4_err_detect_ua0),
        .s2c4_err_detect_ua1(esram__s2c4_err_detect_ua1),
        .s2c4_err_detect_ua2(esram__s2c4_err_detect_ua2),
        .s2c4_err_detect_ua3(esram__s2c4_err_detect_ua3),
        .s2c4_mea_n_ua0(esram__s2c4_mea_n_ua0),
        .s2c4_mea_n_ua1(esram__s2c4_mea_n_ua1),
        .s2c4_mea_n_ua2(esram__s2c4_mea_n_ua2),
        .s2c4_mea_n_ua3(esram__s2c4_mea_n_ua3),
        .s2c4_meb_n_ua0(esram__s2c4_meb_n_ua0),
        .s2c4_meb_n_ua1(esram__s2c4_meb_n_ua1),
        .s2c4_meb_n_ua2(esram__s2c4_meb_n_ua2),
        .s2c4_meb_n_ua3(esram__s2c4_meb_n_ua3),
        .s2c4_sd_n_ua0(esram__s2c4_sd_n_ua0),
        .s2c4_sd_n_ua1(esram__s2c4_sd_n_ua1),
        .s2c4_sd_n_ua2(esram__s2c4_sd_n_ua2),
        .s2c4_sd_n_ua3(esram__s2c4_sd_n_ua3),
        .s2c5_adra_ua0(esram__s2c5_adra_ua0),
        .s2c5_adra_ua1(esram__s2c5_adra_ua1),
        .s2c5_adra_ua2(esram__s2c5_adra_ua2),
        .s2c5_adra_ua3(esram__s2c5_adra_ua3),
        .s2c5_adrb_ua0(esram__s2c5_adrb_ua0),
        .s2c5_adrb_ua1(esram__s2c5_adrb_ua1),
        .s2c5_adrb_ua2(esram__s2c5_adrb_ua2),
        .s2c5_adrb_ua3(esram__s2c5_adrb_ua3),
        .s2c5_da_ua0(esram__s2c5_da_ua0),
        .s2c5_da_ua1(esram__s2c5_da_ua1),
        .s2c5_da_ua2(esram__s2c5_da_ua2),
        .s2c5_da_ua3(esram__s2c5_da_ua3),
        .s2c5_qb_ua0(esram__s2c5_qb_ua0),
        .s2c5_qb_ua1(esram__s2c5_qb_ua1),
        .s2c5_qb_ua2(esram__s2c5_qb_ua2),
        .s2c5_qb_ua3(esram__s2c5_qb_ua3),
        .s2c5_ecca_byp_ua0(esram__s2c5_ecca_byp_ua0),
        .s2c5_ecca_byp_ua1(esram__s2c5_ecca_byp_ua1),
        .s2c5_ecca_byp_ua2(esram__s2c5_ecca_byp_ua2),
        .s2c5_ecca_byp_ua3(esram__s2c5_ecca_byp_ua3),
        .s2c5_eccb_byp_ua0(esram__s2c5_eccb_byp_ua0),
        .s2c5_eccb_byp_ua1(esram__s2c5_eccb_byp_ua1),
        .s2c5_eccb_byp_ua2(esram__s2c5_eccb_byp_ua2),
        .s2c5_eccb_byp_ua3(esram__s2c5_eccb_byp_ua3),
        .s2c5_err_correct_ua0(esram__s2c5_err_correct_ua0),
        .s2c5_err_correct_ua1(esram__s2c5_err_correct_ua1),
        .s2c5_err_correct_ua2(esram__s2c5_err_correct_ua2),
        .s2c5_err_correct_ua3(esram__s2c5_err_correct_ua3),
        .s2c5_err_detect_ua0(esram__s2c5_err_detect_ua0),
        .s2c5_err_detect_ua1(esram__s2c5_err_detect_ua1),
        .s2c5_err_detect_ua2(esram__s2c5_err_detect_ua2),
        .s2c5_err_detect_ua3(esram__s2c5_err_detect_ua3),
        .s2c5_mea_n_ua0(esram__s2c5_mea_n_ua0),
        .s2c5_mea_n_ua1(esram__s2c5_mea_n_ua1),
        .s2c5_mea_n_ua2(esram__s2c5_mea_n_ua2),
        .s2c5_mea_n_ua3(esram__s2c5_mea_n_ua3),
        .s2c5_meb_n_ua0(esram__s2c5_meb_n_ua0),
        .s2c5_meb_n_ua1(esram__s2c5_meb_n_ua1),
        .s2c5_meb_n_ua2(esram__s2c5_meb_n_ua2),
        .s2c5_meb_n_ua3(esram__s2c5_meb_n_ua3),
        .s2c5_sd_n_ua0(esram__s2c5_sd_n_ua0),
        .s2c5_sd_n_ua1(esram__s2c5_sd_n_ua1),
        .s2c5_sd_n_ua2(esram__s2c5_sd_n_ua2),
        .s2c5_sd_n_ua3(esram__s2c5_sd_n_ua3),
        .s2c6_adra_ua0(esram__s2c6_adra_ua0),
        .s2c6_adra_ua1(esram__s2c6_adra_ua1),
        .s2c6_adra_ua2(esram__s2c6_adra_ua2),
        .s2c6_adra_ua3(esram__s2c6_adra_ua3),
        .s2c6_adrb_ua0(esram__s2c6_adrb_ua0),
        .s2c6_adrb_ua1(esram__s2c6_adrb_ua1),
        .s2c6_adrb_ua2(esram__s2c6_adrb_ua2),
        .s2c6_adrb_ua3(esram__s2c6_adrb_ua3),
        .s2c6_da_ua0(esram__s2c6_da_ua0),
        .s2c6_da_ua1(esram__s2c6_da_ua1),
        .s2c6_da_ua2(esram__s2c6_da_ua2),
        .s2c6_da_ua3(esram__s2c6_da_ua3),
        .s2c6_qb_ua0(esram__s2c6_qb_ua0),
        .s2c6_qb_ua1(esram__s2c6_qb_ua1),
        .s2c6_qb_ua2(esram__s2c6_qb_ua2),
        .s2c6_qb_ua3(esram__s2c6_qb_ua3),
        .s2c6_ecca_byp_ua0(esram__s2c6_ecca_byp_ua0),
        .s2c6_ecca_byp_ua1(esram__s2c6_ecca_byp_ua1),
        .s2c6_ecca_byp_ua2(esram__s2c6_ecca_byp_ua2),
        .s2c6_ecca_byp_ua3(esram__s2c6_ecca_byp_ua3),
        .s2c6_eccb_byp_ua0(esram__s2c6_eccb_byp_ua0),
        .s2c6_eccb_byp_ua1(esram__s2c6_eccb_byp_ua1),
        .s2c6_eccb_byp_ua2(esram__s2c6_eccb_byp_ua2),
        .s2c6_eccb_byp_ua3(esram__s2c6_eccb_byp_ua3),
        .s2c6_err_correct_ua0(esram__s2c6_err_correct_ua0),
        .s2c6_err_correct_ua1(esram__s2c6_err_correct_ua1),
        .s2c6_err_correct_ua2(esram__s2c6_err_correct_ua2),
        .s2c6_err_correct_ua3(esram__s2c6_err_correct_ua3),
        .s2c6_err_detect_ua0(esram__s2c6_err_detect_ua0),
        .s2c6_err_detect_ua1(esram__s2c6_err_detect_ua1),
        .s2c6_err_detect_ua2(esram__s2c6_err_detect_ua2),
        .s2c6_err_detect_ua3(esram__s2c6_err_detect_ua3),
        .s2c6_mea_n_ua0(esram__s2c6_mea_n_ua0),
        .s2c6_mea_n_ua1(esram__s2c6_mea_n_ua1),
        .s2c6_mea_n_ua2(esram__s2c6_mea_n_ua2),
        .s2c6_mea_n_ua3(esram__s2c6_mea_n_ua3),
        .s2c6_meb_n_ua0(esram__s2c6_meb_n_ua0),
        .s2c6_meb_n_ua1(esram__s2c6_meb_n_ua1),
        .s2c6_meb_n_ua2(esram__s2c6_meb_n_ua2),
        .s2c6_meb_n_ua3(esram__s2c6_meb_n_ua3),
        .s2c6_sd_n_ua0(esram__s2c6_sd_n_ua0),
        .s2c6_sd_n_ua1(esram__s2c6_sd_n_ua1),
        .s2c6_sd_n_ua2(esram__s2c6_sd_n_ua2),
        .s2c6_sd_n_ua3(esram__s2c6_sd_n_ua3),
        .s2c7_adra_ua0(esram__s2c7_adra_ua0),
        .s2c7_adra_ua1(esram__s2c7_adra_ua1),
        .s2c7_adra_ua2(esram__s2c7_adra_ua2),
        .s2c7_adra_ua3(esram__s2c7_adra_ua3),
        .s2c7_adrb_ua0(esram__s2c7_adrb_ua0),
        .s2c7_adrb_ua1(esram__s2c7_adrb_ua1),
        .s2c7_adrb_ua2(esram__s2c7_adrb_ua2),
        .s2c7_adrb_ua3(esram__s2c7_adrb_ua3),
        .s2c7_da_ua0(esram__s2c7_da_ua0),
        .s2c7_da_ua1(esram__s2c7_da_ua1),
        .s2c7_da_ua2(esram__s2c7_da_ua2),
        .s2c7_da_ua3(esram__s2c7_da_ua3),
        .s2c7_qb_ua0(esram__s2c7_qb_ua0),
        .s2c7_qb_ua1(esram__s2c7_qb_ua1),
        .s2c7_qb_ua2(esram__s2c7_qb_ua2),
        .s2c7_qb_ua3(esram__s2c7_qb_ua3),
        .s2c7_ecca_byp_ua0(esram__s2c7_ecca_byp_ua0),
        .s2c7_ecca_byp_ua1(esram__s2c7_ecca_byp_ua1),
        .s2c7_ecca_byp_ua2(esram__s2c7_ecca_byp_ua2),
        .s2c7_ecca_byp_ua3(esram__s2c7_ecca_byp_ua3),
        .s2c7_eccb_byp_ua0(esram__s2c7_eccb_byp_ua0),
        .s2c7_eccb_byp_ua1(esram__s2c7_eccb_byp_ua1),
        .s2c7_eccb_byp_ua2(esram__s2c7_eccb_byp_ua2),
        .s2c7_eccb_byp_ua3(esram__s2c7_eccb_byp_ua3),
        .s2c7_err_correct_ua0(esram__s2c7_err_correct_ua0),
        .s2c7_err_correct_ua1(esram__s2c7_err_correct_ua1),
        .s2c7_err_correct_ua2(esram__s2c7_err_correct_ua2),
        .s2c7_err_correct_ua3(esram__s2c7_err_correct_ua3),
        .s2c7_err_detect_ua0(esram__s2c7_err_detect_ua0),
        .s2c7_err_detect_ua1(esram__s2c7_err_detect_ua1),
        .s2c7_err_detect_ua2(esram__s2c7_err_detect_ua2),
        .s2c7_err_detect_ua3(esram__s2c7_err_detect_ua3),
        .s2c7_mea_n_ua0(esram__s2c7_mea_n_ua0),
        .s2c7_mea_n_ua1(esram__s2c7_mea_n_ua1),
        .s2c7_mea_n_ua2(esram__s2c7_mea_n_ua2),
        .s2c7_mea_n_ua3(esram__s2c7_mea_n_ua3),
        .s2c7_meb_n_ua0(esram__s2c7_meb_n_ua0),
        .s2c7_meb_n_ua1(esram__s2c7_meb_n_ua1),
        .s2c7_meb_n_ua2(esram__s2c7_meb_n_ua2),
        .s2c7_meb_n_ua3(esram__s2c7_meb_n_ua3),
        .s2c7_sd_n_ua0(esram__s2c7_sd_n_ua0),
        .s2c7_sd_n_ua1(esram__s2c7_sd_n_ua1),
        .s2c7_sd_n_ua2(esram__s2c7_sd_n_ua2),
        .s2c7_sd_n_ua3(esram__s2c7_sd_n_ua3),
        .atpg_mode_n(1'b1),
        .scan_enable0_n(1'b1),
        .freeze_esram_ufi_test_fr_ssm(1'b0),
        .freeze_esram_ufi_nfrzdrv(1'b0),
        .freeze_esram_usrmode(1'b0),
        .freeze_esram_nfrzdrv(1'b1),
        .ptr_en_sync(ptr_en_sync),
        .ptr_en(ptr_en),
        .ptr_rst_n(ptr_rst_n_wire)
    );
        defparam fourteennm_esram_component.c0_wr_fwd_enable        = c0_wr_fwd_enable;
        defparam fourteennm_esram_component.c0_ecc_enable           = c0_ecc_enable;
        defparam fourteennm_esram_component.c0_ecc_byp_enable       = c0_ecc_byp_enable;
        defparam fourteennm_esram_component.c0_bank_enable          = c0_bank_enable;
        defparam fourteennm_esram_component.c0_disable              = c0_disable;
        defparam fourteennm_esram_component.c0_lpmode_enable        = c0_lpmode_enable;
        defparam fourteennm_esram_component.c1_wr_fwd_enable        = c1_wr_fwd_enable;
        defparam fourteennm_esram_component.c1_ecc_enable           = c1_ecc_enable;
        defparam fourteennm_esram_component.c1_ecc_byp_enable       = c1_ecc_byp_enable;
        defparam fourteennm_esram_component.c1_bank_enable          = c1_bank_enable;
        defparam fourteennm_esram_component.c1_disable              = c1_disable;
        defparam fourteennm_esram_component.c1_lpmode_enable        = c1_lpmode_enable;
        defparam fourteennm_esram_component.c2_wr_fwd_enable        = c2_wr_fwd_enable;
        defparam fourteennm_esram_component.c2_ecc_enable           = c2_ecc_enable;
        defparam fourteennm_esram_component.c2_ecc_byp_enable       = c2_ecc_byp_enable;
        defparam fourteennm_esram_component.c2_bank_enable          = c2_bank_enable;
        defparam fourteennm_esram_component.c2_disable              = c2_disable;
        defparam fourteennm_esram_component.c2_lpmode_enable        = c2_lpmode_enable;
        defparam fourteennm_esram_component.c3_wr_fwd_enable        = c3_wr_fwd_enable;
        defparam fourteennm_esram_component.c3_ecc_enable           = c3_ecc_enable;
        defparam fourteennm_esram_component.c3_ecc_byp_enable       = c3_ecc_byp_enable;
        defparam fourteennm_esram_component.c3_bank_enable          = c3_bank_enable;
        defparam fourteennm_esram_component.c3_disable              = c3_disable;
        defparam fourteennm_esram_component.c3_lpmode_enable        = c3_lpmode_enable;
        defparam fourteennm_esram_component.c4_wr_fwd_enable        = c4_wr_fwd_enable;
        defparam fourteennm_esram_component.c4_ecc_enable           = c4_ecc_enable;
        defparam fourteennm_esram_component.c4_ecc_byp_enable       = c4_ecc_byp_enable;
        defparam fourteennm_esram_component.c4_bank_enable          = c4_bank_enable;
        defparam fourteennm_esram_component.c4_disable              = c4_disable;
        defparam fourteennm_esram_component.c4_lpmode_enable        = c4_lpmode_enable;
        defparam fourteennm_esram_component.c5_wr_fwd_enable        = c5_wr_fwd_enable;
        defparam fourteennm_esram_component.c5_ecc_enable           = c5_ecc_enable;
        defparam fourteennm_esram_component.c5_ecc_byp_enable       = c5_ecc_byp_enable;
        defparam fourteennm_esram_component.c5_bank_enable          = c5_bank_enable;
        defparam fourteennm_esram_component.c5_disable              = c5_disable;
        defparam fourteennm_esram_component.c5_lpmode_enable        = c5_lpmode_enable;
        defparam fourteennm_esram_component.c6_wr_fwd_enable        = c6_wr_fwd_enable;
        defparam fourteennm_esram_component.c6_ecc_enable           = c6_ecc_enable;
        defparam fourteennm_esram_component.c6_ecc_byp_enable       = c6_ecc_byp_enable;
        defparam fourteennm_esram_component.c6_bank_enable          = c6_bank_enable;
        defparam fourteennm_esram_component.c6_disable              = c6_disable;
        defparam fourteennm_esram_component.c6_lpmode_enable        = c6_lpmode_enable;
        defparam fourteennm_esram_component.c7_wr_fwd_enable        = c7_wr_fwd_enable;
        defparam fourteennm_esram_component.c7_ecc_enable           = c7_ecc_enable;
        defparam fourteennm_esram_component.c7_ecc_byp_enable       = c7_ecc_byp_enable;
        defparam fourteennm_esram_component.c7_bank_enable          = c7_bank_enable;
        defparam fourteennm_esram_component.c7_disable              = c7_disable;
        defparam fourteennm_esram_component.c7_lpmode_enable        = c7_lpmode_enable;
        defparam fourteennm_esram_component.c2p_ptr_dly             = c2p_ptr_dly;
        defparam fourteennm_esram_component.p2c_ptr_dly             = p2c_ptr_dly;

    (* altera_attribute = {"-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER_SYN_ONLY ON; -name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"} *) logic [16-c0_address_width:0] c0_wraddr_tie_off_reg;
    (* altera_attribute = {"-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER_SYN_ONLY ON; -name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"} *) logic [16-c0_address_width:0] c0_rdaddr_tie_off_reg;
    (* altera_attribute = {"-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER_SYN_ONLY ON; -name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"} *) logic [16-c1_address_width:0] c1_wraddr_tie_off_reg;
    (* altera_attribute = {"-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER_SYN_ONLY ON; -name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"} *) logic [16-c1_address_width:0] c1_rdaddr_tie_off_reg;
    (* altera_attribute = {"-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER_SYN_ONLY ON; -name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"} *) logic [16-c2_address_width:0] c2_wraddr_tie_off_reg;
    (* altera_attribute = {"-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER_SYN_ONLY ON; -name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"} *) logic [16-c2_address_width:0] c2_rdaddr_tie_off_reg;
    (* altera_attribute = {"-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER_SYN_ONLY ON; -name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"} *) logic [16-c3_address_width:0] c3_wraddr_tie_off_reg;
    (* altera_attribute = {"-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER_SYN_ONLY ON; -name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"} *) logic [16-c3_address_width:0] c3_rdaddr_tie_off_reg;
    (* altera_attribute = {"-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER_SYN_ONLY ON; -name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"} *) logic [16-c4_address_width:0] c4_wraddr_tie_off_reg;
    (* altera_attribute = {"-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER_SYN_ONLY ON; -name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"} *) logic [16-c4_address_width:0] c4_rdaddr_tie_off_reg;
    (* altera_attribute = {"-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER_SYN_ONLY ON; -name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"} *) logic [16-c5_address_width:0] c5_wraddr_tie_off_reg;
    (* altera_attribute = {"-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER_SYN_ONLY ON; -name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"} *) logic [16-c5_address_width:0] c5_rdaddr_tie_off_reg;
    (* altera_attribute = {"-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER_SYN_ONLY ON; -name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"} *) logic [16-c6_address_width:0] c6_wraddr_tie_off_reg;
    (* altera_attribute = {"-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER_SYN_ONLY ON; -name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"} *) logic [16-c6_address_width:0] c6_rdaddr_tie_off_reg;
    (* altera_attribute = {"-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER_SYN_ONLY ON; -name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"} *) logic [16-c7_address_width:0] c7_wraddr_tie_off_reg;
    (* altera_attribute = {"-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER_SYN_ONLY ON; -name FORCE_HYPER_REGISTER_FOR_UIB_ESRAM_CORE_REGISTER ON"} *) logic [16-c7_address_width:0] c7_rdaddr_tie_off_reg;
    always @(posedge esram2f_clk_w[0]) begin
        c0_wraddr_tie_off_reg <= 6'b000000;
        c0_rdaddr_tie_off_reg <= 6'b000000;
        c1_wraddr_tie_off_reg <= 6'b000000;
        c1_rdaddr_tie_off_reg <= 6'b000000;
        c2_wraddr_tie_off_reg <= 6'b000000;
        c2_rdaddr_tie_off_reg <= 6'b000000;
        c3_wraddr_tie_off_reg <= 6'b000000;
        c3_rdaddr_tie_off_reg <= 6'b000000;
        c4_wraddr_tie_off_reg <= 6'b000000;
        c4_rdaddr_tie_off_reg <= 6'b000000;
        c5_wraddr_tie_off_reg <= 6'b000000;
        c5_rdaddr_tie_off_reg <= 6'b000000;
        c6_wraddr_tie_off_reg <= 6'b000000;
        c6_rdaddr_tie_off_reg <= 6'b000000;
        c7_wraddr_tie_off_reg <= 6'b000000;
        c7_rdaddr_tie_off_reg <= 6'b000000;
    end

    //Ufi connection
    fourteennm_ufi_esram fourteennm_ufi_esram_component (
        .f2esram_clk_cpa(esram2f_clk_ufi),                  //ufi input 32 bits
        .esram2f_clk_ufi(esram2f_clk_ufi),                  //ufi output 32 bits
        .f2esram_clk(f2esram_clk_wire),                     //ufi output to esram
        .esram2f_clk(esram2f_clk_wire),                     //ufi input from esram
        .esram_iopll_lock2iohmc(iopll_lock2core_ufi),       //pll lock signal from esram iopll
        .iopll_lock2core(iopll_lock2core_w),                  //output pll lock signal to core
        .s2c0_adra_0({c0_wraddr_tie_off_reg,c0_wraddress_0_reg}),
        .s2c0_adrb_0({c0_rdaddr_tie_off_reg,c0_rdaddress_0_reg}),
        .s2c0_da_0(c0_data_0_reg),
        .s2c0_ecca_byp_0(c0_eccencbypass_0_reg),
        .s2c0_eccb_byp_0(c0_eccdecbypass_0_reg),
        .s2c0_mea_n_0(c0_wren_n_0_reg),
        .s2c0_meb_n_0(c0_rden_n_0_reg),
        .s2c0_sd_n_0(c0_sd_n_0_reg),
        .s2c0_err_correct_0(c0_error_correct_0_w),
        .s2c0_err_detect_0(c0_error_detect_0_w),
        .s2c0_qb_0(c0_q_0_w),
        .s2c1_adra_0({c1_wraddr_tie_off_reg,c1_wraddress_0_reg}),
        .s2c1_adrb_0({c1_rdaddr_tie_off_reg,c1_rdaddress_0_reg}),
        .s2c1_da_0(c1_data_0_reg),
        .s2c1_ecca_byp_0(c1_eccencbypass_0_reg),
        .s2c1_eccb_byp_0(c1_eccdecbypass_0_reg),
        .s2c1_mea_n_0(c1_wren_n_0_reg),
        .s2c1_meb_n_0(c1_rden_n_0_reg),
        .s2c1_sd_n_0(c1_sd_n_0_reg),
        .s2c1_err_correct_0(c1_error_correct_0_w),
        .s2c1_err_detect_0(c1_error_detect_0_w),
        .s2c1_qb_0(c1_q_0_w),
        .s2c2_adra_0({c2_wraddr_tie_off_reg,c2_wraddress_0_reg}),
        .s2c2_adrb_0({c2_rdaddr_tie_off_reg,c2_rdaddress_0_reg}),
        .s2c2_da_0(c2_data_0_reg),
        .s2c2_ecca_byp_0(c2_eccencbypass_0_reg),
        .s2c2_eccb_byp_0(c2_eccdecbypass_0_reg),
        .s2c2_mea_n_0(c2_wren_n_0_reg),
        .s2c2_meb_n_0(c2_rden_n_0_reg),
        .s2c2_sd_n_0(c2_sd_n_0_reg),
        .s2c2_err_correct_0(c2_error_correct_0_w),
        .s2c2_err_detect_0(c2_error_detect_0_w),
        .s2c2_qb_0(c2_q_0_w),
        .s2c3_adra_0({c3_wraddr_tie_off_reg,c3_wraddress_0_reg}),
        .s2c3_adrb_0({c3_rdaddr_tie_off_reg,c3_rdaddress_0_reg}),
        .s2c3_da_0(c3_data_0_reg),
        .s2c3_ecca_byp_0(c3_eccencbypass_0_reg),
        .s2c3_eccb_byp_0(c3_eccdecbypass_0_reg),
        .s2c3_mea_n_0(c3_wren_n_0_reg),
        .s2c3_meb_n_0(c3_rden_n_0_reg),
        .s2c3_sd_n_0(c3_sd_n_0_reg),
        .s2c3_err_correct_0(c3_error_correct_0_w),
        .s2c3_err_detect_0(c3_error_detect_0_w),
        .s2c3_qb_0(c3_q_0_w),
        .s2c4_adra_0({c4_wraddr_tie_off_reg,c4_wraddress_0_reg}),
        .s2c4_adrb_0({c4_rdaddr_tie_off_reg,c4_rdaddress_0_reg}),
        .s2c4_da_0(c4_data_0_reg),
        .s2c4_ecca_byp_0(c4_eccencbypass_0_reg),
        .s2c4_eccb_byp_0(c4_eccdecbypass_0_reg),
        .s2c4_mea_n_0(c4_wren_n_0_reg),
        .s2c4_meb_n_0(c4_rden_n_0_reg),
        .s2c4_sd_n_0(c4_sd_n_0_reg),
        .s2c4_err_correct_0(c4_error_correct_0_w),
        .s2c4_err_detect_0(c4_error_detect_0_w),
        .s2c4_qb_0(c4_q_0_w),
        .s2c5_adra_0({c5_wraddr_tie_off_reg,c5_wraddress_0_reg}),
        .s2c5_adrb_0({c5_rdaddr_tie_off_reg,c5_rdaddress_0_reg}),
        .s2c5_da_0(c5_data_0_reg),
        .s2c5_ecca_byp_0(c5_eccencbypass_0_reg),
        .s2c5_eccb_byp_0(c5_eccdecbypass_0_reg),
        .s2c5_mea_n_0(c5_wren_n_0_reg),
        .s2c5_meb_n_0(c5_rden_n_0_reg),
        .s2c5_sd_n_0(c5_sd_n_0_reg),
        .s2c5_err_correct_0(c5_error_correct_0_w),
        .s2c5_err_detect_0(c5_error_detect_0_w),
        .s2c5_qb_0(c5_q_0_w),
        .s2c6_adra_0({c6_wraddr_tie_off_reg,c6_wraddress_0_reg}),
        .s2c6_adrb_0({c6_rdaddr_tie_off_reg,c6_rdaddress_0_reg}),
        .s2c6_da_0(c6_data_0_reg),
        .s2c6_ecca_byp_0(c6_eccencbypass_0_reg),
        .s2c6_eccb_byp_0(c6_eccdecbypass_0_reg),
        .s2c6_mea_n_0(c6_wren_n_0_reg),
        .s2c6_meb_n_0(c6_rden_n_0_reg),
        .s2c6_sd_n_0(c6_sd_n_0_reg),
        .s2c6_err_correct_0(c6_error_correct_0_w),
        .s2c6_err_detect_0(c6_error_detect_0_w),
        .s2c6_qb_0(c6_q_0_w),
        .s2c7_adra_0({c7_wraddr_tie_off_reg,c7_wraddress_0_reg}),
        .s2c7_adrb_0({c7_rdaddr_tie_off_reg,c7_rdaddress_0_reg}),
        .s2c7_da_0(c7_data_0_reg),
        .s2c7_ecca_byp_0(c7_eccencbypass_0_reg),
        .s2c7_eccb_byp_0(c7_eccdecbypass_0_reg),
        .s2c7_mea_n_0(c7_wren_n_0_reg),
        .s2c7_meb_n_0(c7_rden_n_0_reg),
        .s2c7_sd_n_0(c7_sd_n_0_reg),
        .s2c7_err_correct_0(c7_error_correct_0_w),
        .s2c7_err_detect_0(c7_error_detect_0_w),
        .s2c7_qb_0(c7_q_0_w),
        .s2c0_adra_ua0     (esram__s2c0_adra_ua0),
        .s2c0_adrb_ua0     (esram__s2c0_adrb_ua0),
        .s2c0_da_ua0     (esram__s2c0_da_ua0),
        .s2c0_qb_ua0     (esram__s2c0_qb_ua0),
        .s2c0_ecca_byp_ua0     (esram__s2c0_ecca_byp_ua0),
        .s2c0_eccb_byp_ua0     (esram__s2c0_eccb_byp_ua0),
        .s2c0_err_correct_ua0     (esram__s2c0_err_correct_ua0),
        .s2c0_err_detect_ua0     (esram__s2c0_err_detect_ua0),
        .s2c0_mea_n_ua0     (esram__s2c0_mea_n_ua0),
        .s2c0_meb_n_ua0     (esram__s2c0_meb_n_ua0),
        .s2c0_sd_n_ua0     (esram__s2c0_sd_n_ua0),
        .s2c0_adra_ua1     (esram__s2c0_adra_ua1),
        .s2c0_adrb_ua1     (esram__s2c0_adrb_ua1),
        .s2c0_da_ua1     (esram__s2c0_da_ua1),
        .s2c0_qb_ua1     (esram__s2c0_qb_ua1),
        .s2c0_ecca_byp_ua1     (esram__s2c0_ecca_byp_ua1),
        .s2c0_eccb_byp_ua1     (esram__s2c0_eccb_byp_ua1),
        .s2c0_err_correct_ua1     (esram__s2c0_err_correct_ua1),
        .s2c0_err_detect_ua1     (esram__s2c0_err_detect_ua1),
        .s2c0_mea_n_ua1     (esram__s2c0_mea_n_ua1),
        .s2c0_meb_n_ua1     (esram__s2c0_meb_n_ua1),
        .s2c0_sd_n_ua1     (esram__s2c0_sd_n_ua1),
        .s2c0_adra_ua2     (esram__s2c0_adra_ua2),
        .s2c0_adrb_ua2     (esram__s2c0_adrb_ua2),
        .s2c0_da_ua2     (esram__s2c0_da_ua2),
        .s2c0_qb_ua2     (esram__s2c0_qb_ua2),
        .s2c0_ecca_byp_ua2     (esram__s2c0_ecca_byp_ua2),
        .s2c0_eccb_byp_ua2     (esram__s2c0_eccb_byp_ua2),
        .s2c0_err_correct_ua2     (esram__s2c0_err_correct_ua2),
        .s2c0_err_detect_ua2     (esram__s2c0_err_detect_ua2),
        .s2c0_mea_n_ua2     (esram__s2c0_mea_n_ua2),
        .s2c0_meb_n_ua2     (esram__s2c0_meb_n_ua2),
        .s2c0_sd_n_ua2     (esram__s2c0_sd_n_ua2),
        .s2c0_adra_ua3     (esram__s2c0_adra_ua3),
        .s2c0_adrb_ua3     (esram__s2c0_adrb_ua3),
        .s2c0_da_ua3     (esram__s2c0_da_ua3),
        .s2c0_qb_ua3     (esram__s2c0_qb_ua3),
        .s2c0_ecca_byp_ua3     (esram__s2c0_ecca_byp_ua3),
        .s2c0_eccb_byp_ua3     (esram__s2c0_eccb_byp_ua3),
        .s2c0_err_correct_ua3     (esram__s2c0_err_correct_ua3),
        .s2c0_err_detect_ua3     (esram__s2c0_err_detect_ua3),
        .s2c0_mea_n_ua3     (esram__s2c0_mea_n_ua3),
        .s2c0_meb_n_ua3     (esram__s2c0_meb_n_ua3),
        .s2c0_sd_n_ua3     (esram__s2c0_sd_n_ua3),
        .s2c1_adra_ua0     (esram__s2c1_adra_ua0),
        .s2c1_adrb_ua0     (esram__s2c1_adrb_ua0),
        .s2c1_da_ua0     (esram__s2c1_da_ua0),
        .s2c1_qb_ua0     (esram__s2c1_qb_ua0),
        .s2c1_ecca_byp_ua0     (esram__s2c1_ecca_byp_ua0),
        .s2c1_eccb_byp_ua0     (esram__s2c1_eccb_byp_ua0),
        .s2c1_err_correct_ua0     (esram__s2c1_err_correct_ua0),
        .s2c1_err_detect_ua0     (esram__s2c1_err_detect_ua0),
        .s2c1_mea_n_ua0     (esram__s2c1_mea_n_ua0),
        .s2c1_meb_n_ua0     (esram__s2c1_meb_n_ua0),
        .s2c1_sd_n_ua0     (esram__s2c1_sd_n_ua0),
        .s2c1_adra_ua1     (esram__s2c1_adra_ua1),
        .s2c1_adrb_ua1     (esram__s2c1_adrb_ua1),
        .s2c1_da_ua1     (esram__s2c1_da_ua1),
        .s2c1_qb_ua1     (esram__s2c1_qb_ua1),
        .s2c1_ecca_byp_ua1     (esram__s2c1_ecca_byp_ua1),
        .s2c1_eccb_byp_ua1     (esram__s2c1_eccb_byp_ua1),
        .s2c1_err_correct_ua1     (esram__s2c1_err_correct_ua1),
        .s2c1_err_detect_ua1     (esram__s2c1_err_detect_ua1),
        .s2c1_mea_n_ua1     (esram__s2c1_mea_n_ua1),
        .s2c1_meb_n_ua1     (esram__s2c1_meb_n_ua1),
        .s2c1_sd_n_ua1     (esram__s2c1_sd_n_ua1),
        .s2c1_adra_ua2     (esram__s2c1_adra_ua2),
        .s2c1_adrb_ua2     (esram__s2c1_adrb_ua2),
        .s2c1_da_ua2     (esram__s2c1_da_ua2),
        .s2c1_qb_ua2     (esram__s2c1_qb_ua2),
        .s2c1_ecca_byp_ua2     (esram__s2c1_ecca_byp_ua2),
        .s2c1_eccb_byp_ua2     (esram__s2c1_eccb_byp_ua2),
        .s2c1_err_correct_ua2     (esram__s2c1_err_correct_ua2),
        .s2c1_err_detect_ua2     (esram__s2c1_err_detect_ua2),
        .s2c1_mea_n_ua2     (esram__s2c1_mea_n_ua2),
        .s2c1_meb_n_ua2     (esram__s2c1_meb_n_ua2),
        .s2c1_sd_n_ua2     (esram__s2c1_sd_n_ua2),
        .s2c1_adra_ua3     (esram__s2c1_adra_ua3),
        .s2c1_adrb_ua3     (esram__s2c1_adrb_ua3),
        .s2c1_da_ua3     (esram__s2c1_da_ua3),
        .s2c1_qb_ua3     (esram__s2c1_qb_ua3),
        .s2c1_ecca_byp_ua3     (esram__s2c1_ecca_byp_ua3),
        .s2c1_eccb_byp_ua3     (esram__s2c1_eccb_byp_ua3),
        .s2c1_err_correct_ua3     (esram__s2c1_err_correct_ua3),
        .s2c1_err_detect_ua3     (esram__s2c1_err_detect_ua3),
        .s2c1_mea_n_ua3     (esram__s2c1_mea_n_ua3),
        .s2c1_meb_n_ua3     (esram__s2c1_meb_n_ua3),
        .s2c1_sd_n_ua3     (esram__s2c1_sd_n_ua3),
        .s2c2_adra_ua0     (esram__s2c2_adra_ua0),
        .s2c2_adrb_ua0     (esram__s2c2_adrb_ua0),
        .s2c2_da_ua0     (esram__s2c2_da_ua0),
        .s2c2_qb_ua0     (esram__s2c2_qb_ua0),
        .s2c2_ecca_byp_ua0     (esram__s2c2_ecca_byp_ua0),
        .s2c2_eccb_byp_ua0     (esram__s2c2_eccb_byp_ua0),
        .s2c2_err_correct_ua0     (esram__s2c2_err_correct_ua0),
        .s2c2_err_detect_ua0     (esram__s2c2_err_detect_ua0),
        .s2c2_mea_n_ua0     (esram__s2c2_mea_n_ua0),
        .s2c2_meb_n_ua0     (esram__s2c2_meb_n_ua0),
        .s2c2_sd_n_ua0     (esram__s2c2_sd_n_ua0),
        .s2c2_adra_ua1     (esram__s2c2_adra_ua1),
        .s2c2_adrb_ua1     (esram__s2c2_adrb_ua1),
        .s2c2_da_ua1     (esram__s2c2_da_ua1),
        .s2c2_qb_ua1     (esram__s2c2_qb_ua1),
        .s2c2_ecca_byp_ua1     (esram__s2c2_ecca_byp_ua1),
        .s2c2_eccb_byp_ua1     (esram__s2c2_eccb_byp_ua1),
        .s2c2_err_correct_ua1     (esram__s2c2_err_correct_ua1),
        .s2c2_err_detect_ua1     (esram__s2c2_err_detect_ua1),
        .s2c2_mea_n_ua1     (esram__s2c2_mea_n_ua1),
        .s2c2_meb_n_ua1     (esram__s2c2_meb_n_ua1),
        .s2c2_sd_n_ua1     (esram__s2c2_sd_n_ua1),
        .s2c2_adra_ua2     (esram__s2c2_adra_ua2),
        .s2c2_adrb_ua2     (esram__s2c2_adrb_ua2),
        .s2c2_da_ua2     (esram__s2c2_da_ua2),
        .s2c2_qb_ua2     (esram__s2c2_qb_ua2),
        .s2c2_ecca_byp_ua2     (esram__s2c2_ecca_byp_ua2),
        .s2c2_eccb_byp_ua2     (esram__s2c2_eccb_byp_ua2),
        .s2c2_err_correct_ua2     (esram__s2c2_err_correct_ua2),
        .s2c2_err_detect_ua2     (esram__s2c2_err_detect_ua2),
        .s2c2_mea_n_ua2     (esram__s2c2_mea_n_ua2),
        .s2c2_meb_n_ua2     (esram__s2c2_meb_n_ua2),
        .s2c2_sd_n_ua2     (esram__s2c2_sd_n_ua2),
        .s2c2_adra_ua3     (esram__s2c2_adra_ua3),
        .s2c2_adrb_ua3     (esram__s2c2_adrb_ua3),
        .s2c2_da_ua3     (esram__s2c2_da_ua3),
        .s2c2_qb_ua3     (esram__s2c2_qb_ua3),
        .s2c2_ecca_byp_ua3     (esram__s2c2_ecca_byp_ua3),
        .s2c2_eccb_byp_ua3     (esram__s2c2_eccb_byp_ua3),
        .s2c2_err_correct_ua3     (esram__s2c2_err_correct_ua3),
        .s2c2_err_detect_ua3     (esram__s2c2_err_detect_ua3),
        .s2c2_mea_n_ua3     (esram__s2c2_mea_n_ua3),
        .s2c2_meb_n_ua3     (esram__s2c2_meb_n_ua3),
        .s2c2_sd_n_ua3     (esram__s2c2_sd_n_ua3),
        .s2c3_adra_ua0     (esram__s2c3_adra_ua0),
        .s2c3_adrb_ua0     (esram__s2c3_adrb_ua0),
        .s2c3_da_ua0     (esram__s2c3_da_ua0),
        .s2c3_qb_ua0     (esram__s2c3_qb_ua0),
        .s2c3_ecca_byp_ua0     (esram__s2c3_ecca_byp_ua0),
        .s2c3_eccb_byp_ua0     (esram__s2c3_eccb_byp_ua0),
        .s2c3_err_correct_ua0     (esram__s2c3_err_correct_ua0),
        .s2c3_err_detect_ua0     (esram__s2c3_err_detect_ua0),
        .s2c3_mea_n_ua0     (esram__s2c3_mea_n_ua0),
        .s2c3_meb_n_ua0     (esram__s2c3_meb_n_ua0),
        .s2c3_sd_n_ua0     (esram__s2c3_sd_n_ua0),
        .s2c3_adra_ua1     (esram__s2c3_adra_ua1),
        .s2c3_adrb_ua1     (esram__s2c3_adrb_ua1),
        .s2c3_da_ua1     (esram__s2c3_da_ua1),
        .s2c3_qb_ua1     (esram__s2c3_qb_ua1),
        .s2c3_ecca_byp_ua1     (esram__s2c3_ecca_byp_ua1),
        .s2c3_eccb_byp_ua1     (esram__s2c3_eccb_byp_ua1),
        .s2c3_err_correct_ua1     (esram__s2c3_err_correct_ua1),
        .s2c3_err_detect_ua1     (esram__s2c3_err_detect_ua1),
        .s2c3_mea_n_ua1     (esram__s2c3_mea_n_ua1),
        .s2c3_meb_n_ua1     (esram__s2c3_meb_n_ua1),
        .s2c3_sd_n_ua1     (esram__s2c3_sd_n_ua1),
        .s2c3_adra_ua2     (esram__s2c3_adra_ua2),
        .s2c3_adrb_ua2     (esram__s2c3_adrb_ua2),
        .s2c3_da_ua2     (esram__s2c3_da_ua2),
        .s2c3_qb_ua2     (esram__s2c3_qb_ua2),
        .s2c3_ecca_byp_ua2     (esram__s2c3_ecca_byp_ua2),
        .s2c3_eccb_byp_ua2     (esram__s2c3_eccb_byp_ua2),
        .s2c3_err_correct_ua2     (esram__s2c3_err_correct_ua2),
        .s2c3_err_detect_ua2     (esram__s2c3_err_detect_ua2),
        .s2c3_mea_n_ua2     (esram__s2c3_mea_n_ua2),
        .s2c3_meb_n_ua2     (esram__s2c3_meb_n_ua2),
        .s2c3_sd_n_ua2     (esram__s2c3_sd_n_ua2),
        .s2c3_adra_ua3     (esram__s2c3_adra_ua3),
        .s2c3_adrb_ua3     (esram__s2c3_adrb_ua3),
        .s2c3_da_ua3     (esram__s2c3_da_ua3),
        .s2c3_qb_ua3     (esram__s2c3_qb_ua3),
        .s2c3_ecca_byp_ua3     (esram__s2c3_ecca_byp_ua3),
        .s2c3_eccb_byp_ua3     (esram__s2c3_eccb_byp_ua3),
        .s2c3_err_correct_ua3     (esram__s2c3_err_correct_ua3),
        .s2c3_err_detect_ua3     (esram__s2c3_err_detect_ua3),
        .s2c3_mea_n_ua3     (esram__s2c3_mea_n_ua3),
        .s2c3_meb_n_ua3     (esram__s2c3_meb_n_ua3),
        .s2c3_sd_n_ua3     (esram__s2c3_sd_n_ua3),
        .s2c4_adra_ua0     (esram__s2c4_adra_ua0),
        .s2c4_adrb_ua0     (esram__s2c4_adrb_ua0),
        .s2c4_da_ua0     (esram__s2c4_da_ua0),
        .s2c4_qb_ua0     (esram__s2c4_qb_ua0),
        .s2c4_ecca_byp_ua0     (esram__s2c4_ecca_byp_ua0),
        .s2c4_eccb_byp_ua0     (esram__s2c4_eccb_byp_ua0),
        .s2c4_err_correct_ua0     (esram__s2c4_err_correct_ua0),
        .s2c4_err_detect_ua0     (esram__s2c4_err_detect_ua0),
        .s2c4_mea_n_ua0     (esram__s2c4_mea_n_ua0),
        .s2c4_meb_n_ua0     (esram__s2c4_meb_n_ua0),
        .s2c4_sd_n_ua0     (esram__s2c4_sd_n_ua0),
        .s2c4_adra_ua1     (esram__s2c4_adra_ua1),
        .s2c4_adrb_ua1     (esram__s2c4_adrb_ua1),
        .s2c4_da_ua1     (esram__s2c4_da_ua1),
        .s2c4_qb_ua1     (esram__s2c4_qb_ua1),
        .s2c4_ecca_byp_ua1     (esram__s2c4_ecca_byp_ua1),
        .s2c4_eccb_byp_ua1     (esram__s2c4_eccb_byp_ua1),
        .s2c4_err_correct_ua1     (esram__s2c4_err_correct_ua1),
        .s2c4_err_detect_ua1     (esram__s2c4_err_detect_ua1),
        .s2c4_mea_n_ua1     (esram__s2c4_mea_n_ua1),
        .s2c4_meb_n_ua1     (esram__s2c4_meb_n_ua1),
        .s2c4_sd_n_ua1     (esram__s2c4_sd_n_ua1),
        .s2c4_adra_ua2     (esram__s2c4_adra_ua2),
        .s2c4_adrb_ua2     (esram__s2c4_adrb_ua2),
        .s2c4_da_ua2     (esram__s2c4_da_ua2),
        .s2c4_qb_ua2     (esram__s2c4_qb_ua2),
        .s2c4_ecca_byp_ua2     (esram__s2c4_ecca_byp_ua2),
        .s2c4_eccb_byp_ua2     (esram__s2c4_eccb_byp_ua2),
        .s2c4_err_correct_ua2     (esram__s2c4_err_correct_ua2),
        .s2c4_err_detect_ua2     (esram__s2c4_err_detect_ua2),
        .s2c4_mea_n_ua2     (esram__s2c4_mea_n_ua2),
        .s2c4_meb_n_ua2     (esram__s2c4_meb_n_ua2),
        .s2c4_sd_n_ua2     (esram__s2c4_sd_n_ua2),
        .s2c4_adra_ua3     (esram__s2c4_adra_ua3),
        .s2c4_adrb_ua3     (esram__s2c4_adrb_ua3),
        .s2c4_da_ua3     (esram__s2c4_da_ua3),
        .s2c4_qb_ua3     (esram__s2c4_qb_ua3),
        .s2c4_ecca_byp_ua3     (esram__s2c4_ecca_byp_ua3),
        .s2c4_eccb_byp_ua3     (esram__s2c4_eccb_byp_ua3),
        .s2c4_err_correct_ua3     (esram__s2c4_err_correct_ua3),
        .s2c4_err_detect_ua3     (esram__s2c4_err_detect_ua3),
        .s2c4_mea_n_ua3     (esram__s2c4_mea_n_ua3),
        .s2c4_meb_n_ua3     (esram__s2c4_meb_n_ua3),
        .s2c4_sd_n_ua3     (esram__s2c4_sd_n_ua3),
        .s2c5_adra_ua0     (esram__s2c5_adra_ua0),
        .s2c5_adrb_ua0     (esram__s2c5_adrb_ua0),
        .s2c5_da_ua0     (esram__s2c5_da_ua0),
        .s2c5_qb_ua0     (esram__s2c5_qb_ua0),
        .s2c5_ecca_byp_ua0     (esram__s2c5_ecca_byp_ua0),
        .s2c5_eccb_byp_ua0     (esram__s2c5_eccb_byp_ua0),
        .s2c5_err_correct_ua0     (esram__s2c5_err_correct_ua0),
        .s2c5_err_detect_ua0     (esram__s2c5_err_detect_ua0),
        .s2c5_mea_n_ua0     (esram__s2c5_mea_n_ua0),
        .s2c5_meb_n_ua0     (esram__s2c5_meb_n_ua0),
        .s2c5_sd_n_ua0     (esram__s2c5_sd_n_ua0),
        .s2c5_adra_ua1     (esram__s2c5_adra_ua1),
        .s2c5_adrb_ua1     (esram__s2c5_adrb_ua1),
        .s2c5_da_ua1     (esram__s2c5_da_ua1),
        .s2c5_qb_ua1     (esram__s2c5_qb_ua1),
        .s2c5_ecca_byp_ua1     (esram__s2c5_ecca_byp_ua1),
        .s2c5_eccb_byp_ua1     (esram__s2c5_eccb_byp_ua1),
        .s2c5_err_correct_ua1     (esram__s2c5_err_correct_ua1),
        .s2c5_err_detect_ua1     (esram__s2c5_err_detect_ua1),
        .s2c5_mea_n_ua1     (esram__s2c5_mea_n_ua1),
        .s2c5_meb_n_ua1     (esram__s2c5_meb_n_ua1),
        .s2c5_sd_n_ua1     (esram__s2c5_sd_n_ua1),
        .s2c5_adra_ua2     (esram__s2c5_adra_ua2),
        .s2c5_adrb_ua2     (esram__s2c5_adrb_ua2),
        .s2c5_da_ua2     (esram__s2c5_da_ua2),
        .s2c5_qb_ua2     (esram__s2c5_qb_ua2),
        .s2c5_ecca_byp_ua2     (esram__s2c5_ecca_byp_ua2),
        .s2c5_eccb_byp_ua2     (esram__s2c5_eccb_byp_ua2),
        .s2c5_err_correct_ua2     (esram__s2c5_err_correct_ua2),
        .s2c5_err_detect_ua2     (esram__s2c5_err_detect_ua2),
        .s2c5_mea_n_ua2     (esram__s2c5_mea_n_ua2),
        .s2c5_meb_n_ua2     (esram__s2c5_meb_n_ua2),
        .s2c5_sd_n_ua2     (esram__s2c5_sd_n_ua2),
        .s2c5_adra_ua3     (esram__s2c5_adra_ua3),
        .s2c5_adrb_ua3     (esram__s2c5_adrb_ua3),
        .s2c5_da_ua3     (esram__s2c5_da_ua3),
        .s2c5_qb_ua3     (esram__s2c5_qb_ua3),
        .s2c5_ecca_byp_ua3     (esram__s2c5_ecca_byp_ua3),
        .s2c5_eccb_byp_ua3     (esram__s2c5_eccb_byp_ua3),
        .s2c5_err_correct_ua3     (esram__s2c5_err_correct_ua3),
        .s2c5_err_detect_ua3     (esram__s2c5_err_detect_ua3),
        .s2c5_mea_n_ua3     (esram__s2c5_mea_n_ua3),
        .s2c5_meb_n_ua3     (esram__s2c5_meb_n_ua3),
        .s2c5_sd_n_ua3     (esram__s2c5_sd_n_ua3),
        .s2c6_adra_ua0     (esram__s2c6_adra_ua0),
        .s2c6_adrb_ua0     (esram__s2c6_adrb_ua0),
        .s2c6_da_ua0     (esram__s2c6_da_ua0),
        .s2c6_qb_ua0     (esram__s2c6_qb_ua0),
        .s2c6_ecca_byp_ua0     (esram__s2c6_ecca_byp_ua0),
        .s2c6_eccb_byp_ua0     (esram__s2c6_eccb_byp_ua0),
        .s2c6_err_correct_ua0     (esram__s2c6_err_correct_ua0),
        .s2c6_err_detect_ua0     (esram__s2c6_err_detect_ua0),
        .s2c6_mea_n_ua0     (esram__s2c6_mea_n_ua0),
        .s2c6_meb_n_ua0     (esram__s2c6_meb_n_ua0),
        .s2c6_sd_n_ua0     (esram__s2c6_sd_n_ua0),
        .s2c6_adra_ua1     (esram__s2c6_adra_ua1),
        .s2c6_adrb_ua1     (esram__s2c6_adrb_ua1),
        .s2c6_da_ua1     (esram__s2c6_da_ua1),
        .s2c6_qb_ua1     (esram__s2c6_qb_ua1),
        .s2c6_ecca_byp_ua1     (esram__s2c6_ecca_byp_ua1),
        .s2c6_eccb_byp_ua1     (esram__s2c6_eccb_byp_ua1),
        .s2c6_err_correct_ua1     (esram__s2c6_err_correct_ua1),
        .s2c6_err_detect_ua1     (esram__s2c6_err_detect_ua1),
        .s2c6_mea_n_ua1     (esram__s2c6_mea_n_ua1),
        .s2c6_meb_n_ua1     (esram__s2c6_meb_n_ua1),
        .s2c6_sd_n_ua1     (esram__s2c6_sd_n_ua1),
        .s2c6_adra_ua2     (esram__s2c6_adra_ua2),
        .s2c6_adrb_ua2     (esram__s2c6_adrb_ua2),
        .s2c6_da_ua2     (esram__s2c6_da_ua2),
        .s2c6_qb_ua2     (esram__s2c6_qb_ua2),
        .s2c6_ecca_byp_ua2     (esram__s2c6_ecca_byp_ua2),
        .s2c6_eccb_byp_ua2     (esram__s2c6_eccb_byp_ua2),
        .s2c6_err_correct_ua2     (esram__s2c6_err_correct_ua2),
        .s2c6_err_detect_ua2     (esram__s2c6_err_detect_ua2),
        .s2c6_mea_n_ua2     (esram__s2c6_mea_n_ua2),
        .s2c6_meb_n_ua2     (esram__s2c6_meb_n_ua2),
        .s2c6_sd_n_ua2     (esram__s2c6_sd_n_ua2),
        .s2c6_adra_ua3     (esram__s2c6_adra_ua3),
        .s2c6_adrb_ua3     (esram__s2c6_adrb_ua3),
        .s2c6_da_ua3     (esram__s2c6_da_ua3),
        .s2c6_qb_ua3     (esram__s2c6_qb_ua3),
        .s2c6_ecca_byp_ua3     (esram__s2c6_ecca_byp_ua3),
        .s2c6_eccb_byp_ua3     (esram__s2c6_eccb_byp_ua3),
        .s2c6_err_correct_ua3     (esram__s2c6_err_correct_ua3),
        .s2c6_err_detect_ua3     (esram__s2c6_err_detect_ua3),
        .s2c6_mea_n_ua3     (esram__s2c6_mea_n_ua3),
        .s2c6_meb_n_ua3     (esram__s2c6_meb_n_ua3),
        .s2c6_sd_n_ua3     (esram__s2c6_sd_n_ua3),
        .s2c7_adra_ua0     (esram__s2c7_adra_ua0),
        .s2c7_adrb_ua0     (esram__s2c7_adrb_ua0),
        .s2c7_da_ua0     (esram__s2c7_da_ua0),
        .s2c7_qb_ua0     (esram__s2c7_qb_ua0),
        .s2c7_ecca_byp_ua0     (esram__s2c7_ecca_byp_ua0),
        .s2c7_eccb_byp_ua0     (esram__s2c7_eccb_byp_ua0),
        .s2c7_err_correct_ua0     (esram__s2c7_err_correct_ua0),
        .s2c7_err_detect_ua0     (esram__s2c7_err_detect_ua0),
        .s2c7_mea_n_ua0     (esram__s2c7_mea_n_ua0),
        .s2c7_meb_n_ua0     (esram__s2c7_meb_n_ua0),
        .s2c7_sd_n_ua0     (esram__s2c7_sd_n_ua0),
        .s2c7_adra_ua1     (esram__s2c7_adra_ua1),
        .s2c7_adrb_ua1     (esram__s2c7_adrb_ua1),
        .s2c7_da_ua1     (esram__s2c7_da_ua1),
        .s2c7_qb_ua1     (esram__s2c7_qb_ua1),
        .s2c7_ecca_byp_ua1     (esram__s2c7_ecca_byp_ua1),
        .s2c7_eccb_byp_ua1     (esram__s2c7_eccb_byp_ua1),
        .s2c7_err_correct_ua1     (esram__s2c7_err_correct_ua1),
        .s2c7_err_detect_ua1     (esram__s2c7_err_detect_ua1),
        .s2c7_mea_n_ua1     (esram__s2c7_mea_n_ua1),
        .s2c7_meb_n_ua1     (esram__s2c7_meb_n_ua1),
        .s2c7_sd_n_ua1     (esram__s2c7_sd_n_ua1),
        .s2c7_adra_ua2     (esram__s2c7_adra_ua2),
        .s2c7_adrb_ua2     (esram__s2c7_adrb_ua2),
        .s2c7_da_ua2     (esram__s2c7_da_ua2),
        .s2c7_qb_ua2     (esram__s2c7_qb_ua2),
        .s2c7_ecca_byp_ua2     (esram__s2c7_ecca_byp_ua2),
        .s2c7_eccb_byp_ua2     (esram__s2c7_eccb_byp_ua2),
        .s2c7_err_correct_ua2     (esram__s2c7_err_correct_ua2),
        .s2c7_err_detect_ua2     (esram__s2c7_err_detect_ua2),
        .s2c7_mea_n_ua2     (esram__s2c7_mea_n_ua2),
        .s2c7_meb_n_ua2     (esram__s2c7_meb_n_ua2),
        .s2c7_sd_n_ua2     (esram__s2c7_sd_n_ua2),
        .s2c7_adra_ua3     (esram__s2c7_adra_ua3),
        .s2c7_adrb_ua3     (esram__s2c7_adrb_ua3),
        .s2c7_da_ua3     (esram__s2c7_da_ua3),
        .s2c7_qb_ua3     (esram__s2c7_qb_ua3),
        .s2c7_ecca_byp_ua3     (esram__s2c7_ecca_byp_ua3),
        .s2c7_eccb_byp_ua3     (esram__s2c7_eccb_byp_ua3),
        .s2c7_err_correct_ua3     (esram__s2c7_err_correct_ua3),
        .s2c7_err_detect_ua3     (esram__s2c7_err_detect_ua3),
        .s2c7_mea_n_ua3     (esram__s2c7_mea_n_ua3),
        .s2c7_meb_n_ua3     (esram__s2c7_meb_n_ua3),
        .s2c7_sd_n_ua3     (esram__s2c7_sd_n_ua3),
        .ptr_en_sync(ptr_en_sync),
        .cfg_ptr_rst_n(ptr_rst_n_wire),
        .cfg_ptr_en(ptr_en)
        );

        //Define parameter for ufi_esram
        defparam    fourteennm_ufi_esram_component.a_csr_ctrl0 = clock_rate;
        defparam    fourteennm_ufi_esram_component.xs0_dcm_ufimux32to1_dolsgn_rc_dolsgn_0_a_sel_11_0 = xs0_dcm_ufimux32to1_dolsgn_rc_dolsgn_0_a_sel_11_0;
        defparam    fourteennm_ufi_esram_component.xs0_dcm_ufimux32to1_dolsgn_rc_dolsgn_1_a_sel_11_0 = xs0_dcm_ufimux32to1_dolsgn_rc_dolsgn_1_a_sel_11_0;

    wire [1:0] pll_loaden;
    //Define port and params for cpa
    fourteennm_cpa fourteennm_cpa_component (
        .pa_core_clk_in             (f2esram_clk_to_cip),                       // From CORE f2esram_clk    *input
        .pa_core_clk_out            (esram2f_clk_from_cip),                     // To CORE esram2f_clk
        .pa_fbclk_in                (esram_clk_fb),
        .pll_vco_in                 (vcoph),
        .pa_reset_n                 (locked_iopll),
        .phy_clk_in                 (pll_loaden )                               // loaden from pll
    );
        //Define parameter for CPA
        defparam    fourteennm_cpa_component.pa_sim_mode    = "long";           // new parameter to change rtl_sim mode, to see the actual output clock if the duty cycle differs from the 50%.
        defparam    fourteennm_cpa_component.pa_filter_code = 1200;
        defparam    fourteennm_cpa_component.pa_exponent_0  = 3'b010;
        defparam    fourteennm_cpa_component.pa_exponent_1  = 3'b010;
        defparam    fourteennm_cpa_component.pa_feedback_divider_p0     = "div_by_1";
        defparam    fourteennm_cpa_component.pa_feedback_divider_p1     = "div_by_1";
        defparam    fourteennm_cpa_component.pa_feedback_divider_c0     = "div_by_1";
        defparam    fourteennm_cpa_component.pa_feedback_divider_c1     = "div_by_1";


    iopll mega_iopll (
        .rst                (1'b0),
        .adjpllin           (refclk),
        .locked             (locked_iopll),
        .extclk_out         ({extclk1,extclk0}),
        .phout              (vcoph),
        .outclk_4           (pllcout_sig[0]),
        .loaden             (pll_loaden),
        .permit_cal         (1'b1)          //tie off
    );
endmodule
