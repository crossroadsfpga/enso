
`include "./my_struct_s.sv"

module fpga2cpu_pcie (
    input clk,
    input rst,

    // write to FPGA ring buffer.
    // input  flit_lite_t               wr_data,
    // input  logic [PDU_AWIDTH-1:0]    wr_addr,
    // input  logic                     wr_en,
    // output logic [PDU_AWIDTH-1:0]    wr_base_addr,
    // output logic                     wr_base_addr_valid,
    // output logic                     almost_full,
    // input  logic                     update_valid,
    // input  logic [PDU_AWIDTH-1:0]    update_size,

    // packet buffer input and status
    input  flit_lite_t               pkt_buf_wr_data,
    input  logic                     pkt_buf_wr_en,
    output logic [PDU_AWIDTH-1:0]    pkt_buf_occup,

    // descriptor buffer input and status
    input  pkt_desc_t                desc_buf_wr_data,
    input  logic                     desc_buf_wr_en,
    output logic [PDU_AWIDTH-1:0]    desc_buf_occup,

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

    // counters
    output logic [31:0]              dma_queue_full_cnt,
    output logic [31:0]              cpu_buf_full_cnt,
    output logic [31:0]              max_rb // TODO(sadok) remove this, we can infer that using the occup signals from the top module
);

// assign wr_base_addr = 0;
// assign wr_base_addr_valid = 0;
// assign almost_full = 0;
assign pcie_bas_read = 0;

flit_lite_t            pkt_buf_rd_data;
logic                  pkt_buf_rd_en;


pkt_desc_t             desc_buf_rd_data;
logic                  desc_buf_rd_en;

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
logic                 hold_tail;

logic [31:0] missing_flits;
logic [3:0]  missing_flits_in_transfer;

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
    // HACK(sadok) When a request wraps around, we are purposefully writing it
    // past the buffer limit. This means that the next request starts from 0.
    // This assumes that buffers are allocated with an extra page in the end.
    // We may need to revisit this decision once we start using byte streams as
    // there would be no way for software to figure out when we are writing past
    // the buffer limit.
    if (pointer + upd_sz >= rb_size) begin
        return 0;
        // return pointer + upd_sz - rb_size;
    end else begin
        return pointer + upd_sz;
    end
endfunction

function void try_prefetch();
    if (!pref_desc_valid && !wait_for_pref_desc && (desc_buf_occup > 0)) begin
        pref_desc = desc_buf_rd_data;
        desc_buf_rd_en <= 1;
        wait_for_pref_desc = 1;
        rd_queue <= desc_buf_rd_data.queue_id;
        queue_rd_en <= 1;
    end
endfunction

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
        hold_tail <= 0;
    end else begin
        // done prefetching
        if (cur_desc_valid && wait_for_pref_desc && queue_ready) begin
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
                automatic logic [RB_AWIDTH-1:0] free_slot;
                if (!cur_desc_valid && queue_ready) begin
                    cur_desc_valid = 1;
                    cur_head = in_head;
                    // When switching to the same queue, the tail we fetch is
                    // outdated.
                    if (!hold_tail) begin
                        cur_tail = in_tail;
                    end
                    hold_tail <= 0;
                    cur_kmem_addr = in_kmem_addr;
                    missing_flits = cur_desc.size;
                end

                // Always have at least one slot not occupied
                if (cur_tail >= cur_head) begin
                    free_slot = rb_size - cur_tail + cur_head - 1;
                end else begin
                    free_slot = cur_head - cur_tail - 1;
                end

                // TODO(sadok) Current design may cause head-of-line blocking.
                // We may consdier dropping packets here.

                // We may set the writing signals even when pcie_bas_waitrequest
                // is set, but we must make sure that they remain active until
                // pcie_bas_waitrequest is unset. So we are checking this signal
                // not to ensure that we are able to write but instead to make
                // sure that any write request in the previous cycle is complete
                if (!pcie_bas_waitrequest && (pkt_buf_occup > 0)
                        && cur_desc_valid && free_slot >= cur_desc.size) begin
                    automatic logic [3:0] flits_in_transfer;
                    automatic logic [63:0] req_offset = (
                        cur_desc.size - missing_flits) * 64;
                    // max 8 flits per burst
                    if (missing_flits > 8) begin
                        flits_in_transfer = 8;
                    end else begin
                        flits_in_transfer = missing_flits;
                    end

                    if (missing_flits == cur_desc.size) begin
                        assert(pkt_buf_rd_data.sop);
                    end

                    // skips the first block
                    pcie_bas_address <= cur_kmem_addr + 64 * (1 + cur_tail)
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
                    if (pcie_bas_waitrequest) begin
                        dma_queue_full_cnt <= dma_queue_full_cnt + 1;
                    end
                    if (free_slot < cur_desc.size) begin
                        cpu_buf_full_cnt <= cpu_buf_full_cnt + 1;
                        
                        // TODO(sadok) Should we drop the packet instead of
                        // waiting?

                        // Fetch descriptor again so we can hopefully have
                        // enough space to write the packet.
                        hold_tail <= 1;
                        cur_desc_valid = 0;
                        rd_queue <= cur_desc.queue_id;
                        queue_rd_en <= 1;
                    end

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
                    assert(pkt_buf_occup == 0);

                    // a DMA may have finished, ensure write is unset
                    if (!pcie_bas_waitrequest) begin
                        pcie_bas_write <= 0;
                    end else begin
                        dma_queue_full_cnt <= dma_queue_full_cnt + 1;
                    end
                end

                try_prefetch();
            end
            DONE: begin
                if (!pcie_bas_waitrequest) begin // done with previous transfer
                    automatic logic [RB_AWIDTH-1:0] new_tail = get_new_pointer(
                        cur_tail, cur_desc.size);
                    pcie_bas_address <= cur_kmem_addr;
                    pcie_bas_byteenable <= 64'h000000000000000f;
                    pcie_bas_writedata <= {480'h0, new_tail};
                    pcie_bas_write <= 1;
                    pcie_bas_burstcount <= 1;

                    // update tail
                    out_tail <= new_tail;
                    tail_wr_en <= 1;
                    wr_queue <= cur_desc.queue_id;

                    // If we have already prefetched the next descriptor, we can
                    // start the next transfer in the following cycle.
                    if (pref_desc_valid) begin
                        // If the prefetched desc corresponds to the same queue,
                        // we ignore the tail as it is still outdated.
                        if (cur_desc.queue_id != pref_desc.queue_id) begin
                            cur_tail = pref_tail;
                        end else begin
                            cur_tail = new_tail;
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
                        // Prefetch is in progress, make it a regular fetch.
                        wait_for_pref_desc = 0;
                        cur_desc_valid = 0;

                        // When we are switching to the same queue, we must not
                        // override the tail. We use the hold_tail signal to
                        // ensure that.
                        if (cur_desc.queue_id == pref_desc.queue_id) begin
                            hold_tail <= 1;
                            cur_tail = new_tail;
                        end
                        cur_desc = pref_desc;
                        try_prefetch();
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
