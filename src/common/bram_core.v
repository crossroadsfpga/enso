//Legal Notice: (C)2019 Altera Corporation. All rights reserved.  Your
//use of Altera Corporation's design tools, logic functions and other
//software and tools, and its AMPP partner logic functions, and any
//output files any of the foregoing (including device programming or
//simulation files), and any associated documentation or information are
//expressly subject to the terms and conditions of the Altera Program
//License Subscription Agreement or other applicable license agreement,
//including, without limitation, that your use is for the sole purpose
//of programming logic devices manufactured by Altera and sold by Altera
//or its authorized distributors.  Please refer to the applicable
//agreement for further details.

// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on

// turn off superfluous verilog processor warnings 
// altera message_level Level1 
// altera message_off 10034 10035 10036 10037 10230 10240 10030 13469 16735 16788 

module bram_core (
// inputs:
    address,
    address2,
    byteenable,
    byteenable2,
    chipselect,
    chipselect2,
    clk,
    clken,
    clken2,
    reset,
    reset_req,
    write,
    write2,
    writedata,
    writedata2,
    
    // outputs:
    readdata,
    readdata2
);
parameter BEWIDTH=64;
parameter AWIDTH=9;
parameter DWIDTH=512;
parameter DEPTH=512;

  output  [DWIDTH-1: 0] readdata;
  output  [DWIDTH-1: 0] readdata2;
  input   [AWIDTH-1: 0] address;
  input   [AWIDTH-1: 0] address2;
  input   [BEWIDTH-1: 0] byteenable;
  input   [BEWIDTH-1: 0] byteenable2;
  input            chipselect;
  input            chipselect2;
  input            clk;
  input            clken;
  input            clken2;
  input            reset;
  input            reset_req;
  input            write;
  input            write2;
  input   [DWIDTH-1: 0] writedata;
  input   [DWIDTH-1: 0] writedata2;


wire             clocken0;
reg     [DWIDTH-1: 0] readdata;
reg     [DWIDTH-1: 0] readdata2;
wire    [DWIDTH-1: 0] readdata2_ram;
wire    [DWIDTH-1: 0] readdata_ram;
wire             wren;
wire             wren2;
  always @(posedge clk)
    begin
      if (clken)
          readdata <= readdata_ram;
    end


  assign wren = chipselect & write & clken;
  assign clocken0 = ~reset_req;
  always @(posedge clk)
    begin
      if (clken2)
          readdata2 <= readdata2_ram;
    end


  assign wren2 = chipselect2 & write2 & clken2;
  altsyncram the_altsyncram
    (
      .address_a (address),
      .address_b (address2),
      .byteena_a (byteenable),
      .byteena_b (byteenable2),
      .clock0 (clk),
      .clocken0 (clocken0),
      .data_a (writedata),
      .data_b (writedata2),
      .q_a (readdata_ram),
      .q_b (readdata2_ram),
      .wren_a (wren),
      .wren_b (wren2)
    );

  defparam the_altsyncram.address_reg_b = "CLOCK0",
           the_altsyncram.byte_size = 8,
           the_altsyncram.byteena_reg_b = "CLOCK0",
           the_altsyncram.indata_reg_b = "CLOCK0",
           the_altsyncram.init_file = "UNUSED",
           the_altsyncram.lpm_type = "altsyncram",
           the_altsyncram.maximum_depth = DEPTH,
           the_altsyncram.numwords_a = DEPTH,
           the_altsyncram.numwords_b = DEPTH,
           the_altsyncram.operation_mode = "BIDIR_DUAL_PORT",
           the_altsyncram.outdata_reg_a = "UNREGISTERED",
           the_altsyncram.outdata_reg_b = "UNREGISTERED",
           the_altsyncram.ram_block_type = "AUTO",
           the_altsyncram.read_during_write_mode_mixed_ports = "DONT_CARE",
           the_altsyncram.width_a = DWIDTH,
           the_altsyncram.width_b = DWIDTH,
           the_altsyncram.width_byteena_a = BEWIDTH,
           the_altsyncram.width_byteena_b = BEWIDTH,
           the_altsyncram.widthad_a = AWIDTH,
           the_altsyncram.widthad_b = AWIDTH,
           the_altsyncram.wrcontrol_wraddress_reg_b = "CLOCK0";

  //s1, which is an e_avalon_slave
  //s2, which is an e_avalon_slave

endmodule

