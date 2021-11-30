`include "../constants.sv"

module pcie_core (
    input  wire         refclk_clk,
    input  wire         pcie_rstn_npor,
    input  wire         pcie_rstn_pin_perst,
    output wire         wrdm_desc_ready,
    input  wire         wrdm_desc_valid,
    input  wire [173:0] wrdm_desc_data,
    output wire         wrdm_prio_ready,
    input  wire         wrdm_prio_valid,
    input  wire [173:0] wrdm_prio_data,
    output wire         wrdm_tx_valid,
    output wire [31:0]  wrdm_tx_data,
    output wire         rddm_desc_ready,
    input  wire         rddm_desc_valid,
    input  wire [173:0] rddm_desc_data,
    output wire         rddm_prio_ready,
    input  wire         rddm_prio_valid,
    input  wire [173:0] rddm_prio_data,
    output wire         rddm_tx_valid,
    output wire [31:0]  rddm_tx_data,
    output wire         bas_waitrequest,
    input  wire [63:0]  bas_address,
    input  wire [63:0]  bas_byteenable,
    input  wire         bas_read,
    output wire [511:0] bas_readdata,
    output wire         bas_readdatavalid,
    input  wire         bas_write,
    input  wire [511:0] bas_writedata,
    input  wire [3:0]   bas_burstcount,
    output wire [1:0]   bas_response,
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
    output wire         xcvr_tx_out15,
    output logic        pcie_clk,
    output logic        pcie_reset_n,

    input  logic [511:0]               readdata_0,
    input  logic                       readdatavalid_0,
    output logic [511:0]               writedata_0,
    output logic [PCIE_ADDR_WIDTH-1:0] address_0,
    output logic                       write_0,
    output logic                       read_0,
    output logic [63:0]                byteenable_0,

    output logic [511:0] rddm_writedata,
    output logic [63:0]  rddm_address,
    output logic         rddm_write,
    output logic [63:0]  rddm_byteenable,
    input  logic         rddm_waitrequest
);

logic         hip_ctrl_simu_mode_pipe;
logic [66:0]  hip_ctrl_test_in;
logic         pipe_sim_only_sim_pipe_pclk_in;
logic [1:0]   pipe_sim_only_sim_pipe_rate;
logic [5:0]   pipe_sim_only_sim_ltssmstate;
logic [31:0]  pipe_sim_only_txdata0;
logic [31:0]  pipe_sim_only_txdata1;
logic [31:0]  pipe_sim_only_txdata2;
logic [31:0]  pipe_sim_only_txdata3;
logic [31:0]  pipe_sim_only_txdata4;
logic [31:0]  pipe_sim_only_txdata5;
logic [31:0]  pipe_sim_only_txdata6;
logic [31:0]  pipe_sim_only_txdata7;
logic [31:0]  pipe_sim_only_txdata8;
logic [31:0]  pipe_sim_only_txdata9;
logic [31:0]  pipe_sim_only_txdata10;
logic [31:0]  pipe_sim_only_txdata11;
logic [31:0]  pipe_sim_only_txdata12;
logic [31:0]  pipe_sim_only_txdata13;
logic [31:0]  pipe_sim_only_txdata14;
logic [31:0]  pipe_sim_only_txdata15;
logic [3:0]   pipe_sim_only_txdatak0;
logic [3:0]   pipe_sim_only_txdatak1;
logic [3:0]   pipe_sim_only_txdatak2;
logic [3:0]   pipe_sim_only_txdatak3;
logic [3:0]   pipe_sim_only_txdatak4;
logic [3:0]   pipe_sim_only_txdatak5;
logic [3:0]   pipe_sim_only_txdatak6;
logic [3:0]   pipe_sim_only_txdatak7;
logic [3:0]   pipe_sim_only_txdatak8;
logic [3:0]   pipe_sim_only_txdatak9;
logic [3:0]   pipe_sim_only_txdatak10;
logic [3:0]   pipe_sim_only_txdatak11;
logic [3:0]   pipe_sim_only_txdatak12;
logic [3:0]   pipe_sim_only_txdatak13;
logic [3:0]   pipe_sim_only_txdatak14;
logic [3:0]   pipe_sim_only_txdatak15;
logic         pipe_sim_only_txcompl0;
logic         pipe_sim_only_txcompl1;
logic         pipe_sim_only_txcompl2;
logic         pipe_sim_only_txcompl3;
logic         pipe_sim_only_txcompl4;
logic         pipe_sim_only_txcompl5;
logic         pipe_sim_only_txcompl6;
logic         pipe_sim_only_txcompl7;
logic         pipe_sim_only_txcompl8;
logic         pipe_sim_only_txcompl9;
logic         pipe_sim_only_txcompl10;
logic         pipe_sim_only_txcompl11;
logic         pipe_sim_only_txcompl12;
logic         pipe_sim_only_txcompl13;
logic         pipe_sim_only_txcompl14;
logic         pipe_sim_only_txcompl15;
logic         pipe_sim_only_txelecidle0;
logic         pipe_sim_only_txelecidle1;
logic         pipe_sim_only_txelecidle2;
logic         pipe_sim_only_txelecidle3;
logic         pipe_sim_only_txelecidle4;
logic         pipe_sim_only_txelecidle5;
logic         pipe_sim_only_txelecidle6;
logic         pipe_sim_only_txelecidle7;
logic         pipe_sim_only_txelecidle8;
logic         pipe_sim_only_txelecidle9;
logic         pipe_sim_only_txelecidle10;
logic         pipe_sim_only_txelecidle11;
logic         pipe_sim_only_txelecidle12;
logic         pipe_sim_only_txelecidle13;
logic         pipe_sim_only_txelecidle14;
logic         pipe_sim_only_txelecidle15;
logic         pipe_sim_only_txdetectrx0;
logic         pipe_sim_only_txdetectrx1;
logic         pipe_sim_only_txdetectrx2;
logic         pipe_sim_only_txdetectrx3;
logic         pipe_sim_only_txdetectrx4;
logic         pipe_sim_only_txdetectrx5;
logic         pipe_sim_only_txdetectrx6;
logic         pipe_sim_only_txdetectrx7;
logic         pipe_sim_only_txdetectrx8;
logic         pipe_sim_only_txdetectrx9;
logic         pipe_sim_only_txdetectrx10;
logic         pipe_sim_only_txdetectrx11;
logic         pipe_sim_only_txdetectrx12;
logic         pipe_sim_only_txdetectrx13;
logic         pipe_sim_only_txdetectrx14;
logic         pipe_sim_only_txdetectrx15;
logic [1:0]   pipe_sim_only_powerdown0;
logic [1:0]   pipe_sim_only_powerdown1;
logic [1:0]   pipe_sim_only_powerdown2;
logic [1:0]   pipe_sim_only_powerdown3;
logic [1:0]   pipe_sim_only_powerdown4;
logic [1:0]   pipe_sim_only_powerdown5;
logic [1:0]   pipe_sim_only_powerdown6;
logic [1:0]   pipe_sim_only_powerdown7;
logic [1:0]   pipe_sim_only_powerdown8;
logic [1:0]   pipe_sim_only_powerdown9;
logic [1:0]   pipe_sim_only_powerdown10;
logic [1:0]   pipe_sim_only_powerdown11;
logic [1:0]   pipe_sim_only_powerdown12;
logic [1:0]   pipe_sim_only_powerdown13;
logic [1:0]   pipe_sim_only_powerdown14;
logic [1:0]   pipe_sim_only_powerdown15;
logic [2:0]   pipe_sim_only_txmargin0;
logic [2:0]   pipe_sim_only_txmargin1;
logic [2:0]   pipe_sim_only_txmargin2;
logic [2:0]   pipe_sim_only_txmargin3;
logic [2:0]   pipe_sim_only_txmargin4;
logic [2:0]   pipe_sim_only_txmargin5;
logic [2:0]   pipe_sim_only_txmargin6;
logic [2:0]   pipe_sim_only_txmargin7;
logic [2:0]   pipe_sim_only_txmargin8;
logic [2:0]   pipe_sim_only_txmargin9;
logic [2:0]   pipe_sim_only_txmargin10;
logic [2:0]   pipe_sim_only_txmargin11;
logic [2:0]   pipe_sim_only_txmargin12;
logic [2:0]   pipe_sim_only_txmargin13;
logic [2:0]   pipe_sim_only_txmargin14;
logic [2:0]   pipe_sim_only_txmargin15;
logic         pipe_sim_only_txdeemph0;
logic         pipe_sim_only_txdeemph1;
logic         pipe_sim_only_txdeemph2;
logic         pipe_sim_only_txdeemph3;
logic         pipe_sim_only_txdeemph4;
logic         pipe_sim_only_txdeemph5;
logic         pipe_sim_only_txdeemph6;
logic         pipe_sim_only_txdeemph7;
logic         pipe_sim_only_txdeemph8;
logic         pipe_sim_only_txdeemph9;
logic         pipe_sim_only_txdeemph10;
logic         pipe_sim_only_txdeemph11;
logic         pipe_sim_only_txdeemph12;
logic         pipe_sim_only_txdeemph13;
logic         pipe_sim_only_txdeemph14;
logic         pipe_sim_only_txdeemph15;
logic         pipe_sim_only_txswing0;
logic         pipe_sim_only_txswing1;
logic         pipe_sim_only_txswing2;
logic         pipe_sim_only_txswing3;
logic         pipe_sim_only_txswing4;
logic         pipe_sim_only_txswing5;
logic         pipe_sim_only_txswing6;
logic         pipe_sim_only_txswing7;
logic         pipe_sim_only_txswing8;
logic         pipe_sim_only_txswing9;
logic         pipe_sim_only_txswing10;
logic         pipe_sim_only_txswing11;
logic         pipe_sim_only_txswing12;
logic         pipe_sim_only_txswing13;
logic         pipe_sim_only_txswing14;
logic         pipe_sim_only_txswing15;
logic [1:0]   pipe_sim_only_txsynchd0;
logic [1:0]   pipe_sim_only_txsynchd1;
logic [1:0]   pipe_sim_only_txsynchd2;
logic [1:0]   pipe_sim_only_txsynchd3;
logic [1:0]   pipe_sim_only_txsynchd4;
logic [1:0]   pipe_sim_only_txsynchd5;
logic [1:0]   pipe_sim_only_txsynchd6;
logic [1:0]   pipe_sim_only_txsynchd7;
logic [1:0]   pipe_sim_only_txsynchd8;
logic [1:0]   pipe_sim_only_txsynchd9;
logic [1:0]   pipe_sim_only_txsynchd10;
logic [1:0]   pipe_sim_only_txsynchd11;
logic [1:0]   pipe_sim_only_txsynchd12;
logic [1:0]   pipe_sim_only_txsynchd13;
logic [1:0]   pipe_sim_only_txsynchd14;
logic [1:0]   pipe_sim_only_txsynchd15;
logic         pipe_sim_only_txblkst0;
logic         pipe_sim_only_txblkst1;
logic         pipe_sim_only_txblkst2;
logic         pipe_sim_only_txblkst3;
logic         pipe_sim_only_txblkst4;
logic         pipe_sim_only_txblkst5;
logic         pipe_sim_only_txblkst6;
logic         pipe_sim_only_txblkst7;
logic         pipe_sim_only_txblkst8;
logic         pipe_sim_only_txblkst9;
logic         pipe_sim_only_txblkst10;
logic         pipe_sim_only_txblkst11;
logic         pipe_sim_only_txblkst12;
logic         pipe_sim_only_txblkst13;
logic         pipe_sim_only_txblkst14;
logic         pipe_sim_only_txblkst15;
logic         pipe_sim_only_txdataskip0;
logic         pipe_sim_only_txdataskip1;
logic         pipe_sim_only_txdataskip2;
logic         pipe_sim_only_txdataskip3;
logic         pipe_sim_only_txdataskip4;
logic         pipe_sim_only_txdataskip5;
logic         pipe_sim_only_txdataskip6;
logic         pipe_sim_only_txdataskip7;
logic         pipe_sim_only_txdataskip8;
logic         pipe_sim_only_txdataskip9;
logic         pipe_sim_only_txdataskip10;
logic         pipe_sim_only_txdataskip11;
logic         pipe_sim_only_txdataskip12;
logic         pipe_sim_only_txdataskip13;
logic         pipe_sim_only_txdataskip14;
logic         pipe_sim_only_txdataskip15;
logic [1:0]   pipe_sim_only_rate0;
logic [1:0]   pipe_sim_only_rate1;
logic [1:0]   pipe_sim_only_rate2;
logic [1:0]   pipe_sim_only_rate3;
logic [1:0]   pipe_sim_only_rate4;
logic [1:0]   pipe_sim_only_rate5;
logic [1:0]   pipe_sim_only_rate6;
logic [1:0]   pipe_sim_only_rate7;
logic [1:0]   pipe_sim_only_rate8;
logic [1:0]   pipe_sim_only_rate9;
logic [1:0]   pipe_sim_only_rate10;
logic [1:0]   pipe_sim_only_rate11;
logic [1:0]   pipe_sim_only_rate12;
logic [1:0]   pipe_sim_only_rate13;
logic [1:0]   pipe_sim_only_rate14;
logic [1:0]   pipe_sim_only_rate15;
logic         pipe_sim_only_rxpolarity0;
logic         pipe_sim_only_rxpolarity1;
logic         pipe_sim_only_rxpolarity2;
logic         pipe_sim_only_rxpolarity3;
logic         pipe_sim_only_rxpolarity4;
logic         pipe_sim_only_rxpolarity5;
logic         pipe_sim_only_rxpolarity6;
logic         pipe_sim_only_rxpolarity7;
logic         pipe_sim_only_rxpolarity8;
logic         pipe_sim_only_rxpolarity9;
logic         pipe_sim_only_rxpolarity10;
logic         pipe_sim_only_rxpolarity11;
logic         pipe_sim_only_rxpolarity12;
logic         pipe_sim_only_rxpolarity13;
logic         pipe_sim_only_rxpolarity14;
logic         pipe_sim_only_rxpolarity15;
logic [2:0]   pipe_sim_only_currentrxpreset0;
logic [2:0]   pipe_sim_only_currentrxpreset1;
logic [2:0]   pipe_sim_only_currentrxpreset2;
logic [2:0]   pipe_sim_only_currentrxpreset3;
logic [2:0]   pipe_sim_only_currentrxpreset4;
logic [2:0]   pipe_sim_only_currentrxpreset5;
logic [2:0]   pipe_sim_only_currentrxpreset6;
logic [2:0]   pipe_sim_only_currentrxpreset7;
logic [2:0]   pipe_sim_only_currentrxpreset8;
logic [2:0]   pipe_sim_only_currentrxpreset9;
logic [2:0]   pipe_sim_only_currentrxpreset10;
logic [2:0]   pipe_sim_only_currentrxpreset11;
logic [2:0]   pipe_sim_only_currentrxpreset12;
logic [2:0]   pipe_sim_only_currentrxpreset13;
logic [2:0]   pipe_sim_only_currentrxpreset14;
logic [2:0]   pipe_sim_only_currentrxpreset15;
logic [17:0]  pipe_sim_only_currentcoeff0;
logic [17:0]  pipe_sim_only_currentcoeff1;
logic [17:0]  pipe_sim_only_currentcoeff2;
logic [17:0]  pipe_sim_only_currentcoeff3;
logic [17:0]  pipe_sim_only_currentcoeff4;
logic [17:0]  pipe_sim_only_currentcoeff5;
logic [17:0]  pipe_sim_only_currentcoeff6;
logic [17:0]  pipe_sim_only_currentcoeff7;
logic [17:0]  pipe_sim_only_currentcoeff8;
logic [17:0]  pipe_sim_only_currentcoeff9;
logic [17:0]  pipe_sim_only_currentcoeff10;
logic [17:0]  pipe_sim_only_currentcoeff11;
logic [17:0]  pipe_sim_only_currentcoeff12;
logic [17:0]  pipe_sim_only_currentcoeff13;
logic [17:0]  pipe_sim_only_currentcoeff14;
logic [17:0]  pipe_sim_only_currentcoeff15;
logic         pipe_sim_only_rxeqeval0;
logic         pipe_sim_only_rxeqeval1;
logic         pipe_sim_only_rxeqeval2;
logic         pipe_sim_only_rxeqeval3;
logic         pipe_sim_only_rxeqeval4;
logic         pipe_sim_only_rxeqeval5;
logic         pipe_sim_only_rxeqeval6;
logic         pipe_sim_only_rxeqeval7;
logic         pipe_sim_only_rxeqeval8;
logic         pipe_sim_only_rxeqeval9;
logic         pipe_sim_only_rxeqeval10;
logic         pipe_sim_only_rxeqeval11;
logic         pipe_sim_only_rxeqeval12;
logic         pipe_sim_only_rxeqeval13;
logic         pipe_sim_only_rxeqeval14;
logic         pipe_sim_only_rxeqeval15;
logic         pipe_sim_only_rxeqinprogress0;
logic         pipe_sim_only_rxeqinprogress1;
logic         pipe_sim_only_rxeqinprogress2;
logic         pipe_sim_only_rxeqinprogress3;
logic         pipe_sim_only_rxeqinprogress4;
logic         pipe_sim_only_rxeqinprogress5;
logic         pipe_sim_only_rxeqinprogress6;
logic         pipe_sim_only_rxeqinprogress7;
logic         pipe_sim_only_rxeqinprogress8;
logic         pipe_sim_only_rxeqinprogress9;
logic         pipe_sim_only_rxeqinprogress10;
logic         pipe_sim_only_rxeqinprogress11;
logic         pipe_sim_only_rxeqinprogress12;
logic         pipe_sim_only_rxeqinprogress13;
logic         pipe_sim_only_rxeqinprogress14;
logic         pipe_sim_only_rxeqinprogress15;
logic         pipe_sim_only_invalidreq0;
logic         pipe_sim_only_invalidreq1;
logic         pipe_sim_only_invalidreq2;
logic         pipe_sim_only_invalidreq3;
logic         pipe_sim_only_invalidreq4;
logic         pipe_sim_only_invalidreq5;
logic         pipe_sim_only_invalidreq6;
logic         pipe_sim_only_invalidreq7;
logic         pipe_sim_only_invalidreq8;
logic         pipe_sim_only_invalidreq9;
logic         pipe_sim_only_invalidreq10;
logic         pipe_sim_only_invalidreq11;
logic         pipe_sim_only_invalidreq12;
logic         pipe_sim_only_invalidreq13;
logic         pipe_sim_only_invalidreq14;
logic         pipe_sim_only_invalidreq15;
logic [31:0]  pipe_sim_only_rxdata0;
logic [31:0]  pipe_sim_only_rxdata1;
logic [31:0]  pipe_sim_only_rxdata2;
logic [31:0]  pipe_sim_only_rxdata3;
logic [31:0]  pipe_sim_only_rxdata4;
logic [31:0]  pipe_sim_only_rxdata5;
logic [31:0]  pipe_sim_only_rxdata6;
logic [31:0]  pipe_sim_only_rxdata7;
logic [31:0]  pipe_sim_only_rxdata8;
logic [31:0]  pipe_sim_only_rxdata9;
logic [31:0]  pipe_sim_only_rxdata10;
logic [31:0]  pipe_sim_only_rxdata11;
logic [31:0]  pipe_sim_only_rxdata12;
logic [31:0]  pipe_sim_only_rxdata13;
logic [31:0]  pipe_sim_only_rxdata14;
logic [31:0]  pipe_sim_only_rxdata15;
logic [3:0]   pipe_sim_only_rxdatak0;
logic [3:0]   pipe_sim_only_rxdatak1;
logic [3:0]   pipe_sim_only_rxdatak2;
logic [3:0]   pipe_sim_only_rxdatak3;
logic [3:0]   pipe_sim_only_rxdatak4;
logic [3:0]   pipe_sim_only_rxdatak5;
logic [3:0]   pipe_sim_only_rxdatak6;
logic [3:0]   pipe_sim_only_rxdatak7;
logic [3:0]   pipe_sim_only_rxdatak8;
logic [3:0]   pipe_sim_only_rxdatak9;
logic [3:0]   pipe_sim_only_rxdatak10;
logic [3:0]   pipe_sim_only_rxdatak11;
logic [3:0]   pipe_sim_only_rxdatak12;
logic [3:0]   pipe_sim_only_rxdatak13;
logic [3:0]   pipe_sim_only_rxdatak14;
logic [3:0]   pipe_sim_only_rxdatak15;
logic         pipe_sim_only_phystatus0;
logic         pipe_sim_only_phystatus1;
logic         pipe_sim_only_phystatus2;
logic         pipe_sim_only_phystatus3;
logic         pipe_sim_only_phystatus4;
logic         pipe_sim_only_phystatus5;
logic         pipe_sim_only_phystatus6;
logic         pipe_sim_only_phystatus7;
logic         pipe_sim_only_phystatus8;
logic         pipe_sim_only_phystatus9;
logic         pipe_sim_only_phystatus10;
logic         pipe_sim_only_phystatus11;
logic         pipe_sim_only_phystatus12;
logic         pipe_sim_only_phystatus13;
logic         pipe_sim_only_phystatus14;
logic         pipe_sim_only_phystatus15;
logic         pipe_sim_only_rxvalid0;
logic         pipe_sim_only_rxvalid1;
logic         pipe_sim_only_rxvalid2;
logic         pipe_sim_only_rxvalid3;
logic         pipe_sim_only_rxvalid4;
logic         pipe_sim_only_rxvalid5;
logic         pipe_sim_only_rxvalid6;
logic         pipe_sim_only_rxvalid7;
logic         pipe_sim_only_rxvalid8;
logic         pipe_sim_only_rxvalid9;
logic         pipe_sim_only_rxvalid10;
logic         pipe_sim_only_rxvalid11;
logic         pipe_sim_only_rxvalid12;
logic         pipe_sim_only_rxvalid13;
logic         pipe_sim_only_rxvalid14;
logic         pipe_sim_only_rxvalid15;
logic [2:0]   pipe_sim_only_rxstatus0;
logic [2:0]   pipe_sim_only_rxstatus1;
logic [2:0]   pipe_sim_only_rxstatus2;
logic [2:0]   pipe_sim_only_rxstatus3;
logic [2:0]   pipe_sim_only_rxstatus4;
logic [2:0]   pipe_sim_only_rxstatus5;
logic [2:0]   pipe_sim_only_rxstatus6;
logic [2:0]   pipe_sim_only_rxstatus7;
logic [2:0]   pipe_sim_only_rxstatus8;
logic [2:0]   pipe_sim_only_rxstatus9;
logic [2:0]   pipe_sim_only_rxstatus10;
logic [2:0]   pipe_sim_only_rxstatus11;
logic [2:0]   pipe_sim_only_rxstatus12;
logic [2:0]   pipe_sim_only_rxstatus13;
logic [2:0]   pipe_sim_only_rxstatus14;
logic [2:0]   pipe_sim_only_rxstatus15;
logic         pipe_sim_only_rxelecidle0;
logic         pipe_sim_only_rxelecidle1;
logic         pipe_sim_only_rxelecidle2;
logic         pipe_sim_only_rxelecidle3;
logic         pipe_sim_only_rxelecidle4;
logic         pipe_sim_only_rxelecidle5;
logic         pipe_sim_only_rxelecidle6;
logic         pipe_sim_only_rxelecidle7;
logic         pipe_sim_only_rxelecidle8;
logic         pipe_sim_only_rxelecidle9;
logic         pipe_sim_only_rxelecidle10;
logic         pipe_sim_only_rxelecidle11;
logic         pipe_sim_only_rxelecidle12;
logic         pipe_sim_only_rxelecidle13;
logic         pipe_sim_only_rxelecidle14;
logic         pipe_sim_only_rxelecidle15;
logic [1:0]   pipe_sim_only_rxsynchd0;
logic [1:0]   pipe_sim_only_rxsynchd1;
logic [1:0]   pipe_sim_only_rxsynchd2;
logic [1:0]   pipe_sim_only_rxsynchd3;
logic [1:0]   pipe_sim_only_rxsynchd4;
logic [1:0]   pipe_sim_only_rxsynchd5;
logic [1:0]   pipe_sim_only_rxsynchd6;
logic [1:0]   pipe_sim_only_rxsynchd7;
logic [1:0]   pipe_sim_only_rxsynchd8;
logic [1:0]   pipe_sim_only_rxsynchd9;
logic [1:0]   pipe_sim_only_rxsynchd10;
logic [1:0]   pipe_sim_only_rxsynchd11;
logic [1:0]   pipe_sim_only_rxsynchd12;
logic [1:0]   pipe_sim_only_rxsynchd13;
logic [1:0]   pipe_sim_only_rxsynchd14;
logic [1:0]   pipe_sim_only_rxsynchd15;
logic         pipe_sim_only_rxblkst0;
logic         pipe_sim_only_rxblkst1;
logic         pipe_sim_only_rxblkst2;
logic         pipe_sim_only_rxblkst3;
logic         pipe_sim_only_rxblkst4;
logic         pipe_sim_only_rxblkst5;
logic         pipe_sim_only_rxblkst6;
logic         pipe_sim_only_rxblkst7;
logic         pipe_sim_only_rxblkst8;
logic         pipe_sim_only_rxblkst9;
logic         pipe_sim_only_rxblkst10;
logic         pipe_sim_only_rxblkst11;
logic         pipe_sim_only_rxblkst12;
logic         pipe_sim_only_rxblkst13;
logic         pipe_sim_only_rxblkst14;
logic         pipe_sim_only_rxblkst15;
logic         pipe_sim_only_rxdataskip0;
logic         pipe_sim_only_rxdataskip1;
logic         pipe_sim_only_rxdataskip2;
logic         pipe_sim_only_rxdataskip3;
logic         pipe_sim_only_rxdataskip4;
logic         pipe_sim_only_rxdataskip5;
logic         pipe_sim_only_rxdataskip6;
logic         pipe_sim_only_rxdataskip7;
logic         pipe_sim_only_rxdataskip8;
logic         pipe_sim_only_rxdataskip9;
logic         pipe_sim_only_rxdataskip10;
logic         pipe_sim_only_rxdataskip11;
logic         pipe_sim_only_rxdataskip12;
logic         pipe_sim_only_rxdataskip13;
logic         pipe_sim_only_rxdataskip14;
logic         pipe_sim_only_rxdataskip15;
logic [5:0]   pipe_sim_only_dirfeedback0;
logic [5:0]   pipe_sim_only_dirfeedback1;
logic [5:0]   pipe_sim_only_dirfeedback2;
logic [5:0]   pipe_sim_only_dirfeedback3;
logic [5:0]   pipe_sim_only_dirfeedback4;
logic [5:0]   pipe_sim_only_dirfeedback5;
logic [5:0]   pipe_sim_only_dirfeedback6;
logic [5:0]   pipe_sim_only_dirfeedback7;
logic [5:0]   pipe_sim_only_dirfeedback8;
logic [5:0]   pipe_sim_only_dirfeedback9;
logic [5:0]   pipe_sim_only_dirfeedback10;
logic [5:0]   pipe_sim_only_dirfeedback11;
logic [5:0]   pipe_sim_only_dirfeedback12;
logic [5:0]   pipe_sim_only_dirfeedback13;
logic [5:0]   pipe_sim_only_dirfeedback14;
logic [5:0]   pipe_sim_only_dirfeedback15;
logic         pipe_sim_only_sim_pipe_mask_tx_pll_lock;


assign hip_ctrl_simu_mode_pipe = 0;
assign hip_ctrl_test_in = 0;
assign pipe_sim_only_sim_pipe_pclk_in = 0;
assign pipe_sim_only_rxdata0 = 0;
assign pipe_sim_only_rxdata1 = 0;
assign pipe_sim_only_rxdata2 = 0;
assign pipe_sim_only_rxdata3 = 0;
assign pipe_sim_only_rxdata4 = 0;
assign pipe_sim_only_rxdata5 = 0;
assign pipe_sim_only_rxdata6 = 0;
assign pipe_sim_only_rxdata7 = 0;
assign pipe_sim_only_rxdata8 = 0;
assign pipe_sim_only_rxdata9 = 0;
assign pipe_sim_only_rxdata10 = 0;
assign pipe_sim_only_rxdata11 = 0;
assign pipe_sim_only_rxdata12 = 0;
assign pipe_sim_only_rxdata13 = 0;
assign pipe_sim_only_rxdata14 = 0;
assign pipe_sim_only_rxdata15 = 0;
assign pipe_sim_only_rxdatak0 = 0;
assign pipe_sim_only_rxdatak1 = 0;
assign pipe_sim_only_rxdatak2 = 0;
assign pipe_sim_only_rxdatak3 = 0;
assign pipe_sim_only_rxdatak4 = 0;
assign pipe_sim_only_rxdatak5 = 0;
assign pipe_sim_only_rxdatak6 = 0;
assign pipe_sim_only_rxdatak7 = 0;
assign pipe_sim_only_rxdatak8 = 0;
assign pipe_sim_only_rxdatak9 = 0;
assign pipe_sim_only_rxdatak10 = 0;
assign pipe_sim_only_rxdatak11 = 0;
assign pipe_sim_only_rxdatak12 = 0;
assign pipe_sim_only_rxdatak13 = 0;
assign pipe_sim_only_rxdatak14 = 0;
assign pipe_sim_only_rxdatak15 = 0;
assign pipe_sim_only_phystatus0 = 0;
assign pipe_sim_only_phystatus1 = 0;
assign pipe_sim_only_phystatus2 = 0;
assign pipe_sim_only_phystatus3 = 0;
assign pipe_sim_only_phystatus4 = 0;
assign pipe_sim_only_phystatus5 = 0;
assign pipe_sim_only_phystatus6 = 0;
assign pipe_sim_only_phystatus7 = 0;
assign pipe_sim_only_phystatus8 = 0;
assign pipe_sim_only_phystatus9 = 0;
assign pipe_sim_only_phystatus10 = 0;
assign pipe_sim_only_phystatus11 = 0;
assign pipe_sim_only_phystatus12 = 0;
assign pipe_sim_only_phystatus13 = 0;
assign pipe_sim_only_phystatus14 = 0;
assign pipe_sim_only_phystatus15 = 0;
assign pipe_sim_only_rxvalid0 = 0;
assign pipe_sim_only_rxvalid1 = 0;
assign pipe_sim_only_rxvalid2 = 0;
assign pipe_sim_only_rxvalid3 = 0;
assign pipe_sim_only_rxvalid4 = 0;
assign pipe_sim_only_rxvalid5 = 0;
assign pipe_sim_only_rxvalid6 = 0;
assign pipe_sim_only_rxvalid7 = 0;
assign pipe_sim_only_rxvalid8 = 0;
assign pipe_sim_only_rxvalid9 = 0;
assign pipe_sim_only_rxvalid10 = 0;
assign pipe_sim_only_rxvalid11 = 0;
assign pipe_sim_only_rxvalid12 = 0;
assign pipe_sim_only_rxvalid13 = 0;
assign pipe_sim_only_rxvalid14 = 0;
assign pipe_sim_only_rxvalid15 = 0;
assign pipe_sim_only_rxstatus0 = 0;
assign pipe_sim_only_rxstatus1 = 0;
assign pipe_sim_only_rxstatus2 = 0;
assign pipe_sim_only_rxstatus3 = 0;
assign pipe_sim_only_rxstatus4 = 0;
assign pipe_sim_only_rxstatus5 = 0;
assign pipe_sim_only_rxstatus6 = 0;
assign pipe_sim_only_rxstatus7 = 0;
assign pipe_sim_only_rxstatus8 = 0;
assign pipe_sim_only_rxstatus9 = 0;
assign pipe_sim_only_rxstatus10 = 0;
assign pipe_sim_only_rxstatus11 = 0;
assign pipe_sim_only_rxstatus12 = 0;
assign pipe_sim_only_rxstatus13 = 0;
assign pipe_sim_only_rxstatus14 = 0;
assign pipe_sim_only_rxstatus15 = 0;
assign pipe_sim_only_rxelecidle0 = 0;
assign pipe_sim_only_rxelecidle1 = 0;
assign pipe_sim_only_rxelecidle2 = 0;
assign pipe_sim_only_rxelecidle3 = 0;
assign pipe_sim_only_rxelecidle4 = 0;
assign pipe_sim_only_rxelecidle5 = 0;
assign pipe_sim_only_rxelecidle6 = 0;
assign pipe_sim_only_rxelecidle7 = 0;
assign pipe_sim_only_rxelecidle8 = 0;
assign pipe_sim_only_rxelecidle9 = 0;
assign pipe_sim_only_rxelecidle10 = 0;
assign pipe_sim_only_rxelecidle11 = 0;
assign pipe_sim_only_rxelecidle12 = 0;
assign pipe_sim_only_rxelecidle13 = 0;
assign pipe_sim_only_rxelecidle14 = 0;
assign pipe_sim_only_rxelecidle15 = 0;
assign pipe_sim_only_rxsynchd0 = 0;
assign pipe_sim_only_rxsynchd1 = 0;
assign pipe_sim_only_rxsynchd2 = 0;
assign pipe_sim_only_rxsynchd3 = 0;
assign pipe_sim_only_rxsynchd4 = 0;
assign pipe_sim_only_rxsynchd5 = 0;
assign pipe_sim_only_rxsynchd6 = 0;
assign pipe_sim_only_rxsynchd7 = 0;
assign pipe_sim_only_rxsynchd8 = 0;
assign pipe_sim_only_rxsynchd9 = 0;
assign pipe_sim_only_rxsynchd10 = 0;
assign pipe_sim_only_rxsynchd11 = 0;
assign pipe_sim_only_rxsynchd12 = 0;
assign pipe_sim_only_rxsynchd13 = 0;
assign pipe_sim_only_rxsynchd14 = 0;
assign pipe_sim_only_rxsynchd15 = 0;
assign pipe_sim_only_rxblkst0 = 0;
assign pipe_sim_only_rxblkst1 = 0;
assign pipe_sim_only_rxblkst2 = 0;
assign pipe_sim_only_rxblkst3 = 0;
assign pipe_sim_only_rxblkst4 = 0;
assign pipe_sim_only_rxblkst5 = 0;
assign pipe_sim_only_rxblkst6 = 0;
assign pipe_sim_only_rxblkst7 = 0;
assign pipe_sim_only_rxblkst8 = 0;
assign pipe_sim_only_rxblkst9 = 0;
assign pipe_sim_only_rxblkst10 = 0;
assign pipe_sim_only_rxblkst11 = 0;
assign pipe_sim_only_rxblkst12 = 0;
assign pipe_sim_only_rxblkst13 = 0;
assign pipe_sim_only_rxblkst14 = 0;
assign pipe_sim_only_rxblkst15 = 0;
assign pipe_sim_only_rxdataskip0 = 0;
assign pipe_sim_only_rxdataskip1 = 0;
assign pipe_sim_only_rxdataskip2 = 0;
assign pipe_sim_only_rxdataskip3 = 0;
assign pipe_sim_only_rxdataskip4 = 0;
assign pipe_sim_only_rxdataskip5 = 0;
assign pipe_sim_only_rxdataskip6 = 0;
assign pipe_sim_only_rxdataskip7 = 0;
assign pipe_sim_only_rxdataskip8 = 0;
assign pipe_sim_only_rxdataskip9 = 0;
assign pipe_sim_only_rxdataskip10 = 0;
assign pipe_sim_only_rxdataskip11 = 0;
assign pipe_sim_only_rxdataskip12 = 0;
assign pipe_sim_only_rxdataskip13 = 0;
assign pipe_sim_only_rxdataskip14 = 0;
assign pipe_sim_only_rxdataskip15 = 0;
assign pipe_sim_only_dirfeedback0 = 0;
assign pipe_sim_only_dirfeedback1 = 0;
assign pipe_sim_only_dirfeedback2 = 0;
assign pipe_sim_only_dirfeedback3 = 0;
assign pipe_sim_only_dirfeedback4 = 0;
assign pipe_sim_only_dirfeedback5 = 0;
assign pipe_sim_only_dirfeedback6 = 0;
assign pipe_sim_only_dirfeedback7 = 0;
assign pipe_sim_only_dirfeedback8 = 0;
assign pipe_sim_only_dirfeedback9 = 0;
assign pipe_sim_only_dirfeedback10 = 0;
assign pipe_sim_only_dirfeedback11 = 0;
assign pipe_sim_only_dirfeedback12 = 0;
assign pipe_sim_only_dirfeedback13 = 0;
assign pipe_sim_only_dirfeedback14 = 0;
assign pipe_sim_only_dirfeedback15 = 0;
assign pipe_sim_only_sim_pipe_mask_tx_pll_lock = 0;


pcie_ed pcie (
    .refclk_clk                              (refclk_clk),
    .pcie_rstn_npor                          (pcie_rstn_npor),
    .pcie_rstn_pin_perst                     (pcie_rstn_pin_perst),
    .dut_wrdm_conduit_pfnum                  (),
    .dut_wrdm_desc_ready                     (wrdm_desc_ready),
    .dut_wrdm_desc_valid                     (wrdm_desc_valid),
    .dut_wrdm_desc_data                      (wrdm_desc_data),
    .dut_wrdm_prio_ready                     (wrdm_prio_ready),
    .dut_wrdm_prio_valid                     (wrdm_prio_valid),
    .dut_wrdm_prio_data                      (wrdm_prio_data),
    .dut_wrdm_tx_valid                       (wrdm_tx_valid),
    .dut_wrdm_tx_data                        (wrdm_tx_data),
    .dut_rddm_conduit_pfnum                  (),
    .dut_rddm_master_waitrequest             (rddm_waitrequest),
    .dut_rddm_master_write                   (rddm_write),
    .dut_rddm_master_address                 (rddm_address),
    .dut_rddm_master_burstcount              (),
    .dut_rddm_master_byteenable              (rddm_byteenable),
    .dut_rddm_master_writedata               (rddm_writedata),
    .dut_rddm_desc_ready                     (rddm_desc_ready),
    .dut_rddm_desc_valid                     (rddm_desc_valid),
    .dut_rddm_desc_data                      (rddm_desc_data),
    .dut_rddm_prio_ready                     (rddm_prio_ready),
    .dut_rddm_prio_valid                     (rddm_prio_valid),
    .dut_rddm_prio_data                      (rddm_prio_data),
    .dut_rddm_tx_valid                       (rddm_tx_valid),
    .dut_rddm_tx_data                        (rddm_tx_data),
    .dut_bas_slave_waitrequest               (bas_waitrequest),
    .dut_bas_slave_address                   (bas_address),
    .dut_bas_slave_byteenable                (bas_byteenable),
    .dut_bas_slave_read                      (bas_read),
    .dut_bas_slave_readdata                  (bas_readdata),
    .dut_bas_slave_readdatavalid             (bas_readdatavalid),
    .dut_bas_slave_write                     (bas_write),
    .dut_bas_slave_writedata                 (bas_writedata),
    .dut_bas_slave_burstcount                (bas_burstcount),
    .dut_bas_slave_response                  (bas_response),
    .hip_ctrl_simu_mode_pipe                 (hip_ctrl_simu_mode_pipe),
    .hip_ctrl_test_in                        (hip_ctrl_test_in),
    .pipe_sim_only_sim_pipe_pclk_in          (pipe_sim_only_sim_pipe_pclk_in),
    .pipe_sim_only_sim_pipe_rate             (pipe_sim_only_sim_pipe_rate),
    .pipe_sim_only_sim_ltssmstate            (pipe_sim_only_sim_ltssmstate),
    .pipe_sim_only_txdata0                   (pipe_sim_only_txdata0),
    .pipe_sim_only_txdata1                   (pipe_sim_only_txdata1),
    .pipe_sim_only_txdata2                   (pipe_sim_only_txdata2),
    .pipe_sim_only_txdata3                   (pipe_sim_only_txdata3),
    .pipe_sim_only_txdata4                   (pipe_sim_only_txdata4),
    .pipe_sim_only_txdata5                   (pipe_sim_only_txdata5),
    .pipe_sim_only_txdata6                   (pipe_sim_only_txdata6),
    .pipe_sim_only_txdata7                   (pipe_sim_only_txdata7),
    .pipe_sim_only_txdata8                   (pipe_sim_only_txdata8),
    .pipe_sim_only_txdata9                   (pipe_sim_only_txdata9),
    .pipe_sim_only_txdata10                  (pipe_sim_only_txdata10),
    .pipe_sim_only_txdata11                  (pipe_sim_only_txdata11),
    .pipe_sim_only_txdata12                  (pipe_sim_only_txdata12),
    .pipe_sim_only_txdata13                  (pipe_sim_only_txdata13),
    .pipe_sim_only_txdata14                  (pipe_sim_only_txdata14),
    .pipe_sim_only_txdata15                  (pipe_sim_only_txdata15),
    .pipe_sim_only_txdatak0                  (pipe_sim_only_txdatak0),
    .pipe_sim_only_txdatak1                  (pipe_sim_only_txdatak1),
    .pipe_sim_only_txdatak2                  (pipe_sim_only_txdatak2),
    .pipe_sim_only_txdatak3                  (pipe_sim_only_txdatak3),
    .pipe_sim_only_txdatak4                  (pipe_sim_only_txdatak4),
    .pipe_sim_only_txdatak5                  (pipe_sim_only_txdatak5),
    .pipe_sim_only_txdatak6                  (pipe_sim_only_txdatak6),
    .pipe_sim_only_txdatak7                  (pipe_sim_only_txdatak7),
    .pipe_sim_only_txdatak8                  (pipe_sim_only_txdatak8),
    .pipe_sim_only_txdatak9                  (pipe_sim_only_txdatak9),
    .pipe_sim_only_txdatak10                 (pipe_sim_only_txdatak10),
    .pipe_sim_only_txdatak11                 (pipe_sim_only_txdatak11),
    .pipe_sim_only_txdatak12                 (pipe_sim_only_txdatak12),
    .pipe_sim_only_txdatak13                 (pipe_sim_only_txdatak13),
    .pipe_sim_only_txdatak14                 (pipe_sim_only_txdatak14),
    .pipe_sim_only_txdatak15                 (pipe_sim_only_txdatak15),
    .pipe_sim_only_txcompl0                  (pipe_sim_only_txcompl0),
    .pipe_sim_only_txcompl1                  (pipe_sim_only_txcompl1),
    .pipe_sim_only_txcompl2                  (pipe_sim_only_txcompl2),
    .pipe_sim_only_txcompl3                  (pipe_sim_only_txcompl3),
    .pipe_sim_only_txcompl4                  (pipe_sim_only_txcompl4),
    .pipe_sim_only_txcompl5                  (pipe_sim_only_txcompl5),
    .pipe_sim_only_txcompl6                  (pipe_sim_only_txcompl6),
    .pipe_sim_only_txcompl7                  (pipe_sim_only_txcompl7),
    .pipe_sim_only_txcompl8                  (pipe_sim_only_txcompl8),
    .pipe_sim_only_txcompl9                  (pipe_sim_only_txcompl9),
    .pipe_sim_only_txcompl10                 (pipe_sim_only_txcompl10),
    .pipe_sim_only_txcompl11                 (pipe_sim_only_txcompl11),
    .pipe_sim_only_txcompl12                 (pipe_sim_only_txcompl12),
    .pipe_sim_only_txcompl13                 (pipe_sim_only_txcompl13),
    .pipe_sim_only_txcompl14                 (pipe_sim_only_txcompl14),
    .pipe_sim_only_txcompl15                 (pipe_sim_only_txcompl15),
    .pipe_sim_only_txelecidle0               (pipe_sim_only_txelecidle0),
    .pipe_sim_only_txelecidle1               (pipe_sim_only_txelecidle1),
    .pipe_sim_only_txelecidle2               (pipe_sim_only_txelecidle2),
    .pipe_sim_only_txelecidle3               (pipe_sim_only_txelecidle3),
    .pipe_sim_only_txelecidle4               (pipe_sim_only_txelecidle4),
    .pipe_sim_only_txelecidle5               (pipe_sim_only_txelecidle5),
    .pipe_sim_only_txelecidle6               (pipe_sim_only_txelecidle6),
    .pipe_sim_only_txelecidle7               (pipe_sim_only_txelecidle7),
    .pipe_sim_only_txelecidle8               (pipe_sim_only_txelecidle8),
    .pipe_sim_only_txelecidle9               (pipe_sim_only_txelecidle9),
    .pipe_sim_only_txelecidle10              (pipe_sim_only_txelecidle10),
    .pipe_sim_only_txelecidle11              (pipe_sim_only_txelecidle11),
    .pipe_sim_only_txelecidle12              (pipe_sim_only_txelecidle12),
    .pipe_sim_only_txelecidle13              (pipe_sim_only_txelecidle13),
    .pipe_sim_only_txelecidle14              (pipe_sim_only_txelecidle14),
    .pipe_sim_only_txelecidle15              (pipe_sim_only_txelecidle15),
    .pipe_sim_only_txdetectrx0               (pipe_sim_only_txdetectrx0),
    .pipe_sim_only_txdetectrx1               (pipe_sim_only_txdetectrx1),
    .pipe_sim_only_txdetectrx2               (pipe_sim_only_txdetectrx2),
    .pipe_sim_only_txdetectrx3               (pipe_sim_only_txdetectrx3),
    .pipe_sim_only_txdetectrx4               (pipe_sim_only_txdetectrx4),
    .pipe_sim_only_txdetectrx5               (pipe_sim_only_txdetectrx5),
    .pipe_sim_only_txdetectrx6               (pipe_sim_only_txdetectrx6),
    .pipe_sim_only_txdetectrx7               (pipe_sim_only_txdetectrx7),
    .pipe_sim_only_txdetectrx8               (pipe_sim_only_txdetectrx8),
    .pipe_sim_only_txdetectrx9               (pipe_sim_only_txdetectrx9),
    .pipe_sim_only_txdetectrx10              (pipe_sim_only_txdetectrx10),
    .pipe_sim_only_txdetectrx11              (pipe_sim_only_txdetectrx11),
    .pipe_sim_only_txdetectrx12              (pipe_sim_only_txdetectrx12),
    .pipe_sim_only_txdetectrx13              (pipe_sim_only_txdetectrx13),
    .pipe_sim_only_txdetectrx14              (pipe_sim_only_txdetectrx14),
    .pipe_sim_only_txdetectrx15              (pipe_sim_only_txdetectrx15),
    .pipe_sim_only_powerdown0                (pipe_sim_only_powerdown0),
    .pipe_sim_only_powerdown1                (pipe_sim_only_powerdown1),
    .pipe_sim_only_powerdown2                (pipe_sim_only_powerdown2),
    .pipe_sim_only_powerdown3                (pipe_sim_only_powerdown3),
    .pipe_sim_only_powerdown4                (pipe_sim_only_powerdown4),
    .pipe_sim_only_powerdown5                (pipe_sim_only_powerdown5),
    .pipe_sim_only_powerdown6                (pipe_sim_only_powerdown6),
    .pipe_sim_only_powerdown7                (pipe_sim_only_powerdown7),
    .pipe_sim_only_powerdown8                (pipe_sim_only_powerdown8),
    .pipe_sim_only_powerdown9                (pipe_sim_only_powerdown9),
    .pipe_sim_only_powerdown10               (pipe_sim_only_powerdown10),
    .pipe_sim_only_powerdown11               (pipe_sim_only_powerdown11),
    .pipe_sim_only_powerdown12               (pipe_sim_only_powerdown12),
    .pipe_sim_only_powerdown13               (pipe_sim_only_powerdown13),
    .pipe_sim_only_powerdown14               (pipe_sim_only_powerdown14),
    .pipe_sim_only_powerdown15               (pipe_sim_only_powerdown15),
    .pipe_sim_only_txmargin0                 (pipe_sim_only_txmargin0),
    .pipe_sim_only_txmargin1                 (pipe_sim_only_txmargin1),
    .pipe_sim_only_txmargin2                 (pipe_sim_only_txmargin2),
    .pipe_sim_only_txmargin3                 (pipe_sim_only_txmargin3),
    .pipe_sim_only_txmargin4                 (pipe_sim_only_txmargin4),
    .pipe_sim_only_txmargin5                 (pipe_sim_only_txmargin5),
    .pipe_sim_only_txmargin6                 (pipe_sim_only_txmargin6),
    .pipe_sim_only_txmargin7                 (pipe_sim_only_txmargin7),
    .pipe_sim_only_txmargin8                 (pipe_sim_only_txmargin8),
    .pipe_sim_only_txmargin9                 (pipe_sim_only_txmargin9),
    .pipe_sim_only_txmargin10                (pipe_sim_only_txmargin10),
    .pipe_sim_only_txmargin11                (pipe_sim_only_txmargin11),
    .pipe_sim_only_txmargin12                (pipe_sim_only_txmargin12),
    .pipe_sim_only_txmargin13                (pipe_sim_only_txmargin13),
    .pipe_sim_only_txmargin14                (pipe_sim_only_txmargin14),
    .pipe_sim_only_txmargin15                (pipe_sim_only_txmargin15),
    .pipe_sim_only_txdeemph0                 (pipe_sim_only_txdeemph0),
    .pipe_sim_only_txdeemph1                 (pipe_sim_only_txdeemph1),
    .pipe_sim_only_txdeemph2                 (pipe_sim_only_txdeemph2),
    .pipe_sim_only_txdeemph3                 (pipe_sim_only_txdeemph3),
    .pipe_sim_only_txdeemph4                 (pipe_sim_only_txdeemph4),
    .pipe_sim_only_txdeemph5                 (pipe_sim_only_txdeemph5),
    .pipe_sim_only_txdeemph6                 (pipe_sim_only_txdeemph6),
    .pipe_sim_only_txdeemph7                 (pipe_sim_only_txdeemph7),
    .pipe_sim_only_txdeemph8                 (pipe_sim_only_txdeemph8),
    .pipe_sim_only_txdeemph9                 (pipe_sim_only_txdeemph9),
    .pipe_sim_only_txdeemph10                (pipe_sim_only_txdeemph10),
    .pipe_sim_only_txdeemph11                (pipe_sim_only_txdeemph11),
    .pipe_sim_only_txdeemph12                (pipe_sim_only_txdeemph12),
    .pipe_sim_only_txdeemph13                (pipe_sim_only_txdeemph13),
    .pipe_sim_only_txdeemph14                (pipe_sim_only_txdeemph14),
    .pipe_sim_only_txdeemph15                (pipe_sim_only_txdeemph15),
    .pipe_sim_only_txswing0                  (pipe_sim_only_txswing0),
    .pipe_sim_only_txswing1                  (pipe_sim_only_txswing1),
    .pipe_sim_only_txswing2                  (pipe_sim_only_txswing2),
    .pipe_sim_only_txswing3                  (pipe_sim_only_txswing3),
    .pipe_sim_only_txswing4                  (pipe_sim_only_txswing4),
    .pipe_sim_only_txswing5                  (pipe_sim_only_txswing5),
    .pipe_sim_only_txswing6                  (pipe_sim_only_txswing6),
    .pipe_sim_only_txswing7                  (pipe_sim_only_txswing7),
    .pipe_sim_only_txswing8                  (pipe_sim_only_txswing8),
    .pipe_sim_only_txswing9                  (pipe_sim_only_txswing9),
    .pipe_sim_only_txswing10                 (pipe_sim_only_txswing10),
    .pipe_sim_only_txswing11                 (pipe_sim_only_txswing11),
    .pipe_sim_only_txswing12                 (pipe_sim_only_txswing12),
    .pipe_sim_only_txswing13                 (pipe_sim_only_txswing13),
    .pipe_sim_only_txswing14                 (pipe_sim_only_txswing14),
    .pipe_sim_only_txswing15                 (pipe_sim_only_txswing15),
    .pipe_sim_only_txsynchd0                 (pipe_sim_only_txsynchd0),
    .pipe_sim_only_txsynchd1                 (pipe_sim_only_txsynchd1),
    .pipe_sim_only_txsynchd2                 (pipe_sim_only_txsynchd2),
    .pipe_sim_only_txsynchd3                 (pipe_sim_only_txsynchd3),
    .pipe_sim_only_txsynchd4                 (pipe_sim_only_txsynchd4),
    .pipe_sim_only_txsynchd5                 (pipe_sim_only_txsynchd5),
    .pipe_sim_only_txsynchd6                 (pipe_sim_only_txsynchd6),
    .pipe_sim_only_txsynchd7                 (pipe_sim_only_txsynchd7),
    .pipe_sim_only_txsynchd8                 (pipe_sim_only_txsynchd8),
    .pipe_sim_only_txsynchd9                 (pipe_sim_only_txsynchd9),
    .pipe_sim_only_txsynchd10                (pipe_sim_only_txsynchd10),
    .pipe_sim_only_txsynchd11                (pipe_sim_only_txsynchd11),
    .pipe_sim_only_txsynchd12                (pipe_sim_only_txsynchd12),
    .pipe_sim_only_txsynchd13                (pipe_sim_only_txsynchd13),
    .pipe_sim_only_txsynchd14                (pipe_sim_only_txsynchd14),
    .pipe_sim_only_txsynchd15                (pipe_sim_only_txsynchd15),
    .pipe_sim_only_txblkst0                  (pipe_sim_only_txblkst0),
    .pipe_sim_only_txblkst1                  (pipe_sim_only_txblkst1),
    .pipe_sim_only_txblkst2                  (pipe_sim_only_txblkst2),
    .pipe_sim_only_txblkst3                  (pipe_sim_only_txblkst3),
    .pipe_sim_only_txblkst4                  (pipe_sim_only_txblkst4),
    .pipe_sim_only_txblkst5                  (pipe_sim_only_txblkst5),
    .pipe_sim_only_txblkst6                  (pipe_sim_only_txblkst6),
    .pipe_sim_only_txblkst7                  (pipe_sim_only_txblkst7),
    .pipe_sim_only_txblkst8                  (pipe_sim_only_txblkst8),
    .pipe_sim_only_txblkst9                  (pipe_sim_only_txblkst9),
    .pipe_sim_only_txblkst10                 (pipe_sim_only_txblkst10),
    .pipe_sim_only_txblkst11                 (pipe_sim_only_txblkst11),
    .pipe_sim_only_txblkst12                 (pipe_sim_only_txblkst12),
    .pipe_sim_only_txblkst13                 (pipe_sim_only_txblkst13),
    .pipe_sim_only_txblkst14                 (pipe_sim_only_txblkst14),
    .pipe_sim_only_txblkst15                 (pipe_sim_only_txblkst15),
    .pipe_sim_only_txdataskip0               (pipe_sim_only_txdataskip0),
    .pipe_sim_only_txdataskip1               (pipe_sim_only_txdataskip1),
    .pipe_sim_only_txdataskip2               (pipe_sim_only_txdataskip2),
    .pipe_sim_only_txdataskip3               (pipe_sim_only_txdataskip3),
    .pipe_sim_only_txdataskip4               (pipe_sim_only_txdataskip4),
    .pipe_sim_only_txdataskip5               (pipe_sim_only_txdataskip5),
    .pipe_sim_only_txdataskip6               (pipe_sim_only_txdataskip6),
    .pipe_sim_only_txdataskip7               (pipe_sim_only_txdataskip7),
    .pipe_sim_only_txdataskip8               (pipe_sim_only_txdataskip8),
    .pipe_sim_only_txdataskip9               (pipe_sim_only_txdataskip9),
    .pipe_sim_only_txdataskip10              (pipe_sim_only_txdataskip10),
    .pipe_sim_only_txdataskip11              (pipe_sim_only_txdataskip11),
    .pipe_sim_only_txdataskip12              (pipe_sim_only_txdataskip12),
    .pipe_sim_only_txdataskip13              (pipe_sim_only_txdataskip13),
    .pipe_sim_only_txdataskip14              (pipe_sim_only_txdataskip14),
    .pipe_sim_only_txdataskip15              (pipe_sim_only_txdataskip15),
    .pipe_sim_only_rate0                     (pipe_sim_only_rate0),
    .pipe_sim_only_rate1                     (pipe_sim_only_rate1),
    .pipe_sim_only_rate2                     (pipe_sim_only_rate2),
    .pipe_sim_only_rate3                     (pipe_sim_only_rate3),
    .pipe_sim_only_rate4                     (pipe_sim_only_rate4),
    .pipe_sim_only_rate5                     (pipe_sim_only_rate5),
    .pipe_sim_only_rate6                     (pipe_sim_only_rate6),
    .pipe_sim_only_rate7                     (pipe_sim_only_rate7),
    .pipe_sim_only_rate8                     (pipe_sim_only_rate8),
    .pipe_sim_only_rate9                     (pipe_sim_only_rate9),
    .pipe_sim_only_rate10                    (pipe_sim_only_rate10),
    .pipe_sim_only_rate11                    (pipe_sim_only_rate11),
    .pipe_sim_only_rate12                    (pipe_sim_only_rate12),
    .pipe_sim_only_rate13                    (pipe_sim_only_rate13),
    .pipe_sim_only_rate14                    (pipe_sim_only_rate14),
    .pipe_sim_only_rate15                    (pipe_sim_only_rate15),
    .pipe_sim_only_rxpolarity0               (pipe_sim_only_rxpolarity0),
    .pipe_sim_only_rxpolarity1               (pipe_sim_only_rxpolarity1),
    .pipe_sim_only_rxpolarity2               (pipe_sim_only_rxpolarity2),
    .pipe_sim_only_rxpolarity3               (pipe_sim_only_rxpolarity3),
    .pipe_sim_only_rxpolarity4               (pipe_sim_only_rxpolarity4),
    .pipe_sim_only_rxpolarity5               (pipe_sim_only_rxpolarity5),
    .pipe_sim_only_rxpolarity6               (pipe_sim_only_rxpolarity6),
    .pipe_sim_only_rxpolarity7               (pipe_sim_only_rxpolarity7),
    .pipe_sim_only_rxpolarity8               (pipe_sim_only_rxpolarity8),
    .pipe_sim_only_rxpolarity9               (pipe_sim_only_rxpolarity9),
    .pipe_sim_only_rxpolarity10              (pipe_sim_only_rxpolarity10),
    .pipe_sim_only_rxpolarity11              (pipe_sim_only_rxpolarity11),
    .pipe_sim_only_rxpolarity12              (pipe_sim_only_rxpolarity12),
    .pipe_sim_only_rxpolarity13              (pipe_sim_only_rxpolarity13),
    .pipe_sim_only_rxpolarity14              (pipe_sim_only_rxpolarity14),
    .pipe_sim_only_rxpolarity15              (pipe_sim_only_rxpolarity15),
    .pipe_sim_only_currentrxpreset0          (pipe_sim_only_currentrxpreset0),
    .pipe_sim_only_currentrxpreset1          (pipe_sim_only_currentrxpreset1),
    .pipe_sim_only_currentrxpreset2          (pipe_sim_only_currentrxpreset2),
    .pipe_sim_only_currentrxpreset3          (pipe_sim_only_currentrxpreset3),
    .pipe_sim_only_currentrxpreset4          (pipe_sim_only_currentrxpreset4),
    .pipe_sim_only_currentrxpreset5          (pipe_sim_only_currentrxpreset5),
    .pipe_sim_only_currentrxpreset6          (pipe_sim_only_currentrxpreset6),
    .pipe_sim_only_currentrxpreset7          (pipe_sim_only_currentrxpreset7),
    .pipe_sim_only_currentrxpreset8          (pipe_sim_only_currentrxpreset8),
    .pipe_sim_only_currentrxpreset9          (pipe_sim_only_currentrxpreset9),
    .pipe_sim_only_currentrxpreset10         (pipe_sim_only_currentrxpreset10),
    .pipe_sim_only_currentrxpreset11         (pipe_sim_only_currentrxpreset11),
    .pipe_sim_only_currentrxpreset12         (pipe_sim_only_currentrxpreset12),
    .pipe_sim_only_currentrxpreset13         (pipe_sim_only_currentrxpreset13),
    .pipe_sim_only_currentrxpreset14         (pipe_sim_only_currentrxpreset14),
    .pipe_sim_only_currentrxpreset15         (pipe_sim_only_currentrxpreset15),
    .pipe_sim_only_currentcoeff0             (pipe_sim_only_currentcoeff0),
    .pipe_sim_only_currentcoeff1             (pipe_sim_only_currentcoeff1),
    .pipe_sim_only_currentcoeff2             (pipe_sim_only_currentcoeff2),
    .pipe_sim_only_currentcoeff3             (pipe_sim_only_currentcoeff3),
    .pipe_sim_only_currentcoeff4             (pipe_sim_only_currentcoeff4),
    .pipe_sim_only_currentcoeff5             (pipe_sim_only_currentcoeff5),
    .pipe_sim_only_currentcoeff6             (pipe_sim_only_currentcoeff6),
    .pipe_sim_only_currentcoeff7             (pipe_sim_only_currentcoeff7),
    .pipe_sim_only_currentcoeff8             (pipe_sim_only_currentcoeff8),
    .pipe_sim_only_currentcoeff9             (pipe_sim_only_currentcoeff9),
    .pipe_sim_only_currentcoeff10            (pipe_sim_only_currentcoeff10),
    .pipe_sim_only_currentcoeff11            (pipe_sim_only_currentcoeff11),
    .pipe_sim_only_currentcoeff12            (pipe_sim_only_currentcoeff12),
    .pipe_sim_only_currentcoeff13            (pipe_sim_only_currentcoeff13),
    .pipe_sim_only_currentcoeff14            (pipe_sim_only_currentcoeff14),
    .pipe_sim_only_currentcoeff15            (pipe_sim_only_currentcoeff15),
    .pipe_sim_only_rxeqeval0                 (pipe_sim_only_rxeqeval0),
    .pipe_sim_only_rxeqeval1                 (pipe_sim_only_rxeqeval1),
    .pipe_sim_only_rxeqeval2                 (pipe_sim_only_rxeqeval2),
    .pipe_sim_only_rxeqeval3                 (pipe_sim_only_rxeqeval3),
    .pipe_sim_only_rxeqeval4                 (pipe_sim_only_rxeqeval4),
    .pipe_sim_only_rxeqeval5                 (pipe_sim_only_rxeqeval5),
    .pipe_sim_only_rxeqeval6                 (pipe_sim_only_rxeqeval6),
    .pipe_sim_only_rxeqeval7                 (pipe_sim_only_rxeqeval7),
    .pipe_sim_only_rxeqeval8                 (pipe_sim_only_rxeqeval8),
    .pipe_sim_only_rxeqeval9                 (pipe_sim_only_rxeqeval9),
    .pipe_sim_only_rxeqeval10                (pipe_sim_only_rxeqeval10),
    .pipe_sim_only_rxeqeval11                (pipe_sim_only_rxeqeval11),
    .pipe_sim_only_rxeqeval12                (pipe_sim_only_rxeqeval12),
    .pipe_sim_only_rxeqeval13                (pipe_sim_only_rxeqeval13),
    .pipe_sim_only_rxeqeval14                (pipe_sim_only_rxeqeval14),
    .pipe_sim_only_rxeqeval15                (pipe_sim_only_rxeqeval15),
    .pipe_sim_only_rxeqinprogress0           (pipe_sim_only_rxeqinprogress0),
    .pipe_sim_only_rxeqinprogress1           (pipe_sim_only_rxeqinprogress1),
    .pipe_sim_only_rxeqinprogress2           (pipe_sim_only_rxeqinprogress2),
    .pipe_sim_only_rxeqinprogress3           (pipe_sim_only_rxeqinprogress3),
    .pipe_sim_only_rxeqinprogress4           (pipe_sim_only_rxeqinprogress4),
    .pipe_sim_only_rxeqinprogress5           (pipe_sim_only_rxeqinprogress5),
    .pipe_sim_only_rxeqinprogress6           (pipe_sim_only_rxeqinprogress6),
    .pipe_sim_only_rxeqinprogress7           (pipe_sim_only_rxeqinprogress7),
    .pipe_sim_only_rxeqinprogress8           (pipe_sim_only_rxeqinprogress8),
    .pipe_sim_only_rxeqinprogress9           (pipe_sim_only_rxeqinprogress9),
    .pipe_sim_only_rxeqinprogress10          (pipe_sim_only_rxeqinprogress10),
    .pipe_sim_only_rxeqinprogress11          (pipe_sim_only_rxeqinprogress11),
    .pipe_sim_only_rxeqinprogress12          (pipe_sim_only_rxeqinprogress12),
    .pipe_sim_only_rxeqinprogress13          (pipe_sim_only_rxeqinprogress13),
    .pipe_sim_only_rxeqinprogress14          (pipe_sim_only_rxeqinprogress14),
    .pipe_sim_only_rxeqinprogress15          (pipe_sim_only_rxeqinprogress15),
    .pipe_sim_only_invalidreq0               (pipe_sim_only_invalidreq0),
    .pipe_sim_only_invalidreq1               (pipe_sim_only_invalidreq1),
    .pipe_sim_only_invalidreq2               (pipe_sim_only_invalidreq2),
    .pipe_sim_only_invalidreq3               (pipe_sim_only_invalidreq3),
    .pipe_sim_only_invalidreq4               (pipe_sim_only_invalidreq4),
    .pipe_sim_only_invalidreq5               (pipe_sim_only_invalidreq5),
    .pipe_sim_only_invalidreq6               (pipe_sim_only_invalidreq6),
    .pipe_sim_only_invalidreq7               (pipe_sim_only_invalidreq7),
    .pipe_sim_only_invalidreq8               (pipe_sim_only_invalidreq8),
    .pipe_sim_only_invalidreq9               (pipe_sim_only_invalidreq9),
    .pipe_sim_only_invalidreq10              (pipe_sim_only_invalidreq10),
    .pipe_sim_only_invalidreq11              (pipe_sim_only_invalidreq11),
    .pipe_sim_only_invalidreq12              (pipe_sim_only_invalidreq12),
    .pipe_sim_only_invalidreq13              (pipe_sim_only_invalidreq13),
    .pipe_sim_only_invalidreq14              (pipe_sim_only_invalidreq14),
    .pipe_sim_only_invalidreq15              (pipe_sim_only_invalidreq15),
    .pipe_sim_only_rxdata0                   (pipe_sim_only_rxdata0),
    .pipe_sim_only_rxdata1                   (pipe_sim_only_rxdata1),
    .pipe_sim_only_rxdata2                   (pipe_sim_only_rxdata2),
    .pipe_sim_only_rxdata3                   (pipe_sim_only_rxdata3),
    .pipe_sim_only_rxdata4                   (pipe_sim_only_rxdata4),
    .pipe_sim_only_rxdata5                   (pipe_sim_only_rxdata5),
    .pipe_sim_only_rxdata6                   (pipe_sim_only_rxdata6),
    .pipe_sim_only_rxdata7                   (pipe_sim_only_rxdata7),
    .pipe_sim_only_rxdata8                   (pipe_sim_only_rxdata8),
    .pipe_sim_only_rxdata9                   (pipe_sim_only_rxdata9),
    .pipe_sim_only_rxdata10                  (pipe_sim_only_rxdata10),
    .pipe_sim_only_rxdata11                  (pipe_sim_only_rxdata11),
    .pipe_sim_only_rxdata12                  (pipe_sim_only_rxdata12),
    .pipe_sim_only_rxdata13                  (pipe_sim_only_rxdata13),
    .pipe_sim_only_rxdata14                  (pipe_sim_only_rxdata14),
    .pipe_sim_only_rxdata15                  (pipe_sim_only_rxdata15),
    .pipe_sim_only_rxdatak0                  (pipe_sim_only_rxdatak0),
    .pipe_sim_only_rxdatak1                  (pipe_sim_only_rxdatak1),
    .pipe_sim_only_rxdatak2                  (pipe_sim_only_rxdatak2),
    .pipe_sim_only_rxdatak3                  (pipe_sim_only_rxdatak3),
    .pipe_sim_only_rxdatak4                  (pipe_sim_only_rxdatak4),
    .pipe_sim_only_rxdatak5                  (pipe_sim_only_rxdatak5),
    .pipe_sim_only_rxdatak6                  (pipe_sim_only_rxdatak6),
    .pipe_sim_only_rxdatak7                  (pipe_sim_only_rxdatak7),
    .pipe_sim_only_rxdatak8                  (pipe_sim_only_rxdatak8),
    .pipe_sim_only_rxdatak9                  (pipe_sim_only_rxdatak9),
    .pipe_sim_only_rxdatak10                 (pipe_sim_only_rxdatak10),
    .pipe_sim_only_rxdatak11                 (pipe_sim_only_rxdatak11),
    .pipe_sim_only_rxdatak12                 (pipe_sim_only_rxdatak12),
    .pipe_sim_only_rxdatak13                 (pipe_sim_only_rxdatak13),
    .pipe_sim_only_rxdatak14                 (pipe_sim_only_rxdatak14),
    .pipe_sim_only_rxdatak15                 (pipe_sim_only_rxdatak15),
    .pipe_sim_only_phystatus0                (pipe_sim_only_phystatus0),
    .pipe_sim_only_phystatus1                (pipe_sim_only_phystatus1),
    .pipe_sim_only_phystatus2                (pipe_sim_only_phystatus2),
    .pipe_sim_only_phystatus3                (pipe_sim_only_phystatus3),
    .pipe_sim_only_phystatus4                (pipe_sim_only_phystatus4),
    .pipe_sim_only_phystatus5                (pipe_sim_only_phystatus5),
    .pipe_sim_only_phystatus6                (pipe_sim_only_phystatus6),
    .pipe_sim_only_phystatus7                (pipe_sim_only_phystatus7),
    .pipe_sim_only_phystatus8                (pipe_sim_only_phystatus8),
    .pipe_sim_only_phystatus9                (pipe_sim_only_phystatus9),
    .pipe_sim_only_phystatus10               (pipe_sim_only_phystatus10),
    .pipe_sim_only_phystatus11               (pipe_sim_only_phystatus11),
    .pipe_sim_only_phystatus12               (pipe_sim_only_phystatus12),
    .pipe_sim_only_phystatus13               (pipe_sim_only_phystatus13),
    .pipe_sim_only_phystatus14               (pipe_sim_only_phystatus14),
    .pipe_sim_only_phystatus15               (pipe_sim_only_phystatus15),
    .pipe_sim_only_rxvalid0                  (pipe_sim_only_rxvalid0),
    .pipe_sim_only_rxvalid1                  (pipe_sim_only_rxvalid1),
    .pipe_sim_only_rxvalid2                  (pipe_sim_only_rxvalid2),
    .pipe_sim_only_rxvalid3                  (pipe_sim_only_rxvalid3),
    .pipe_sim_only_rxvalid4                  (pipe_sim_only_rxvalid4),
    .pipe_sim_only_rxvalid5                  (pipe_sim_only_rxvalid5),
    .pipe_sim_only_rxvalid6                  (pipe_sim_only_rxvalid6),
    .pipe_sim_only_rxvalid7                  (pipe_sim_only_rxvalid7),
    .pipe_sim_only_rxvalid8                  (pipe_sim_only_rxvalid8),
    .pipe_sim_only_rxvalid9                  (pipe_sim_only_rxvalid9),
    .pipe_sim_only_rxvalid10                 (pipe_sim_only_rxvalid10),
    .pipe_sim_only_rxvalid11                 (pipe_sim_only_rxvalid11),
    .pipe_sim_only_rxvalid12                 (pipe_sim_only_rxvalid12),
    .pipe_sim_only_rxvalid13                 (pipe_sim_only_rxvalid13),
    .pipe_sim_only_rxvalid14                 (pipe_sim_only_rxvalid14),
    .pipe_sim_only_rxvalid15                 (pipe_sim_only_rxvalid15),
    .pipe_sim_only_rxstatus0                 (pipe_sim_only_rxstatus0),
    .pipe_sim_only_rxstatus1                 (pipe_sim_only_rxstatus1),
    .pipe_sim_only_rxstatus2                 (pipe_sim_only_rxstatus2),
    .pipe_sim_only_rxstatus3                 (pipe_sim_only_rxstatus3),
    .pipe_sim_only_rxstatus4                 (pipe_sim_only_rxstatus4),
    .pipe_sim_only_rxstatus5                 (pipe_sim_only_rxstatus5),
    .pipe_sim_only_rxstatus6                 (pipe_sim_only_rxstatus6),
    .pipe_sim_only_rxstatus7                 (pipe_sim_only_rxstatus7),
    .pipe_sim_only_rxstatus8                 (pipe_sim_only_rxstatus8),
    .pipe_sim_only_rxstatus9                 (pipe_sim_only_rxstatus9),
    .pipe_sim_only_rxstatus10                (pipe_sim_only_rxstatus10),
    .pipe_sim_only_rxstatus11                (pipe_sim_only_rxstatus11),
    .pipe_sim_only_rxstatus12                (pipe_sim_only_rxstatus12),
    .pipe_sim_only_rxstatus13                (pipe_sim_only_rxstatus13),
    .pipe_sim_only_rxstatus14                (pipe_sim_only_rxstatus14),
    .pipe_sim_only_rxstatus15                (pipe_sim_only_rxstatus15),
    .pipe_sim_only_rxelecidle0               (pipe_sim_only_rxelecidle0),
    .pipe_sim_only_rxelecidle1               (pipe_sim_only_rxelecidle1),
    .pipe_sim_only_rxelecidle2               (pipe_sim_only_rxelecidle2),
    .pipe_sim_only_rxelecidle3               (pipe_sim_only_rxelecidle3),
    .pipe_sim_only_rxelecidle4               (pipe_sim_only_rxelecidle4),
    .pipe_sim_only_rxelecidle5               (pipe_sim_only_rxelecidle5),
    .pipe_sim_only_rxelecidle6               (pipe_sim_only_rxelecidle6),
    .pipe_sim_only_rxelecidle7               (pipe_sim_only_rxelecidle7),
    .pipe_sim_only_rxelecidle8               (pipe_sim_only_rxelecidle8),
    .pipe_sim_only_rxelecidle9               (pipe_sim_only_rxelecidle9),
    .pipe_sim_only_rxelecidle10              (pipe_sim_only_rxelecidle10),
    .pipe_sim_only_rxelecidle11              (pipe_sim_only_rxelecidle11),
    .pipe_sim_only_rxelecidle12              (pipe_sim_only_rxelecidle12),
    .pipe_sim_only_rxelecidle13              (pipe_sim_only_rxelecidle13),
    .pipe_sim_only_rxelecidle14              (pipe_sim_only_rxelecidle14),
    .pipe_sim_only_rxelecidle15              (pipe_sim_only_rxelecidle15),
    .pipe_sim_only_rxsynchd0                 (pipe_sim_only_rxsynchd0),
    .pipe_sim_only_rxsynchd1                 (pipe_sim_only_rxsynchd1),
    .pipe_sim_only_rxsynchd2                 (pipe_sim_only_rxsynchd2),
    .pipe_sim_only_rxsynchd3                 (pipe_sim_only_rxsynchd3),
    .pipe_sim_only_rxsynchd4                 (pipe_sim_only_rxsynchd4),
    .pipe_sim_only_rxsynchd5                 (pipe_sim_only_rxsynchd5),
    .pipe_sim_only_rxsynchd6                 (pipe_sim_only_rxsynchd6),
    .pipe_sim_only_rxsynchd7                 (pipe_sim_only_rxsynchd7),
    .pipe_sim_only_rxsynchd8                 (pipe_sim_only_rxsynchd8),
    .pipe_sim_only_rxsynchd9                 (pipe_sim_only_rxsynchd9),
    .pipe_sim_only_rxsynchd10                (pipe_sim_only_rxsynchd10),
    .pipe_sim_only_rxsynchd11                (pipe_sim_only_rxsynchd11),
    .pipe_sim_only_rxsynchd12                (pipe_sim_only_rxsynchd12),
    .pipe_sim_only_rxsynchd13                (pipe_sim_only_rxsynchd13),
    .pipe_sim_only_rxsynchd14                (pipe_sim_only_rxsynchd14),
    .pipe_sim_only_rxsynchd15                (pipe_sim_only_rxsynchd15),
    .pipe_sim_only_rxblkst0                  (pipe_sim_only_rxblkst0),
    .pipe_sim_only_rxblkst1                  (pipe_sim_only_rxblkst1),
    .pipe_sim_only_rxblkst2                  (pipe_sim_only_rxblkst2),
    .pipe_sim_only_rxblkst3                  (pipe_sim_only_rxblkst3),
    .pipe_sim_only_rxblkst4                  (pipe_sim_only_rxblkst4),
    .pipe_sim_only_rxblkst5                  (pipe_sim_only_rxblkst5),
    .pipe_sim_only_rxblkst6                  (pipe_sim_only_rxblkst6),
    .pipe_sim_only_rxblkst7                  (pipe_sim_only_rxblkst7),
    .pipe_sim_only_rxblkst8                  (pipe_sim_only_rxblkst8),
    .pipe_sim_only_rxblkst9                  (pipe_sim_only_rxblkst9),
    .pipe_sim_only_rxblkst10                 (pipe_sim_only_rxblkst10),
    .pipe_sim_only_rxblkst11                 (pipe_sim_only_rxblkst11),
    .pipe_sim_only_rxblkst12                 (pipe_sim_only_rxblkst12),
    .pipe_sim_only_rxblkst13                 (pipe_sim_only_rxblkst13),
    .pipe_sim_only_rxblkst14                 (pipe_sim_only_rxblkst14),
    .pipe_sim_only_rxblkst15                 (pipe_sim_only_rxblkst15),
    .pipe_sim_only_rxdataskip0               (pipe_sim_only_rxdataskip0),
    .pipe_sim_only_rxdataskip1               (pipe_sim_only_rxdataskip1),
    .pipe_sim_only_rxdataskip2               (pipe_sim_only_rxdataskip2),
    .pipe_sim_only_rxdataskip3               (pipe_sim_only_rxdataskip3),
    .pipe_sim_only_rxdataskip4               (pipe_sim_only_rxdataskip4),
    .pipe_sim_only_rxdataskip5               (pipe_sim_only_rxdataskip5),
    .pipe_sim_only_rxdataskip6               (pipe_sim_only_rxdataskip6),
    .pipe_sim_only_rxdataskip7               (pipe_sim_only_rxdataskip7),
    .pipe_sim_only_rxdataskip8               (pipe_sim_only_rxdataskip8),
    .pipe_sim_only_rxdataskip9               (pipe_sim_only_rxdataskip9),
    .pipe_sim_only_rxdataskip10              (pipe_sim_only_rxdataskip10),
    .pipe_sim_only_rxdataskip11              (pipe_sim_only_rxdataskip11),
    .pipe_sim_only_rxdataskip12              (pipe_sim_only_rxdataskip12),
    .pipe_sim_only_rxdataskip13              (pipe_sim_only_rxdataskip13),
    .pipe_sim_only_rxdataskip14              (pipe_sim_only_rxdataskip14),
    .pipe_sim_only_rxdataskip15              (pipe_sim_only_rxdataskip15),
    .pipe_sim_only_dirfeedback0              (pipe_sim_only_dirfeedback0),
    .pipe_sim_only_dirfeedback1              (pipe_sim_only_dirfeedback1),
    .pipe_sim_only_dirfeedback2              (pipe_sim_only_dirfeedback2),
    .pipe_sim_only_dirfeedback3              (pipe_sim_only_dirfeedback3),
    .pipe_sim_only_dirfeedback4              (pipe_sim_only_dirfeedback4),
    .pipe_sim_only_dirfeedback5              (pipe_sim_only_dirfeedback5),
    .pipe_sim_only_dirfeedback6              (pipe_sim_only_dirfeedback6),
    .pipe_sim_only_dirfeedback7              (pipe_sim_only_dirfeedback7),
    .pipe_sim_only_dirfeedback8              (pipe_sim_only_dirfeedback8),
    .pipe_sim_only_dirfeedback9              (pipe_sim_only_dirfeedback9),
    .pipe_sim_only_dirfeedback10             (pipe_sim_only_dirfeedback10),
    .pipe_sim_only_dirfeedback11             (pipe_sim_only_dirfeedback11),
    .pipe_sim_only_dirfeedback12             (pipe_sim_only_dirfeedback12),
    .pipe_sim_only_dirfeedback13             (pipe_sim_only_dirfeedback13),
    .pipe_sim_only_dirfeedback14             (pipe_sim_only_dirfeedback14),
    .pipe_sim_only_dirfeedback15             (pipe_sim_only_dirfeedback15),
    .pipe_sim_only_sim_pipe_mask_tx_pll_lock (pipe_sim_only_sim_pipe_mask_tx_pll_lock),
    .xcvr_rx_in0                             (xcvr_rx_in0),
    .xcvr_rx_in1                             (xcvr_rx_in1),
    .xcvr_rx_in2                             (xcvr_rx_in2),
    .xcvr_rx_in3                             (xcvr_rx_in3),
    .xcvr_rx_in4                             (xcvr_rx_in4),
    .xcvr_rx_in5                             (xcvr_rx_in5),
    .xcvr_rx_in6                             (xcvr_rx_in6),
    .xcvr_rx_in7                             (xcvr_rx_in7),
    .xcvr_rx_in8                             (xcvr_rx_in8),
    .xcvr_rx_in9                             (xcvr_rx_in9),
    .xcvr_rx_in10                            (xcvr_rx_in10),
    .xcvr_rx_in11                            (xcvr_rx_in11),
    .xcvr_rx_in12                            (xcvr_rx_in12),
    .xcvr_rx_in13                            (xcvr_rx_in13),
    .xcvr_rx_in14                            (xcvr_rx_in14),
    .xcvr_rx_in15                            (xcvr_rx_in15),
    .xcvr_tx_out0                            (xcvr_tx_out0),
    .xcvr_tx_out1                            (xcvr_tx_out1),
    .xcvr_tx_out2                            (xcvr_tx_out2),
    .xcvr_tx_out3                            (xcvr_tx_out3),
    .xcvr_tx_out4                            (xcvr_tx_out4),
    .xcvr_tx_out5                            (xcvr_tx_out5),
    .xcvr_tx_out6                            (xcvr_tx_out6),
    .xcvr_tx_out7                            (xcvr_tx_out7),
    .xcvr_tx_out8                            (xcvr_tx_out8),
    .xcvr_tx_out9                            (xcvr_tx_out9),
    .xcvr_tx_out10                           (xcvr_tx_out10),
    .xcvr_tx_out11                           (xcvr_tx_out11),
    .xcvr_tx_out12                           (xcvr_tx_out12),
    .xcvr_tx_out13                           (xcvr_tx_out13),
    .xcvr_tx_out14                           (xcvr_tx_out14),
    .xcvr_tx_out15                           (xcvr_tx_out15),
    .generic_component_0_coreclkout_hip_clk          (pcie_clk),
    .generic_component_0_app_nreset_status_1_reset_n (pcie_reset_n),
    .mm_bridge_0_m0_waitrequest              (1'b0),
    .mm_bridge_0_m0_readdata                 (readdata_0),
    .mm_bridge_0_m0_readdatavalid            (readdatavalid_0),
    .mm_bridge_0_m0_burstcount               (),
    .mm_bridge_0_m0_writedata                (writedata_0),
    .mm_bridge_0_m0_address                  (address_0),
    .mm_bridge_0_m0_write                    (write_0),
    .mm_bridge_0_m0_read                     (read_0),
    .mm_bridge_0_m0_byteenable               (byteenable_0),
    .mm_bridge_0_m0_debugaccess              ()
);
endmodule
