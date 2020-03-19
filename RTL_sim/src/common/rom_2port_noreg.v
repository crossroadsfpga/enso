// (C) 2001-2018 Intel Corporation. All rights reserved.
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
module  rom_2port_noreg  (
    address_a,
    address_b,
    clock,
    q_a,
    q_b);

	parameter DWIDTH = 16;
	parameter AWIDTH = 15;
	parameter MEM_SIZE = 32768;
	parameter INIT_FILE = "./hashtable0.mif";

    input  [AWIDTH-1:0]  address_a;
    input  [AWIDTH-1:0]  address_b;
    input    clock;
    output [DWIDTH-1:0]  q_a;
    output [DWIDTH-1:0]  q_b;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
    tri1     clock;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

    wire [DWIDTH-1:0] sub_wire0 = 0;
    wire  sub_wire1 = 1'h0;
    wire [DWIDTH-1:0] sub_wire2;
    wire [DWIDTH-1:0] sub_wire3;
    wire [DWIDTH-1:0] q_a = sub_wire2[DWIDTH-1:0];
    wire [DWIDTH-1:0] q_b = sub_wire3[DWIDTH-1:0];

    altera_syncram  altera_syncram_component (
                .address_a (address_a),
                .address_b (address_b),
                .clock0 (clock),
                .data_a (sub_wire0),
                .data_b (sub_wire0),
                .wren_a (sub_wire1),
                .wren_b (sub_wire1),
                .q_a (sub_wire2),
                .q_b (sub_wire3)
                // synopsys translate_off
                ,
                .aclr0 (),
                .aclr1 (),
                .address2_a (1'b1),
                .address2_b (1'b1),
                .addressstall_a (),
                .addressstall_b (),
                .byteena_a (),
                .byteena_b (),
                .clock1 (),
                .clocken0 (),
                .clocken1 (),
                .clocken2 (),
                .clocken3 (),
                .eccencbypass (1'b0),
                .eccencparity (8'b0),
                .eccstatus (),
                .rden_a (),
                .rden_b (),
                .sclr ()
                // synopsys translate_on
                );
    defparam
        altera_syncram_component.address_reg_b  = "CLOCK0",
        altera_syncram_component.clock_enable_input_a  = "BYPASS",
        altera_syncram_component.clock_enable_input_b  = "BYPASS",
        altera_syncram_component.clock_enable_output_a  = "BYPASS",
        altera_syncram_component.clock_enable_output_b  = "BYPASS",
        altera_syncram_component.indata_reg_b  = "CLOCK0",
//`ifdef NO_PLI
//        altera_syncram_component.init_file = "./hashtable0.rif"
//`else
        altera_syncram_component.init_file = INIT_FILE
//`endif
,
        altera_syncram_component.intended_device_family  = "Stratix 10",
        altera_syncram_component.lpm_type  = "altera_syncram",
        altera_syncram_component.numwords_a  = MEM_SIZE,
        altera_syncram_component.numwords_b  = MEM_SIZE,
        altera_syncram_component.operation_mode  = "BIDIR_DUAL_PORT",
        altera_syncram_component.outdata_aclr_a  = "NONE",
        altera_syncram_component.outdata_aclr_b  = "NONE",
        altera_syncram_component.outdata_sclr_a  = "NONE",
        altera_syncram_component.outdata_sclr_b  = "NONE",
        altera_syncram_component.outdata_reg_a  = "UNREGISTERED",
        altera_syncram_component.outdata_reg_b  = "UNREGISTERED",
        altera_syncram_component.power_up_uninitialized  = "FALSE",
        altera_syncram_component.widthad_a  = AWIDTH,
        altera_syncram_component.widthad_b  = AWIDTH,
        altera_syncram_component.width_a  = DWIDTH,
        altera_syncram_component.width_b  = DWIDTH,
        altera_syncram_component.width_byteena_a  = 1,
        altera_syncram_component.width_byteena_b  = 1;

endmodule


