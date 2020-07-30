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

`include "./src/my_struct_s.sv"

`timescale 1 ps / 1 ps
//`define DISABLE_PCIE
//`define DISABLE_DRAM
`define USE_BRAM
module alt_ehipc2_hw (
 
    input clk50,
    input in_clk100,
`ifndef USE_BRAM
    input clk_esram_ref,
`endif

    input cpu_resetn,

    // QSFP
    output wire  qsfp_lowpwr,   // LPMode
    output wire  qsfp_rstn,   // ResetL

    // 10G IO
    input wire i_clk_ref,
    input wire [3:0] i_rx_serial,
    output wire [3:0] o_tx_serial,

    //PCIe
    input  wire         refclk_clk,         
    //input  wire         pcie_rstn_npor,   
    input  wire         pcie_rstn_pin_perst,
    input  wire         xcvr_rx_in0,        
    input  wire         xcvr_rx_in1,        
    input  wire         xcvr_rx_in2,        
    input  wire         xcvr_rx_in3,        
    input  wire         xcvr_rx_in4,        
    input  wire         xcvr_rx_in5,        
    input  wire         xcvr_rx_in6,        
    input  wire         xcvr_rx_in7,        
    input  wire         xcvr_rx_in8,        
    input  wire         xcvr_rx_in9,        
    input  wire         xcvr_rx_in10,       
    input  wire         xcvr_rx_in11,       
    input  wire         xcvr_rx_in12,       
    input  wire         xcvr_rx_in13,       
    input  wire         xcvr_rx_in14,       
    input  wire         xcvr_rx_in15,       
    output wire         xcvr_tx_out0,       
    output wire         xcvr_tx_out1,       
    output wire         xcvr_tx_out2,       
    output wire         xcvr_tx_out3,       
    output wire         xcvr_tx_out4,       
    output wire         xcvr_tx_out5,       
    output wire         xcvr_tx_out6,       
    output wire         xcvr_tx_out7,       
    output wire         xcvr_tx_out8,       
    output wire         xcvr_tx_out9,       
    output wire         xcvr_tx_out10,      
    output wire         xcvr_tx_out11,      
    output wire         xcvr_tx_out12,      
    output wire         xcvr_tx_out13,      
    output wire         xcvr_tx_out14,      
    output wire         xcvr_tx_out15
);


    assign qsfp_rstn = 1'b1;
    assign qsfp_lowpwr = 1'b0;
    //assign user_led = 8'b0;


    localparam DEVICE_FAMILY = "Stratix 10";
    localparam WORDS = 8;
    localparam WIDTH = 64;
    localparam SOP_ON_LANE0 = 1'b1;
    localparam SIM_NO_TEMP_SENSE = 1'b0;


    /////////////////////////
    // dev_clr sync-reset
    /////////////////////////
    //clk100=i_reconfig_clk
    wire user_mode_sync, arst, iopll_locked, clk100;
    alt_aeuex_user_mode_det dev_clr( .ref_clk(clk100), .user_mode_sync(user_mode_sync));

    wire source_reset;
     wire i_reconfig_reset;

  //Instantiate S10 IP reset:
/*
      wire ninit_done ;
      reset_ip reset (
    .ninit_done (ninit_done)
      );
*/
    //Zhipeng Start
    wire user_clk, user_clk_high, user_pll_locked;
    wire         esram_pll_lock; 
    //Zhipeng End

      
      
// ARST conditional upon ninit_done from S10 IP reset. Ninit_done is active low. ninit_done=0 => s10 is good to go      
    //Zhipeng Start
    //assign arst = ~user_mode_sync | ~cpu_resetn | ~iopll_locked | source_reset | ninit_done ;
    //assign arst = ~user_mode_sync | ~cpu_resetn | ~iopll_locked | source_reset | ninit_done | ~user_pll_locked;
    assign arst = ~user_mode_sync | ~cpu_resetn | ~iopll_locked | ~user_pll_locked;
    //Zhipeng End






    assign i_reconfig_reset = arst;

    


        wire [15:0] i_eth_reconfig_addr;
    wire [31:0] o_eth_reconfig_readdata;
    wire        i_eth_reconfig_read, i_eth_reconfig_write,o_eth_reconfig_readdata_valid;

    wire [31:0] i_eth_reconfig_writedata;
    wire [4*32-1:0] i_xcvr_reconfig_writedata;

    wire        i_reconfig_clk = clk100;
    wire        i_clk_tx;
    wire        o_clk_pll_div64; //connected to i_clk_tx implicitly?


    // input domain (from user logic toward pins)




    wire                   clk_din = i_clk_tx;
    wire [WORDS*WIDTH-1:0] din;               // payload to send, left to right
    wire       [WORDS-1:0] din_start;         // start pos, first of every 8 bytes
    wire     [WORDS*8-1:0] din_end_pos;       // end position, any byte
    wire                   din_ack;           // payload is accepted

    // output domain (from pins toward user logic)
    wire                   clk_dout = o_clk_pll_div64;
    wire    [WORDS*64-1:0] dout_d;            // 5 word out stream, left to right
    wire       [WORDS-1:0] dout_first_data;
    wire     [WORDS*8-1:0] dout_last_data;
    wire                   dout_valid;

    wire    [511:0] i_tx_data;
    wire      [5:0] i_tx_empty;
    wire            i_tx_endofpacket;
    wire            o_tx_ready;
    wire            i_tx_startofpacket;
    wire            i_tx_valid;
    wire    [511:0] o_rx_data;
    wire      [5:0] o_rx_empty;
    wire            o_rx_endofpacket;
    wire            o_rx_startofpacket;
    wire            o_rx_valid;
    wire      [5:0] o_rx_error;

    //--- functions
    //Zhipeng Start
    //`include "common/alt_aeuex_wide_l8if_functions.iv"
    //assign i_tx_data          = din;
    //Zhipeng End
    //assign din_ack             = o_tx_ready;
    //assign dout_d              = o_rx_data;
    //assign dout_valid          = o_rx_valid;
    //assign dout_first_data     = {o_rx_startofpacket, {WORDS-1{1'b0}}};
    //assign dout_last_data      = o_rx_endofpacket ? alt_aeuex_wide_decode6to64(o_rx_empty) : 64'h0;


    wire tx_serial_clk_01;
    wire tx_serial_clk_23;
    wire [1:0]   tx_serial_clk = {tx_serial_clk_23,tx_serial_clk_01};
    wire tx_pll_locked_01;
    wire tx_pll_locked_23;
wire [1:0]   tx_pll_locked;


   wire      atx12_cascade;

    //Zhipeng Start
    logic    pcie_reset_n_r1;
    logic    pcie_reset_n_r2;
    logic    [511:0] stats_rx_data;
    logic      [5:0] stats_rx_empty;
    logic            stats_rx_endofpacket;
    logic            stats_rx_startofpacket;
    logic            stats_rx_valid;
    logic            stats_rx_ready;

    logic    [511:0] top_in_data;
    logic      [5:0] top_in_empty;
    logic            top_in_endofpacket;
    logic            top_in_startofpacket;
    logic            top_in_valid;
    logic            top_in_ready;
    logic    [511:0] top_out_data;
    logic      [5:0] top_out_empty;
    logic            top_out_endofpacket;
    logic            top_out_startofpacket;
    logic            top_out_valid;
    logic            top_out_ready;
    logic            top_out_almost_full;
    logic  [511:0]  reg_top_in_data;
    logic  [5:0]    reg_top_in_empty;
    logic           reg_top_in_valid;
    logic           reg_top_in_startofpacket;
    logic           reg_top_in_endofpacket;
    logic  [511:0]  reg_top_out_data;
    logic  [5:0]    reg_top_out_empty;
    logic           reg_top_out_valid;
    logic           reg_top_out_startofpacket;
    logic           reg_top_out_endofpacket;
    logic           reg_top_out_almost_full;
 
    logic [29:0] s_addr;
    logic s_read;
    logic s_write;
    logic [31:0] s_writedata;
    logic [31:0] s_readdata;
    logic s_readdata_valid;
    logic custom;
    logic [31:0] top_readdata;
    logic top_readdata_valid;

    logic           out_fifo0_in_csr_address;
    logic           out_fifo0_in_csr_read;
    logic           out_fifo0_in_csr_write;
    logic [31:0]    out_fifo0_in_csr_readdata;
    logic [31:0]    out_fifo0_in_csr_writedata;

    //PCIe signal
    logic         pcie_rstn_npor;
    logic         pcie_clk;
    logic         pcie_reset_n;

    logic         pcie_rddm_desc_ready;
    logic         pcie_rddm_desc_valid;
    logic [173:0] pcie_rddm_desc_data;
    logic         pcie_wrdm_desc_ready;
    logic         pcie_wrdm_desc_valid;
    logic [173:0] pcie_wrdm_desc_data;
    logic         pcie_wrdm_prio_ready;
    logic         pcie_wrdm_prio_valid;
    logic [173:0] pcie_wrdm_prio_data;
    logic [PCIE_ADDR_WIDTH-1:0]  pcie_address_0;      
    logic         pcie_write_0;        
    logic         pcie_read_0;         
    logic         pcie_readdatavalid_0;
    logic [511:0] pcie_readdata_0;     
    logic [511:0] pcie_writedata_0;    
    logic [63:0]  pcie_byteenable_0;   
    logic [PCIE_ADDR_WIDTH-1:0]  pcie_address_1;      
    logic         pcie_write_1;        
    logic         pcie_read_1;         
    logic         pcie_readdatavalid_1;
    logic [511:0] pcie_readdata_1;     
    logic [511:0] pcie_writedata_1;    
    logic [63:0]  pcie_byteenable_1;   
    //eSRAM signals
    logic         clk_datamover;
    logic         rst_datamover;
    logic         esram_pkt_buf_wren;
`ifdef USE_BRAM
    logic [14:0]  esram_pkt_buf_rdaddress;
    logic [14:0]  esram_pkt_buf_wraddress;
    logic [14:0]  reg_esram_pkt_buf_wraddress;
    logic [14:0]  reg_esram_pkt_buf_rdaddress;
`else
    logic [16:0]  esram_pkt_buf_rdaddress;
    logic [16:0]  esram_pkt_buf_wraddress;
    logic [16:0]  reg_esram_pkt_buf_wraddress;
    logic [16:0]  reg_esram_pkt_buf_rdaddress;
`endif

    logic [519:0] esram_pkt_buf_wrdata;
    logic         esram_pkt_buf_rden;
    logic         esram_pkt_buf_rd_valid;
    logic [519:0] esram_pkt_buf_rddata;

    logic         reg_esram_pkt_buf_wren;
    logic [519:0] reg_esram_pkt_buf_wrdata;
    logic         reg_esram_pkt_buf_rden;
    logic         reg_esram_pkt_buf_rd_valid;
    logic [519:0] reg_esram_pkt_buf_rddata;
//Zhipeng End
   
// Master : support lane0 and lane1
    atx_pll_e50g_master atx_m (
        .pll_refclk0        (i_clk_ref),
        .tx_serial_clk_gxt  (tx_serial_clk_23),
    .gxt_output_to_blw_atx (atx12_cascade),  
        .pll_locked         (tx_pll_locked_23),
        .pll_cal_busy       ()
    );


// Slave : support lane2 and lane3
   atx_pll_e50g_slave atx_s  (
    .gxt_input_from_abv_atx(atx12_cascade),  
        .pll_refclk0        (i_clk_ref),
        .tx_serial_clk_gxt  (tx_serial_clk_01),
        .pll_locked         (tx_pll_locked_01),
        .pll_cal_busy       ()
    );

   assign tx_pll_locked[0] = tx_pll_locked_23;
   assign tx_pll_locked[1] = tx_pll_locked_23; 



 
    alt_ehipc2_sys_pll u0 (
        .rst        (~cpu_resetn),  // reset.reset
        .refclk     (clk50),        // refclk.clk
        .locked     (iopll_locked), // locked.export
        .outclk_0   (clk100)        // outclk0.clk
    );


    wire [3:0]   o_xcvr_reconfig_waitrequest;
    wire [127:0]  o_xcvr_reconfig_readdata;

    reg    status_read_r;
    reg    status_write_r;
    reg [31:0] status_writedata_r;
    reg [19:0] status_addr_r;
    wire [31:0] status_writedata;

    wire [31:0] status_readdata;
    wire [19:0] status_addr;
    wire status_readdata_valid, status_waitrequest;
    wire select_waitrequest;
  
    always @(posedge i_reconfig_clk) begin
        if (arst) begin
            status_read_r <= 0;
            status_write_r <= 0;
            status_writedata_r <= 32'b0;
            status_addr_r <= 20'b0;
        end
    else if( !select_waitrequest || status_read || status_write ) begin
            status_read_r <= status_read;
            status_write_r <= status_write;
            status_writedata_r <= status_writedata;
            status_addr_r <= status_addr;
        end
    end

    //Zhipeng Start
    //assign select_waitrequest = ((status_addr_r >= 20'h10000) && (status_addr_r <= 20'h10FFF)) ? o_xcvr_reconfig_waitrequest[0] :
    //                            ((status_addr_r >= 20'h11000) && (status_addr_r <= 20'h11FFF)) ? o_xcvr_reconfig_waitrequest[1] :
    //                            ((status_addr_r >= 20'h12000) && (status_addr_r <= 20'h12FFF)) ? o_xcvr_reconfig_waitrequest[2] :
    //                            ((status_addr_r >= 20'h13000) && (status_addr_r <= 20'h13FFF)) ? o_xcvr_reconfig_waitrequest[3] :
    //                            ((status_addr_r >= 20'h00000) && (status_addr_r <= 20'h00FFF)) ? o_eth_reconfig_waitrequest :
    //                            1'b0;
   
    assign select_waitrequest = custom ? 1'b1 :
                                ((status_addr_r >= 20'h10000) && (status_addr_r <= 20'h10FFF)) ? o_xcvr_reconfig_waitrequest[0] :
                                ((status_addr_r >= 20'h11000) && (status_addr_r <= 20'h11FFF)) ? o_xcvr_reconfig_waitrequest[1] :
                                ((status_addr_r >= 20'h12000) && (status_addr_r <= 20'h12FFF)) ? o_xcvr_reconfig_waitrequest[2] :
                                ((status_addr_r >= 20'h13000) && (status_addr_r <= 20'h13FFF)) ? o_xcvr_reconfig_waitrequest[3] :
                                ((status_addr_r >= 20'h00000) && (status_addr_r <= 20'h00FFF)) ? o_eth_reconfig_waitrequest :
                                1'b0;
    //Zhipeng End
    
//Decoding for avmm address map registers
   wire   [3:0] xcvr_reconfig_readdata_valid;
   wire [3:0]   i_xcvr_reconfig_read;
   wire [3:0]   i_xcvr_reconfig_write;
   wire [43:0]  i_xcvr_reconfig_address;
       
//Reconfig Decoding XCVR 0      
    //Zhipeng Start
    //wire    xcvr0_cs    = ((status_addr_r >= 20'h10000) && (status_addr_r <= 20'h10FFF));
    wire    xcvr0_cs    = ((status_addr_r >= 20'h10000) && (status_addr_r <= 20'h10FFF)) && !custom;
    //Zhipeng End
    wire    xcvr0_read = status_read_r && xcvr0_cs;
    wire    xcvr0_write = status_write_r && xcvr0_cs;
    assign i_xcvr_reconfig_address[10:0]  = (xcvr0_read || xcvr0_write) ? status_addr_r[10:0] : 11'b0; 
    assign  xcvr_reconfig_readdata_valid[0]   = xcvr0_read && !o_xcvr_reconfig_waitrequest[0];
//Reconfig Decoding XCVR 1      
    //Zhipeng Start
    //wire    xcvr1_cs    = ((status_addr_r >= 20'h11000) && (status_addr_r <= 20'h11FFF));
    wire    xcvr1_cs    = ((status_addr_r >= 20'h11000) && (status_addr_r <= 20'h11FFF)) && !custom;
    //Zhipeng End
    wire    xcvr1_read = status_read_r && xcvr1_cs;
    wire    xcvr1_write = status_write_r && xcvr1_cs;
    assign i_xcvr_reconfig_address[21:11] = (xcvr1_read || xcvr1_write) ? status_addr_r[10:0] : 11'b0; 
    assign  xcvr_reconfig_readdata_valid[1]    = xcvr1_read  && !o_xcvr_reconfig_waitrequest[1];
 //Reconfig Decoding XCVR 2     
    //Zhipeng Start
    //wire    xcvr2_cs    = ((status_addr_r >= 20'h12000) && (status_addr_r <= 20'h12FFF));
    wire    xcvr2_cs    = ((status_addr_r >= 20'h12000) && (status_addr_r <= 20'h12FFF)) && !custom;
    //Zhipeng End
    wire    xcvr2_read = status_read_r && xcvr2_cs;
    wire    xcvr2_write = status_write_r && xcvr2_cs;
    assign i_xcvr_reconfig_address[32:22]  = (xcvr2_read || xcvr2_write) ? status_addr_r[10:0] : 11'b0; 
    assign   xcvr_reconfig_readdata_valid[2]   =xcvr2_read  && !o_xcvr_reconfig_waitrequest[2];
 //Reconfig Decoding XCVR 3     
    //Zhipeng Start
    //wire    xcvr3_cs    = ((status_addr_r >= 20'h13000) && (status_addr_r <= 20'h13FFF));
    wire    xcvr3_cs    = ((status_addr_r >= 20'h13000) && (status_addr_r <= 20'h13FFF)) && !custom;
    //Zhipeng End
    wire    xcvr3_read = status_read_r && xcvr3_cs;
    wire    xcvr3_write = status_write_r && xcvr3_cs;
    assign i_xcvr_reconfig_address[43:33]  = (xcvr3_read ||xcvr3_write) ? status_addr_r[10:0] : 11'b0; 
    assign   xcvr_reconfig_readdata_valid[3]    = xcvr3_read && !o_xcvr_reconfig_waitrequest[3];

  //Reconfig Decoding Eth       
    //Zhipeng Start
    //wire    eth_cs    = ((status_addr_r >= 20'h00000) && (status_addr_r <= 20'h00FFF));
    wire    eth_cs    = ((status_addr_r >= 20'h00000) && (status_addr_r <= 20'h00FFF)) && !custom;
    //Zhipeng End
    wire    eth_read = status_read_r && eth_cs;
    wire    eth_write = status_write_r && eth_cs;
    assign i_eth_reconfig_addr = (eth_read|| eth_write) ? status_addr_r[15:0] : 16'b0; 
   
   assign i_eth_reconfig_writedata = status_writedata_r;
   assign i_xcvr_reconfig_writedata = {4{status_writedata_r}};
   
//wire [3:0] o_tx_serial;
//wire [3:0] i_rx_serial;
wire [39:0] o_rxstatus_data;
wire [7:0] o_rx_pfc;
wire i_stats_snapshot;
assign i_stats_snapshot = 1'b0;
assign i_clk_tx = o_clk_pll_div64;
assign i_clk_rx = o_clk_pll_div64;
assign i_xcvr_reconfig_read = {xcvr3_read,xcvr2_read,xcvr1_read,xcvr0_read};
assign i_xcvr_reconfig_write = {xcvr3_write,xcvr2_write,xcvr1_write,xcvr0_write};
assign i_eth_reconfig_read = eth_read;
assign i_eth_reconfig_write = eth_write;
 
    ex_100G av_top (
           .i_stats_snapshot(i_stats_snapshot),
           .o_cdr_lock(o_cdr_lock),
           .i_eth_reconfig_addr(i_eth_reconfig_addr),
           .i_eth_reconfig_read(i_eth_reconfig_read),
           .i_eth_reconfig_write(i_eth_reconfig_write),
           .o_eth_reconfig_readdata(o_eth_reconfig_readdata),
           .o_eth_reconfig_readdata_valid(o_eth_reconfig_readdata_valid),
           .i_eth_reconfig_writedata(i_eth_reconfig_writedata),
           .o_eth_reconfig_waitrequest(o_eth_reconfig_waitrequest),
           .o_tx_lanes_stable(o_tx_lanes_stable),
           .o_rx_pcs_ready(o_rx_pcs_ready),
           .o_ehip_ready(o_ehip_ready),
           .o_rx_block_lock(o_rx_block_lock),
           .o_rx_am_lock(o_rx_am_lock),
           .o_rx_hi_ber(o_rx_hi_ber),
           .o_local_fault_status(o_local_fault_status),
           .o_remote_fault_status(o_remote_fault_status),
           .i_clk_ref(i_clk_ref),
           .i_clk_tx(i_clk_tx),
           .i_clk_rx(i_clk_rx),
           .o_clk_pll_div64(o_clk_pll_div64),
           .o_clk_pll_div66(o_clk_pll_div66),
           .o_clk_rec_div64(o_clk_rec_div64),
           .o_clk_rec_div66(o_clk_rec_div66),
           .i_csr_rst_n(~arst),
           .i_tx_rst_n(1'b1),
           .i_rx_rst_n(1'b1),
           .o_tx_serial(o_tx_serial),
           .i_rx_serial(i_rx_serial),
           .i_reconfig_clk(i_reconfig_clk),
           .i_reconfig_reset(i_reconfig_reset),
           .i_xcvr_reconfig_address(i_xcvr_reconfig_address),
           .i_xcvr_reconfig_read(i_xcvr_reconfig_read),
           .i_xcvr_reconfig_write(i_xcvr_reconfig_write),
           .o_xcvr_reconfig_readdata(o_xcvr_reconfig_readdata),
           .i_xcvr_reconfig_writedata(i_xcvr_reconfig_writedata),
           .o_xcvr_reconfig_waitrequest(o_xcvr_reconfig_waitrequest),
           .o_tx_ready(o_tx_ready),
           .o_rx_valid(o_rx_valid),
           .i_tx_valid(i_tx_valid),
           .i_tx_data(i_tx_data),
           .o_rx_data(o_rx_data),
           .i_tx_error(1'b0),
           .i_tx_startofpacket(i_tx_startofpacket),
           .i_tx_endofpacket(i_tx_endofpacket),
           .i_tx_empty(i_tx_empty),
           .i_tx_skip_crc(1'b0),
           .o_rx_startofpacket(o_rx_startofpacket),
           .o_rx_endofpacket(o_rx_endofpacket),
           .o_rx_empty(o_rx_empty),
           .o_rx_error(o_rx_error),
           .o_rxstatus_data(o_rxstatus_data),
           .o_rxstatus_valid(o_rxstatus_valid),
           .i_tx_pfc(8'b0),
           .o_rx_pfc(o_rx_pfc),
           .i_tx_pause(1'b0),
           .o_rx_pause(o_rx_pause),
    .i_tx_serial_clk(tx_serial_clk),
        .i_tx_pll_locked(tx_pll_locked)
    );


 

    // _______________________________________
    // generate and check some simple data transfers
    // _____________________________________________________________
//Zhipeng Start
//    wire [31:0] status_readdata_pc;
//    wire status_readdata_valid_pc;
//    alt_e100s10_packet_client pc (
//        .i_arst                     (arst),
//          
//            // TX to Ethernet
//        .i_clk_tx                   (clk_din),
//        .i_tx_ready                 (o_tx_ready),
//        .o_tx_valid                 (i_tx_valid),
//        .o_tx_data                  (din),
//        .o_tx_sop                   (i_tx_startofpacket),
//        .o_tx_eop                   (i_tx_endofpacket),
//        .o_tx_empty                 (i_tx_empty),
//            
//            // RX from Ethernet
//        .i_clk_rx                   (clk_dout),
//        .i_rx_sop                   (o_rx_startofpacket),
//        .i_rx_eop                   (o_rx_endofpacket),
//        .i_rx_empty                 (o_rx_empty),
//        .i_rx_data                  (o_rx_data),
//        .i_rx_valid                 (o_rx_valid),
//            // status register bus
//        .i_clk_status               (i_reconfig_clk),
//        .i_status_addr              (status_addr[15:0]),
//        .i_status_read              (status_read & ~|status_addr[19:16]),
//        .i_status_write             (status_write & ~|status_addr[19:16]),
//        .i_status_writedata         (status_writedata),
//        .o_status_readdata          (status_readdata_pc),
//        .o_status_readdata_valid    (status_readdata_valid_pc)
//    );
//    
//    defparam pc.WORDS = WORDS;
//    defparam pc.WIDTH = WIDTH;

//Zhipeng End
   //Avalon // _____________________________________________________________
    // merge status bus
    // _____________________________________________________________

  //  wire [31:0] status_readdata;
   // wire  status_waitrequest;
//Zhipeng Start
//    alt_aeuex_avalon_mm_read_combine #(
//        .TIMEOUT             (11), // for long ehip response
//        .NUM_CLIENTS         (6)
//    ) arc (
//        .clk            (i_reconfig_clk),
//        .arst           (arst),
//        .host_read        (status_read),
//        .host_readdata        (status_readdata),
//        .host_readdata_valid    (status_readdata_valid),
//        .host_waitrequest    (status_waitrequest),
//
//
//        .client_readdata_valid    ({o_eth_reconfig_readdata_valid, status_readdata_valid_pc, xcvr_reconfig_readdata_valid}),
//        .client_readdata    ({o_eth_reconfig_readdata,status_readdata_pc,o_xcvr_reconfig_readdata})
//
//    );
    alt_aeuex_avalon_mm_read_combine #(
        .TIMEOUT             (11), // for long ehip response
        .NUM_CLIENTS         (3)
    ) arc (
        .clk            (i_reconfig_clk),
        .arst           (arst),
        .host_read        (status_read),
        .host_readdata        (status_readdata),
        .host_readdata_valid    (status_readdata_valid),
        .host_waitrequest    (status_waitrequest),


        .client_readdata_valid    ({o_eth_reconfig_readdata_valid, s_readdata_valid, top_readdata_valid}),
        .client_readdata    ({o_eth_reconfig_readdata,s_readdata, top_readdata})

    );
//Zhipeng End
    // _______________________________________________________________________________________________________________ 
    // jtag_avalon 
    // _______________________________________________________________________________________________________________
    wire [31:0] av_addr;
    assign status_addr = av_addr[21:2];
    wire [3:0] byteenable;

    alt_ehipc2_jtag_avalon jtag_master (
        .clk_clk                (i_reconfig_clk),

        .clk_reset_reset        (arst),
        .master_address         (av_addr),
        .master_readdata        (status_readdata),
        .master_read            (status_read),
        .master_write           (status_write),
        .master_writedata       (status_writedata),
        .master_waitrequest     (status_waitrequest),
        .master_readdatavalid   (status_readdata_valid),
        .master_byteenable      (byteenable),
        .master_reset_reset     ()
    );
    // ___________________________________________________________

      // Sources and probes instance
 //Zhipeng Start
//    reg [5:0] clk50_cnt = 6'b0;
//
//
//    reg [5:0] clk100_cnt = 6'b0;
//    reg [5:0] clk_txmac_cnt = 6'b0;
//    reg [5:0] clk_rxmac_cnt = 6'b0;
//    reg [5:0] clk_rx_rs_cnt = 6'b0;
//    reg [5:0] clk_tx_rs_cnt = 6'b0;
//    reg       o_rx_startofpacketD=0;
//    reg       o_rx_endofpacketD=0;
//    reg        i_rx_endofpacketD=0;
//    reg        i_tx_startofpacketD=0;
//    reg        i_tx_endofpacketD=0;
//    reg        o_rx_errorD=0;
//    reg [5:0] tx_sop_cnt = 6'b0;
//    reg [5:0] tx_eop_cnt = 6'b0;
//    reg [5:0] rx_sop_cnt = 6'b0;
//    reg [5:0] rx_eop_cnt = 6'b0;
//    reg [5:0] rx_err_cnt = 6'b0;
//
//
//    always @(posedge o_clk_pll_div64) begin
//        if (o_rx_block_lock ) begin
//        tx_sop_cnt <= 6'h0;
//        tx_eop_cnt <= 6'h0;
//        end 
//        else begin
//        i_tx_startofpacketD <= i_tx_startofpacket&o_tx_ready;
//        i_tx_endofpacketD    <= i_tx_endofpacket &o_tx_ready;
//        tx_sop_cnt <= i_tx_startofpacketD ? tx_sop_cnt + 6'd1 : tx_sop_cnt;
//        tx_eop_cnt <= i_tx_endofpacketD   ? tx_eop_cnt + 6'd1 : tx_eop_cnt;
//        end
//    end
//
//    always @(posedge o_clk_pll_div64) begin
//        if (o_rx_block_lock ) begin
//        rx_sop_cnt <= 6'h0;
//        rx_eop_cnt <= 6'h0;   
//        rx_err_cnt <= 6'h0;
//        end 
//        else begin
//        o_rx_startofpacketD <= o_rx_startofpacket&&o_rx_valid;
//        o_rx_endofpacketD   <= o_rx_endofpacket &&o_rx_valid;
//        o_rx_errorD         <= o_rx_error && o_rx_valid;
//        rx_sop_cnt <= o_rx_startofpacketD ? rx_sop_cnt + 6'd1 : rx_sop_cnt;
//        rx_eop_cnt <= o_rx_endofpacketD   ? rx_eop_cnt + 6'd1 : rx_eop_cnt;
//        rx_err_cnt <= o_rx_errorD   ? rx_err_cnt + 6'd1 : rx_err_cnt;
//        end
//    end
//
//    wire  all_rx_seop_cnt_all = (|rx_sop_cnt) | (|rx_eop_cnt) | (|rx_err_cnt);
//    wire  all_tx_seop_cnt_all = (|tx_sop_cnt) | (|tx_eop_cnt);
//
//    always @(posedge o_clk_pll_div64) begin
//    clk_rxmac_cnt <= clk_rxmac_cnt + 6'd1;
//    end
//
//    always @(posedge o_clk_pll_div64) begin
//    clk_txmac_cnt <= clk_txmac_cnt + 6'd1;
//    end
//
//  
//    always @(posedge clk50) begin
//    clk50_cnt <= clk50_cnt + 6'd1;
//    end
//
//
//    always @(posedge clk100) begin
//    clk100_cnt <= clk100_cnt + 6'd1;
//    end
//
//   // always @(posedge clk_rx_rs) begin
//    //clk_rx_rs_cnt <=  clk_rx_rs_cnt + 6'd1;
//    ///end
//    //always @(posedge clk_tx_rs) begin
//    //clk_tx_rs_cnt <=  clk_tx_rs_cnt + 6'd1;
//    //end
//
//
    wire [7:0] system_status;
//    assign system_status[0] = arst;
//
//    assign system_status[1] = clk100_cnt[3];
//
//    assign system_status[2] = clk50_cnt[3];
//
//
//    assign system_status[3] = clk_txmac_cnt[5];
//
//    assign system_status[4] = clk_rxmac_cnt[5];
//    assign system_status[5] = all_rx_seop_cnt_all;
//    assign system_status[6] = all_tx_seop_cnt_all;
//    assign system_status[7] = tx_pll_locked_01;
//
//assign user_io[0]= clk_txmac_cnt[5];
//assign user_io[1]= clk_rxmac_cnt[5];
////assign user_io[2]= clk_rx_rs_cnt[5];
////assign user_io[3]= clk_tx_rs_cnt[5];
//assign user_io[4]= rx_sop_cnt[5]; 
//assign user_io[5]= rx_eop_cnt[5];
//assign user_io[6]= tx_sop_cnt[5];
//assign user_io[7]= tx_eop_cnt[5];
//assign user_io[8]= 0;
//assign user_io[9]= 0;

/*
    probe8 prb (
       .source  (source_reset),
       .probe   (system_status)
    );
*/
    // Zhipeng Start
    //Add my own pll to create user_clk 300MHz currently. 
    my_pll user_pll (
        .rst      (~cpu_resetn),      //   input,  width = 1,   reset.reset
        .refclk   (in_clk100),   //   input,  width = 1,  refclk.clk
        .locked   (user_pll_locked),   //  output,  width = 1,  locked.export
        .outclk_0 (user_clk),  //  output,  width = 1, outclk0.clk
        .outclk_1 (user_clk_high)  //  output,  width = 1, outclk0.clk
    );

    //Zhipeng End

    //Stats 
    assign s_addr = av_addr[31:2];
    assign custom = av_addr[31];

    assign s_read = status_read;
    assign s_write = status_write;
    assign s_writedata = status_writedata;

    assign rst_datamover = arst | !esram_pll_lock;
    assign pcie_rstn_npor = cpu_resetn;

    my_stats stats(
        .arst(arst),
    
        .clk_tx  (clk_din),
        .tx_ready(o_tx_ready),
        .tx_valid(i_tx_valid),
        .tx_data (i_tx_data),
        .tx_sop  (i_tx_startofpacket),
        .tx_eop  (i_tx_endofpacket),
        .tx_empty(i_tx_empty),
    
        .clk_rx  (clk_dout),
        .rx_sop  (o_rx_startofpacket),
        .rx_eop  (o_rx_endofpacket),
        .rx_empty(o_rx_empty),
        .rx_data (o_rx_data),
        .rx_valid(o_rx_valid),

        .rx_ready  (stats_rx_ready),
        .o_rx_sop  (stats_rx_startofpacket),
        .o_rx_eop  (stats_rx_endofpacket),
        .o_rx_empty(stats_rx_empty),
        .o_rx_data (stats_rx_data),
        .o_rx_valid(stats_rx_valid),

        .clk_status           (i_reconfig_clk),
        .status_addr          (s_addr),
        .status_read          (s_read),
        .status_write         (s_write),
        .status_writedata     (s_writedata),
        .status_readdata      (s_readdata),
        .status_readdata_valid(s_readdata_valid)
    );

    dc_fifo_wrapper input_fifo (
        .in_clk            (clk_dout),    
        .in_reset_n        (!arst),      
        .out_clk           (clk_datamover),    
        .out_reset_n       (!rst_datamover),      
        .in_data           (stats_rx_data),           
        .in_valid          (stats_rx_valid),          
        .in_ready          (stats_rx_ready),           
        .in_startofpacket  (stats_rx_startofpacket),  
        .in_endofpacket    (stats_rx_endofpacket),
        .in_empty          (stats_rx_empty), 
        .out_data          (top_in_data),          
        .out_valid         (top_in_valid),         
        .out_ready         (1'b1),         
        .out_startofpacket (top_in_startofpacket), 
        .out_endofpacket   (top_in_endofpacket),   
        .out_empty         (top_in_empty)          
    );

    top top_inst (
        //CLK & Rst
        .clk               (user_clk),            
        .rst               (arst),       
        .clk_datamover     (clk_datamover),            
        .rst_datamover     (rst_datamover),       
        .clk_pcie          (pcie_clk),            
        .rst_pcie          (!pcie_reset_n),       
        //Ethernet in & out data      
        .in_data                      (reg_top_in_data),           
        .in_valid                     (reg_top_in_valid),          
        .in_sop                       (reg_top_in_startofpacket),  
        .in_eop                       (reg_top_in_endofpacket),
        .in_empty                     (reg_top_in_empty),  
        .reg_out_data                 (top_out_data),          
        .reg_out_valid                (top_out_valid),         
        .out_almost_full              (reg_top_out_almost_full),         
        .reg_out_sop                  (top_out_startofpacket), 
        .reg_out_eop                  (top_out_endofpacket),   
        .reg_out_empty                (top_out_empty), 
        //PCIe    
        .pcie_rddm_desc_ready         (pcie_rddm_desc_ready),
        .pcie_rddm_desc_valid         (pcie_rddm_desc_valid),
        .pcie_rddm_desc_data          (pcie_rddm_desc_data),
        .pcie_wrdm_desc_ready         (pcie_wrdm_desc_ready),
        .pcie_wrdm_desc_valid         (pcie_wrdm_desc_valid),
        .pcie_wrdm_desc_data          (pcie_wrdm_desc_data),
        .pcie_wrdm_prio_ready         (pcie_wrdm_prio_ready),
        .pcie_wrdm_prio_valid         (pcie_wrdm_prio_valid),
        .pcie_wrdm_prio_data          (pcie_wrdm_prio_data),
        .pcie_address_0               (pcie_address_0), 
        .pcie_write_0                 (pcie_write_0), 
        .pcie_read_0                  (pcie_read_0), 
        .pcie_readdatavalid_0         (pcie_readdatavalid_0), 
        .pcie_readdata_0              (pcie_readdata_0), 
        .pcie_writedata_0             (pcie_writedata_0), 
        .pcie_byteenable_0            (pcie_byteenable_0), 
        .pcie_address_1               (pcie_address_1), 
        .pcie_write_1                 (pcie_write_1), 
        .pcie_read_1                  (pcie_read_1), 
        .pcie_readdatavalid_1         (pcie_readdatavalid_1), 
        .pcie_readdata_1              (pcie_readdata_1), 
        .pcie_writedata_1             (pcie_writedata_1), 
        .pcie_byteenable_1            (pcie_byteenable_1),  
        //eSRAM
        .reg_esram_pkt_buf_wren       (esram_pkt_buf_wren),
        .reg_esram_pkt_buf_wraddress  (esram_pkt_buf_wraddress),
        .reg_esram_pkt_buf_wrdata     (esram_pkt_buf_wrdata),
        .reg_esram_pkt_buf_rden       (esram_pkt_buf_rden),
        .reg_esram_pkt_buf_rdaddress  (esram_pkt_buf_rdaddress),
        .esram_pkt_buf_rd_valid       (reg_esram_pkt_buf_rd_valid),
        .esram_pkt_buf_rddata         (reg_esram_pkt_buf_rddata),
        //JTAG
        .clk_status        (i_reconfig_clk),
        .status_addr       (s_addr),
        .status_read       (s_read),
        .status_write      (s_write),
        .status_writedata  (s_writedata),
        .status_readdata   (top_readdata),
        .status_readdata_valid  (top_readdata_valid)
    );

    hyper_pipe_root reg_io_inst (
        //clk & rst
        .clk                    (user_clk),            
        .rst                    (arst),            
        .clk_datamover          (clk_datamover),            
        .rst_datamover          (rst_datamover),            
        //Ethernet in & out data
        .in_data                (top_in_data),           
        .in_valid               (top_in_valid),          
        .in_sop                 (top_in_startofpacket),  
        .in_eop                 (top_in_endofpacket),
        .in_empty               (top_in_empty),  
        .out_data               (top_out_data),          
        .out_valid              (top_out_valid),         
        .out_almost_full        (top_out_almost_full),         
        .out_sop                (top_out_startofpacket), 
        .out_eop                (top_out_endofpacket),   
        .out_empty              (top_out_empty), 
        //eSRAM
        .esram_pkt_buf_wren     (esram_pkt_buf_wren),
        .esram_pkt_buf_wraddress(esram_pkt_buf_wraddress),
        .esram_pkt_buf_wrdata   (esram_pkt_buf_wrdata),
        .esram_pkt_buf_rden     (esram_pkt_buf_rden),
        .esram_pkt_buf_rdaddress(esram_pkt_buf_rdaddress),
        .esram_pkt_buf_rd_valid (esram_pkt_buf_rd_valid),
        .esram_pkt_buf_rddata   (esram_pkt_buf_rddata),
        //output
        .reg_in_data                (reg_top_in_data),           
        .reg_in_valid               (reg_top_in_valid),          
        .reg_in_sop                 (reg_top_in_startofpacket),  
        .reg_in_eop                 (reg_top_in_endofpacket),
        .reg_in_empty               (reg_top_in_empty),  
        .reg_out_data               (reg_top_out_data),          
        .reg_out_valid              (reg_top_out_valid),         
        .reg_out_almost_full        (reg_top_out_almost_full),         
        .reg_out_sop                (reg_top_out_startofpacket), 
        .reg_out_eop                (reg_top_out_endofpacket),   
        .reg_out_empty              (reg_top_out_empty), 
        .reg_esram_pkt_buf_wren     (reg_esram_pkt_buf_wren),
        .reg_esram_pkt_buf_wraddress(reg_esram_pkt_buf_wraddress),
        .reg_esram_pkt_buf_wrdata   (reg_esram_pkt_buf_wrdata),
        .reg_esram_pkt_buf_rden     (reg_esram_pkt_buf_rden),
        .reg_esram_pkt_buf_rdaddress(reg_esram_pkt_buf_rdaddress),
        .reg_esram_pkt_buf_rd_valid (reg_esram_pkt_buf_rd_valid),
        .reg_esram_pkt_buf_rddata   (reg_esram_pkt_buf_rddata)
    );


    dc_fifo_wrapper_infill output_fifo (
        .in_clk            (user_clk),    
        .in_reset_n        (!arst),      
        .out_clk           (clk_din),    
        .out_reset_n       (!arst),      
        .in_csr_address    (out_fifo0_in_csr_address),
        .in_csr_read       (out_fifo0_in_csr_read),
        .in_csr_write      (out_fifo0_in_csr_write),
        .in_csr_readdata   (out_fifo0_in_csr_readdata),
        .in_csr_writedata  (out_fifo0_in_csr_writedata),
        .in_data           (reg_top_out_data),           
        .in_valid          (reg_top_out_valid),          
        .in_ready          (),           
        .in_startofpacket  (reg_top_out_startofpacket),  
        .in_endofpacket    (reg_top_out_endofpacket),
        .in_empty          (reg_top_out_empty), 
        .out_data          (i_tx_data),          
        .out_valid         (i_tx_valid),         
        .out_ready         (o_tx_ready),         
        .out_startofpacket (i_tx_startofpacket), 
        .out_endofpacket   (i_tx_endofpacket),   
        .out_empty         (i_tx_empty)          
    );

    dc_back_pressure #(
        .FULL_LEVEL(490)
    )
    dc_bp_out_fifo0 (
        .clk            (user_clk),
        .rst            (arst),
        .csr_address    (out_fifo0_in_csr_address),
        .csr_read       (out_fifo0_in_csr_read),
        .csr_write      (out_fifo0_in_csr_write),
        .csr_readdata   (out_fifo0_in_csr_readdata),
        .csr_writedata  (out_fifo0_in_csr_writedata),
        .almost_full    (top_out_almost_full)
    );
`ifdef NO_PCIE    
    assign pcie_clk = user_clk;
    assign pcie_reset_n = !arst;
    assign pcie_rddm_desc_ready = 0;
    assign pcie_wrdm_desc_ready = 0;
    assign pcie_wrdm_prio_ready = 0;
    assign pcie_write_0 = 0;
    assign pcie_read_0 = 0;
    assign pcie_write_1 = 0;
    assign pcie_read_1 = 0;
`else
pcie_core pcie (
    .refclk_clk             (refclk_clk),           
    .pcie_rstn_npor         (pcie_rstn_npor),       
    .pcie_rstn_pin_perst    (pcie_rstn_pin_perst),  
    .xcvr_rx_in0            (xcvr_rx_in0),              
    .xcvr_rx_in1            (xcvr_rx_in1),          
    .xcvr_rx_in2            (xcvr_rx_in2),          
    .xcvr_rx_in3            (xcvr_rx_in3),          
    .xcvr_rx_in4            (xcvr_rx_in4),          
    .xcvr_rx_in5            (xcvr_rx_in5),          
    .xcvr_rx_in6            (xcvr_rx_in6),          
    .xcvr_rx_in7            (xcvr_rx_in7),          
    .xcvr_rx_in8            (xcvr_rx_in8),          
    .xcvr_rx_in9            (xcvr_rx_in9),          
    .xcvr_rx_in10           (xcvr_rx_in10),         
    .xcvr_rx_in11           (xcvr_rx_in11),         
    .xcvr_rx_in12           (xcvr_rx_in12),         
    .xcvr_rx_in13           (xcvr_rx_in13),         
    .xcvr_rx_in14           (xcvr_rx_in14),         
    .xcvr_rx_in15           (xcvr_rx_in15),         
    .xcvr_tx_out0           (xcvr_tx_out0),         
    .xcvr_tx_out1           (xcvr_tx_out1),         
    .xcvr_tx_out2           (xcvr_tx_out2),         
    .xcvr_tx_out3           (xcvr_tx_out3),         
    .xcvr_tx_out4           (xcvr_tx_out4),         
    .xcvr_tx_out5           (xcvr_tx_out5),         
    .xcvr_tx_out6           (xcvr_tx_out6),         
    .xcvr_tx_out7           (xcvr_tx_out7),         
    .xcvr_tx_out8           (xcvr_tx_out8),         
    .xcvr_tx_out9           (xcvr_tx_out9),         
    .xcvr_tx_out10          (xcvr_tx_out10),        
    .xcvr_tx_out11          (xcvr_tx_out11),        
    .xcvr_tx_out12          (xcvr_tx_out12),        
    .xcvr_tx_out13          (xcvr_tx_out13),        
    .xcvr_tx_out14          (xcvr_tx_out14),        
    .xcvr_tx_out15          (xcvr_tx_out15),        
    .pcie_clk               (pcie_clk),
    .pcie_reset_n           (pcie_reset_n),
    .rddm_desc_ready        (pcie_rddm_desc_ready),
    .rddm_desc_valid        (pcie_rddm_desc_valid),
    .rddm_desc_data         (pcie_rddm_desc_data),
    .wrdm_desc_ready        (pcie_wrdm_desc_ready),
    .wrdm_desc_valid        (pcie_wrdm_desc_valid),
    .wrdm_desc_data         (pcie_wrdm_desc_data),
    .wrdm_prio_ready        (pcie_wrdm_prio_ready),
    .wrdm_prio_valid        (pcie_wrdm_prio_valid),
    .wrdm_prio_data         (pcie_wrdm_prio_data),
    .address_0              (pcie_address_0), 
    .write_0                (pcie_write_0), 
    .read_0                 (pcie_read_0), 
    .readdatavalid_0        (pcie_readdatavalid_0), 
    .readdata_0             (pcie_readdata_0), 
    .writedata_0            (pcie_writedata_0), 
    .byteenable_0           (pcie_byteenable_0), 
    .address_1              (pcie_address_1), 
    .write_1                (pcie_write_1), 
    .read_1                 (pcie_read_1), 
    .readdatavalid_1        (pcie_readdatavalid_1), 
    .readdata_1             (pcie_readdata_1), 
    .writedata_1            (pcie_writedata_1), 
    .byteenable_1           (pcie_byteenable_1)  
);
`endif


`ifdef USE_BRAM
    assign clk_datamover = user_clk;
esram_wrapper esram_pkt_buffer(
    .clk_esram_ref  (1'b0), //100 MHz
    .esram_pll_lock (esram_pll_lock), 
    .clk_esram      (clk_datamover), //200 MHz
    .wren           (reg_esram_pkt_buf_wren),
    .wraddress      (reg_esram_pkt_buf_wraddress),
    .wrdata         (reg_esram_pkt_buf_wrdata),
    .rden           (reg_esram_pkt_buf_rden),
    .rdaddress      (reg_esram_pkt_buf_rdaddress),
    .rd_valid       (esram_pkt_buf_rd_valid),
    .rddata         (esram_pkt_buf_rddata)
);
`else

esram_wrapper esram_pkt_buffer(
    .clk_esram_ref  (clk_esram_ref), //100 MHz
    .esram_pll_lock (esram_pll_lock), 
    .clk_esram      (clk_datamover), //200 MHz
    .wren           (reg_esram_pkt_buf_wren),
    .wraddress      (reg_esram_pkt_buf_wraddress),
    .wrdata         (reg_esram_pkt_buf_wrdata),
    .rden           (reg_esram_pkt_buf_rden),
    .rdaddress      (reg_esram_pkt_buf_rdaddress),
    .rd_valid       (esram_pkt_buf_rd_valid),
    .rddata         (esram_pkt_buf_rddata)
);
`endif

//Zhipeng End
endmodule

