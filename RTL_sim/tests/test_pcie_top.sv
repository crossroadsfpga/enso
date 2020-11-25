`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
`include "../src/pcie_top.sv"
`include "../src/fpga2cpu_pcie.sv"
module test_pcie_top;

`ifndef NB_QUEUES
`define NB_QUEUES 1
`endif

localparam pcie_period = 4;
localparam status_period = 10;
localparam nb_queues = `NB_QUEUES;
localparam use_bram = 1;
localparam write_pointer = 1;
localparam req_size = 16;

localparam target_nb_requests = 10000;

// size of the host buffer used by each queue (in flits)
// localparam RAM_BUF_SIZE = 65535;
// localparam RAM_BUF_SIZE = 8191;
localparam RAM_BUF_SIZE = 128;

logic [63:0] cnt;
logic        clk;
logic        rst;

logic                       pcie_bas_waitrequest;
logic [63:0]                pcie_bas_address;
logic [63:0]                pcie_bas_byteenable;
logic                       pcie_bas_read;
logic [511:0]               pcie_bas_readdata;
logic                       pcie_bas_readdatavalid;
logic                       pcie_bas_write;
logic [511:0]               pcie_bas_writedata;
logic [3:0]                 pcie_bas_burstcount;
logic [1:0]                 pcie_bas_response;
logic [PCIE_ADDR_WIDTH-1:0] pcie_address_0;
logic                       pcie_write_0;
logic                       pcie_read_0;
logic                       pcie_readdatavalid_0;
logic [511:0]               pcie_readdata_0;
logic [511:0]               pcie_writedata_0;
logic [63:0]                pcie_byteenable_0;

flit_lite_t            pcie_rb_wr_data;
logic [PDU_AWIDTH-1:0] pcie_rb_wr_addr;
logic                  pcie_rb_wr_en;
logic [PDU_AWIDTH-1:0] pcie_rb_wr_base_addr;
logic                  pcie_rb_wr_base_addr_valid;
logic                  pcie_rb_almost_full;
logic [31:0]           pcie_max_rb;
logic                  pcie_rb_update_valid;
logic [PDU_AWIDTH-1:0] pcie_rb_update_size;
logic                  disable_pcie;
pdu_metadata_t         pdumeta_cpu_data;
logic                  pdumeta_cpu_valid;
logic [9:0]            pdumeta_cnt;
logic [31:0]           dma_queue_full_cnt;
logic [31:0]           cpu_buf_full_cnt;

logic        clk_status;
logic [29:0] status_addr;
logic        status_read;
logic        status_write;
logic [31:0] status_writedata;
logic [31:0] status_readdata;
logic        status_readdata_valid;

logic stop;
logic error_termination;
logic [31:0] stop_cnt;

// Host RAM
logic [511:0] ram[nb_queues][RAM_BUF_SIZE];

logic [63:0] rx_cnt;
logic [63:0] req_cnt;
logic [$clog2(MAX_PKT_SIZE)-1:0] pdu_flit_cnt;

initial cnt = 0;
initial clk = 0;
initial clk_status = 0;
initial rst = 1;
initial stop = 0;
initial error_termination = 0;

always #(pcie_period) clk = ~clk;
always #(status_period) clk_status = ~clk_status;

always @(posedge clk) begin
    cnt <= cnt + 1;

    pcie_write_0 <= 0;
    pcie_read_0 <= 0;

    if (cnt < 10) begin // reset
        rst <= 1;
        pcie_bas_waitrequest <= 0;
        pcie_address_0 <= 0;
        
        pcie_writedata_0 <= 0;
        pcie_byteenable_0 <= 0;
        rx_cnt <= 0;
        req_cnt <= 0;
        stop_cnt <= 0;
        pdu_flit_cnt <= 0;
    end else if (cnt == 10) begin
        rst <= 0;
    end else if (cnt == 11) begin
        // set queue
        pcie_write_0 <= 1;
        pcie_address_0 <= 0;
        pcie_writedata_0 <= 0;
        pcie_writedata_0[127:64] <= 64'hdeadbeef00000000;
        pcie_byteenable_0 <= 0;
        pcie_byteenable_0[15:8] <= 8'hff;
    end else begin
        if (rx_cnt == target_nb_requests * (req_size/16 + write_pointer)) begin
            stop_cnt <= 10;    
        end

        if (pcie_bas_write) begin
            rx_cnt <= rx_cnt + 1;
            pdu_flit_cnt <= pdu_flit_cnt + 1;
            if ((pdu_flit_cnt + 1) == (req_size + (16 - 1))/16 + write_pointer)
            begin
                req_cnt <= req_cnt + 1;
                pdu_flit_cnt <= 0;
            end else begin
                if (req_cnt != pcie_bas_writedata[511:480] 
                        && !error_termination) begin
                    assert(req_cnt == pcie_bas_writedata[511:480]);
                    error_termination <= 1;
                end
            end
        end

        // TODO(sadok) check address
        // TODO(sadok) write to memory
        // TODO(sadok) set pcie_bas_waitrequest sometimes
    end

    if (stop_cnt != 0) begin
        stop_cnt <= stop_cnt - 1;
        if (stop_cnt == 1) begin
            stop <= 1;
        end
    end

    // if (!stop && !error_termination) begin
    //     $display("cnt: %d", cnt);
    //     $display("------------------------------------------------");
    // end
end


typedef enum{
    CONFIGURE_0,
    CONFIGURE_1,
    CONFIGURE_2,
    READ_MEMORY,
    READ_PCIE_START,
    READ_PCIE
} c_state_t;

c_state_t conf_state;

//Configure
//Read and display pkt/flow cnts
always @(posedge clk_status) begin
    status_read <= 0;
    status_write <= 0;
    status_writedata <= 0;
    if (rst) begin
        status_addr <= 0;
        conf_state <= CONFIGURE_0;
    end else begin
        case (conf_state)
            CONFIGURE_0: begin
                automatic logic [25:0] buf_size = RAM_BUF_SIZE;
                conf_state <= CONFIGURE_1;
                status_addr <= 30'h2A00_0000;
                status_write <= 1;

                `ifdef NO_PCIE
                    // pcie disabled
                    status_writedata <= {5'(nb_queues), buf_size, 1'b1};
                `else
                    // pcie enabled
                    status_writedata <= {5'(nb_queues), buf_size, 1'b0};
                `endif
            end
            CONFIGURE_1: begin
                conf_state <= CONFIGURE_2;
                status_addr <= 30'h2A00_0001;
                status_write <= 1;
                status_writedata <= {
                    30'(req_size), 1'(use_bram), 1'(write_pointer)
                };
            end
            CONFIGURE_2: begin
                // conf_state <= READ_MEMORY;
                conf_state <= READ_PCIE_START; // skipping READ_MEMORY
                status_addr <= 30'h2A00_0002;
                status_write <= 1;
                status_writedata <= 32'(target_nb_requests);
            end
            READ_MEMORY: begin
                if (stop || error_termination) begin
                    integer queue;
                    integer i;
                    integer j;
                    integer k;
                    for (queue = 0; queue < nb_queues; queue = queue + 1) begin
                        $display("Queue %d", queue);
                        // printing only the beginning of the RAM buffer,
                        // may print the entire thing instead:
                        for (i = 0; i < 25; i = i + 1) begin
                        // for (i = 0; i < RAM_BUF_SIZE; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                $write("%h:", i*64+j*8);
                                for (k = 0; k < 8; k = k + 1) begin
                                    $write(" %h", ram[queue][i][j*64+k*8 +: 8]);
                                end
                                $write("\n");
                            end
                        end
                    end
                    conf_state <= READ_PCIE_START;
                end
            end
            READ_PCIE_START: begin
                if (stop || error_termination) begin
                    status_read <= 1;
                    status_addr <= 30'h2A00_0000;
                    conf_state <= READ_PCIE;
                    $display("read_pcie:");
                end
            end
            READ_PCIE: begin
                if (status_readdata_valid) begin
                    $display("%d: 0x%8h", status_addr[6:0], status_readdata);

                    if (status_addr == (30'h2A00_0000 + 30'd3 + 30'd4 * nb_queues)) begin
                        $display("done");
                        $finish;
                    end else begin
                        status_addr <= status_addr + 1;
                        status_read <= 1;
                    end
                end
            end
        endcase
    end
end

assign pcie_bas_readdata = 0;
assign pcie_bas_readdatavalid = 0;
assign pcie_bas_response = 0;

assign pcie_rb_wr_data = 0;
assign pcie_rb_wr_addr = 0;
assign pcie_rb_wr_en = 0;
assign pcie_rb_update_valid = 0;
assign pcie_rb_update_size = 0;
assign pdumeta_cnt = 0;

pcie_top pcie (
    .pcie_clk               (clk),
    .pcie_reset_n           (!rst),
    .pcie_bas_waitrequest   (pcie_bas_waitrequest),
    .pcie_bas_address       (pcie_bas_address),
    .pcie_bas_byteenable    (pcie_bas_byteenable),
    .pcie_bas_read          (pcie_bas_read),
    .pcie_bas_readdata      (pcie_bas_readdata),
    .pcie_bas_readdatavalid (pcie_bas_readdatavalid),
    .pcie_bas_write         (pcie_bas_write),
    .pcie_bas_writedata     (pcie_bas_writedata),
    .pcie_bas_burstcount    (pcie_bas_burstcount),
    .pcie_bas_response      (pcie_bas_response),
    .pcie_address_0         (pcie_address_0),
    .pcie_write_0           (pcie_write_0),
    .pcie_read_0            (pcie_read_0),
    .pcie_readdatavalid_0   (pcie_readdatavalid_0),
    .pcie_readdata_0        (pcie_readdata_0),
    .pcie_writedata_0       (pcie_writedata_0),
    .pcie_byteenable_0      (pcie_byteenable_0),
    .pcie_rb_wr_data        (pcie_rb_wr_data),
    .pcie_rb_wr_addr        (pcie_rb_wr_addr),
    .pcie_rb_wr_en          (pcie_rb_wr_en),
    .pcie_rb_wr_base_addr   (pcie_rb_wr_base_addr),
    .pcie_rb_wr_base_addr_valid(pcie_rb_wr_base_addr_valid),
    .pcie_rb_almost_full    (pcie_rb_almost_full),
    .pcie_max_rb            (pcie_max_rb),
    .pcie_rb_update_valid   (pcie_rb_update_valid),
    .pcie_rb_update_size    (pcie_rb_update_size),
    .disable_pcie           (disable_pcie),
    .pdumeta_cpu_data       (pdumeta_cpu_data),
    .pdumeta_cpu_valid      (pdumeta_cpu_valid),
    .pdumeta_cnt            (pdumeta_cnt),
    .dma_queue_full_cnt     (dma_queue_full_cnt),
    .cpu_buf_full_cnt       (cpu_buf_full_cnt),
    .clk_status             (clk_status),
    .status_addr            (status_addr),
    .status_read            (status_read),
    .status_write           (status_write),
    .status_writedata       (status_writedata),
    .status_readdata        (status_readdata),
    .status_readdata_valid  (status_readdata_valid)
);

endmodule
