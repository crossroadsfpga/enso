
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
    // input  logic                     frb_read,

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
logic [31:0] last_target_nb_requests;

logic [RB_AWIDTH-1:0] new_tail;

logic [31-RB_AWIDTH:0] tail_padding; // 4 is for 16 DWORD

logic wrdm_desc_ready_r1;
logic wrdm_desc_ready_r2;

logic [31:0] nb_requests;

typedef enum
{
    IDLE,
    START_BURST,
    COMPLETE_BURST,
    DONE
} state_t;

state_t state;

logic [63:0] page_offset;

assign wr_base_addr = 0;
assign wr_base_addr_valid = 0;
assign almost_full = 0;

// CPU side addr
assign cpu_data_addr = kmem_addr + 64; // the global reg

flit_lite_t            intern_wr_data;
logic                  intern_wr_en;

flit_lite_t            intern_rd_data;
logic                  intern_rd_en;

logic [PDU_AWIDTH-1:0] occup;

logic dma_ctrl_ready;
logic desc_valid;
logic ready_for_new_transfers;

logic [31:0] nb_flits;
logic [31:0] missing_flits;
logic [3:0] missing_flits_in_transfer;
logic hold_queue_ready;

assign new_tail = (tail + nb_flits >= rb_size) ? 
                        (tail + nb_flits - rb_size) :
                        (tail + nb_flits);

assign pcie_bas_read = 0;

logic [63:0] queue_id;

// FSM
always @(posedge clk) begin
    desc_valid <= 0;
    dma_done <= 0;
    dma_start <= 0;
    intern_rd_en <= 0;
    if (rst) begin
        state <= IDLE;
        out_tail <= 0;
        dma_queue_full_cnt <= 0;
        cpu_buf_full_cnt <= 0;
        page_offset <= 0;
        missing_flits <= 0;
        missing_flits_in_transfer <= 0;
        dma_queue <= 0;
        nb_flits <= 0;
        queue_id <= 0;
        hold_queue_ready <= 0;
        pcie_bas_write <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (occup > 0) begin
                    automatic pdu_hdr_t hdr = intern_rd_data.data;
                    assert(intern_rd_data.sop);
                    missing_flits <= hdr.pdu_flit;
                    nb_flits <= hdr.pdu_flit;
                    dma_queue <= hdr.queue_id;
                    page_offset <= queue_id * 4096; // TODO adjust to reflect actual host rb size
                    intern_rd_en <= 1;
                    hold_queue_ready <= 0;
                    dma_start <= 1;

                    state <= START_BURST;
                end

                // a pending DMA may have been completed, zero signals
                if (!pcie_bas_waitrequest) begin
                    pcie_bas_address <= 0;
                    pcie_bas_byteenable <= 0;
                    pcie_bas_writedata <= 0;
                    pcie_bas_write <= 0;
                    pcie_bas_burstcount <= 0;
                end
            end
            START_BURST: begin
                // We may set the writing signals even when pcie_bas_waitrequest
                // is set, but we must make sure that they remain active until
                // pcie_bas_waitrequest is unset. So we are checking this signal
                // not to ensure that we are able to write but instead to make
                // sure that any write request in the previous cycle is complete
                if (!pcie_bas_waitrequest && 
                        (queue_ready || hold_queue_ready)) begin
                    automatic logic [3:0] flits_in_transfer;
                    automatic logic [63:0] req_offset = (
                        nb_flits - missing_flits) * 64;
                    hold_queue_ready <= 1;

                    // max 8 flits per burst
                    if (missing_flits > 8) begin
                        flits_in_transfer = 8;
                    end else begin
                        flits_in_transfer = missing_flits;
                    end

                    pcie_bas_address <= cpu_data_addr + page_offset + req_offset;
                    pcie_bas_byteenable <= 64'hffffffffffffffff;
                    pcie_bas_writedata <= intern_rd_data.data;
                    intern_rd_en <= 1;
                    pcie_bas_write <= 1;
                    pcie_bas_burstcount <= flits_in_transfer; // number of flits in this transfer (max 8)

                    if (missing_flits > 1) begin
                        state <= COMPLETE_BURST;
                        missing_flits <= missing_flits - 1;
                        missing_flits_in_transfer <= flits_in_transfer - 1;
                    end else begin
                        // pcie_bas_byteenable <= ; // TODO(sadok) handle unaligned cases here
                        state <= DONE;
                        assert(intern_rd_data.eop);
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
                    pcie_bas_writedata <= intern_rd_data.data;
                    intern_rd_en <= 1;
                    pcie_bas_write <= 1;
                    pcie_bas_burstcount <= 0;

                    if (missing_flits_in_transfer == 1) begin
                        if (missing_flits > 1) begin
                            state <= START_BURST;
                        end else begin
                            // pcie_bas_byteenable <= ; // TODO(sadok) handle unaligned cases here
                            state <= DONE;
                            assert(intern_rd_data.eop);
                        end
                    end
                end else begin
                    dma_queue_full_cnt <= dma_queue_full_cnt + 1;
                end
            end
            DONE: begin
                if (!pcie_bas_waitrequest) begin // done with previous transfer
                    if (write_pointer) begin
                        //
                        // Send done descriptor
                        //
                        pcie_bas_address <= kmem_addr + page_offset;
                        pcie_bas_byteenable <= 64'h000000000000000f;
                        pcie_bas_writedata <= {480'h0, tail}; // TODO(sadok) make sure tail is being written to the right location
                        pcie_bas_write <= 1;
                        pcie_bas_burstcount <= 1;
                    end else begin
                        pcie_bas_address <= 0;
                        pcie_bas_byteenable <= 0;
                        pcie_bas_writedata <= 0;
                        pcie_bas_write <= 0;
                        pcie_bas_burstcount <= 0;
                    end

                    // update tail
                    out_tail <= new_tail;
                    dma_done <= 1;

                    state <= IDLE;
                end else begin
                    dma_queue_full_cnt <= dma_queue_full_cnt + 1;
                end
            end
            default: state <= IDLE;
        endcase
    end
end

always @(posedge clk) begin
    if (rst) begin
        max_rb <= 0;
    end else begin
        if (occup > max_rb) begin
            max_rb <= occup;
        end
    end
end

logic [PDU_AWIDTH-1:0] flits_written;
pdu_hdr_t pdu_hdr;

typedef enum
{
    GEN_IDLE,
    GEN_DESC,
    GEN_DONE
} gen_state_t;

gen_state_t gen_state;

assign pdu_hdr.padding = 0;
assign pdu_hdr.queue_id = queue_id;
assign pdu_hdr.action = 0;
assign pdu_hdr.pdu_flit = (req_size + (16 - 1))/16;
assign pdu_hdr.pdu_size = req_size * 4;
assign pdu_hdr.prot = 0;
assign pdu_hdr.tuple = 0;
assign pdu_hdr.pdu_id = nb_requests;

always @(posedge clk) begin
    intern_wr_en <= 0;
    intern_wr_data <= 0;
    last_target_nb_requests <= target_nb_requests;
    if (rst) begin
        gen_state <= GEN_IDLE;
        flits_written <= 0;
        queue_id <= 0;
        nb_requests <= 0;
        transmit_cycles <= 0;
        last_target_nb_requests <= 0;
    end else begin
        case (gen_state)
            GEN_IDLE: begin
                if (nb_requests < target_nb_requests) begin
                    gen_state <= GEN_DESC;
                end
            end
            GEN_DESC: begin
                if (occup < (PDU_DEPTH - 2)) begin
                    intern_wr_en <= 1;
                    intern_wr_data.sop <= 0;
                    intern_wr_data.data <= {
                        nb_requests, 32'h00000000, 64'h0000babe0000face, 
                        64'h0000babe0000face, 64'h0000babe0000face,
                        64'h0000babe0000face, 64'h0000babe0000face, 
                        64'h0000babe0000face, 64'h0000babe0000face
                    };

                    flits_written <= flits_written + 1;

                    if ((flits_written + 1) * 16 >= req_size) begin
                        gen_state <= GEN_DONE;
                        intern_wr_data.eop <= 1; // last block
                    end else begin
                        intern_wr_data.eop <= 0;
                    end
                end
            end
            GEN_DONE: begin
                // write PDU header
                if (occup < (PDU_DEPTH - 2)) begin
                    intern_wr_en <= 1;
                    intern_wr_data.sop <= 1;
                    intern_wr_data.data <= pdu_hdr;
                    intern_wr_data.eop <= 0;
                    flits_written <= 0;
                    nb_requests <= nb_requests + 1;
                    if (((queue_id + 1) * 4096 + req_size * 4) > (rb_size * 64)) begin
                        queue_id <= 0;
                    end else begin
                        queue_id <= queue_id + 1;
                    end
                    if (nb_requests + 1 == target_nb_requests) begin
                        gen_state <= GEN_IDLE;
                    end else begin
                        gen_state <= GEN_DESC;
                    end
                end
            end
            default: gen_state <= GEN_IDLE;
        endcase

        // count cycles until we go back to the IDLE state and there are no more
        // pending packets in the ring buffer
        if (gen_state != GEN_IDLE || occup != 0) begin
            transmit_cycles <= transmit_cycles + 1;
        end

        if (target_nb_requests != last_target_nb_requests) begin
            nb_requests <= 0;
            transmit_cycles <= 0;
        end
    end
end

prefetch_rb #(
    .DEPTH(PDU_DEPTH),
    .AWIDTH(PDU_AWIDTH),
    .DWIDTH($bits(flit_lite_t))
)
prefetch_rb_inst (
    .clk     (clk),
    .rst     (rst),
    .wr_data (intern_wr_data),
    .wr_en   (intern_wr_en),
    .rd_data (intern_rd_data),
    .rd_en   (intern_rd_en),
    .occup   (occup)
);
endmodule
