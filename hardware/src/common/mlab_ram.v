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
module  mlab_ram  (
    clock,
    data,
    rdaddress,
    wraddress,
    wren,
    q);
parameter AWIDTH = 3;
parameter DWIDTH = 16;
    input    clock;
    input  [DWIDTH-1:0]  data;
    input  [AWIDTH-1:0]  rdaddress;
    input  [AWIDTH-1:0]  wraddress;
    input    wren;
    output [DWIDTH-1:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

    wire [DWIDTH-1:0] sub_wire0;
    wire [DWIDTH-1:0] q = sub_wire0[DWIDTH-1:0];

    altdpram  altdpram_component (
                .data (data),
                .inclock (clock),
                .outclock (clock),
                .rdaddress (rdaddress),
                .wraddress (wraddress),
                .wren (wren),
                .q (sub_wire0),
                .aclr (1'b0),
                .sclr (1'b0),
                .byteena (1'b1),
                .inclocken (1'b1),
                .outclocken (1'b1),
                .rdaddressstall (1'b0),
                .rden (1'b1),
                .wraddressstall (1'b0));
    defparam
        altdpram_component.indata_aclr  = "OFF",
        altdpram_component.indata_reg  = "INCLOCK",
        altdpram_component.intended_device_family  = "Stratix 10",
        altdpram_component.lpm_type  = "altdpram",
        altdpram_component.ram_block_type  = "MLAB",
        altdpram_component.outdata_aclr  = "OFF",
        altdpram_component.outdata_sclr  = "OFF",
        altdpram_component.outdata_reg  = "INCLOCK",
        altdpram_component.rdaddress_aclr  = "OFF",
        altdpram_component.rdaddress_reg  = "UNREGISTERED",
        altdpram_component.rdcontrol_aclr  = "OFF",
        altdpram_component.rdcontrol_reg  = "UNREGISTERED",
        altdpram_component.read_during_write_mode_mixed_ports  = "DONT_CARE",
        altdpram_component.width  = DWIDTH,
        altdpram_component.widthad  = AWIDTH,
        altdpram_component.width_byteena  = 1,
        altdpram_component.wraddress_aclr  = "OFF",
        altdpram_component.wraddress_reg  = "INCLOCK",
        altdpram_component.wrcontrol_aclr  = "OFF",
        altdpram_component.wrcontrol_reg  = "INCLOCK";







endmodule
