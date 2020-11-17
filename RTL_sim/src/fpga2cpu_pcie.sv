
`include "./my_struct_s.sv"

module fpga2cpu_pcie (
    input clk,
    input rst,

    // write to FPGA ring buffer.
    input  flit_lite_t               wr_data,
    input  logic [PDU_AWIDTH-1:0]    wr_addr,
    input  logic                     wr_en,
    output logic [PDU_AWIDTH-1:0]    wr_base_addr,
    output logic                     wr_base_addr_valid,
    output logic                     almost_full,
    output logic [31:0]              max_rb,
    input  logic                     update_valid,
    input  logic [PDU_AWIDTH-1:0]    update_size,

    // CPU ring buffer signals
    input  logic [RB_AWIDTH-1:0]     head,
    input  logic [RB_AWIDTH-1:0]     tail,
    input  logic [63:0]              kmem_addr,
    input  logic                     queue_ready,
    output logic [RB_AWIDTH-1:0]     out_tail,
    output logic                     dma_done,
    output logic [APP_IDX_WIDTH-1:0] dma_queue,
    output logic                     dma_start,
    input  logic [30:0]              rb_size,

    // PCIe BAS
    input  logic                       pcie_bas_waitrequest,
    output logic [63:0]                pcie_bas_address,
    output logic [63:0]                pcie_bas_byteenable,
    output logic                       pcie_bas_read,
    input  logic [511:0]               pcie_bas_readdata,
    input  logic                       pcie_bas_readdatavalid,
    output logic                       pcie_bas_write,
    output logic [511:0]               pcie_bas_writedata,
    output logic [3:0]                 pcie_bas_burstcount,
    input  logic [1:0]                 pcie_bas_response,

    // Write to Write data mover
    // input  logic                     wrdm_desc_ready,
    // output logic                     wrdm_desc_valid,
    // output logic [173:0]             wrdm_desc_data,

    // Write-data-mover read data
    // output logic [511:0]             frb_readdata,
    // output logic                     frb_readvalid,
    // input  logic [PDU_AWIDTH-1:0]    frb_address,
    input  logic                     frb_read,

    // counters
    output logic [31:0]              dma_queue_full_cnt,
    output logic [31:0]              cpu_buf_full_cnt,

    // pcie profile
    input logic                      write_pointer,
    input logic                      use_bram,
    input logic  [31:0]              target_nb_requests,
    input logic  [31:0]              req_size,  // in dwords
    output logic [31:0]              transmit_cycles
);

localparam EP_BASE_ADDR = 32'h0004_0000;
localparam DONE_ID = 8'hFE;

pcie_desc_t data_desc;
pcie_desc_t data_desc_low;
pcie_desc_t data_desc_high;
pcie_desc_t done_desc;
logic [63:0] cpu_data_addr;
logic [63:0] cpu_data_addr_low;
logic [63:0] cpu_data_addr_high;
logic [31:0] ep_data_addr_high;
logic [31:0] data_base_addr;
logic [31:0] last_target_nb_requests;

// logic [511:0]          my_wr_data;
// logic [PDU_AWIDTH-1:0] my_wr_addr;
// logic                  my_wr_en;

logic wrdm_desc_ready_r1;
logic wrdm_desc_ready_r2;

logic [31:0] nb_requests;

typedef enum
{
    IDLE,
    START_BURST,
    COMPLETE_BURST,
    DONE,
    WAIT_DONE
} state_t;

state_t state;

logic [PDU_AWIDTH-1:0]  dma_base_addr;

logic [63:0] page_offset;

assign dma_base_addr = 0;
assign wr_base_addr = 0;
assign wr_base_addr_valid = 0;
assign almost_full = 0;
assign max_rb = 0;
assign dma_start = 0;
assign dma_queue = 0;

// CPU side addr
assign cpu_data_addr = kmem_addr + 64; // the global reg

// The base addr of fpga side ring buffer. BRAM starts with an offset
assign data_base_addr = EP_BASE_ADDR + (RB_BRAM_OFFSET + dma_base_addr) << 6;

// assign done_desc = '{
//     func_nb: 0,
//     desc_id: DONE_ID,
//     app_spec: 0,
//     reserved: 0,
//     single_src: 0,
//     immediate: 1,
//     nb_dwords: 18'd1,
//     dst_addr: kmem_addr + page_offset,
//     saddr_data: {32'h0, nb_requests} // data
// };

// assign data_desc = '{
//     func_nb: 0,
//     desc_id: 0,
//     app_spec: 0,
//     reserved: 0,
//     single_src: 0,
//     immediate: 0,
//     nb_dwords: {req_size},
//     dst_addr: cpu_data_addr + page_offset,
//     saddr_data: {32'h0, data_base_addr}
// };

// always @ (posedge clk) begin
//     // wrdm_desc_ready has a 3-cycle latency, wrdm_desc_ready_r2 is active, we
//     // can write in the following cycle
//     wrdm_desc_ready_r1 <= wrdm_desc_ready;
//     wrdm_desc_ready_r2 <= wrdm_desc_ready_r1 && wrdm_desc_ready;
// end

logic dma_ctrl_ready;
logic desc_valid;
logic ready_for_new_transfers;
logic pending_transfer;

// wrdm_desc_ready has a 3-cycle latency. If wrdm_desc_ready_r2 is active, we
// can write in the following cycle
// assign dma_ctrl_ready = wrdm_desc_ready && wrdm_desc_ready_r2;

// We are not allowed to set wrdm_desc_valid when wrdm_desc_ready is not set.
// This creates the possibility that wrdm_desc_ready becomes 0 at the same time
// as we initiate a transfer. To make sure this never happens we do this
// assignment combinationally. This also means that if we start a write
// (desc_valid=1) and wrdm_desc_ready becomes 0 at the same time, we must hold
// back new transfers and retry sending once it becomes available again
// assign wrdm_desc_valid = desc_valid & wrdm_desc_ready;

// we are only ready for new transfers if we are ready to write and there is no
// pending transfer
// assign ready_for_new_transfers = dma_ctrl_ready && !pending_transfer;


logic [31:0] nb_flits;
logic [31:0] missing_flits;
logic [3:0] missing_flits_in_transfer;

assign nb_flits = (req_size + 15) / 16;

assign pcie_bas_read = 0;

// FSM
always @ (posedge clk) begin
    desc_valid <= 0;
    dma_done <= 0;
    // my_wr_data <= 0;
    // my_wr_en <= 0;
    // my_wr_addr <= 0;
    last_target_nb_requests <= target_nb_requests;
    if (rst) begin
        state <= IDLE;
        out_tail <= 0;
        dma_queue_full_cnt <= 0;
        cpu_buf_full_cnt <= 0;
        pending_transfer <= 0;
        nb_requests <= 0;
        transmit_cycles <= 0;
        page_offset <= 0;
        last_target_nb_requests <= 0;
        missing_flits <= 0;
        missing_flits_in_transfer <= 0;
        
        // bas
        pcie_bas_write <= 0;

        // my_wr_data <= {
        //     64'h0000babe0000face, 64'h0000babe0000face, 
        //     64'h0000babe0000face, 64'h0000babe0000face,
        //     64'h0000babe0000face, 64'h0000babe0000face, 
        //     64'h0000babe0000face, 64'h0000babe0000face
        // };
        // my_wr_en <= 1;
        // my_wr_addr <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (nb_requests < target_nb_requests) begin
                    state <= START_BURST;
                    missing_flits <= nb_flits;
                end
            end
            START_BURST: begin
                // We may set the writing signals even when pcie_bas_waitrequest
                // is set, but we must make sure that they remain active until
                // pcie_bas_waitrequest is unset. So we are checking this signal
                // not to ensure that we are able to write but instead to make
                // sure that any write request in the previous cycle is complete
                if (!pcie_bas_waitrequest) begin
                    logic [3:0] flits_in_transfer;
                    logic [63:0] req_offset = (nb_flits - missing_flits) * 64;

                    // max 8 flits per burst
                    if (missing_flits > 8) begin
                        flits_in_transfer = 8;
                    end else begin
                        flits_in_transfer = missing_flits;
                    end

                    pcie_bas_address <= cpu_data_addr + page_offset + req_offset;
                    pcie_bas_byteenable <= 64'hffffffffffffffff;
                    pcie_bas_writedata <= {
                        missing_flits, 32'hbeef0000, 64'hdead0000beef0000, 
                        64'hdead0000beef0000, 64'hdead0000beef0000,
                        64'hdead0000beef0000, 64'hdead0000beef0000, 
                        64'hdead0000beef0000, 64'hdead0000beef0000
                    };
                    pcie_bas_write <= 1;
                    pcie_bas_burstcount <= flits_in_transfer; // number of flits in this transfer (max 8)

                    if (missing_flits > 1) begin
                        state <= COMPLETE_BURST;
                        missing_flits <= missing_flits - 1;
                        missing_flits_in_transfer <= flits_in_transfer - 1;
                    end else begin
                        // pcie_bas_byteenable <= ; // TODO(sadok) handle unaligned cases here
                        state <= DONE;
                    end
                end else begin
                    dma_queue_full_cnt <= dma_queue_full_cnt + 1;
                end
            end
            COMPLETE_BURST: begin
                if (!pcie_bas_waitrequest) begin // done with previous transfer
                    missing_flits <= missing_flits - 1;
                    missing_flits_in_transfer <= missing_flits_in_transfer - 1;

                    // subsequent bursts from the same transfer do not need to
                    // set the address
                    pcie_bas_address <= 0;
                    pcie_bas_byteenable <= 64'hffffffffffffffff;
                    pcie_bas_writedata <= {
                        missing_flits, 32'hbeef0000, 64'hdead0000beef0000, 
                        64'hdead0000beef0000, 64'hdead0000beef0000,
                        64'hdead0000beef0000, 64'hdead0000beef0000, 
                        64'hdead0000beef0000, 64'hdead0000beef0000
                    };
                    pcie_bas_write <= 1;
                    pcie_bas_burstcount <= 0;

                    if (missing_flits_in_transfer == 1) begin
                        if (missing_flits > 1) begin
                            state <= START_BURST;
                        end else begin
                            // pcie_bas_byteenable <= ; // TODO(sadok) handle unaligned cases here
                            state <= DONE;
                        end
                    end
                end else begin
                    dma_queue_full_cnt <= dma_queue_full_cnt + 1;
                end
            end
            DONE: begin
                if (!pcie_bas_waitrequest) begin // done with previous transfer
                    nb_requests <= nb_requests + 1;

                    if ((page_offset + 4096 + req_size * 4) > (rb_size * 64)) begin
                        page_offset <= 0;
                    end else begin
                        page_offset <= page_offset + 4096;
                    end

                    if (write_pointer) begin
                        //
                        // Send done descriptor
                        //
                        pcie_bas_address <= kmem_addr + page_offset;
                        pcie_bas_byteenable <= 64'h000000000000000f;
                        pcie_bas_writedata <= {480'h0, nb_requests}; // data
                        pcie_bas_write <= 1;
                        pcie_bas_burstcount <= 1;
                    end else begin
                        pcie_bas_address <= 0;
                        pcie_bas_byteenable <= 0;
                        pcie_bas_writedata <= 0;
                        pcie_bas_write <= 0;
                        pcie_bas_burstcount <= 0;
                    end

                    if ((nb_requests + 1) == target_nb_requests) begin
                        state <= WAIT_DONE;
                    end else begin
                        missing_flits <= nb_flits;
                        state <= START_BURST;
                    end
                end else begin
                    dma_queue_full_cnt <= dma_queue_full_cnt + 1;
                end
            end
            WAIT_DONE: begin
                // wait for previous requests to complete
                if (!pcie_bas_waitrequest) begin
                    pcie_bas_address <= 0;
                    pcie_bas_byteenable <= 0;
                    pcie_bas_writedata <= 0;
                    pcie_bas_write <= 0;
                    pcie_bas_burstcount <= 0;
                    state <= IDLE;
                end else begin
                    dma_queue_full_cnt <= dma_queue_full_cnt + 1;
                end
            end
            default: state <= IDLE;
        endcase

        // if (desc_valid && !wrdm_desc_ready) begin
        //     // DMA desc became unavailable while trying to write
        //     pending_transfer <= 1;
        // end

        // // retry sending pending transfer, wrdm_desc_data should be already set
        // // to the right value
        // if (dma_ctrl_ready && pending_transfer) begin
        //     desc_valid <= 1;
        //     pending_transfer <= 0;
        // end

        if (state != IDLE) begin
            transmit_cycles <= transmit_cycles + 1;
        end

        if (target_nb_requests != last_target_nb_requests) begin
            nb_requests <= 0;
            page_offset <= 0;
            transmit_cycles <= 0;
        end
    end
end

logic frb_read_r;
logic [511:0] bram_data_out;

// always @(posedge clk) begin
//     if (use_bram) begin
//         frb_read_r <= frb_read;
//         frb_readvalid <= frb_read_r;
//     end else begin
//         frb_readvalid <= frb_read;
//     end
// end

// always_comb begin
//     if (use_bram) begin
//         frb_readdata <= bram_data_out;
//     end else begin
//         frb_readdata <= {
//             64'hdead0000beef0000, 64'hdead0000beef0000, 
//             64'hdead0000beef0000, 64'hdead0000beef0000,
//             64'hdead0000beef0000, 64'hdead0000beef0000, 
//             64'hdead0000beef0000, 64'hdead0000beef0000
//         };
//     end
// end

// bram_simple2port #(
//     .AWIDTH(PDU_AWIDTH),
//     .DWIDTH(512),
//     .DEPTH(PDU_DEPTH)
// )
// pdu_buffer (
//     .clock      (clk),
//     .data       (my_wr_data),
//     .rdaddress  (frb_address), // MISSING!!!!
//     .rden       (frb_read),    // MISSING!!!!
//     .wraddress  (my_wr_addr),
//     .wren       (my_wr_en),
//     .q          (bram_data_out)
// );
endmodule
