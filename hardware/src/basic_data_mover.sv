`include "./constants.sv"
module basic_data_mover (
    input  logic         clk,
    input  logic         rst,

    input  logic          meta_valid,
    input  var metadata_t meta_data,
    output logic          meta_ready,

    output logic [PKTBUF_AWIDTH-1:0] pkt_buffer_address,
    output logic                     pkt_buffer_read,
    input  logic                     pkt_buffer_readvalid,
    input  var flit_t                pkt_buffer_readdata,

    output logic [PKT_AWIDTH-1:0] emptylist_in_data,
    output logic                  emptylist_in_valid,
    input  logic                  emptylist_in_ready,

    // When set, routes all incoming packets back to Ethernet.
    input  logic disable_pcie,

    // RX packet data to PCIe.
    output logic         pcie_rx_pkt_sop,
    output logic         pcie_rx_pkt_eop,
    output logic         pcie_rx_pkt_valid,
    output logic [511:0] pcie_rx_pkt_data,
    output logic [5:0]   pcie_rx_pkt_empty,
    input  logic         pcie_rx_pkt_ready,
    input  logic         pcie_rx_pkt_almost_full,

    // RX metadata to PCIe.
    output logic          pcie_rx_meta_valid,
    output var metadata_t pcie_rx_meta_data,
    input  logic          pcie_rx_meta_ready,
    input  logic          pcie_rx_meta_almost_full,

    // TX packet data from PCIe.
    input  logic         pcie_tx_pkt_sop,
    input  logic         pcie_tx_pkt_eop,
    input  logic         pcie_tx_pkt_valid,
    input  logic [511:0] pcie_tx_pkt_data,
    input  logic [5:0]   pcie_tx_pkt_empty,
    output logic         pcie_tx_pkt_ready,

    output logic         eth_pkt_sop,
    output logic         eth_pkt_eop,
    output logic         eth_pkt_valid,
    output logic [511:0] eth_pkt_data,
    output logic [5:0]   eth_pkt_empty,
    input  logic         eth_pkt_ready,
    input  logic         eth_pkt_almost_full
);

`ifdef USE_BRAM
localparam NUM_PIPES = (2+2+2+1);
`else
// On-chip memory read latency is 12 cycles for eSRAM.
localparam NUM_PIPES = (2+2+12+1);
`endif

logic [PKT_AWIDTH-1:0] pktID;
logic [4:0] flits;

logic [4:0] flits_cnt;
logic [2:0] pkt_flags;
logic [2:0] pkt_flags_r;


logic first_ready;
logic middle_ready;
logic almost_full;

logic [15:0] statable_cnt;

typedef enum
{
    WAIT_STATABLE,
    INIT,
    IDLE,
    FIRST,
    MIDDLE
} state_t;

state_t state;

assign meta_ready =
    ((state == IDLE) || first_ready || middle_ready) && !almost_full;
assign first_ready =
    (state == FIRST) && ((pkt_flags == PKT_DROP) || (flits == 1));
assign middle_ready = (state == MIDDLE) && (flits_cnt == (flits - 1));
assign almost_full = pcie_rx_pkt_almost_full | pcie_rx_meta_almost_full;

// Quick and Dirty tweak for PDU flag.
always @(posedge clk) begin
    if (rst) begin
        pcie_rx_meta_valid <= 0;
    end else begin
        pcie_rx_meta_valid <= 0;
        if (meta_valid & meta_ready & (meta_data.pkt_flags == PKT_PCIE)
            & !disable_pcie)
        begin
            pcie_rx_meta_valid <= 1;
        end
    end
    pcie_rx_meta_data <= meta_data;
end

// Capture the meta_data.
always @(posedge clk) begin
    if (rst) begin
        pktID <= 0;
        flits <= 0;
        pkt_flags <= 0;
    end else begin
        if (meta_valid & meta_ready) begin
            pktID <= meta_data.pktID;
            flits <= meta_data.flits;
            if (disable_pcie && (meta_data.pkt_flags != PKT_DROP)) begin
                pkt_flags <= PKT_ETH;
            end else begin
                pkt_flags <= meta_data.pkt_flags;
            end
        end
    end
end

// Debug.
always @(posedge clk) begin
    if (!emptylist_in_ready & emptylist_in_valid) begin
        hterminate("PKT emptylist is full!");
    end
    `ifdef VERBOSE
    if (meta_valid & meta_ready) begin
        `hdisplay(("pkt:%d,length:%d,flag:%d",
            meta_data.pktID,meta_data.len,meta_data.pkt_flags));
    end
    `endif
end

// Read Logic.
always @(posedge clk) begin
    if (rst) begin
        flits_cnt <= 0;
        state <= WAIT_STATABLE;
        emptylist_in_data <= 0;
        emptylist_in_valid <= 0;
        statable_cnt <= 0;
        pkt_buffer_read <= 0;
    end else begin
        case (state)
            WAIT_STATABLE: begin
                statable_cnt <= statable_cnt + 1'b1;
                if (statable_cnt == 50) begin
                    state <= INIT;
                    emptylist_in_valid <= 1'b1;
                end
            end
            // Init the emptylist.
            INIT: begin
                if (emptylist_in_valid & emptylist_in_ready) begin
                    emptylist_in_data <= emptylist_in_data + 1'b1;
                    if (emptylist_in_data == PKT_NUM-1) begin
                        emptylist_in_valid <= 1'b0;
                        state <= IDLE;
                        `hdisplay(("Finish PKT emptylist init"));
                    end
                end
            end
            IDLE: begin
                // Clear.
                pkt_buffer_address <= 0;
                pkt_buffer_read <= 0;
                flits_cnt <= 0;
                emptylist_in_valid <= 1'b0;
                if (meta_valid & !almost_full) begin
                    state <= FIRST;
                end
            end
            FIRST:begin
                emptylist_in_valid <= 0;
                if (pkt_flags == PKT_DROP) begin
                    pkt_buffer_read <= 0;
                    emptylist_in_valid <= 1'b1;
                    emptylist_in_data <= pktID;
                    if (meta_valid & !almost_full) begin
                        state <= FIRST;
                    end else begin
                        state <= IDLE;
                    end
                end else begin
                    pkt_buffer_read <= 1;
                    pkt_buffer_address <= (pktID << 5);
                    // Last flit.
                    if (flits == 1) begin
                        emptylist_in_valid <= 1'b1;
                        emptylist_in_data <= pktID;
                        if (meta_valid & !almost_full) begin
                            state <= FIRST;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        state <= MIDDLE;
                        flits_cnt <= flits_cnt + 1'b1;
                    end
                end
            end
            MIDDLE:begin
                emptylist_in_valid <= 1'b0;
                // Last flit.
                if (flits_cnt == flits - 1) begin
                    pkt_buffer_address <= pkt_buffer_address + 1'b1;
                    flits_cnt <= 0;

                    emptylist_in_valid <= 1'b1;
                    emptylist_in_data <= pktID;

                    // Wait.
                    if (meta_valid & !almost_full) begin
                        state <= FIRST;
                    end else begin
                        state <= IDLE;
                    end
                end else begin
                    pkt_buffer_read <= 1;
                    pkt_buffer_address <= pkt_buffer_address + 1'b1;
                    flits_cnt <= flits_cnt + 1'b1;
                end
            end
        endcase
    end
end


// Write logic (no backpressure yet).
always @(posedge clk) begin
    if (rst) begin
        pcie_rx_pkt_valid <= 0;
    end else begin
        pcie_rx_pkt_data <= pkt_buffer_readdata.data;
        pcie_rx_pkt_sop <= 0;
        pcie_rx_pkt_eop <= 0;
        pcie_rx_pkt_empty <= 0;
        pcie_rx_pkt_valid <= 0;

        // TODO(sadok): Re-enable return path for incoming packets to Ethernet.
        // Right now Ethernet TX is being used exclusively for PCIe TX.
        // When re-enabling the return path, must make sure that
        // eth_pkt_almost_full is being considered in the `almost_full` signal.
        // eth_pkt_data <= pkt_buffer_readdata.data;
        // eth_pkt_sop <= 0;
        // eth_pkt_eop <= 0;
        // eth_pkt_empty <= 0;
        // eth_pkt_valid <= 0;

        if (pkt_buffer_readvalid) begin
            // Send check_pkt to data_fifo.
            if (pkt_flags_r == PKT_PCIE) begin
                pcie_rx_pkt_sop <= pkt_buffer_readdata.sop;
                pcie_rx_pkt_eop <= pkt_buffer_readdata.eop;
                pcie_rx_pkt_valid <= 1;
                pcie_rx_pkt_empty <= pkt_buffer_readdata.empty;
            end else begin
                // eth_pkt_sop <= pkt_buffer_readdata.sop;
                // eth_pkt_eop <= pkt_buffer_readdata.eop;
                // eth_pkt_valid <= 1;
                // eth_pkt_empty <= pkt_buffer_readdata.empty;
            end
        end
    end
end

always_comb begin
    eth_pkt_data = pcie_tx_pkt_data;
    eth_pkt_sop = pcie_tx_pkt_sop;
    eth_pkt_eop = pcie_tx_pkt_eop;
    eth_pkt_empty = pcie_tx_pkt_empty;
    eth_pkt_valid = pcie_tx_pkt_valid;
    pcie_tx_pkt_ready = eth_pkt_ready;
end

hyper_pipe #(
    .WIDTH (3),
    .NUM_PIPES(NUM_PIPES)
) hp_flags (
    .clk(clk),
    .din(pkt_flags),
    .dout(pkt_flags_r)
);

`ASSERT_CORRECT_PKT_STREAM(BasicDataMoverInRxPktStream, pkt_buffer_readdata.sop,
    pkt_buffer_readdata.eop, pkt_buffer_readvalid, pkt_buffer_readvalid, clk,
    rst)

`ASSERT_CORRECT_PKT_STREAM(BasicDataMoverOutRxPktStream, pcie_rx_pkt_sop,
    pcie_rx_pkt_eop, pcie_rx_pkt_valid, pcie_rx_pkt_ready, clk, rst)

`ASSERT_CORRECT_PKT_STREAM(BasicDataMoverInTxPktStream, pcie_tx_pkt_sop,
    pcie_tx_pkt_eop, pcie_tx_pkt_valid, pcie_tx_pkt_ready, clk, rst)

endmodule
