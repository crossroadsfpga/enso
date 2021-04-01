`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
`include "../src/pcie_top.sv"
`include "../src/fpga2cpu_pcie.sv"
module test_pcie_top;

`ifndef NB_DSC_QUEUES
`define NB_DSC_QUEUES 1
`endif

`ifndef NB_PKT_QUEUES
`define NB_PKT_QUEUES 1
`endif

generate
    // We assume this during the test, it does not necessarily hold in general.
    if (((`NB_PKT_QUEUES / `NB_DSC_QUEUES) * `NB_DSC_QUEUES) != `NB_PKT_QUEUES)
    begin
        $error("NB_PKT_QUEUES must be a multiple of NB_DSC_QUEUES");
    end
endgenerate

localparam pcie_period = 4;
localparam status_period = 10;
localparam nb_dsc_queues = `NB_DSC_QUEUES;
localparam nb_pkt_queues = `NB_PKT_QUEUES;
localparam pkt_per_dsc_queue = nb_pkt_queues / nb_dsc_queues;
localparam pkt_size = 64;
localparam req_size = pkt_size/4; // in dwords

// #cycles to wait before updating the head pointer for the packet queue
localparam update_head_delay = 64;

localparam target_nb_requests = 32;

// size of the host buffer used by each queue (in flits)
localparam DSC_BUF_SIZE = 8192;
localparam PKT_BUF_SIZE = 8192;
let max(a,b) = (a > b) ? a : b;
localparam RAM_SIZE = max(DSC_BUF_SIZE, PKT_BUF_SIZE);
localparam RAM_ADDR_LEN = $clog2(RAM_SIZE);

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

flit_lite_t            pcie_pkt_buf_wr_data;
logic                  pcie_pkt_buf_wr_en;
logic [F2C_RB_AWIDTH-1:0] pcie_pkt_buf_occup;

pkt_desc_t             pcie_desc_buf_wr_data;
logic                  pcie_desc_buf_wr_en;
logic [F2C_RB_AWIDTH-1:0] pcie_desc_buf_occup;

logic                  disable_pcie;
logic                  sw_reset;
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
logic [511:0] ram[nb_pkt_queues + nb_dsc_queues][RAM_SIZE];

logic [BRAM_TABLE_IDX_WIDTH-1:0] expected_pkt_queue;
logic [BRAM_TABLE_IDX_WIDTH-1:0] cfg_queue;
logic [nb_pkt_queues-1:0]        pending_pkt_tails_valid;
logic [31:0] pending_pkt_tails[nb_pkt_queues];
logic [31:0] last_upd_pkt_q;
logic [31:0] head_upd_delay_cnt;
logic [63:0] rx_cnt;
logic [63:0] req_cnt;
logic [63:0] start_wait;
logic        startup_ready;
logic [2:0]  burst_offset; // max of 8 flits per burst
logic [3:0]  burst_size;
logic [$clog2(MAX_PKT_SIZE)-1:0] pdu_flit_cnt;

initial cnt = 0;
initial clk = 0;
initial clk_status = 0;
initial rst = 1;
initial stop = 0;
initial error_termination = 0;

always #(pcie_period) clk = ~clk;
always #(status_period) clk_status = ~clk_status;

typedef enum
{
    SETUP_0,
    SETUP_1,
    WAIT,
    RUN
} control_state_t;

control_state_t control_state;

always @(posedge clk) begin
    cnt <= cnt + 1;

    pcie_write_0 = 0;
    pcie_read_0 <= 0;

    if (cnt < 10) begin // reset
        automatic integer c;
        rst <= 1;
        pcie_bas_waitrequest <= 0;
        pcie_address_0 <= 0;
        
        pcie_writedata_0 <= 0;
        pcie_byteenable_0 <= 0;
        rx_cnt <= 0;
        req_cnt <= 0;
        stop_cnt <= 0;
        pdu_flit_cnt <= 0;
        expected_pkt_queue <= 0;
        cfg_queue <= 0;
        start_wait <= 0;
        startup_ready <= 0;
        burst_offset <= 0;
        burst_size <= 0;

        control_state <= SETUP_0;

        last_upd_pkt_q <= 0;
        head_upd_delay_cnt <= 0;

        pending_pkt_tails_valid <= 0;

        for (c = 0; c < nb_pkt_queues; c++) begin
            pending_pkt_tails[c] <= 0;
        end
    end else begin
        case (control_state)
            SETUP_0: begin
                if (cnt == 10) begin
                    rst <= 0;
                end else begin
                    // set pkt queues
                    pcie_write_0 = 1;
                    pcie_address_0 <= cfg_queue << 12;
                    pcie_writedata_0 <= 0;
                    pcie_byteenable_0 <= 0;
                    
                    // pkt queue address
                    // note that we are placing queues 32 bit apart in the
                    // address space, this this is done to simplify the test and
                    // it is not a requirement
                    pcie_writedata_0[64 +: 64] <= 64'habcd000000000000 +
                        (cfg_queue << 32);
                    pcie_byteenable_0[8 +: 8] <= 8'hff;

                    if (cfg_queue == nb_pkt_queues - 1) begin
                        control_state <= SETUP_1;
                        cfg_queue <= 0;
                    end else begin
                        cfg_queue <= cfg_queue + 1;
                    end
                end
            end
            SETUP_1: begin
                // set dsc queues
                pcie_write_0 = 1;
                pcie_address_0 <= (cfg_queue + MAX_NB_FLOWS) << 12;
                pcie_writedata_0 <= 0;
                pcie_byteenable_0 <= 0;
                
                // dsc queue address
                // we place dsc queues after pkt queues in the address space but
                // this is done to simplify the test and it is not a requirement
                pcie_writedata_0[64 +: 64] <= 64'habcd000000000000 +
                    ((cfg_queue + nb_pkt_queues) << 32);
                pcie_byteenable_0[8 +: 8] <= 8'hff;

                if (cfg_queue == nb_dsc_queues - 1) begin
                    control_state <= WAIT;
                    cfg_queue <= 0;
                end else begin
                    cfg_queue <= cfg_queue + 1;
                end
            end
            WAIT: begin
                if (start_wait == 0) begin
                    start_wait <= cnt;
                end else if (cnt == start_wait + 10) begin
                    startup_ready <= 1;
                    control_state <= RUN;
                end
            end
            RUN: begin
                if (stop_cnt == 0 && req_cnt == target_nb_requests) begin
                    automatic integer i;
                    automatic logic all_ready = 1;
                    for (i = 0; i < nb_pkt_queues; i++) begin
                        // if (pending_pkt_tails[i] != 
                        //         target_nb_requests/nb_pkt_queues) begin
                        if (pending_pkt_tails_valid[i]) begin
                            all_ready = 0;
                            break;
                        end
                    end
                    if (all_ready) begin
                        stop_cnt <= 20;
                    end
                end

                if (pcie_bas_write) begin
                    automatic logic [31:0] cur_queue;
                    automatic logic [31:0] cur_address;

                    cur_queue = pcie_bas_address[32 +: BRAM_TABLE_IDX_WIDTH];

                    if (pcie_bas_burstcount != 0) begin
                        burst_offset = 0;
                        burst_size <= pcie_bas_burstcount;
                    end else if (burst_offset + 1 >= burst_size) begin
                        $error("Requests beyond burst size.");
                    end else begin
                        burst_offset = burst_offset + 1;
                    end

                    cur_address = pcie_bas_address[6 +: RAM_ADDR_LEN]
                                  + burst_offset;

                    if (cur_queue < nb_pkt_queues) begin // pkt queue
                        assert(cur_queue == expected_pkt_queue) else $fatal;

                        pdu_flit_cnt = pdu_flit_cnt + 1;

                        // check payload
                        assert(req_cnt == pcie_bas_writedata[511:480])
                            else $fatal;

                        // last packet flit
                        if (pdu_flit_cnt == (req_size + (16 - 1))/16) begin
                            req_cnt <= req_cnt + 1;
                            pdu_flit_cnt = 0;
                            if ((expected_pkt_queue + 1) < nb_pkt_queues) begin
                                expected_pkt_queue <= expected_pkt_queue + 1;
                            end else begin
                                expected_pkt_queue <= 0;
                            end
                        end
                    end else begin // dsc queue
                        automatic logic [31:0] pkt_per_dsc_queue;
                        automatic logic [31:0] expected_dsc_queue;
                        automatic pcie_pkt_desc_t pcie_pkt_desc;

                        // dsc queues can receive only one flit per burst
                        assert(pcie_bas_burstcount == 1) else $fatal;

                        pcie_pkt_desc = pcie_bas_writedata;

                        assert(pcie_pkt_desc.signal == 1) else $fatal;

                        // This is due to how we configured the queue addresses
                        // (dsc queues after pkt queues) as well as how we send
                        // packets (round robin among pkt queues).
                        pkt_per_dsc_queue = nb_pkt_queues / nb_dsc_queues;
                        expected_dsc_queue = nb_pkt_queues +
                            expected_pkt_queue / pkt_per_dsc_queue;

                        assert(cur_queue == expected_dsc_queue) else $fatal;

                        // update dsc queue here
                        pcie_write_0 = 1;
                        pcie_address_0 <= (
                            cur_queue - nb_pkt_queues + MAX_NB_FLOWS) << 12;
                        pcie_writedata_0 <= 0;
                        pcie_byteenable_0 <= 0;

                        pcie_writedata_0[32 +: 32] <= cur_address;
                        pcie_byteenable_0[4 +: 4] <= 4'hf;

                        // Shoud not receive a descriptor to the same queue
                        // before software advanced the head for this queue.
                        assert(pending_pkt_tails_valid[
                            pcie_pkt_desc.queue_id] == 0) else $fatal;

                        // save tail so we can advance the head later
                        pending_pkt_tails[pcie_pkt_desc.queue_id] <= pcie_pkt_desc.tail;
                        pending_pkt_tails_valid[pcie_pkt_desc.queue_id] <= 1'b1;
                    end 

                    $display("%d:%d+%d", cur_queue, 
                        pcie_bas_address[6 +: RAM_ADDR_LEN], burst_offset);

                    // check if address out of bound
                    if (cur_address > RAM_SIZE) begin
                        $error("Address out of bound");
                    end else begin
                        ram[cur_queue][cur_address] <= pcie_bas_writedata;
                    end

                    rx_cnt <= rx_cnt + 1;
                end

                if (head_upd_delay_cnt != 0) begin
                    head_upd_delay_cnt--;
                end

                // if not trying to write anything, we can try to advance one of
                // the head pointers
                if (pcie_write_0 == 0 && head_upd_delay_cnt == 0) begin
                    automatic integer i;
                    for (i = 0; i < nb_pkt_queues; i++) begin
                        automatic integer q = 
                            (i + last_upd_pkt_q) % nb_pkt_queues;
                        if (pending_pkt_tails_valid[q]) begin
                            pcie_write_0 = 1;
                            pcie_address_0 <= q << 12;
                            pcie_writedata_0 <= 0;
                            pcie_byteenable_0 <= 0;

                            pcie_writedata_0[32 +: 32] <= pending_pkt_tails[q];
                            pcie_byteenable_0[4 +: 4] <= 4'hf;

                            pending_pkt_tails_valid[q] <= 0;
                            
                            last_upd_pkt_q = q;
                            break;
                        end
                    end

                    if (last_upd_pkt_q == nb_pkt_queues - 1) begin
                        head_upd_delay_cnt <= update_head_delay;
                    end
                end
            end
        endcase
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

typedef enum
{
    GEN_START_WAIT,
    GEN_IDLE,
    GEN_DATA
} gen_state_t;

gen_state_t                gen_state;
logic [FLOW_IDX_WIDTH-1:0] pkt_queue_id;
logic [APP_IDX_WIDTH-1:0]  dsc_queue_id;
logic [31:0]               nb_requests;
logic [F2C_RB_AWIDTH-1:0]     flits_written;
logic [32:0]               transmit_cycles;

// Generate requests
always @(posedge clk) begin
    pcie_pkt_buf_wr_en <= 0;
    pcie_desc_buf_wr_en <= 0;
    if (rst) begin
        gen_state <= GEN_START_WAIT;
        flits_written <= 0;
        pkt_queue_id <= 0;
        dsc_queue_id <= 0;
        nb_requests <= 0;
        transmit_cycles <= 0;
    end else begin
        automatic logic can_insert_pkt = (pcie_pkt_buf_occup < (F2C_RB_DEPTH - 2))
            && (pcie_desc_buf_occup < (F2C_RB_DEPTH - 2));
        case (gen_state)
            GEN_START_WAIT: begin
                if (startup_ready) begin
                   gen_state <= GEN_IDLE; 
                end
            end
            GEN_IDLE: begin
                if (nb_requests < target_nb_requests) begin
                    pkt_queue_id <= 0;
                    dsc_queue_id <= 0;
                    flits_written <= 0;
                    gen_state <= GEN_DATA;
                end
            end
            GEN_DATA: begin
                if (can_insert_pkt) begin
                    pcie_pkt_buf_wr_en <= 1;
                    pcie_pkt_buf_wr_data.data <= {
                        nb_requests, 32'h00000000, 64'h0000babe0000face, 
                        64'h0000babe0000face, 64'h0000babe0000face,
                        64'h0000babe0000face, 64'h0000babe0000face, 
                        64'h0000babe0000face, 64'h0000babe0000face
                    };

                    flits_written <= flits_written + 1;

                    // first block
                    pcie_pkt_buf_wr_data.sop <= (flits_written == 0);

                    if ((flits_written + 1) * 16 >= req_size) begin
                        pcie_pkt_buf_wr_data.eop <= 1; // last block
                        nb_requests <= nb_requests + 1;
                        flits_written <= 0;

                        // write descriptor
                        pcie_desc_buf_wr_en <= 1;
                        pcie_desc_buf_wr_data.dsc_queue_id <= dsc_queue_id;
                        pcie_desc_buf_wr_data.pkt_queue_id <= pkt_queue_id;
                        pcie_desc_buf_wr_data.size <= (req_size + (16 - 1))/16;

                        if (nb_requests + 1 == target_nb_requests) begin
                            gen_state <= GEN_IDLE;
                        end else begin
                            if ((pkt_queue_id + 1) == nb_pkt_queues) begin
                                pkt_queue_id = 0;
                            end else begin
                                pkt_queue_id = pkt_queue_id + 1;
                            end

                            dsc_queue_id = pkt_queue_id / pkt_per_dsc_queue;
                        end
                    end else begin
                        pcie_pkt_buf_wr_data.eop <= 0;
                    end
                end
            end
            default: gen_state <= GEN_IDLE;
        endcase

        // count cycles until we go back to the IDLE state and there are no more
        // pending packets in the ring buffer
        if (gen_state != GEN_IDLE || pcie_pkt_buf_occup != 0) begin
            transmit_cycles <= transmit_cycles + 1;
        end
    end
end

typedef enum{
    CONFIGURE_0,
    CONFIGURE_1,
    READ_MEMORY,
    READ_PCIE_START,
    READ_PCIE_PKT_Q,
    READ_PCIE_DSC_Q,
    ZERO_PCIE
} c_state_t;

c_state_t conf_state;

logic [31:0] read_pcie_cnt;

//Configure
//Read and display pkt/flow cnts
always @(posedge clk_status) begin
    status_read <= 0;
    status_write <= 0;
    status_writedata <= 0;
    if (rst) begin
        status_addr <= 0;
        read_pcie_cnt <= 0;
        conf_state <= CONFIGURE_0;
    end else begin
        case (conf_state)
            CONFIGURE_0: begin
                automatic logic [25:0] pkt_buf_size = PKT_BUF_SIZE;
                status_addr <= 30'h2A00_0000;
                status_write <= 1;

                `ifdef NO_PCIE
                    // pcie disabled
                    status_writedata <= {5'b00000, pkt_buf_size, 1'b1};
                `else
                    // pcie enabled
                    status_writedata <= {5'b00000, pkt_buf_size, 1'b0};
                `endif
                conf_state <= CONFIGURE_1;
            end
            CONFIGURE_1: begin
                automatic logic [25:0] dsc_buf_size = DSC_BUF_SIZE;
                status_addr <= 30'h2A00_0001;
                status_write <= 1;
                
                status_writedata <= {6'h0, dsc_buf_size};
                conf_state <= READ_MEMORY;
            end
            READ_MEMORY: begin
                if (stop || error_termination) begin
                    automatic integer q;
                    automatic integer pkt_q;
                    automatic integer i;
                    automatic integer j;
                    automatic integer k;

                    for (q = 0; q < nb_dsc_queues; q = q + 1) begin
                        $display("Queue %d", q);
                        // printing only the beginning of each buffer,
                        // may print the entire thing instead
                        $display("Descriptor queue:");
                        for (i = 0; i < 25; i = i + 1) begin
                        // for (i = 0; i < RAM_SIZE; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                $write("%h:", i*64+j*8);
                                for (k = 0; k < 8; k = k + 1) begin
                                    $write(" %h",
                                        ram[q+nb_pkt_queues][i][j*64+k*8 +: 8]);
                                end
                                $write("\n");
                            end
                        end

                        $display("Packet queues:");
                        for (pkt_q = q*pkt_per_dsc_queue;
                            pkt_q < (q+1)*pkt_per_dsc_queue; pkt_q = pkt_q + 1)
                        begin
                            $display("Packet queue: %d", pkt_q);
                            for (i = 0; i < 25; i = i + 1) begin
                                for (j = 0; j < 8; j = j + 1) begin
                                    $write("%h:", i*64+j*8);
                                    for (k = 0; k < 8; k = k + 1) begin
                                        $write(" %h",
                                            ram[pkt_q][i][j*64+k*8 +: 8]);
                                    end
                                    $write("\n");
                                end
                            end
                        end
                    end
                    conf_state <= READ_PCIE_START;
                end
            end
            READ_PCIE_START: begin
                if (stop || error_termination) begin
                    $display("transmit_cycles: %d", transmit_cycles);
                    status_read <= 1;
                    status_addr <= 30'h2A00_0000;
                    conf_state <= READ_PCIE_PKT_Q;
                    $display("read_pcie:");
                    $display("status + pkt queues:");
                end
            end
            READ_PCIE_PKT_Q: begin
                if (status_readdata_valid) begin
                    $display("%d: 0x%8h", status_addr[15:0], status_readdata);
                    status_addr = status_addr + 1;
                    status_read <= 1;
                    if (status_addr == (
                            30'h2A00_0000 + 30'd4 * nb_pkt_queues + 30'd2)) begin
                        status_addr <= 
                            30'h2A00_0000 + 30'd4 * MAX_NB_FLOWS + 30'd2;
                        status_writedata <= 0;
                        conf_state <= READ_PCIE_DSC_Q;
                        $display("dsc queues:");
                    end
                end
            end
            READ_PCIE_DSC_Q: begin
                if (status_readdata_valid) begin
                    $display("%d: 0x%8h", status_addr[15:0], status_readdata);
                    status_addr = status_addr + 1;
                    if (status_addr == (
                            30'h2A00_0000 + 30'd4 * MAX_NB_FLOWS 
                            + 30'd4 * nb_pkt_queues + 30'd2)) begin
                        read_pcie_cnt <= read_pcie_cnt + 1;
                        if (read_pcie_cnt == 1) begin
                            $display("done");
                            $finish;
                        end else begin
                            status_addr = 30'h2A00_0000;
                            status_write <= 1;
                            status_writedata <= 0;
                            conf_state <= ZERO_PCIE;
                        end
                    end else begin
                        status_read <= 1;
                    end
                end
            end
            ZERO_PCIE: begin
                if (status_addr == (
                        30'h2A00_0000 + 30'd4 * (MAX_NB_FLOWS + MAX_NB_APPS)
                        + 30'd2)) begin
                    conf_state <= READ_PCIE_START;
                    $display("After zeroing PCIe:");
                end else begin
                    status_write <= 1;
                    status_writedata <= 0;
                    status_addr <= status_addr + 1;
                end
            end
        endcase
    end
end

assign pcie_bas_readdata = 0;
assign pcie_bas_readdatavalid = 0;
assign pcie_bas_response = 0;

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
    .pcie_pkt_buf_wr_data   (pcie_pkt_buf_wr_data),
    .pcie_pkt_buf_wr_en     (pcie_pkt_buf_wr_en),
    .pcie_pkt_buf_occup     (pcie_pkt_buf_occup),
    .pcie_desc_buf_wr_data  (pcie_desc_buf_wr_data),
    .pcie_desc_buf_wr_en    (pcie_desc_buf_wr_en),
    .pcie_desc_buf_occup    (pcie_desc_buf_occup),
    .disable_pcie           (disable_pcie),
    .sw_reset               (sw_reset),
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
