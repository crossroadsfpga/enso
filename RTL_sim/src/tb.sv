`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
`include "./my_struct_s.sv"
module tb;


// duration for each bit = 20 * timescale = 20 * 1 ns  = 20ns
localparam period = 10;  
localparam period_rx = 2.56;  
localparam period_tx = 2.56;  
localparam period_user = 5;  
localparam period_esram_ref = 10;  
localparam period_esram = 5;  
localparam period_pcie = 4;  
localparam data_width = 528;  
localparam lo = 0;  
localparam hi = 2400;     //m10_100
localparam stop = (hi*2*1.25+100000);  

logic  clk_status;
logic  clk_rxmac;
logic  clk_txmac;
logic  clk_user;
logic  clk_datamover;
logic  clk_esram_ref;
logic  clk_esram;
logic  clk_pcie;


logic rst_datamover;

logic  rst;
logic [31:0] pkt_cnt;
logic [31:0] cnt;
logic [31:0] addr;
logic [data_width -1:0] arr[lo:hi];

//Ethner signals
logic  [511:0]  l8_rx_data;
logic  [5:0]    l8_rx_empty;
logic           l8_rx_valid;
logic           l8_rx_startofpacket;
logic           l8_rx_endofpacket;
logic           l8_rx_ready;

logic  [511:0]  stats_rx_data;
logic  [5:0]    stats_rx_empty;
logic           stats_rx_valid;
logic           stats_rx_startofpacket;
logic           stats_rx_endofpacket;
logic           stats_rx_ready;

logic  [511:0]  top_in_data;
logic  [5:0]    top_in_empty;
logic           top_in_valid;
logic           top_in_startofpacket;
logic           top_in_endofpacket;
logic  [511:0]  top_out_data;
logic  [5:0]    top_out_empty;
logic           top_out_valid;
logic           top_out_startofpacket;
logic           top_out_endofpacket;
logic           top_out_almost_full;

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

logic  [511:0]  l8_tx_data;
logic  [5:0]    l8_tx_empty;
logic           l8_tx_valid;
logic           l8_tx_startofpacket;
logic           l8_tx_endofpacket;
logic           l8_tx_ready;

logic           out_fifo0_in_csr_address;
logic           out_fifo0_in_csr_read;
logic           out_fifo0_in_csr_write;
logic [31:0]    out_fifo0_in_csr_readdata;
logic [31:0]    out_fifo0_in_csr_writedata;

//PCIE
logic           disable_pcie;
logic [513:0]   pcie_rb_wr_data;
logic [11:0]    pcie_rb_wr_addr;          
logic           pcie_rb_wr_en;  
logic [11:0]    pcie_rb_wr_base_addr;          
logic           pcie_rb_almost_full;          
logic           pcie_rb_update_valid;
logic [11:0]    pcie_rb_update_size;

logic           reg_disable_pcie;
logic [513:0]   reg_pcie_rb_wr_data;
logic [11:0]    reg_pcie_rb_wr_addr;          
logic           reg_pcie_rb_wr_en;  
logic [11:0]    reg_pcie_rb_wr_base_addr;          
logic           reg_pcie_rb_almost_full;          
logic           reg_pcie_rb_update_valid;
logic [11:0]    reg_pcie_rb_update_size;

//eSRAM signals
logic esram_pll_lock; 
logic         esram_pkt_buf_wren;
logic [16:0]  esram_pkt_buf_wraddress;
logic [519:0] esram_pkt_buf_wrdata;
logic         esram_pkt_buf_rden;
logic [16:0]  esram_pkt_buf_rdaddress;
logic         esram_pkt_buf_rd_valid;
logic [519:0] esram_pkt_buf_rddata;
logic         reg_esram_pkt_buf_wren;
logic [16:0]  reg_esram_pkt_buf_wraddress;
logic [519:0] reg_esram_pkt_buf_wrdata;
logic         reg_esram_pkt_buf_rden;
logic [16:0]  reg_esram_pkt_buf_rdaddress;
logic         reg_esram_pkt_buf_rd_valid;
logic [519:0] reg_esram_pkt_buf_rddata;

//JTAG
logic [29:0] s_addr;
logic s_read;
logic s_write;
logic [31:0] s_writedata;
logic [31:0] s_readdata;
logic s_readdata_valid;
logic [15:0] s_cnt;
logic [31:0] top_readdata;
logic top_readdata_valid;
logic [31:0] dram_readdata;
logic dram_readdata_valid;

logic [3:0] tx_cnt;
logic [3:0] rx_cnt;

logic [31:0] pktID;
logic [31:0] ft_pkt;

logic [3:0] rate_cnt;

typedef enum{
    READ,
    WAIT
} state_t;

state_t read_state;

typedef enum{
    DISABLE_PCIE,
    IDLE,
    IN_PKT,
    OUT_PKT,
    INCOMP_OUT_PKT,
    PARSER_OUT_PKT,
    MAX_PARSER_FIFO,
    FD_IN_PKT,
    FD_OUT_PKT,
    MAX_FD_OUT_FIFO,
    DM_IN_PKT,
    IN_EMPTYLIST_PKT,
    OUT_EMPTYLIST_PKT,
    PKT_ETH,
    PKT_DROP,
    PKT_PCIE,
    MAX_DM2PCIE_FIFO,
    PCIE_PKT,
    PCIE_META,
    DM_PCIE_PKT,
    DM_PCIE_META,
    DM_ETH_PKT
} c_state_t;

c_state_t conf_state;

initial clk_rxmac = 0;
initial clk_txmac = 1;
initial clk_user = 0;
initial clk_esram_ref = 0;
initial clk_esram = 0;
initial clk_pcie = 0;

initial clk_status = 0;
initial l8_tx_ready = 0;
initial tx_cnt = 0;
initial rx_cnt = 0;


initial rst = 1;
initial cnt = 0;
initial rate_cnt = 0;
always #(period) clk_status = ~clk_status;
always #(period_rx) clk_rxmac = ~clk_rxmac;
always #(period_tx) clk_txmac = ~clk_txmac;
always #(period_user) clk_user = ~clk_user;
always #(period_esram_ref) clk_esram_ref = ~clk_esram_ref;
always #(period_esram) clk_esram = ~clk_esram;
always #(period_pcie) clk_pcie = ~clk_pcie;

//
//read raw data
initial
	begin : init_block
		integer i;          // temporary for generate reset value
		for (i = lo; i <= hi; i = i + 1) begin
			arr[i] = {((data_width + 1)/2){2'b0}} ;//initial it as all zero(zzp 06.30.2015)
		end
		$readmemh("./input_gen/m10_100.pkt", arr, lo, hi);//read data from rom
	end // initial begin

assign l8_rx_startofpacket = arr[addr][524];
assign l8_rx_endofpacket = arr[addr][520];
assign l8_rx_empty = arr[addr][519:512];
assign l8_rx_data = arr[addr][511:0];
assign rst_datamover = rst | !esram_pll_lock;
assign clk_datamover = clk_esram;

always @(posedge clk_rxmac)
begin
    if (rst) begin
        pktID <= 0;
    end else if(l8_rx_startofpacket & l8_rx_valid)begin
        pktID <= pktID + 1;
    end
end

always @(posedge clk_txmac)
begin
    if (tx_cnt < 4'd10)begin
        tx_cnt <= tx_cnt + 1'b1;
    end else begin
        tx_cnt <= 0;
        l8_tx_ready <= ~ l8_tx_ready;
    end
end

always @(posedge clk_rxmac)
begin
    //$display("-----CYCLE %d-----", cnt);
	cnt <= cnt + 1;
    if(rate_cnt == 9)begin
        rate_cnt <= 0;
    end else begin
        rate_cnt <= rate_cnt + 1;
    end
	if (cnt == 1) begin
		rst <= 1;
        addr <= 0;
        l8_rx_valid <= 0;
        //output_V_READY <= 1;
	end else if (cnt == 35) begin
		rst <= 0;
    //Make sure the stats reset is done.
    end else if (cnt == 7000) begin
        l8_rx_valid <= 1;
    end else if (cnt >=7001 ) begin

        //if(rate_cnt < 8)begin
            if (cnt[1])begin
            //if (cnt[2:0]==0)begin
            //if (cnt %2)begin
                if(addr<hi)begin
                    addr <= addr + 1;
                    l8_rx_valid <= 1;
                end else begin
                    l8_rx_valid <= 0;
                end
            end else begin
                l8_rx_valid <=0;
            end
	end

    if (cnt == stop) begin
        $display("STOP READING!");
	end
end


//Configure
//Read and display pkt/flow cnts
always @(posedge clk_status) begin
    if(rst)begin
        s_addr <= 0;
        s_read <= 0;
        s_write <= 0;
        s_writedata <= 0;
        s_cnt <= 0;
        conf_state <= DISABLE_PCIE;
    end else begin
        case(conf_state)
            DISABLE_PCIE:begin
                conf_state <= IDLE;
                s_write <= 1;
                s_addr <= 30'h2A00_000F;
            `ifdef NO_PCIE
                s_writedata <= 1;
            `else
                s_writedata <= 0;
            `endif
            end
            IDLE:begin
                s_write <= 0;
                if(cnt>=stop)begin
                    conf_state <= IN_PKT;
                    s_read <= 1;
                    s_addr <= 30'h2200_0000;
                end
            end
            IN_PKT:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("---- PRINT STATS ------");
                    $display("IN_PKT:\t%d",top_readdata);
                    conf_state <= OUT_PKT;
                    s_read <= 1;
                    s_addr <= 30'h2200_0001;
                end
            end
            OUT_PKT:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("OUT_PKT:\t%d",top_readdata);
                    conf_state <= INCOMP_OUT_PKT;
                    s_read <= 1;
                    s_addr <= 30'h2200_0002;
                end
            end
            INCOMP_OUT_PKT:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("INCOMP_OUT_PKT:\t%d",top_readdata);
                    conf_state <= PARSER_OUT_PKT;
                    s_read <= 1;
                    s_addr <= 30'h2200_0003;
                end
            end
            PARSER_OUT_PKT:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("PARSER_OUT_PKT:\t%d",top_readdata);
                    conf_state <= MAX_PARSER_FIFO;
                    s_read <= 1;
                    s_addr <= 30'h2200_0004;
                end
            end
            MAX_PARSER_FIFO:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("MAX_PARSER_FIFO:\t%d",top_readdata);
                    conf_state <= FD_IN_PKT;
                    s_read <= 1;
                    s_addr <= 30'h2200_0005;
                end
            end
            FD_IN_PKT:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("FD_IN_PKT:\t%d",top_readdata);
                    conf_state <= FD_OUT_PKT;
                    s_read <= 1;
                    s_addr <= 30'h2200_0006;
                end
            end
            FD_OUT_PKT:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("FD_OUT_PKT:\t%d",top_readdata);
                    conf_state <= MAX_FD_OUT_FIFO;
                    s_read <= 1;
                    s_addr <= 30'h2200_0007;
                end
            end
            MAX_FD_OUT_FIFO:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("MAX_FD_OUT_PKT:\t%d",top_readdata);
                    conf_state <= DM_IN_PKT;
                    s_read <= 1;
                    s_addr <= 30'h2200_0008;
                end
            end
            DM_IN_PKT:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("DM_IN_PKT:\t%d",top_readdata);
                    conf_state <= IN_EMPTYLIST_PKT;
                    s_read <= 1;
                    s_addr <= 30'h2200_0009;
                end
            end

            IN_EMPTYLIST_PKT:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("IN_EMPTYLIST_PKT:\t%d",top_readdata);
                    conf_state <= OUT_EMPTYLIST_PKT;
                    s_read <= 1;
                    s_addr <= 30'h2200_000A;
                end
            end
            OUT_EMPTYLIST_PKT:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("OUT_EMPTYLIST_PKT:\t%d",top_readdata);
                    conf_state <= PKT_ETH;
                    s_read <= 1;
                    s_addr <= 30'h2200_000B;
                end
            end
            PKT_ETH:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("PKT_ETH:\t%d",top_readdata);
                    conf_state <= PKT_DROP;
                    s_read <= 1;
                    s_addr <= 30'h2200_000C;
                end
            end
            PKT_DROP:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("PKT_DROP:\t%d",top_readdata);
                    conf_state <= PKT_PCIE;
                    s_read <= 1;
                    s_addr <= 30'h2200_000D;
                end
            end
            PKT_PCIE:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("PKT_PCIE:\t%d",top_readdata);
                    conf_state <= MAX_DM2PCIE_FIFO;
                    s_read <= 1;
                    s_addr <= 30'h2200_000E;
                end
            end
            MAX_DM2PCIE_FIFO:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("MAX_DM2PCIE_FIFO:\t%d",top_readdata);
                    conf_state <= PCIE_PKT;
                    s_read <= 1;
                    s_addr <= 30'h2200_000F;
                end
            end
            PCIE_PKT:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("PCIE_PKT:\t%d",top_readdata);
                    conf_state <= PCIE_META;
                    s_read <= 1;
                    s_addr <= 30'h2200_0010;
                end
            end
            PCIE_META:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("PCIE_META:\t%d",top_readdata);
                    conf_state <= DM_PCIE_PKT;
                    s_read <= 1;
                    s_addr <= 30'h2200_0011;
                end
            end
            DM_PCIE_PKT:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("DM_PCIE_PKT:\t%d",top_readdata);
                    conf_state <= DM_PCIE_META;
                    s_read <= 1;
                    s_addr <= 30'h2200_0012;
                end
            end
            DM_PCIE_META:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("DM_PCIE_META:\t%d",top_readdata);
                    conf_state <= DM_ETH_PKT;
                    s_read <= 1;
                    s_addr <= 30'h2200_0013;
                end
            end
            DM_ETH_PKT:begin
                s_read <= 0;
                if(top_readdata_valid)begin
                    $display("DM_ETH_PKT:\t%d",top_readdata);
                    $display("done");
                    $finish;
                end
            end
        endcase
    end
end

dc_fifo_wrapper input_fifo (
	.in_clk            (clk_rxmac),    
	.in_reset_n        (!rst),      
	.out_clk           (clk_datamover),    
	.out_reset_n       (!rst),      
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
    //clk & rst
	.clk                          (clk_user),            
	.rst                          (rst),       
	.clk_datamover                (clk_datamover),            
	.rst_datamover                (rst_datamover),       
	.clk_pcie                     (clk_pcie),            
	.rst_pcie                     (rst),       
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
    .reg_pcie_rb_wr_data          (pcie_rb_wr_data),           
    .reg_pcie_rb_wr_addr          (pcie_rb_wr_addr),          
    .reg_pcie_rb_wr_en            (pcie_rb_wr_en),  
    .pcie_rb_wr_base_addr         (reg_pcie_rb_wr_base_addr),  
    .pcie_rb_almost_full          (reg_pcie_rb_almost_full),          
    .reg_pcie_rb_update_valid     (pcie_rb_update_valid),
    .reg_pcie_rb_update_size      (pcie_rb_update_size),
    .disable_pcie                 (reg_disable_pcie),
    //eSRAM
    .reg_esram_pkt_buf_wren       (esram_pkt_buf_wren),
    .reg_esram_pkt_buf_wraddress  (esram_pkt_buf_wraddress),
    .reg_esram_pkt_buf_wrdata     (esram_pkt_buf_wrdata),
    .reg_esram_pkt_buf_rden       (esram_pkt_buf_rden),
    .reg_esram_pkt_buf_rdaddress  (esram_pkt_buf_rdaddress),
    .esram_pkt_buf_rd_valid       (reg_esram_pkt_buf_rd_valid),
    .esram_pkt_buf_rddata         (reg_esram_pkt_buf_rddata),
    //JTAG
    .clk_status                   (clk_status),
    .status_addr                  (s_addr),
    .status_read                  (s_read),
    .status_write                 (s_write),
    .status_writedata             (s_writedata),
    .status_readdata              (top_readdata),
    .status_readdata_valid        (top_readdata_valid)
);

hyper_pipe_root reg_io_inst (
    //clk & rst
	.clk                    (clk_user),            
    .rst                    (rst),
	.clk_datamover          (clk_datamover),            
    .rst_datamover          (rst_datamover),
	.clk_pcie               (clk_pcie),            
	.rst_pcie               (rst),            
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
    //PCIe    
    .pcie_rb_wr_data        (pcie_rb_wr_data),           
    .pcie_rb_wr_addr        (pcie_rb_wr_addr),          
    .pcie_rb_wr_en          (pcie_rb_wr_en),  
    .pcie_rb_wr_base_addr   (pcie_rb_wr_base_addr),  
    .pcie_rb_almost_full    (pcie_rb_almost_full),          
    .pcie_rb_update_valid   (pcie_rb_update_valid),
    .pcie_rb_update_size    (pcie_rb_update_size),
    .disable_pcie           (disable_pcie),
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
    .reg_pcie_rb_wr_data        (reg_pcie_rb_wr_data),           
    .reg_pcie_rb_wr_addr        (reg_pcie_rb_wr_addr),          
    .reg_pcie_rb_wr_en          (reg_pcie_rb_wr_en),  
    .reg_pcie_rb_wr_base_addr   (reg_pcie_rb_wr_base_addr),  
    .reg_pcie_rb_almost_full    (reg_pcie_rb_almost_full),          
    .reg_pcie_rb_update_valid   (reg_pcie_rb_update_valid),
    .reg_pcie_rb_update_size    (reg_pcie_rb_update_size),
    .reg_disable_pcie           (reg_disable_pcie),
    .reg_esram_pkt_buf_wren     (reg_esram_pkt_buf_wren),
    .reg_esram_pkt_buf_wraddress(reg_esram_pkt_buf_wraddress),
    .reg_esram_pkt_buf_wrdata   (reg_esram_pkt_buf_wrdata),
    .reg_esram_pkt_buf_rden     (reg_esram_pkt_buf_rden),
    .reg_esram_pkt_buf_rdaddress(reg_esram_pkt_buf_rdaddress),
    .reg_esram_pkt_buf_rd_valid (reg_esram_pkt_buf_rd_valid),
    .reg_esram_pkt_buf_rddata   (reg_esram_pkt_buf_rddata)
);


dc_fifo_wrapper_infill out_fifo0 (
	.in_clk            (clk_user),    
	.in_reset_n        (!rst),      
	.out_clk           (clk_txmac),    
	.out_reset_n       (!rst),      
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
	.out_data          (l8_tx_data),          
	.out_valid         (l8_tx_valid),         
	.out_ready         (l8_tx_ready),         
	.out_startofpacket (l8_tx_startofpacket), 
	.out_endofpacket   (l8_tx_endofpacket),   
	.out_empty         (l8_tx_empty)          
);

dc_back_pressure #(
    .FULL_LEVEL(490)
)
dc_bp_out_fifo0 (
    .clk            (clk_user),
    .rst            (rst),
    .csr_address    (out_fifo0_in_csr_address),
    .csr_read       (out_fifo0_in_csr_read),
    .csr_write      (out_fifo0_in_csr_write),
    .csr_readdata   (out_fifo0_in_csr_readdata),
    .csr_writedata  (out_fifo0_in_csr_writedata),
    .almost_full    (top_out_almost_full)
);

my_stats stats(
    .arst(rst),

    .clk_tx(clk_txmac),
    .tx_ready(l8_tx_ready),
    .tx_valid(l8_tx_valid),
    .tx_data(l8_tx_data),
    .tx_sop(l8_tx_startofpacket),
    .tx_eop(l8_tx_endofpacket),
    .tx_empty(l8_tx_empty),

    .clk_rx(clk_rxmac),
    .rx_sop(l8_rx_startofpacket),
    .rx_eop(l8_rx_endofpacket),
    .rx_empty(l8_rx_empty),
    .rx_data(l8_rx_data),
    .rx_valid(l8_rx_valid),

    .rx_ready(stats_rx_ready),
    .o_rx_sop(stats_rx_startofpacket),
    .o_rx_eop(stats_rx_endofpacket),
    .o_rx_empty(stats_rx_empty),
    .o_rx_data(stats_rx_data),
    .o_rx_valid(stats_rx_valid),

    .clk_status(clk_status),
    .status_addr(s_addr),
    .status_read(s_read),
    .status_write(s_write),
    .status_writedata(s_writedata),
    .status_readdata(s_readdata),
    .status_readdata_valid(s_readdata_valid)
);

pcie_top pcie (
    .refclk_clk             (1'b0),                              //         refclk.clk
    .pcie_rstn_npor         (1'b1),                          //      pcie_rstn.npor
    .pcie_rstn_pin_perst    (1'b0),                     //               .pin_perst
    .xcvr_rx_in0            (1'b0),                             //           xcvr.rx_in0
    .xcvr_rx_in1            (1'b0),                             //               .rx_in1
    .xcvr_rx_in2            (1'b0),                             //               .rx_in2
    .xcvr_rx_in3            (1'b0),                             //               .rx_in3
    .xcvr_rx_in4            (1'b0),                             //               .rx_in4
    .xcvr_rx_in5            (1'b0),                             //               .rx_in5
    .xcvr_rx_in6            (1'b0),                             //               .rx_in6
    .xcvr_rx_in7            (1'b0),                             //               .rx_in7
    .xcvr_rx_in8            (1'b0),                             //               .rx_in8
    .xcvr_rx_in9            (1'b0),                             //               .rx_in9
    .xcvr_rx_in10           (1'b0),                            //               .rx_in10
    .xcvr_rx_in11           (1'b0),                            //               .rx_in11
    .xcvr_rx_in12           (1'b0),                            //               .rx_in12
    .xcvr_rx_in13           (1'b0),                            //               .rx_in13
    .xcvr_rx_in14           (1'b0),                            //               .rx_in14
    .xcvr_rx_in15           (1'b0),                            //               .rx_in15
    .xcvr_tx_out0           (),                            //               .tx_out0
    .xcvr_tx_out1           (),                            //               .tx_out1
    .xcvr_tx_out2           (),                            //               .tx_out2
    .xcvr_tx_out3           (),                            //               .tx_out3
    .xcvr_tx_out4           (),                            //               .tx_out4
    .xcvr_tx_out5           (),                            //               .tx_out5
    .xcvr_tx_out6           (),                            //               .tx_out6
    .xcvr_tx_out7           (),                            //               .tx_out7
    .xcvr_tx_out8           (),                            //               .tx_out8
    .xcvr_tx_out9           (),                            //               .tx_out9
    .xcvr_tx_out10          (),                           //               .tx_out10
    .xcvr_tx_out11          (),                           //               .tx_out11
    .xcvr_tx_out12          (),                           //               .tx_out12
    .xcvr_tx_out13          (),                           //               .tx_out13
    .xcvr_tx_out14          (),                           //               .tx_out14
    .xcvr_tx_out15          (),                           //               .tx_out15
    .pcie_clk               (clk_pcie),
    .pcie_reset_n           (!rst),
    .pcie_rb_wr_data        (reg_pcie_rb_wr_data),           
    .pcie_rb_wr_addr        (reg_pcie_rb_wr_addr),          
    .pcie_rb_wr_en          (reg_pcie_rb_wr_en),  
    .pcie_rb_wr_base_addr   (pcie_rb_wr_base_addr),  
    .pcie_rb_almost_full    (pcie_rb_almost_full),          
    .pcie_rb_update_valid   (reg_pcie_rb_update_valid),
    .pcie_rb_update_size    (reg_pcie_rb_update_size),
    .disable_pcie           (disable_pcie),
    .clk_status             (clk_status),
    .status_addr            (s_addr),
    .status_read            (s_read),
    .status_write           (s_write),
    .status_writedata       (s_writedata),
    .status_readdata        (pcie_readdata),
    .status_readdata_valid  (pcie_readdata_valid)
);

esram_wrapper esram_pkt_buffer(
    .clk_esram_ref  (clk_esram_ref), //100 MHz
    .esram_pll_lock (esram_pll_lock), 
    .clk_esram      (clk_esram), //200 MHz
    .wren           (reg_esram_pkt_buf_wren),
    .wraddress      (reg_esram_pkt_buf_wraddress),
    .wrdata         (reg_esram_pkt_buf_wrdata),
    .rden           (reg_esram_pkt_buf_rden),
    .rdaddress      (reg_esram_pkt_buf_rdaddress),
    .rd_valid       (esram_pkt_buf_rd_valid),
    .rddata         (esram_pkt_buf_rddata)
);

endmodule
