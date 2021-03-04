
`include "./my_struct_s.sv"

module fpga2cpu_pcie (
    input logic clk,
    input logic rst,

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
    input  logic [RB_AWIDTH-1:0]            in_dsc_head,
    input  logic [RB_AWIDTH-1:0]            in_dsc_tail,
    input  logic [63:0]                     in_dsc_buf_addr,
    input  logic [RB_AWIDTH-1:0]            in_pkt_head,
    input  logic [RB_AWIDTH-1:0]            in_pkt_tail,
    input  logic [63:0]                     in_pkt_buf_addr,
    output logic [BRAM_TABLE_IDX_WIDTH-1:0] rd_pkt_queue,
    output logic [BRAM_TABLE_IDX_WIDTH-1:0] rd_dsc_queue,
    input  logic                            queue_ready,
    output logic [RB_AWIDTH-1:0]            out_dsc_tail,
    output logic [RB_AWIDTH-1:0]            out_pkt_tail,
    output logic [BRAM_TABLE_IDX_WIDTH-1:0] wr_pkt_queue,
    output logic [BRAM_TABLE_IDX_WIDTH-1:0] wr_dsc_queue,
    output logic                            queue_rd_en,
    output logic                            tail_wr_en,
    input  logic [30:0]                     dsc_rb_size,
    input  logic [30:0]                     pkt_rb_size,

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

    // Counter reset
    input  logic                     sw_reset,

    // Counters
    output logic [31:0]              dma_queue_full_cnt,
    output logic [31:0]              cpu_buf_full_cnt
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
logic [RB_AWIDTH-1:0] cur_dsc_head;
logic [RB_AWIDTH-1:0] cur_dsc_tail;
logic [63:0]          cur_dsc_buf_addr;
logic [RB_AWIDTH-1:0] cur_pkt_head;
logic [RB_AWIDTH-1:0] cur_pkt_tail;
logic [RB_AWIDTH-1:0] first_flit_pkt_tail;
logic [63:0]          cur_pkt_buf_addr;
logic                 cur_desc_valid;

pkt_desc_t            pref_desc;
logic [RB_AWIDTH-1:0] pref_dsc_head;
logic [RB_AWIDTH-1:0] pref_dsc_tail;
logic [63:0]          pref_dsc_buf_addr;
logic [RB_AWIDTH-1:0] pref_pkt_head;
logic [RB_AWIDTH-1:0] pref_pkt_tail;
logic [63:0]          pref_pkt_buf_addr;
logic                 pref_desc_valid;

logic                 wait_for_pref_desc;
logic                 hold_pkt_tail;
logic                 hold_dsc_tail;

logic [31:0] missing_flits;
logic [3:0]  missing_flits_in_transfer;

logic [31:0] dma_queue_full_cnt_r;
logic [31:0] cpu_buf_full_cnt_r;

logic [63:0]  pcie_bas_address_r;
logic [63:0]  pcie_bas_byteenable_r;
logic         pcie_bas_write_r;
logic [511:0] pcie_bas_writedata_r;
logic [3:0]   pcie_bas_burstcount_r;

logic [511:0] first_flit_data;

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
    logic [RB_AWIDTH-1:0] upd_sz,
    logic [30:0] buf_sz
);
    if (pointer + upd_sz >= buf_sz) begin
        return pointer + upd_sz - buf_sz;
    end else begin
        return pointer + upd_sz;
    end
endfunction

function void try_prefetch();
    if (!pref_desc_valid && !wait_for_pref_desc && (desc_buf_occup > 0)) begin
        pref_desc = desc_buf_rd_data;
        desc_buf_rd_en <= 1;
        wait_for_pref_desc = 1;
        rd_pkt_queue <= desc_buf_rd_data.pkt_queue_id;
        rd_dsc_queue <= desc_buf_rd_data.dsc_queue_id;
        queue_rd_en <= 1;
    end
endfunction

function logic [RB_AWIDTH-1:0] dma_pkt(
    logic [RB_AWIDTH-1:0] tail,
    logic [511:0] data,
    logic [3:0] flits_in_transfer
    // TODO(sadok) expose byteenable?
);
    if (cur_pkt_buf_addr && cur_dsc_buf_addr) begin
        // Assume that it is a burst when flits_in_transfer == 0, no need to set 
        // address.
        if (flits_in_transfer != 0) begin
            pcie_bas_address_r <= cur_pkt_buf_addr + 64 * tail;
        end

        pcie_bas_byteenable_r <= 64'hffffffffffffffff;
        pcie_bas_writedata_r <= data;
        pcie_bas_write_r <= 1;
        pcie_bas_burstcount_r <= flits_in_transfer;

        return get_new_pointer(tail, flits_in_transfer, pkt_rb_size);
    end
    return tail;
endfunction

function void dma_signature(
    logic [RB_AWIDTH-1:0] tail,
    logic [3:0] flits_in_transfer
);
    // When there is only one missing flit, we should write the signature
    automatic rb_signature_t signature_flit;

    // TODO(sadok) Make signature unique to the app.
    // TODO(sadok) Use signature flit to place information about unaligned data
    // so that software can figure out where it ends.
    signature_flit.signature = 128'hbabefacebabefacebabefacebabeface;
    signature_flit.pad = 0;

    dma_pkt(tail, signature_flit, flits_in_transfer);
endfunction

// Consume requests and issue DMAs
always @(posedge clk) begin
    tail_wr_en <= 0;
    queue_rd_en <= 0;
    pkt_buf_rd_en <= 0;
    desc_buf_rd_en <= 0;
    
    dma_queue_full_cnt <= dma_queue_full_cnt_r;
    cpu_buf_full_cnt <= cpu_buf_full_cnt_r;

    if (!pcie_bas_waitrequest) begin
        pcie_bas_address <= pcie_bas_address_r;
        pcie_bas_byteenable <= pcie_bas_byteenable_r;
        pcie_bas_write <= pcie_bas_write_r;
        pcie_bas_writedata <= pcie_bas_writedata_r;
        pcie_bas_burstcount <= pcie_bas_burstcount_r;
    end

    rst_r <= rst;
    if (rst_r | sw_reset) begin
        state <= IDLE;
        dma_queue_full_cnt_r <= 0;
        cpu_buf_full_cnt_r <= 0;
        pcie_bas_write_r <= 0;
        cur_desc_valid <= 0;
        pref_desc_valid <= 0;
        wait_for_pref_desc <= 0;
        hold_pkt_tail <= 0;
        hold_dsc_tail <= 0;
    end else begin
        // done prefetching
        if (cur_desc_valid && wait_for_pref_desc && queue_ready) begin
            wait_for_pref_desc = 0;
            pref_desc_valid = 1;
            pref_dsc_head = in_dsc_head;
            pref_dsc_tail = in_dsc_tail;
            pref_dsc_buf_addr = in_dsc_buf_addr;
            pref_pkt_head = in_pkt_head;
            pref_pkt_tail = in_pkt_tail;
            pref_pkt_buf_addr = in_pkt_buf_addr;
        end

        case (state)
            IDLE: begin
                // invariant: cur_desc_valid == 0
                if (desc_buf_occup > 0 && pkt_buf_occup > 0) begin
                    // fetch next queue state
                    wait_for_pref_desc <= 0; // regular fetch
                    rd_pkt_queue <= desc_buf_rd_data.pkt_queue_id;
                    rd_dsc_queue <= desc_buf_rd_data.dsc_queue_id;
                    cur_desc <= desc_buf_rd_data;
                    desc_buf_rd_en <= 1;
                    queue_rd_en <= 1;

                    // We need to save the packet's first flit so that we can
                    // start the transfer from the second. We need this to avoid
                    // overriding the signature before we complete the transfer.
                    assert(pkt_buf_rd_data.sop);
                    first_flit_data <= pkt_buf_rd_data.data;
                    pkt_buf_rd_en <= 1;

                    state <= START_BURST;
                end

                // a DMA may have finished, ensure write is unset
                if (!pcie_bas_waitrequest) begin
                    pcie_bas_write_r <= 0;
                end
            end
            START_BURST: begin
                automatic logic [RB_AWIDTH-1:0] dsc_free_slot;
                automatic logic [RB_AWIDTH-1:0] pkt_free_slot;

                // pending fetch arrived
                if (!cur_desc_valid && queue_ready) begin
                    cur_desc_valid = 1;
                    cur_dsc_head = in_dsc_head;
                    cur_pkt_head = in_pkt_head;
                    // When switching to the same queue, the tail we fetch is
                    // outdated.
                    if (!hold_pkt_tail) begin
                        cur_pkt_tail = in_pkt_tail;
                    end
                    if (!hold_dsc_tail) begin
                        cur_dsc_tail = in_dsc_tail;
                    end
                    hold_pkt_tail <= 0;
                    hold_dsc_tail <= 0;
                    cur_dsc_buf_addr = in_dsc_buf_addr;
                    cur_pkt_buf_addr = in_pkt_buf_addr;
                    missing_flits = cur_desc.size;
                end

                // Always have at least one slot not occupied in both the
                // descriptor ring buffer and the packet ring buffer
                if (cur_dsc_tail >= cur_dsc_head) begin
                    dsc_free_slot = dsc_rb_size[RB_AWIDTH-1:0] - cur_dsc_tail
                                    + cur_dsc_head - 1'b1;
                end else begin
                    dsc_free_slot = cur_dsc_head - cur_dsc_tail - 1'b1;
                end
                if (cur_pkt_tail >= cur_pkt_head) begin
                    pkt_free_slot = pkt_rb_size[RB_AWIDTH-1:0] - cur_pkt_tail
                                    + cur_pkt_head - 1'b1;
                end else begin
                    pkt_free_slot = cur_pkt_head - cur_pkt_tail - 1'b1;
                end

                // TODO(sadok) Current design may cause head-of-line blocking.
                // We may consdier dropping packets here.

                // We may set the writing signals even when pcie_bas_waitrequest
                // is set, but we must make sure that they remain active until
                // pcie_bas_waitrequest is unset. So we are checking this signal
                // not to ensure that we are able to write but instead to make
                // sure that any write request in the previous cycle is complete
                if (!pcie_bas_waitrequest && cur_desc_valid && dsc_free_slot > 0
                        && pkt_free_slot >= missing_flits) begin
                    automatic logic [3:0] flits_in_transfer;
                    // max 8 flits per burst
                    if (missing_flits > 8) begin
                        flits_in_transfer = 8;
                    end else begin
                        flits_in_transfer = missing_flits[3:0];
                    end

                    if (missing_flits == cur_desc.size) begin
                        // save first flit's tail to DMA it later
                        first_flit_pkt_tail <= cur_pkt_tail;
                        
                        // skip first flit
                        cur_pkt_tail = get_new_pointer(
                            cur_pkt_tail, 1, pkt_rb_size);
                    end

                    // The DMA transfer cannot go across the buffer limit.
                    if (flits_in_transfer > (
                            pkt_rb_size[RB_AWIDTH-1:0] - cur_pkt_tail)) begin
                        flits_in_transfer = 
                            pkt_rb_size[RB_AWIDTH-1:0] - cur_pkt_tail;
                    end

                    if (missing_flits > 1) begin
                        dma_pkt(cur_pkt_tail, pkt_buf_rd_data.data,
                                flits_in_transfer);

                        cur_pkt_tail = get_new_pointer(
                            cur_pkt_tail, 1, pkt_rb_size);

                        pkt_buf_rd_en <= 1;
                        state <= COMPLETE_BURST;
                        missing_flits <= missing_flits - 1;
                        missing_flits_in_transfer <= flits_in_transfer - 1'b1;
                    end else begin
                        dma_signature(cur_pkt_tail, 1);

                        // TODO(sadok) handle unaligned cases here
                        // pcie_bas_byteenable_r <= ;
                        state <= DONE;
                    end
                end else begin
                    if (pcie_bas_waitrequest) begin
                        dma_queue_full_cnt_r <= dma_queue_full_cnt_r + 1;
                    end else begin
                        pcie_bas_write_r <= 0;
                    end
                    if (pkt_free_slot < cur_desc.size || dsc_free_slot == 0)
                    begin
                        cpu_buf_full_cnt_r <= cpu_buf_full_cnt_r + 1;
                        
                        // TODO(sadok) Should we drop the packet instead of
                        // waiting?

                        // Fetch descriptor again so we can hopefully have
                        // enough space to write the packet.
                        hold_pkt_tail <= 1;
                        hold_dsc_tail <= 1;
                        cur_desc_valid = 0;
                        rd_pkt_queue <= cur_desc.pkt_queue_id;
                        rd_dsc_queue <= cur_desc.dsc_queue_id;
                        queue_rd_en <= 1;
                    end
                end

                try_prefetch();
            end
            COMPLETE_BURST: begin
                if (!pcie_bas_waitrequest) begin
                    missing_flits <= missing_flits - 1;
                    missing_flits_in_transfer <= 
                        missing_flits_in_transfer - 1'b1;

                    // Subsequent bursts from the same transfer do not need to
                    // set the address.
                    if (missing_flits > 1) begin
                        dma_pkt(0, pkt_buf_rd_data.data, 0);
                        pkt_buf_rd_en <= 1;

                        cur_pkt_tail <= get_new_pointer(
                                cur_pkt_tail, 1, pkt_rb_size);
                        if (missing_flits_in_transfer == 1) begin
                            state <= START_BURST;
                        end
                    end else begin
                        // TODO(sadok) handle unaligned cases here
                        // pcie_bas_byteenable_r <= ;

                        dma_signature(0, 0);
                        state <= DONE;
                    end
                end else begin
                    assert(pkt_buf_occup == 0);

                    // a DMA may have finished, ensure write is unset
                    if (!pcie_bas_waitrequest) begin
                        pcie_bas_write_r <= 0;
                    end else begin
                        dma_queue_full_cnt_r <= dma_queue_full_cnt_r + 1;
                    end
                end

                try_prefetch();
            end
            DONE: begin
                // Since we only write the packet to the packet buffer when
                // there is space in both the descriptor and packet ring
                // buffers, when we get here we know that it is safe to write
                // the descriptor.

                // make sure the previous transfer is complete
                if (!pcie_bas_waitrequest) begin
                    // TODO(sadok) reenable the dsc queue (remember to increment
                    // dsc tail)
                    // automatic pcie_pkt_desc_t pcie_pkt_desc;
                    
                    // pcie_pkt_desc.signal = 1;
                    // pcie_pkt_desc.tail = {
                    //     {{$bits(pcie_pkt_desc.tail) - RB_AWIDTH}{1'b0}},
                    //     cur_pkt_tail
                    // };
                    // pcie_pkt_desc.queue_id = cur_desc.pkt_queue_id;
                    // pcie_pkt_desc.pad = 0;
                    
                    // // Skip DMA when addresses are not set
                    // if (cur_pkt_buf_addr && cur_dsc_buf_addr) begin
                    //     pcie_bas_address_r <= cur_dsc_buf_addr
                    //                           + 64 * cur_dsc_tail;
                    //     pcie_bas_byteenable_r <= 64'hffffffffffffffff;
                    //     pcie_bas_writedata_r <= pcie_pkt_desc;
                    //     pcie_bas_write_r <= 1;
                    //     pcie_bas_burstcount_r <= 1;
                    // end

                    // dma first flit and override old signature
                    dma_pkt(first_flit_pkt_tail, first_flit_data, 1);

                    // update tail
                    // out_dsc_tail <= get_new_pointer(cur_dsc_tail, 1,
                    //     dsc_rb_size);
                    out_dsc_tail <= cur_dsc_tail;
                    out_pkt_tail <= cur_pkt_tail;
                    tail_wr_en <= 1;
                    wr_pkt_queue <= cur_desc.pkt_queue_id;
                    wr_dsc_queue <= cur_desc.dsc_queue_id;

                    // If we have already prefetched the next descriptor, we can
                    // start the next transfer in the following cycle.
                    if (pref_desc_valid) begin
                        // If the prefetched desc corresponds to the same queue,
                        // we ignore the tail as it is still outdated.
                        if (cur_desc.pkt_queue_id != pref_desc.pkt_queue_id)
                        begin
                            cur_pkt_tail = pref_pkt_tail;
                        end
                        if (cur_desc.dsc_queue_id != pref_desc.dsc_queue_id)
                        begin
                            cur_dsc_tail = pref_dsc_tail;
                        end
                        cur_desc = pref_desc;
                        cur_dsc_head = pref_dsc_head;
                        cur_dsc_buf_addr = pref_dsc_buf_addr;
                        cur_pkt_head = pref_pkt_head;
                        cur_pkt_buf_addr = pref_pkt_buf_addr;
                        pref_desc_valid = 0;
                        cur_desc_valid = 1;
                        missing_flits <= pref_desc.size;
                        
                        // Prefetching will prevent the tail from being updated
                        // in this cycle, we handle this after the case by
                        // reattempting the write in the following cycle.
                        try_prefetch();
                        state = START_BURST;
                    end else if (wait_for_pref_desc) begin
                        // Prefetch is in progress, make it a regular fetch.
                        wait_for_pref_desc = 0;
                        cur_desc_valid = 0;

                        // When we are not switching queues, we must not
                        // override the tail. We use the hold_*_tail signals to
                        // ensure that.
                        if (cur_desc.pkt_queue_id == pref_desc.pkt_queue_id)
                        begin
                            hold_pkt_tail <= 1;
                            // cur_dsc_tail = new_dsc_tail;
                            // cur_pkt_tail = new_pkt_tail;
                        end else begin
                            hold_pkt_tail <= 0;
                        end
                        if (cur_desc.dsc_queue_id == pref_desc.dsc_queue_id)
                        begin
                            hold_dsc_tail <= 1;
                            // cur_dsc_tail = new_dsc_tail;
                        end else begin
                            hold_dsc_tail <= 0;
                        end
                        cur_desc = pref_desc;
                        try_prefetch();
                        state = START_BURST;
                    end else begin
                        // no prefetch available or in progress
                        cur_desc_valid = 0;
                        state = IDLE;
                    end

                    if (state != IDLE) begin
                        // If there is a descriptor to prefetch, there must be a
                        // packet available in the packet queue. Therefore we
                        // can save its first flit right away so that we can
                        // start transferring the second flit in the next cycle.
                        assert(pkt_buf_occup > 0);
                        assert(pkt_buf_rd_data.sop);
                        first_flit_data <= pkt_buf_rd_data.data;
                        pkt_buf_rd_en <= 1;
                    end
                end else begin
                    dma_queue_full_cnt_r <= dma_queue_full_cnt_r + 1;
                end
            end
            default: state <= IDLE;
        endcase

        // Attempted to read and write at the same time. Try to write again.
        if (tail_wr_en && queue_rd_en) begin
            tail_wr_en <= 1;
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
