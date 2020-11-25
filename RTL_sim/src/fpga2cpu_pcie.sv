
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
    input  logic [RB_AWIDTH-1:0]     in_head,
    input  logic [RB_AWIDTH-1:0]     in_tail,
    input  logic [63:0]              in_kmem_addr,
    output logic [APP_IDX_WIDTH-1:0] rd_queue,
    input  logic                     queue_ready,
    output logic [RB_AWIDTH-1:0]     out_tail,
    output logic [APP_IDX_WIDTH-1:0] wr_queue,
    output logic                     queue_rd_en,
    output logic                     tail_wr_en,
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

assign wr_base_addr = 0;
assign wr_base_addr_valid = 0;
assign almost_full = 0;
assign pcie_bas_read = 0;

flit_lite_t            pkt_buf_wr_data;
logic                  pkt_buf_wr_en;
flit_lite_t            pkt_buf_rd_data;
logic                  pkt_buf_rd_en;
logic [PDU_AWIDTH-1:0] pkt_buf_occup;

typedef struct packed {
    logic [APP_IDX_WIDTH-1:0] queue_id;
    logic [16:0] size; // in number of flits TODO(sadok) this is much bigger
                       // than the MTU, consider using the expression below:
    // logic [$clog2(MAX_PKT_SIZE)-1:0] size; // in number of flits
} pkt_desc_t;

pkt_desc_t             desc_buf_wr_data;
logic                  desc_buf_wr_en;
pkt_desc_t             desc_buf_rd_data;
logic                  desc_buf_rd_en;
logic [PDU_AWIDTH-1:0] desc_buf_occup;

pkt_desc_t            cur_desc;
logic [RB_AWIDTH-1:0] cur_head;
logic [RB_AWIDTH-1:0] cur_tail;
logic [63:0]          cur_kmem_addr;
logic                 cur_desc_valid;

pkt_desc_t            pref_desc;
logic [RB_AWIDTH-1:0] pref_head;
logic [RB_AWIDTH-1:0] pref_tail;
logic [63:0]          pref_kmem_addr;
logic                 pref_desc_valid;

logic                 wait_for_pref_desc;

logic [RB_AWIDTH-1:0] new_tail;

logic [31:0] nb_flits;
logic [31:0] missing_flits;
logic [3:0]  missing_flits_in_transfer;

logic [63:0] page_offset;

logic rst_r;

typedef enum
{
    IDLE,
    START_BURST,
    COMPLETE_BURST,
    DONE
} state_t;

state_t state;

function logic [RB_AWIDTH-1:0] get_new_pointer(
    logic [RB_AWIDTH-1:0] pointer, 
    logic [RB_AWIDTH-1:0] upd_sz
);
    if (pointer + upd_sz >= rb_size) begin
        return pointer + upd_sz - rb_size;
    end else begin
        return pointer + upd_sz;
    end
endfunction

assign new_tail = get_new_pointer(cur_tail, nb_flits);

function void try_prefetch();
    if (!pref_desc_valid && !wait_for_pref_desc && (desc_buf_occup > 0)) begin
        pref_desc = desc_buf_rd_data;
        desc_buf_rd_en <= 1;
        wait_for_pref_desc = 1;
        rd_queue <= desc_buf_rd_data.queue_id;
        queue_rd_en <= 1;
    end
endfunction

// TODO(sadok) adjust to reflect actual host rb size
assign page_offset = cur_desc.queue_id * 4096;
assign nb_flits = cur_desc.size;

// Consume requests and issue DMAs
always @(posedge clk) begin
    tail_wr_en <= 0;
    queue_rd_en <= 0;
    pkt_buf_rd_en <= 0;
    desc_buf_rd_en <= 0;

    rst_r <= rst;
    if (rst_r) begin
        state <= IDLE;
        dma_queue_full_cnt <= 0;
        cpu_buf_full_cnt <= 0;
        pcie_bas_write <= 0;
        cur_desc_valid <= 0;
        pref_desc_valid <= 0;
        wait_for_pref_desc <= 0;
    end else begin
        // done prefetching
        if (wait_for_pref_desc && queue_ready) begin
            wait_for_pref_desc = 0;
            pref_desc_valid = 1;
            pref_head = in_head;
            pref_tail = in_tail;
            pref_kmem_addr = in_kmem_addr;
        end

        case (state)
            IDLE: begin
                // invariant: cur_desc_valid == 0
                if (desc_buf_occup > 0) begin
                    // fetch next queue state
                    wait_for_pref_desc <= 0; // regular fetch
                    rd_queue <= desc_buf_rd_data.queue_id;
                    cur_desc <= desc_buf_rd_data;
                    desc_buf_rd_en <= 1;
                    queue_rd_en <= 1;

                    state <= START_BURST;
                end

                // a DMA may have finished, ensure write is unset
                if (!pcie_bas_waitrequest) begin
                    pcie_bas_write <= 0;
                end
            end
            START_BURST: begin
                // pending fetch arrived
                if (!cur_desc_valid && queue_ready) begin
                    cur_desc_valid = 1;
                    cur_head = in_head;
                    cur_tail = in_tail;
                    cur_kmem_addr = in_kmem_addr;
                    missing_flits = cur_desc.size;
                end

                // TODO(sadok) must check head to ensure that there is enough
                // space in the buffer in host memory

                // We may set the writing signals even when pcie_bas_waitrequest
                // is set, but we must make sure that they remain active until
                // pcie_bas_waitrequest is unset. So we are checking this signal
                // not to ensure that we are able to write but instead to make
                // sure that any write request in the previous cycle is complete
                if (!pcie_bas_waitrequest && (pkt_buf_occup > 0)
                        && cur_desc_valid) begin
                    automatic logic [3:0] flits_in_transfer;
                    automatic logic [63:0] req_offset = (
                        nb_flits - missing_flits) * 64;

                    // max 8 flits per burst
                    if (missing_flits > 8) begin
                        flits_in_transfer = 8;
                    end else begin
                        flits_in_transfer = missing_flits;
                    end

                    if (missing_flits == nb_flits) begin
                        assert(pkt_buf_rd_data.sop);
                    end

                    // skips the first block
                    // TODO(sadok) remove page_offset
                    pcie_bas_address <= cur_kmem_addr + 64 + page_offset 
                        + req_offset;
                    
                    pcie_bas_byteenable <= 64'hffffffffffffffff;
                    pcie_bas_writedata <= pkt_buf_rd_data.data;
                    pkt_buf_rd_en <= 1;
                    pcie_bas_write <= 1;
                    pcie_bas_burstcount <= flits_in_transfer;

                    if (missing_flits > 1) begin
                        state <= COMPLETE_BURST;
                        missing_flits <= missing_flits - 1;
                        missing_flits_in_transfer <= flits_in_transfer - 1;
                    end else begin
                        // TODO(sadok) handle unaligned cases here
                        // pcie_bas_byteenable <= ;
                        state <= DONE;
                        assert(pkt_buf_rd_data.eop);
                    end
                end else begin
                    dma_queue_full_cnt <= dma_queue_full_cnt + 1;

                    // a DMA may have finished, ensure write is unset
                    if (!pcie_bas_waitrequest) begin
                        pcie_bas_write <= 0;
                    end
                end

                try_prefetch();
            end
            COMPLETE_BURST: begin
                if (!pcie_bas_waitrequest && (pkt_buf_occup > 0)) begin
                    missing_flits <= missing_flits - 1;
                    missing_flits_in_transfer <= missing_flits_in_transfer - 1;

                    // subsequent bursts from the same transfer do not need to
                    // set the address
                    // pcie_bas_address <= 0;
                    pcie_bas_byteenable <= 64'hffffffffffffffff;
                    pcie_bas_writedata <= pkt_buf_rd_data.data;
                    pkt_buf_rd_en <= 1;
                    pcie_bas_write <= 1;
                    pcie_bas_burstcount <= 0;

                    if (missing_flits_in_transfer == 1) begin
                        if (missing_flits > 1) begin
                            state <= START_BURST;
                            assert(!pkt_buf_rd_data.eop);
                        end else begin
                            // TODO(sadok) handle unaligned cases here
                            // pcie_bas_byteenable <= ;
                            state <= DONE;
                            assert(pkt_buf_rd_data.eop);
                        end
                    end
                end else begin
                    dma_queue_full_cnt <= dma_queue_full_cnt + 1;

                    // a DMA may have finished, ensure write is unset
                    if (!pcie_bas_waitrequest) begin
                        pcie_bas_write <= 0;
                    end
                end

                try_prefetch();
            end
            DONE: begin
                if (!pcie_bas_waitrequest) begin // done with previous transfer
                    if (write_pointer) begin
                        // Send done descriptor
                        // TODO(sadok) make sure tail is being written to the
                        // right location
                        pcie_bas_address <= cur_kmem_addr + page_offset;
                        pcie_bas_byteenable <= 64'h000000000000000f;
                        pcie_bas_writedata <= {480'h0, new_tail};
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
                    tail_wr_en <= 1;
                    wr_queue <= cur_desc.queue_id;

                    // if we have already prefetched the next descriptor, we can
                    // start the next transfer in the following cycle
                    if (pref_desc_valid) begin
                        // If the prefetched desc corresponds to the same queue,
                        // we ignore the tail as it is still outdated.
                        if (cur_desc.queue_id != pref_desc.queue_id) begin
                            cur_tail = pref_tail;
                        end
                        cur_desc = pref_desc;
                        cur_head = pref_head;
                        cur_kmem_addr = pref_kmem_addr;
                        pref_desc_valid = 0;
                        cur_desc_valid = 1;
                        missing_flits <= pref_desc.size;
                        
                        // Prefetching will prevent the tail from being updated
                        // in this cycle, we handle this after the case by
                        // reattempting the write in the following cycle.
                        try_prefetch();
                        state <= START_BURST;
                    end else if (wait_for_pref_desc) begin
                        // prefetch is in progress, make it a regular fetch
                        wait_for_pref_desc = 0;
                        cur_desc_valid = 0;
                        cur_desc = pref_desc;
                        state <= START_BURST;
                    end else begin
                        // no prefetch available or in progress
                        cur_desc_valid = 0;
                        state <= IDLE;
                    end
                end else begin
                    dma_queue_full_cnt <= dma_queue_full_cnt + 1;
                end
            end
            default: state <= IDLE;
        endcase

        // Attempt to read and write at the same time. Try to write again.
        if (tail_wr_en && queue_rd_en) begin
            tail_wr_en <= 1;
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        max_rb <= 0;
    end else begin
        if (pkt_buf_occup > max_rb) begin
            max_rb <= pkt_buf_occup;
        end
    end
end

typedef enum
{
    GEN_IDLE,
    GEN_DATA
} gen_state_t;

gen_state_t               gen_state;
logic [APP_IDX_WIDTH-1:0] queue_id;
logic [31:0]              nb_requests;
logic [PDU_AWIDTH-1:0]    flits_written;
logic [31:0]              last_target_nb_requests;

// Generate requests
always @(posedge clk) begin
    pkt_buf_wr_en <= 0;
    desc_buf_wr_en <= 0;
    last_target_nb_requests <= target_nb_requests;
    if (rst) begin
        gen_state <= GEN_IDLE;
        flits_written <= 0;
        queue_id <= 0;
        nb_requests <= 0;
        transmit_cycles <= 0;
        last_target_nb_requests <= 0;
    end else begin
        automatic logic can_insert_pkt = (pkt_buf_occup < (PDU_DEPTH - 2)) && 
                                         (desc_buf_occup < (PDU_DEPTH - 2));
        case (gen_state)
            GEN_IDLE: begin
                if (nb_requests < target_nb_requests) begin
                    queue_id <= 0;
                    flits_written <= 0;
                    gen_state <= GEN_DATA;
                end
            end
            GEN_DATA: begin
                if (can_insert_pkt) begin
                    pkt_buf_wr_en <= 1;
                    pkt_buf_wr_data.data <= {
                        nb_requests, 32'h00000000, 64'h0000babe0000face, 
                        64'h0000babe0000face, 64'h0000babe0000face,
                        64'h0000babe0000face, 64'h0000babe0000face, 
                        64'h0000babe0000face, 64'h0000babe0000face
                    };

                    flits_written <= flits_written + 1;

                    pkt_buf_wr_data.sop <= (flits_written == 0); // first block

                    if ((flits_written + 1) * 16 >= req_size) begin
                        pkt_buf_wr_data.eop <= 1; // last block
                        nb_requests <= nb_requests + 1;
                        flits_written <= 0;

                        // write descriptor
                        desc_buf_wr_en <= 1;
                        desc_buf_wr_data.queue_id <= queue_id;
                        desc_buf_wr_data.size <= (req_size + (16 - 1))/16;

                        if (nb_requests + 1 == target_nb_requests) begin
                            gen_state <= GEN_IDLE;
                        end else begin
                            if (((queue_id + 1) * 4096 + req_size * 4) > 
                                    (rb_size * 64)) begin
                                queue_id <= 0;
                            end else begin
                                queue_id <= queue_id + 1;
                            end
                        end
                    end else begin
                        pkt_buf_wr_data.eop <= 0;
                    end
                end
            end
            default: gen_state <= GEN_IDLE;
        endcase

        // count cycles until we go back to the IDLE state and there are no more
        // pending packets in the ring buffer
        if (gen_state != GEN_IDLE || pkt_buf_occup != 0) begin
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
pkt_buf (
    .clk     (clk),
    .rst     (rst),
    .wr_data (pkt_buf_wr_data),
    .wr_en   (pkt_buf_wr_en),
    .rd_data (pkt_buf_rd_data),
    .rd_en   (pkt_buf_rd_en),
    .occup   (pkt_buf_occup)
);

// Descriptor buffer. This was sized considering the worst case -- where all
// packets are min-sized. We may use a smaller buffer here to save BRAM.
prefetch_rb #(
    .DEPTH(PDU_DEPTH),
    .AWIDTH(PDU_AWIDTH),
    .DWIDTH($bits(pkt_desc_t))
)
desc_buf (
    .clk     (clk),
    .rst     (rst),
    .wr_data (desc_buf_wr_data),
    .wr_en   (desc_buf_wr_en),
    .rd_data (desc_buf_rd_data),
    .rd_en   (desc_buf_rd_en),
    .occup   (desc_buf_occup)
);

endmodule
