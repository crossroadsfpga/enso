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


// (C) 2001-2013 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other
// software and tools, and its AMPP partner logic functions, and any output
// files any of the foregoing (including device programming or simulation
// files), and any associated documentation or information are expressly subject
// to the terms and conditions of the Altera Program License Subscription
// Agreement, Altera MegaCore Function License Agreement, or other applicable
// license agreement, including, without limitation, that your use is for the
// sole purpose of programming logic devices manufactured by Altera and sold by
// Altera or its authorized distributors.  Please refer to the applicable
// agreement for further details.


// $Id: //acds/rel/13.1/ip/.../avalon-st_data_format_adapter.sv.terp#1 $
// $Revision: #1 $
// $Date: 2013/09/21 $
// $Author: dmunday $


// --------------------------------------------------------------------------------
//| Avalon Streaming Data Adapter
// --------------------------------------------------------------------------------

`timescale 1ns / 100ps

// ------------------------------------------
// Generation parameters:
//   output_name:        dc_fifo_convert_data_format_adapter_0_data_format_adapter_181_52nunda
//   usePackets:         true
//   hasInEmpty:         true
//   inEmptyWidth:       6
//   hasOutEmpty:        true
//   outEmptyWidth:      5
//   inDataWidth:        512
//   outDataWidth:       256
//   channelWidth:       0
//   inErrorWidth:       0
//   outErrorWidth:      0
//   inSymbolsPerBeat:   64
//   outSymbolsPerBeat:  32
//   maxState:           63
//   stateWidth:         6
//   maxChannel:         0
//   symbolWidth:        8
//   numMemSymbols:      63
//   symbolWidth:        8


// ------------------------------------------


module data_adapter_core (
 // Interface: in
 output reg         in_ready,
 input              in_valid,
 input [512-1 : 0]    in_data,
 input              in_startofpacket,
 input              in_endofpacket,
 input [6-1 : 0] in_empty,
 // Interface: out
 input                out_ready,
 output reg           out_valid,
 output reg [256-1: 0]  out_data,
 output reg           out_startofpacket,
 output reg           out_endofpacket,
 output reg [5-1 : 0] out_empty,

  // Interface: clk
 input              clk,
 // Interface: reset
 input              reset_n

);



   // ---------------------------------------------------------------------
   //| Signal Declarations
   // ---------------------------------------------------------------------
   reg         state_read_addr;
   wire [6-1:0]   state_from_memory;
   reg  [6-1:0]   state;
   reg  [6-1:0]   new_state;
   reg  [6-1:0]   state_d1;

   reg            in_ready_d1;
   reg            mem_readaddr;
   reg            mem_readaddr_d1;
   reg            a_ready;
   reg            a_valid;
   reg            a_channel;
   reg [8-1:0]    a_data0;
   reg [8-1:0]    a_data1;
   reg [8-1:0]    a_data2;
   reg [8-1:0]    a_data3;
   reg [8-1:0]    a_data4;
   reg [8-1:0]    a_data5;
   reg [8-1:0]    a_data6;
   reg [8-1:0]    a_data7;
   reg [8-1:0]    a_data8;
   reg [8-1:0]    a_data9;
   reg [8-1:0]    a_data10;
   reg [8-1:0]    a_data11;
   reg [8-1:0]    a_data12;
   reg [8-1:0]    a_data13;
   reg [8-1:0]    a_data14;
   reg [8-1:0]    a_data15;
   reg [8-1:0]    a_data16;
   reg [8-1:0]    a_data17;
   reg [8-1:0]    a_data18;
   reg [8-1:0]    a_data19;
   reg [8-1:0]    a_data20;
   reg [8-1:0]    a_data21;
   reg [8-1:0]    a_data22;
   reg [8-1:0]    a_data23;
   reg [8-1:0]    a_data24;
   reg [8-1:0]    a_data25;
   reg [8-1:0]    a_data26;
   reg [8-1:0]    a_data27;
   reg [8-1:0]    a_data28;
   reg [8-1:0]    a_data29;
   reg [8-1:0]    a_data30;
   reg [8-1:0]    a_data31;
   reg [8-1:0]    a_data32;
   reg [8-1:0]    a_data33;
   reg [8-1:0]    a_data34;
   reg [8-1:0]    a_data35;
   reg [8-1:0]    a_data36;
   reg [8-1:0]    a_data37;
   reg [8-1:0]    a_data38;
   reg [8-1:0]    a_data39;
   reg [8-1:0]    a_data40;
   reg [8-1:0]    a_data41;
   reg [8-1:0]    a_data42;
   reg [8-1:0]    a_data43;
   reg [8-1:0]    a_data44;
   reg [8-1:0]    a_data45;
   reg [8-1:0]    a_data46;
   reg [8-1:0]    a_data47;
   reg [8-1:0]    a_data48;
   reg [8-1:0]    a_data49;
   reg [8-1:0]    a_data50;
   reg [8-1:0]    a_data51;
   reg [8-1:0]    a_data52;
   reg [8-1:0]    a_data53;
   reg [8-1:0]    a_data54;
   reg [8-1:0]    a_data55;
   reg [8-1:0]    a_data56;
   reg [8-1:0]    a_data57;
   reg [8-1:0]    a_data58;
   reg [8-1:0]    a_data59;
   reg [8-1:0]    a_data60;
   reg [8-1:0]    a_data61;
   reg [8-1:0]    a_data62;
   reg [8-1:0]    a_data63;
   reg            a_startofpacket;
   reg            a_endofpacket;
   reg  [6-1:0]   a_empty;
   reg            a_error;
   reg            b_ready;
   reg            b_valid;
   reg            b_channel;
   reg  [256-1:0]   b_data;
   reg            b_startofpacket;
   wire           b_startofpacket_wire;
   reg            b_endofpacket;
   reg  [5-1:0]   b_empty;
   reg            b_error;
   reg            mem_write0;
   reg  [8-1:0]   mem_writedata0;
   wire [8-1:0]   mem_readdata0;
   wire           mem_waitrequest0;
   reg  [8-1:0]   mem0[0:0];
   reg            mem_write1;
   reg  [8-1:0]   mem_writedata1;
   wire [8-1:0]   mem_readdata1;
   wire           mem_waitrequest1;
   reg  [8-1:0]   mem1[0:0];
   reg            mem_write2;
   reg  [8-1:0]   mem_writedata2;
   wire [8-1:0]   mem_readdata2;
   wire           mem_waitrequest2;
   reg  [8-1:0]   mem2[0:0];
   reg            mem_write3;
   reg  [8-1:0]   mem_writedata3;
   wire [8-1:0]   mem_readdata3;
   wire           mem_waitrequest3;
   reg  [8-1:0]   mem3[0:0];
   reg            mem_write4;
   reg  [8-1:0]   mem_writedata4;
   wire [8-1:0]   mem_readdata4;
   wire           mem_waitrequest4;
   reg  [8-1:0]   mem4[0:0];
   reg            mem_write5;
   reg  [8-1:0]   mem_writedata5;
   wire [8-1:0]   mem_readdata5;
   wire           mem_waitrequest5;
   reg  [8-1:0]   mem5[0:0];
   reg            mem_write6;
   reg  [8-1:0]   mem_writedata6;
   wire [8-1:0]   mem_readdata6;
   wire           mem_waitrequest6;
   reg  [8-1:0]   mem6[0:0];
   reg            mem_write7;
   reg  [8-1:0]   mem_writedata7;
   wire [8-1:0]   mem_readdata7;
   wire           mem_waitrequest7;
   reg  [8-1:0]   mem7[0:0];
   reg            mem_write8;
   reg  [8-1:0]   mem_writedata8;
   wire [8-1:0]   mem_readdata8;
   wire           mem_waitrequest8;
   reg  [8-1:0]   mem8[0:0];
   reg            mem_write9;
   reg  [8-1:0]   mem_writedata9;
   wire [8-1:0]   mem_readdata9;
   wire           mem_waitrequest9;
   reg  [8-1:0]   mem9[0:0];
   reg            mem_write10;
   reg  [8-1:0]   mem_writedata10;
   wire [8-1:0]   mem_readdata10;
   wire           mem_waitrequest10;
   reg  [8-1:0]   mem10[0:0];
   reg            mem_write11;
   reg  [8-1:0]   mem_writedata11;
   wire [8-1:0]   mem_readdata11;
   wire           mem_waitrequest11;
   reg  [8-1:0]   mem11[0:0];
   reg            mem_write12;
   reg  [8-1:0]   mem_writedata12;
   wire [8-1:0]   mem_readdata12;
   wire           mem_waitrequest12;
   reg  [8-1:0]   mem12[0:0];
   reg            mem_write13;
   reg  [8-1:0]   mem_writedata13;
   wire [8-1:0]   mem_readdata13;
   wire           mem_waitrequest13;
   reg  [8-1:0]   mem13[0:0];
   reg            mem_write14;
   reg  [8-1:0]   mem_writedata14;
   wire [8-1:0]   mem_readdata14;
   wire           mem_waitrequest14;
   reg  [8-1:0]   mem14[0:0];
   reg            mem_write15;
   reg  [8-1:0]   mem_writedata15;
   wire [8-1:0]   mem_readdata15;
   wire           mem_waitrequest15;
   reg  [8-1:0]   mem15[0:0];
   reg            mem_write16;
   reg  [8-1:0]   mem_writedata16;
   wire [8-1:0]   mem_readdata16;
   wire           mem_waitrequest16;
   reg  [8-1:0]   mem16[0:0];
   reg            mem_write17;
   reg  [8-1:0]   mem_writedata17;
   wire [8-1:0]   mem_readdata17;
   wire           mem_waitrequest17;
   reg  [8-1:0]   mem17[0:0];
   reg            mem_write18;
   reg  [8-1:0]   mem_writedata18;
   wire [8-1:0]   mem_readdata18;
   wire           mem_waitrequest18;
   reg  [8-1:0]   mem18[0:0];
   reg            mem_write19;
   reg  [8-1:0]   mem_writedata19;
   wire [8-1:0]   mem_readdata19;
   wire           mem_waitrequest19;
   reg  [8-1:0]   mem19[0:0];
   reg            mem_write20;
   reg  [8-1:0]   mem_writedata20;
   wire [8-1:0]   mem_readdata20;
   wire           mem_waitrequest20;
   reg  [8-1:0]   mem20[0:0];
   reg            mem_write21;
   reg  [8-1:0]   mem_writedata21;
   wire [8-1:0]   mem_readdata21;
   wire           mem_waitrequest21;
   reg  [8-1:0]   mem21[0:0];
   reg            mem_write22;
   reg  [8-1:0]   mem_writedata22;
   wire [8-1:0]   mem_readdata22;
   wire           mem_waitrequest22;
   reg  [8-1:0]   mem22[0:0];
   reg            mem_write23;
   reg  [8-1:0]   mem_writedata23;
   wire [8-1:0]   mem_readdata23;
   wire           mem_waitrequest23;
   reg  [8-1:0]   mem23[0:0];
   reg            mem_write24;
   reg  [8-1:0]   mem_writedata24;
   wire [8-1:0]   mem_readdata24;
   wire           mem_waitrequest24;
   reg  [8-1:0]   mem24[0:0];
   reg            mem_write25;
   reg  [8-1:0]   mem_writedata25;
   wire [8-1:0]   mem_readdata25;
   wire           mem_waitrequest25;
   reg  [8-1:0]   mem25[0:0];
   reg            mem_write26;
   reg  [8-1:0]   mem_writedata26;
   wire [8-1:0]   mem_readdata26;
   wire           mem_waitrequest26;
   reg  [8-1:0]   mem26[0:0];
   reg            mem_write27;
   reg  [8-1:0]   mem_writedata27;
   wire [8-1:0]   mem_readdata27;
   wire           mem_waitrequest27;
   reg  [8-1:0]   mem27[0:0];
   reg            mem_write28;
   reg  [8-1:0]   mem_writedata28;
   wire [8-1:0]   mem_readdata28;
   wire           mem_waitrequest28;
   reg  [8-1:0]   mem28[0:0];
   reg            mem_write29;
   reg  [8-1:0]   mem_writedata29;
   wire [8-1:0]   mem_readdata29;
   wire           mem_waitrequest29;
   reg  [8-1:0]   mem29[0:0];
   reg            mem_write30;
   reg  [8-1:0]   mem_writedata30;
   wire [8-1:0]   mem_readdata30;
   wire           mem_waitrequest30;
   reg  [8-1:0]   mem30[0:0];
   reg            mem_write31;
   reg  [8-1:0]   mem_writedata31;
   wire [8-1:0]   mem_readdata31;
   wire           mem_waitrequest31;
   reg  [8-1:0]   mem31[0:0];
   reg            mem_write32;
   reg  [8-1:0]   mem_writedata32;
   wire [8-1:0]   mem_readdata32;
   wire           mem_waitrequest32;
   reg  [8-1:0]   mem32[0:0];
   reg            mem_write33;
   reg  [8-1:0]   mem_writedata33;
   wire [8-1:0]   mem_readdata33;
   wire           mem_waitrequest33;
   reg  [8-1:0]   mem33[0:0];
   reg            mem_write34;
   reg  [8-1:0]   mem_writedata34;
   wire [8-1:0]   mem_readdata34;
   wire           mem_waitrequest34;
   reg  [8-1:0]   mem34[0:0];
   reg            mem_write35;
   reg  [8-1:0]   mem_writedata35;
   wire [8-1:0]   mem_readdata35;
   wire           mem_waitrequest35;
   reg  [8-1:0]   mem35[0:0];
   reg            mem_write36;
   reg  [8-1:0]   mem_writedata36;
   wire [8-1:0]   mem_readdata36;
   wire           mem_waitrequest36;
   reg  [8-1:0]   mem36[0:0];
   reg            mem_write37;
   reg  [8-1:0]   mem_writedata37;
   wire [8-1:0]   mem_readdata37;
   wire           mem_waitrequest37;
   reg  [8-1:0]   mem37[0:0];
   reg            mem_write38;
   reg  [8-1:0]   mem_writedata38;
   wire [8-1:0]   mem_readdata38;
   wire           mem_waitrequest38;
   reg  [8-1:0]   mem38[0:0];
   reg            mem_write39;
   reg  [8-1:0]   mem_writedata39;
   wire [8-1:0]   mem_readdata39;
   wire           mem_waitrequest39;
   reg  [8-1:0]   mem39[0:0];
   reg            mem_write40;
   reg  [8-1:0]   mem_writedata40;
   wire [8-1:0]   mem_readdata40;
   wire           mem_waitrequest40;
   reg  [8-1:0]   mem40[0:0];
   reg            mem_write41;
   reg  [8-1:0]   mem_writedata41;
   wire [8-1:0]   mem_readdata41;
   wire           mem_waitrequest41;
   reg  [8-1:0]   mem41[0:0];
   reg            mem_write42;
   reg  [8-1:0]   mem_writedata42;
   wire [8-1:0]   mem_readdata42;
   wire           mem_waitrequest42;
   reg  [8-1:0]   mem42[0:0];
   reg            mem_write43;
   reg  [8-1:0]   mem_writedata43;
   wire [8-1:0]   mem_readdata43;
   wire           mem_waitrequest43;
   reg  [8-1:0]   mem43[0:0];
   reg            mem_write44;
   reg  [8-1:0]   mem_writedata44;
   wire [8-1:0]   mem_readdata44;
   wire           mem_waitrequest44;
   reg  [8-1:0]   mem44[0:0];
   reg            mem_write45;
   reg  [8-1:0]   mem_writedata45;
   wire [8-1:0]   mem_readdata45;
   wire           mem_waitrequest45;
   reg  [8-1:0]   mem45[0:0];
   reg            mem_write46;
   reg  [8-1:0]   mem_writedata46;
   wire [8-1:0]   mem_readdata46;
   wire           mem_waitrequest46;
   reg  [8-1:0]   mem46[0:0];
   reg            mem_write47;
   reg  [8-1:0]   mem_writedata47;
   wire [8-1:0]   mem_readdata47;
   wire           mem_waitrequest47;
   reg  [8-1:0]   mem47[0:0];
   reg            mem_write48;
   reg  [8-1:0]   mem_writedata48;
   wire [8-1:0]   mem_readdata48;
   wire           mem_waitrequest48;
   reg  [8-1:0]   mem48[0:0];
   reg            mem_write49;
   reg  [8-1:0]   mem_writedata49;
   wire [8-1:0]   mem_readdata49;
   wire           mem_waitrequest49;
   reg  [8-1:0]   mem49[0:0];
   reg            mem_write50;
   reg  [8-1:0]   mem_writedata50;
   wire [8-1:0]   mem_readdata50;
   wire           mem_waitrequest50;
   reg  [8-1:0]   mem50[0:0];
   reg            mem_write51;
   reg  [8-1:0]   mem_writedata51;
   wire [8-1:0]   mem_readdata51;
   wire           mem_waitrequest51;
   reg  [8-1:0]   mem51[0:0];
   reg            mem_write52;
   reg  [8-1:0]   mem_writedata52;
   wire [8-1:0]   mem_readdata52;
   wire           mem_waitrequest52;
   reg  [8-1:0]   mem52[0:0];
   reg            mem_write53;
   reg  [8-1:0]   mem_writedata53;
   wire [8-1:0]   mem_readdata53;
   wire           mem_waitrequest53;
   reg  [8-1:0]   mem53[0:0];
   reg            mem_write54;
   reg  [8-1:0]   mem_writedata54;
   wire [8-1:0]   mem_readdata54;
   wire           mem_waitrequest54;
   reg  [8-1:0]   mem54[0:0];
   reg            mem_write55;
   reg  [8-1:0]   mem_writedata55;
   wire [8-1:0]   mem_readdata55;
   wire           mem_waitrequest55;
   reg  [8-1:0]   mem55[0:0];
   reg            mem_write56;
   reg  [8-1:0]   mem_writedata56;
   wire [8-1:0]   mem_readdata56;
   wire           mem_waitrequest56;
   reg  [8-1:0]   mem56[0:0];
   reg            mem_write57;
   reg  [8-1:0]   mem_writedata57;
   wire [8-1:0]   mem_readdata57;
   wire           mem_waitrequest57;
   reg  [8-1:0]   mem57[0:0];
   reg            mem_write58;
   reg  [8-1:0]   mem_writedata58;
   wire [8-1:0]   mem_readdata58;
   wire           mem_waitrequest58;
   reg  [8-1:0]   mem58[0:0];
   reg            mem_write59;
   reg  [8-1:0]   mem_writedata59;
   wire [8-1:0]   mem_readdata59;
   wire           mem_waitrequest59;
   reg  [8-1:0]   mem59[0:0];
   reg            mem_write60;
   reg  [8-1:0]   mem_writedata60;
   wire [8-1:0]   mem_readdata60;
   wire           mem_waitrequest60;
   reg  [8-1:0]   mem60[0:0];
   reg            mem_write61;
   reg  [8-1:0]   mem_writedata61;
   wire [8-1:0]   mem_readdata61;
   wire           mem_waitrequest61;
   reg  [8-1:0]   mem61[0:0];
   reg            mem_write62;
   reg  [8-1:0]   mem_writedata62;
   wire [8-1:0]   mem_readdata62;
   wire           mem_waitrequest62;
   reg  [8-1:0]   mem62[0:0];
   reg            sop_mem_writeenable;
   reg            sop_mem_writedata;
   wire           mem_waitrequest_sop;

   wire           state_waitrequest;
   reg            state_waitrequest_d1;

   reg            in_channel = 0;
   reg            out_channel;



   reg in_error = 0;
   reg out_error;


   reg  [6-1:0]   state_register;
   reg            sop_register;
   reg            error_register;
   reg  [8-1:0]   data0_register;
   reg  [8-1:0]   data1_register;
   reg  [8-1:0]   data2_register;
   reg  [8-1:0]   data3_register;
   reg  [8-1:0]   data4_register;
   reg  [8-1:0]   data5_register;
   reg  [8-1:0]   data6_register;
   reg  [8-1:0]   data7_register;
   reg  [8-1:0]   data8_register;
   reg  [8-1:0]   data9_register;
   reg  [8-1:0]   data10_register;
   reg  [8-1:0]   data11_register;
   reg  [8-1:0]   data12_register;
   reg  [8-1:0]   data13_register;
   reg  [8-1:0]   data14_register;
   reg  [8-1:0]   data15_register;
   reg  [8-1:0]   data16_register;
   reg  [8-1:0]   data17_register;
   reg  [8-1:0]   data18_register;
   reg  [8-1:0]   data19_register;
   reg  [8-1:0]   data20_register;
   reg  [8-1:0]   data21_register;
   reg  [8-1:0]   data22_register;
   reg  [8-1:0]   data23_register;
   reg  [8-1:0]   data24_register;
   reg  [8-1:0]   data25_register;
   reg  [8-1:0]   data26_register;
   reg  [8-1:0]   data27_register;
   reg  [8-1:0]   data28_register;
   reg  [8-1:0]   data29_register;
   reg  [8-1:0]   data30_register;
   reg  [8-1:0]   data31_register;
   reg  [8-1:0]   data32_register;
   reg  [8-1:0]   data33_register;
   reg  [8-1:0]   data34_register;
   reg  [8-1:0]   data35_register;
   reg  [8-1:0]   data36_register;
   reg  [8-1:0]   data37_register;
   reg  [8-1:0]   data38_register;
   reg  [8-1:0]   data39_register;
   reg  [8-1:0]   data40_register;
   reg  [8-1:0]   data41_register;
   reg  [8-1:0]   data42_register;
   reg  [8-1:0]   data43_register;
   reg  [8-1:0]   data44_register;
   reg  [8-1:0]   data45_register;
   reg  [8-1:0]   data46_register;
   reg  [8-1:0]   data47_register;
   reg  [8-1:0]   data48_register;
   reg  [8-1:0]   data49_register;
   reg  [8-1:0]   data50_register;
   reg  [8-1:0]   data51_register;
   reg  [8-1:0]   data52_register;
   reg  [8-1:0]   data53_register;
   reg  [8-1:0]   data54_register;
   reg  [8-1:0]   data55_register;
   reg  [8-1:0]   data56_register;
   reg  [8-1:0]   data57_register;
   reg  [8-1:0]   data58_register;
   reg  [8-1:0]   data59_register;
   reg  [8-1:0]   data60_register;
   reg  [8-1:0]   data61_register;
   reg  [8-1:0]   data62_register;

   // ---------------------------------------------------------------------
   //| Input Register Stage
   // ---------------------------------------------------------------------
   always @(posedge clk or negedge reset_n) begin
      if (!reset_n) begin
         a_valid   <= 0;
         a_channel <= 0;
         a_data0   <= 0;
         a_data1   <= 0;
         a_data2   <= 0;
         a_data3   <= 0;
         a_data4   <= 0;
         a_data5   <= 0;
         a_data6   <= 0;
         a_data7   <= 0;
         a_data8   <= 0;
         a_data9   <= 0;
         a_data10   <= 0;
         a_data11   <= 0;
         a_data12   <= 0;
         a_data13   <= 0;
         a_data14   <= 0;
         a_data15   <= 0;
         a_data16   <= 0;
         a_data17   <= 0;
         a_data18   <= 0;
         a_data19   <= 0;
         a_data20   <= 0;
         a_data21   <= 0;
         a_data22   <= 0;
         a_data23   <= 0;
         a_data24   <= 0;
         a_data25   <= 0;
         a_data26   <= 0;
         a_data27   <= 0;
         a_data28   <= 0;
         a_data29   <= 0;
         a_data30   <= 0;
         a_data31   <= 0;
         a_data32   <= 0;
         a_data33   <= 0;
         a_data34   <= 0;
         a_data35   <= 0;
         a_data36   <= 0;
         a_data37   <= 0;
         a_data38   <= 0;
         a_data39   <= 0;
         a_data40   <= 0;
         a_data41   <= 0;
         a_data42   <= 0;
         a_data43   <= 0;
         a_data44   <= 0;
         a_data45   <= 0;
         a_data46   <= 0;
         a_data47   <= 0;
         a_data48   <= 0;
         a_data49   <= 0;
         a_data50   <= 0;
         a_data51   <= 0;
         a_data52   <= 0;
         a_data53   <= 0;
         a_data54   <= 0;
         a_data55   <= 0;
         a_data56   <= 0;
         a_data57   <= 0;
         a_data58   <= 0;
         a_data59   <= 0;
         a_data60   <= 0;
         a_data61   <= 0;
         a_data62   <= 0;
         a_data63   <= 0;
         a_startofpacket <= 0;
         a_endofpacket   <= 0;
         a_empty <= 0;
         a_error <= 0;
      end else begin
         if (in_ready) begin
            a_valid   <= in_valid;
            a_channel <= in_channel;
            a_error   <= in_error;
            a_data0 <= in_data[511:504];
            a_data1 <= in_data[503:496];
            a_data2 <= in_data[495:488];
            a_data3 <= in_data[487:480];
            a_data4 <= in_data[479:472];
            a_data5 <= in_data[471:464];
            a_data6 <= in_data[463:456];
            a_data7 <= in_data[455:448];
            a_data8 <= in_data[447:440];
            a_data9 <= in_data[439:432];
            a_data10 <= in_data[431:424];
            a_data11 <= in_data[423:416];
            a_data12 <= in_data[415:408];
            a_data13 <= in_data[407:400];
            a_data14 <= in_data[399:392];
            a_data15 <= in_data[391:384];
            a_data16 <= in_data[383:376];
            a_data17 <= in_data[375:368];
            a_data18 <= in_data[367:360];
            a_data19 <= in_data[359:352];
            a_data20 <= in_data[351:344];
            a_data21 <= in_data[343:336];
            a_data22 <= in_data[335:328];
            a_data23 <= in_data[327:320];
            a_data24 <= in_data[319:312];
            a_data25 <= in_data[311:304];
            a_data26 <= in_data[303:296];
            a_data27 <= in_data[295:288];
            a_data28 <= in_data[287:280];
            a_data29 <= in_data[279:272];
            a_data30 <= in_data[271:264];
            a_data31 <= in_data[263:256];
            a_data32 <= in_data[255:248];
            a_data33 <= in_data[247:240];
            a_data34 <= in_data[239:232];
            a_data35 <= in_data[231:224];
            a_data36 <= in_data[223:216];
            a_data37 <= in_data[215:208];
            a_data38 <= in_data[207:200];
            a_data39 <= in_data[199:192];
            a_data40 <= in_data[191:184];
            a_data41 <= in_data[183:176];
            a_data42 <= in_data[175:168];
            a_data43 <= in_data[167:160];
            a_data44 <= in_data[159:152];
            a_data45 <= in_data[151:144];
            a_data46 <= in_data[143:136];
            a_data47 <= in_data[135:128];
            a_data48 <= in_data[127:120];
            a_data49 <= in_data[119:112];
            a_data50 <= in_data[111:104];
            a_data51 <= in_data[103:96];
            a_data52 <= in_data[95:88];
            a_data53 <= in_data[87:80];
            a_data54 <= in_data[79:72];
            a_data55 <= in_data[71:64];
            a_data56 <= in_data[63:56];
            a_data57 <= in_data[55:48];
            a_data58 <= in_data[47:40];
            a_data59 <= in_data[39:32];
            a_data60 <= in_data[31:24];
            a_data61 <= in_data[23:16];
            a_data62 <= in_data[15:8];
            a_data63 <= in_data[7:0];
            a_startofpacket <= in_startofpacket;
            a_endofpacket   <= in_endofpacket;
            a_empty         <= 0;
            if (in_endofpacket)
               a_empty <= in_empty;
         end
      end
   end

   always @* begin
      state_read_addr = a_channel;
      if (in_ready)
         state_read_addr = in_channel;
   end


   // ---------------------------------------------------------------------
   //| State & Memory Keepers
   // ---------------------------------------------------------------------
   always @(posedge clk or negedge reset_n) begin
      if (!reset_n) begin
         in_ready_d1          <= 0;
         state_d1             <= 0;
         mem_readaddr_d1      <= 0;
         state_waitrequest_d1 <= 0;
      end else begin
         in_ready_d1          <= in_ready;
         state_d1             <= state;
         mem_readaddr_d1      <= mem_readaddr;
         state_waitrequest_d1 <= state_waitrequest;
      end
   end

   always @(posedge clk or negedge reset_n) begin
      if (!reset_n) begin
         state_register <= 0;
         sop_register   <= 0;
         data0_register <= 0;
         data1_register <= 0;
         data2_register <= 0;
         data3_register <= 0;
         data4_register <= 0;
         data5_register <= 0;
         data6_register <= 0;
         data7_register <= 0;
         data8_register <= 0;
         data9_register <= 0;
         data10_register <= 0;
         data11_register <= 0;
         data12_register <= 0;
         data13_register <= 0;
         data14_register <= 0;
         data15_register <= 0;
         data16_register <= 0;
         data17_register <= 0;
         data18_register <= 0;
         data19_register <= 0;
         data20_register <= 0;
         data21_register <= 0;
         data22_register <= 0;
         data23_register <= 0;
         data24_register <= 0;
         data25_register <= 0;
         data26_register <= 0;
         data27_register <= 0;
         data28_register <= 0;
         data29_register <= 0;
         data30_register <= 0;
         data31_register <= 0;
         data32_register <= 0;
         data33_register <= 0;
         data34_register <= 0;
         data35_register <= 0;
         data36_register <= 0;
         data37_register <= 0;
         data38_register <= 0;
         data39_register <= 0;
         data40_register <= 0;
         data41_register <= 0;
         data42_register <= 0;
         data43_register <= 0;
         data44_register <= 0;
         data45_register <= 0;
         data46_register <= 0;
         data47_register <= 0;
         data48_register <= 0;
         data49_register <= 0;
         data50_register <= 0;
         data51_register <= 0;
         data52_register <= 0;
         data53_register <= 0;
         data54_register <= 0;
         data55_register <= 0;
         data56_register <= 0;
         data57_register <= 0;
         data58_register <= 0;
         data59_register <= 0;
         data60_register <= 0;
         data61_register <= 0;
         data62_register <= 0;
      end else begin
         state_register <= new_state;
         if (sop_mem_writeenable)
            sop_register   <= sop_mem_writedata;
         if (mem_write0)
            data0_register <= mem_writedata0;
         if (mem_write1)
            data1_register <= mem_writedata1;
         if (mem_write2)
            data2_register <= mem_writedata2;
         if (mem_write3)
            data3_register <= mem_writedata3;
         if (mem_write4)
            data4_register <= mem_writedata4;
         if (mem_write5)
            data5_register <= mem_writedata5;
         if (mem_write6)
            data6_register <= mem_writedata6;
         if (mem_write7)
            data7_register <= mem_writedata7;
         if (mem_write8)
            data8_register <= mem_writedata8;
         if (mem_write9)
            data9_register <= mem_writedata9;
         if (mem_write10)
            data10_register <= mem_writedata10;
         if (mem_write11)
            data11_register <= mem_writedata11;
         if (mem_write12)
            data12_register <= mem_writedata12;
         if (mem_write13)
            data13_register <= mem_writedata13;
         if (mem_write14)
            data14_register <= mem_writedata14;
         if (mem_write15)
            data15_register <= mem_writedata15;
         if (mem_write16)
            data16_register <= mem_writedata16;
         if (mem_write17)
            data17_register <= mem_writedata17;
         if (mem_write18)
            data18_register <= mem_writedata18;
         if (mem_write19)
            data19_register <= mem_writedata19;
         if (mem_write20)
            data20_register <= mem_writedata20;
         if (mem_write21)
            data21_register <= mem_writedata21;
         if (mem_write22)
            data22_register <= mem_writedata22;
         if (mem_write23)
            data23_register <= mem_writedata23;
         if (mem_write24)
            data24_register <= mem_writedata24;
         if (mem_write25)
            data25_register <= mem_writedata25;
         if (mem_write26)
            data26_register <= mem_writedata26;
         if (mem_write27)
            data27_register <= mem_writedata27;
         if (mem_write28)
            data28_register <= mem_writedata28;
         if (mem_write29)
            data29_register <= mem_writedata29;
         if (mem_write30)
            data30_register <= mem_writedata30;
         if (mem_write31)
            data31_register <= mem_writedata31;
         if (mem_write32)
            data32_register <= mem_writedata32;
         if (mem_write33)
            data33_register <= mem_writedata33;
         if (mem_write34)
            data34_register <= mem_writedata34;
         if (mem_write35)
            data35_register <= mem_writedata35;
         if (mem_write36)
            data36_register <= mem_writedata36;
         if (mem_write37)
            data37_register <= mem_writedata37;
         if (mem_write38)
            data38_register <= mem_writedata38;
         if (mem_write39)
            data39_register <= mem_writedata39;
         if (mem_write40)
            data40_register <= mem_writedata40;
         if (mem_write41)
            data41_register <= mem_writedata41;
         if (mem_write42)
            data42_register <= mem_writedata42;
         if (mem_write43)
            data43_register <= mem_writedata43;
         if (mem_write44)
            data44_register <= mem_writedata44;
         if (mem_write45)
            data45_register <= mem_writedata45;
         if (mem_write46)
            data46_register <= mem_writedata46;
         if (mem_write47)
            data47_register <= mem_writedata47;
         if (mem_write48)
            data48_register <= mem_writedata48;
         if (mem_write49)
            data49_register <= mem_writedata49;
         if (mem_write50)
            data50_register <= mem_writedata50;
         if (mem_write51)
            data51_register <= mem_writedata51;
         if (mem_write52)
            data52_register <= mem_writedata52;
         if (mem_write53)
            data53_register <= mem_writedata53;
         if (mem_write54)
            data54_register <= mem_writedata54;
         if (mem_write55)
            data55_register <= mem_writedata55;
         if (mem_write56)
            data56_register <= mem_writedata56;
         if (mem_write57)
            data57_register <= mem_writedata57;
         if (mem_write58)
            data58_register <= mem_writedata58;
         if (mem_write59)
            data59_register <= mem_writedata59;
         if (mem_write60)
            data60_register <= mem_writedata60;
         if (mem_write61)
            data61_register <= mem_writedata61;
         if (mem_write62)
            data62_register <= mem_writedata62;
         end
      end

      assign state_from_memory = state_register;
      assign b_startofpacket_wire = sop_register;
      assign mem_readdata0 = data0_register;
      assign mem_readdata1 = data1_register;
      assign mem_readdata2 = data2_register;
      assign mem_readdata3 = data3_register;
      assign mem_readdata4 = data4_register;
      assign mem_readdata5 = data5_register;
      assign mem_readdata6 = data6_register;
      assign mem_readdata7 = data7_register;
      assign mem_readdata8 = data8_register;
      assign mem_readdata9 = data9_register;
      assign mem_readdata10 = data10_register;
      assign mem_readdata11 = data11_register;
      assign mem_readdata12 = data12_register;
      assign mem_readdata13 = data13_register;
      assign mem_readdata14 = data14_register;
      assign mem_readdata15 = data15_register;
      assign mem_readdata16 = data16_register;
      assign mem_readdata17 = data17_register;
      assign mem_readdata18 = data18_register;
      assign mem_readdata19 = data19_register;
      assign mem_readdata20 = data20_register;
      assign mem_readdata21 = data21_register;
      assign mem_readdata22 = data22_register;
      assign mem_readdata23 = data23_register;
      assign mem_readdata24 = data24_register;
      assign mem_readdata25 = data25_register;
      assign mem_readdata26 = data26_register;
      assign mem_readdata27 = data27_register;
      assign mem_readdata28 = data28_register;
      assign mem_readdata29 = data29_register;
      assign mem_readdata30 = data30_register;
      assign mem_readdata31 = data31_register;
      assign mem_readdata32 = data32_register;
      assign mem_readdata33 = data33_register;
      assign mem_readdata34 = data34_register;
      assign mem_readdata35 = data35_register;
      assign mem_readdata36 = data36_register;
      assign mem_readdata37 = data37_register;
      assign mem_readdata38 = data38_register;
      assign mem_readdata39 = data39_register;
      assign mem_readdata40 = data40_register;
      assign mem_readdata41 = data41_register;
      assign mem_readdata42 = data42_register;
      assign mem_readdata43 = data43_register;
      assign mem_readdata44 = data44_register;
      assign mem_readdata45 = data45_register;
      assign mem_readdata46 = data46_register;
      assign mem_readdata47 = data47_register;
      assign mem_readdata48 = data48_register;
      assign mem_readdata49 = data49_register;
      assign mem_readdata50 = data50_register;
      assign mem_readdata51 = data51_register;
      assign mem_readdata52 = data52_register;
      assign mem_readdata53 = data53_register;
      assign mem_readdata54 = data54_register;
      assign mem_readdata55 = data55_register;
      assign mem_readdata56 = data56_register;
      assign mem_readdata57 = data57_register;
      assign mem_readdata58 = data58_register;
      assign mem_readdata59 = data59_register;
      assign mem_readdata60 = data60_register;
      assign mem_readdata61 = data61_register;
      assign mem_readdata62 = data62_register;

   // ---------------------------------------------------------------------
   //| State Machine
   // ---------------------------------------------------------------------
   always @* begin


   b_ready = (out_ready || ~out_valid);

   a_ready   = 0;
   b_data    = 0;
   b_valid   = 0;
   b_channel = a_channel;
   b_error   = a_error;

   state = state_from_memory;

   new_state           = state;
   mem_write0          = 0;
   mem_writedata0      = a_data0;
   mem_write1          = 0;
   mem_writedata1      = a_data0;
   mem_write2          = 0;
   mem_writedata2      = a_data0;
   mem_write3          = 0;
   mem_writedata3      = a_data0;
   mem_write4          = 0;
   mem_writedata4      = a_data0;
   mem_write5          = 0;
   mem_writedata5      = a_data0;
   mem_write6          = 0;
   mem_writedata6      = a_data0;
   mem_write7          = 0;
   mem_writedata7      = a_data0;
   mem_write8          = 0;
   mem_writedata8      = a_data0;
   mem_write9          = 0;
   mem_writedata9      = a_data0;
   mem_write10          = 0;
   mem_writedata10      = a_data0;
   mem_write11          = 0;
   mem_writedata11      = a_data0;
   mem_write12          = 0;
   mem_writedata12      = a_data0;
   mem_write13          = 0;
   mem_writedata13      = a_data0;
   mem_write14          = 0;
   mem_writedata14      = a_data0;
   mem_write15          = 0;
   mem_writedata15      = a_data0;
   mem_write16          = 0;
   mem_writedata16      = a_data0;
   mem_write17          = 0;
   mem_writedata17      = a_data0;
   mem_write18          = 0;
   mem_writedata18      = a_data0;
   mem_write19          = 0;
   mem_writedata19      = a_data0;
   mem_write20          = 0;
   mem_writedata20      = a_data0;
   mem_write21          = 0;
   mem_writedata21      = a_data0;
   mem_write22          = 0;
   mem_writedata22      = a_data0;
   mem_write23          = 0;
   mem_writedata23      = a_data0;
   mem_write24          = 0;
   mem_writedata24      = a_data0;
   mem_write25          = 0;
   mem_writedata25      = a_data0;
   mem_write26          = 0;
   mem_writedata26      = a_data0;
   mem_write27          = 0;
   mem_writedata27      = a_data0;
   mem_write28          = 0;
   mem_writedata28      = a_data0;
   mem_write29          = 0;
   mem_writedata29      = a_data0;
   mem_write30          = 0;
   mem_writedata30      = a_data0;
   mem_write31          = 0;
   mem_writedata31      = a_data0;
   mem_write32          = 0;
   mem_writedata32      = a_data0;
   mem_write33          = 0;
   mem_writedata33      = a_data0;
   mem_write34          = 0;
   mem_writedata34      = a_data0;
   mem_write35          = 0;
   mem_writedata35      = a_data0;
   mem_write36          = 0;
   mem_writedata36      = a_data0;
   mem_write37          = 0;
   mem_writedata37      = a_data0;
   mem_write38          = 0;
   mem_writedata38      = a_data0;
   mem_write39          = 0;
   mem_writedata39      = a_data0;
   mem_write40          = 0;
   mem_writedata40      = a_data0;
   mem_write41          = 0;
   mem_writedata41      = a_data0;
   mem_write42          = 0;
   mem_writedata42      = a_data0;
   mem_write43          = 0;
   mem_writedata43      = a_data0;
   mem_write44          = 0;
   mem_writedata44      = a_data0;
   mem_write45          = 0;
   mem_writedata45      = a_data0;
   mem_write46          = 0;
   mem_writedata46      = a_data0;
   mem_write47          = 0;
   mem_writedata47      = a_data0;
   mem_write48          = 0;
   mem_writedata48      = a_data0;
   mem_write49          = 0;
   mem_writedata49      = a_data0;
   mem_write50          = 0;
   mem_writedata50      = a_data0;
   mem_write51          = 0;
   mem_writedata51      = a_data0;
   mem_write52          = 0;
   mem_writedata52      = a_data0;
   mem_write53          = 0;
   mem_writedata53      = a_data0;
   mem_write54          = 0;
   mem_writedata54      = a_data0;
   mem_write55          = 0;
   mem_writedata55      = a_data0;
   mem_write56          = 0;
   mem_writedata56      = a_data0;
   mem_write57          = 0;
   mem_writedata57      = a_data0;
   mem_write58          = 0;
   mem_writedata58      = a_data0;
   mem_write59          = 0;
   mem_writedata59      = a_data0;
   mem_write60          = 0;
   mem_writedata60      = a_data0;
   mem_write61          = 0;
   mem_writedata61      = a_data0;
   mem_write62          = 0;
   mem_writedata62      = a_data0;
   sop_mem_writeenable = 0;

   b_endofpacket = a_endofpacket;

   b_startofpacket = 0;

   b_endofpacket = 0;
   b_empty = 0;

   case (state)
            0 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = a_startofpacket;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         1 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         2 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         3 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         4 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         5 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         6 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         7 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         8 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         9 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         10 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         11 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         12 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         13 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         14 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         15 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         16 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         17 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         18 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         19 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         20 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         21 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         22 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         23 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         24 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         25 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         26 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         27 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         28 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         29 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         30 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         31 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         32 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         33 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         34 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         35 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         36 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         37 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         38 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         39 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         40 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         41 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         42 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         43 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         44 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         45 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         46 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         47 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         48 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         49 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         50 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         51 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         52 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         53 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         54 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         55 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         56 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         57 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         58 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         59 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         60 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         61 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         62 : begin
            b_data[255:248] = a_data0;
            b_data[247:240] = a_data1;
            b_data[239:232] = a_data2;
            b_data[231:224] = a_data3;
            b_data[223:216] = a_data4;
            b_data[215:208] = a_data5;
            b_data[207:200] = a_data6;
            b_data[199:192] = a_data7;
            b_data[191:184] = a_data8;
            b_data[183:176] = a_data9;
            b_data[175:168] = a_data10;
            b_data[167:160] = a_data11;
            b_data[159:152] = a_data12;
            b_data[151:144] = a_data13;
            b_data[143:136] = a_data14;
            b_data[135:128] = a_data15;
            b_data[127:120] = a_data16;
            b_data[119:112] = a_data17;
            b_data[111:104] = a_data18;
            b_data[103:96] = a_data19;
            b_data[95:88] = a_data20;
            b_data[87:80] = a_data21;
            b_data[79:72] = a_data22;
            b_data[71:64] = a_data23;
            b_data[63:56] = a_data24;
            b_data[55:48] = a_data25;
            b_data[47:40] = a_data26;
            b_data[39:32] = a_data27;
            b_data[31:24] = a_data28;
            b_data[23:16] = a_data29;
            b_data[15:8] = a_data30;
            b_data[7:0] = a_data31;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
               if (a_valid) begin
                  b_valid = 1;
                  new_state = state+1'b1;
                     if (a_endofpacket && (a_empty >= 32) ) begin
                        new_state = 0;
                        b_empty = a_empty - 32;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end
         63 : begin
            b_data[255:248] = a_data32;
            b_data[247:240] = a_data33;
            b_data[239:232] = a_data34;
            b_data[231:224] = a_data35;
            b_data[223:216] = a_data36;
            b_data[215:208] = a_data37;
            b_data[207:200] = a_data38;
            b_data[199:192] = a_data39;
            b_data[191:184] = a_data40;
            b_data[183:176] = a_data41;
            b_data[175:168] = a_data42;
            b_data[167:160] = a_data43;
            b_data[159:152] = a_data44;
            b_data[151:144] = a_data45;
            b_data[143:136] = a_data46;
            b_data[135:128] = a_data47;
            b_data[127:120] = a_data48;
            b_data[119:112] = a_data49;
            b_data[111:104] = a_data50;
            b_data[103:96] = a_data51;
            b_data[95:88] = a_data52;
            b_data[87:80] = a_data53;
            b_data[79:72] = a_data54;
            b_data[71:64] = a_data55;
            b_data[63:56] = a_data56;
            b_data[55:48] = a_data57;
            b_data[47:40] = a_data58;
            b_data[39:32] = a_data59;
            b_data[31:24] = a_data60;
            b_data[23:16] = a_data61;
            b_data[15:8] = a_data62;
            b_data[7:0] = a_data63;
            b_startofpacket = 0;
            if (out_ready || ~out_valid) begin
            a_ready = 1;
               if (a_valid) begin
                  b_valid = 1;
                  new_state = 0;
                     if (a_endofpacket && (a_empty >= 0) ) begin
                        new_state = 0;
                        b_empty = a_empty - 0;
                        b_endofpacket = 1;
                        a_ready = 1;
                     end
                  end
               end
            end

   endcase

      in_ready = (a_ready || ~a_valid);

      mem_readaddr = in_channel;
      if (~in_ready)
         mem_readaddr = mem_readaddr_d1;


      sop_mem_writedata = 0;
      if (a_valid)
         sop_mem_writedata = a_startofpacket;
      if (b_ready && b_valid && b_startofpacket)
         sop_mem_writeenable = 1;

   end


   // ---------------------------------------------------------------------
   //| Output Register Stage
   // ---------------------------------------------------------------------
   always @(posedge clk or negedge reset_n) begin
      if (!reset_n) begin
         out_valid         <= 0;
         out_data          <= 0;
         out_channel       <= 0;
         out_startofpacket <= 0;
         out_endofpacket   <= 0;
         out_empty         <= 0;
         out_error         <= 0;
      end else begin
         if (out_ready || ~out_valid) begin
            out_valid         <= b_valid;
            out_data          <= b_data;
            out_channel       <= b_channel;
            out_startofpacket <= b_startofpacket;
            out_endofpacket   <= b_endofpacket;
            out_empty         <= b_empty;
            out_error         <= b_error;
         end
      end
   end




endmodule
