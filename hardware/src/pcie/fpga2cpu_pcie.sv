
`include "../constants.sv"

module fpga2cpu_pcie (
    input logic clk,
    input logic rst,

    // packet buffer input and status
    input  var flit_lite_t           pkt_buf_wr_data,
    input  logic                     pkt_buf_wr_en,
    output logic                     pkt_buf_in_ready,
    output logic [F2C_RB_AWIDTH-1:0] pkt_buf_occup,

    // descriptor buffer input and status
    input  var pkt_dsc_t             desc_buf_wr_data,
    input  logic                     desc_buf_wr_en,
    output logic                     desc_buf_in_ready,
    output logic [F2C_RB_AWIDTH-1:0] desc_buf_occup,

    // CPU ring buffer config signals
    input  logic [30:0]                     dsc_rb_size,
    input  logic [30:0]                     pkt_rb_size,

    // BRAM signals for dsc queues
    bram_interface_io.owner dsc_q_table_tails,
    bram_interface_io.owner dsc_q_table_heads,
    bram_interface_io.owner dsc_q_table_l_addrs,
    bram_interface_io.owner dsc_q_table_h_addrs,

    // BRAM signals for pkt queues
    bram_interface_io.owner pkt_q_table_tails,
    bram_interface_io.owner pkt_q_table_heads,
    bram_interface_io.owner pkt_q_table_l_addrs,
    bram_interface_io.owner pkt_q_table_h_addrs,

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

    // PCIe write signals (used to intercept pointer updates)
    input  logic                            queue_updated,
    input  logic [BRAM_TABLE_IDX_WIDTH-1:0] updated_queue_idx,

    // Counter reset
    input  logic                     sw_reset,

    // Counters
    output logic [31:0]              dma_queue_full_cnt,
    output logic [31:0]              cpu_dsc_buf_full_cnt,
    output logic [31:0]              cpu_pkt_buf_full_cnt,
    output logic [31:0]              pending_prefetch_cnt
);

// assign wr_base_addr = 0;
// assign wr_base_addr_valid = 0;
// assign almost_full = 0;
assign pcie_bas_read = 0;

flit_lite_t pkt_buf_rd_data;
logic       pkt_buf_out_ready;
logic       pkt_buf_out_valid;

pkt_dsc_t  desc_buf_rd_data;
logic       desc_buf_rd_en;
logic       desc_buf_out_valid;

pkt_dsc_t            cur_desc;
logic [RB_AWIDTH-1:0] cur_dsc_head;
logic [RB_AWIDTH-1:0] cur_dsc_tail;
logic [63:0]          cur_dsc_buf_addr;
logic [RB_AWIDTH-1:0] cur_pkt_head;
logic [RB_AWIDTH-1:0] cur_pkt_tail;
logic [63:0]          cur_pkt_buf_addr;
logic                 cur_desc_valid;
logic                 cur_pkt_needs_dsc;

pkt_dsc_t             pref_desc;
logic [RB_AWIDTH-1:0] pref_dsc_head;
logic [RB_AWIDTH-1:0] pref_dsc_tail;
logic [63:0]          pref_dsc_buf_addr;
logic [RB_AWIDTH-1:0] pref_pkt_head;
logic [RB_AWIDTH-1:0] pref_pkt_tail;
logic [63:0]          pref_pkt_buf_addr;
logic                 pref_desc_valid;
logic                 pref_pkt_needs_dsc;

logic                 wait_for_pref_desc;
logic                 hold_pkt_tail;
logic                 hold_dsc_tail;

logic [$bits(cur_desc.size):0] missing_flits;
logic [3:0]  missing_flits_in_transfer;

logic [31:0] dma_queue_full_cnt_r;
logic [31:0] cpu_dsc_buf_full_cnt_r;
logic [31:0] cpu_pkt_buf_full_cnt_r;
logic [31:0] pending_prefetch_cnt_r;

logic [63:0]  pcie_bas_address_r;
logic [63:0]  pcie_bas_byteenable_r;
logic         pcie_bas_write_r;
logic [511:0] pcie_bas_writedata_r;
logic [3:0]   pcie_bas_burstcount_r;

logic                            queue_ready;
logic                            tail_wr_en;
logic                            queue_rd_en;
logic                            queue_rd_en_r;
logic [BRAM_TABLE_IDX_WIDTH-1:0] rd_pkt_queue;
logic [BRAM_TABLE_IDX_WIDTH-1:0] rd_pkt_queue_r;
logic [BRAM_TABLE_IDX_WIDTH-1:0] rd_dsc_queue;
logic [BRAM_TABLE_IDX_WIDTH-1:0] wr_pkt_queue;
logic [BRAM_TABLE_IDX_WIDTH-1:0] wr_dsc_queue;
logic [RB_AWIDTH-1:0]            new_dsc_tail;
logic [RB_AWIDTH-1:0]            new_pkt_tail;

logic [RB_AWIDTH-1:0] dsc_head;
logic [RB_AWIDTH-1:0] dsc_tail;
logic [63:0]          dsc_buf_addr;
logic [RB_AWIDTH-1:0] pkt_head;
logic [RB_AWIDTH-1:0] pkt_tail;
logic                 pkt_q_needs_dsc;
logic [63:0]          pkt_buf_addr;

logic rst_r;

// The BRAM port b's are exposed outside the module while port a's are only used
// internally.
// descriptor queue table interface signals (port a)
bram_interface_io dsc_q_table_a_tails();
bram_interface_io dsc_q_table_a_heads();
bram_interface_io dsc_q_table_a_l_addrs();
bram_interface_io dsc_q_table_a_h_addrs();

// packet queue table interface signals (port a)
bram_interface_io pkt_q_table_a_tails();
bram_interface_io pkt_q_table_a_heads();
bram_interface_io pkt_q_table_a_l_addrs();
bram_interface_io pkt_q_table_a_h_addrs();

// Bit vector holding the status of every pkt queue
// (i.e., if they need a descriptor or not).
logic [MAX_NB_FLOWS-1:0] pkt_q_status;

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
    if (!pref_desc_valid && !wait_for_pref_desc && desc_buf_out_valid
            && !desc_buf_rd_en) begin
        pref_desc = desc_buf_rd_data;
        desc_buf_rd_en <= 1;
        wait_for_pref_desc = 1;
        rd_pkt_queue <= desc_buf_rd_data.pkt_queue_id;
        rd_dsc_queue <= desc_buf_rd_data.dsc_queue_id;
        queue_rd_en <= 1;
    end
endfunction

function void dma_pkt(
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
    end
endfunction

// Consume requests and issue DMAs
always @(posedge clk) begin
    tail_wr_en <= 0;
    queue_rd_en <= 0;
    pkt_buf_out_ready <= 0;
    desc_buf_rd_en <= 0;
    
    dma_queue_full_cnt <= dma_queue_full_cnt_r;
    cpu_dsc_buf_full_cnt <= cpu_dsc_buf_full_cnt_r;
    cpu_pkt_buf_full_cnt <= cpu_pkt_buf_full_cnt_r;
    pending_prefetch_cnt <= pending_prefetch_cnt_r;

    if (!pcie_bas_waitrequest) begin
        pcie_bas_address <= pcie_bas_address_r;
        pcie_bas_byteenable <= pcie_bas_byteenable_r;
        pcie_bas_write <= pcie_bas_write_r;

        // When we DMA a packet, we wait one cycle for it to become available
        // in the FIFO. With a descriptor this is not necessary, as long as
        // there is at least a one-cycle gap between descriptors.
        if (pkt_buf_out_ready) begin
            pcie_bas_writedata <= pkt_buf_rd_data.data;
        end else begin
            pcie_bas_writedata <= pcie_bas_writedata_r;
        end
        pcie_bas_burstcount <= pcie_bas_burstcount_r;
    end

    rst_r <= rst;
    if (rst_r | sw_reset) begin
        state <= IDLE;
        dma_queue_full_cnt_r <= 0;
        cpu_dsc_buf_full_cnt_r <= 0;
        cpu_pkt_buf_full_cnt_r <= 0;
        pending_prefetch_cnt_r <= 0;
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
            pref_dsc_head = dsc_head;
            pref_dsc_tail = dsc_tail;
            pref_dsc_buf_addr = dsc_buf_addr;
            pref_pkt_head = pkt_head;
            pref_pkt_tail = pkt_tail;
            pref_pkt_needs_dsc = pkt_q_needs_dsc;
            pref_pkt_buf_addr = pkt_buf_addr;
        end

        case (state)
            IDLE: begin
                // invariant: cur_desc_valid == 0
                if (desc_buf_out_valid && pkt_buf_out_valid) begin
                    // fetch next queue state
                    wait_for_pref_desc <= 0; // regular fetch
                    rd_pkt_queue <= desc_buf_rd_data.pkt_queue_id;
                    rd_dsc_queue <= desc_buf_rd_data.dsc_queue_id;
                    cur_desc <= desc_buf_rd_data;
                    desc_buf_rd_en <= 1;
                    queue_rd_en <= 1;

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
                    cur_dsc_head = dsc_head;
                    cur_pkt_head = pkt_head;
                    cur_pkt_needs_dsc = pkt_q_needs_dsc;
                    // When switching to the same queue, the tail we fetch is
                    // outdated.
                    if (!hold_pkt_tail) begin
                        cur_pkt_tail = pkt_tail;
                    end
                    if (!hold_dsc_tail) begin
                        cur_dsc_tail = dsc_tail;
                    end
                    hold_pkt_tail <= 0;
                    hold_dsc_tail <= 0;
                    cur_dsc_buf_addr = dsc_buf_addr;
                    cur_pkt_buf_addr = pkt_buf_addr;
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
                if (!pcie_bas_waitrequest && cur_desc_valid && pkt_buf_out_valid
                        && pkt_free_slot >= missing_flits && dsc_free_slot != 0)
                begin
                    automatic logic [3:0] flits_in_transfer;
                    // max 8 flits per burst
                    if (missing_flits > 8) begin
                        flits_in_transfer = 8;
                    end else begin
                        flits_in_transfer = missing_flits[3:0];
                    end

                    if (missing_flits == cur_desc.size) begin
                        assert(pkt_buf_rd_data.sop);
                    end

                    // The DMA transfer cannot go across the buffer limit.
                    if (flits_in_transfer > (
                            pkt_rb_size[RB_AWIDTH-1:0] - cur_pkt_tail)) begin
                        flits_in_transfer = 
                            pkt_rb_size[RB_AWIDTH-1:0] - cur_pkt_tail;
                    end

                    dma_pkt(cur_pkt_tail, pkt_buf_rd_data.data,
                            flits_in_transfer);

                    cur_pkt_tail = get_new_pointer(
                        cur_pkt_tail, 1, pkt_rb_size);

                    pkt_buf_out_ready <= 1;

                    if (missing_flits > 1) begin
                        state <= COMPLETE_BURST;
                        missing_flits <= missing_flits - 1;
                        missing_flits_in_transfer <= flits_in_transfer - 1'b1;
                    end else begin
                        // TODO(sadok) handle unaligned cases here
                        // pcie_bas_byteenable_r <= ;
                        state <= DONE;
                        assert(pkt_buf_rd_data.eop);
                    end
                end else begin
                    if (pcie_bas_waitrequest) begin
                        dma_queue_full_cnt_r <= dma_queue_full_cnt_r + 1;
                    end else begin
                        pcie_bas_write_r <= 0;
                    end
                    if (pkt_free_slot < missing_flits) begin
                        cpu_pkt_buf_full_cnt_r <= cpu_pkt_buf_full_cnt_r + 1;
                    end
                    if (dsc_free_slot == 0) begin
                        cpu_dsc_buf_full_cnt_r <= cpu_dsc_buf_full_cnt_r + 1;
                    end
                    if (!cur_desc_valid) begin
                        pending_prefetch_cnt_r <= pending_prefetch_cnt_r + 1;
                    end
                    if (pkt_free_slot < missing_flits || dsc_free_slot == 0)
                    begin
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
                if (!pcie_bas_waitrequest && pkt_buf_out_valid) begin
                    missing_flits <= missing_flits - 1;
                    missing_flits_in_transfer <= 
                        missing_flits_in_transfer - 1'b1;

                    // Subsequent bursts from the same transfer do not need to
                    // set the address.
                    dma_pkt(0, pkt_buf_rd_data.data, 0);
                    pkt_buf_out_ready <= 1;
                    cur_pkt_tail <= get_new_pointer(
                        cur_pkt_tail, 1, pkt_rb_size);

                    // last flit in burst
                    if (missing_flits_in_transfer == 1) begin
                        if (missing_flits > 1) begin
                            // more flits to send for this packet
                            state <= START_BURST;
                        end else begin
                            // we are done with this packet
                            state <= DONE;
                        end
                    end
                end else begin
                    if (pcie_bas_waitrequest) begin
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
                    automatic pcie_pkt_dsc_t pcie_pkt_desc;
                    pcie_pkt_desc.signal = 1;
                    pcie_pkt_desc.tail = {
                        {{$bits(pcie_pkt_desc.tail) - RB_AWIDTH}{1'b0}},
                        cur_pkt_tail
                    };
                    pcie_pkt_desc.queue_id = cur_desc.pkt_queue_id;
                    pcie_pkt_desc.pad = 0;

                    if (cur_pkt_needs_dsc) begin
                        // Skip DMA when addresses are not set
                        if (cur_pkt_buf_addr && cur_dsc_buf_addr) begin
                            pcie_bas_address_r <= cur_dsc_buf_addr
                                                + 64 * cur_dsc_tail;
                            pcie_bas_byteenable_r <= 64'hffffffffffffffff;
                            pcie_bas_writedata_r <= pcie_pkt_desc;
                            pcie_bas_write_r <= 1;
                            pcie_bas_burstcount_r <= 1;
                            // update tail
                            cur_dsc_tail = get_new_pointer(cur_dsc_tail, 1,
                                dsc_rb_size);
                        end
                    end else begin
                        // since we are not writing anything, we have to make
                        // sure that write is unset
                        pcie_bas_write_r <= 0;
                    end

                    // TODO(sadok) Output new tails at the start of the packet
                    // transfer, this should inform the DMA engine of the latest
                    // pointer before we transmit the descriptor. This is useful
                    // when we start to reactively send events
                    new_dsc_tail <= cur_dsc_tail;
                    new_pkt_tail <= cur_pkt_tail;
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
                        cur_pkt_needs_dsc = pref_pkt_needs_dsc;
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
                        end else begin
                            hold_pkt_tail <= 0;
                        end
                        if (cur_desc.dsc_queue_id == pref_desc.dsc_queue_id)
                        begin
                            hold_dsc_tail <= 1;
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

fifo_wrapper_infill #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL($bits(flit_lite_t)),
    .FIFO_DEPTH(F2C_RB_DEPTH)
)
pkt_buf (
    .clk           (clk),
    .reset         (rst),
    .csr_address   (2'b0),
    .csr_read      (1'b1),
    .csr_write     (1'b0),
    .csr_readdata  (pkt_buf_occup),
    .csr_writedata (32'b0),
    .in_data       (pkt_buf_wr_data),
    .in_valid      (pkt_buf_wr_en),
    .in_ready      (pkt_buf_in_ready),
    .out_data      (pkt_buf_rd_data),
    .out_valid     (pkt_buf_out_valid),
    .out_ready     (pkt_buf_out_ready)
);

// Descriptor buffer. This was sized considering the worst case -- where all
// packets are min-sized. We may use a smaller buffer here to save BRAM.
fifo_wrapper_infill #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL($bits(pkt_dsc_t)),
    .FIFO_DEPTH(F2C_RB_DEPTH)
)
desc_buf (
    .clk           (clk),
    .reset         (rst),
    .csr_address   (2'b0),
    .csr_read      (1'b1),
    .csr_write     (1'b0),
    .csr_readdata  (desc_buf_occup),
    .csr_writedata (32'b0),
    .in_data       (desc_buf_wr_data),
    .in_valid      (desc_buf_wr_en),
    .in_ready      (desc_buf_in_ready),
    .out_data      (desc_buf_rd_data),
    .out_valid     (desc_buf_out_valid),
    .out_ready     (desc_buf_rd_en)
);

logic dsc_q_table_a_tails_rd_en_r;
logic dsc_q_table_a_tails_rd_en_r2;
logic dsc_q_table_a_heads_rd_en_r;
logic dsc_q_table_a_heads_rd_en_r2;
logic dsc_q_table_a_l_addrs_rd_en_r;
logic dsc_q_table_a_l_addrs_rd_en_r2;
logic dsc_q_table_a_h_addrs_rd_en_r;
logic dsc_q_table_a_h_addrs_rd_en_r2;

logic pkt_q_table_a_tails_rd_en_r;
logic pkt_q_table_a_tails_rd_en_r2;
logic pkt_q_table_a_heads_rd_en_r;
logic pkt_q_table_a_heads_rd_en_r2;
logic pkt_q_table_a_l_addrs_rd_en_r;
logic pkt_q_table_a_l_addrs_rd_en_r2;
logic pkt_q_table_a_h_addrs_rd_en_r;
logic pkt_q_table_a_h_addrs_rd_en_r2;

logic [RB_AWIDTH-1:0]            dsc_q_table_heads_wr_data_b_r;
logic [RB_AWIDTH-1:0]            dsc_q_table_heads_wr_data_b_r2;
logic [RB_AWIDTH-1:0]            dsc_q_table_tails_wr_data_a_r;
logic [RB_AWIDTH-1:0]            dsc_q_table_tails_wr_data_a_r2;
logic [RB_AWIDTH-1:0]            pkt_q_table_heads_wr_data_b_r;
logic [RB_AWIDTH-1:0]            pkt_q_table_heads_wr_data_b_r2;
logic [RB_AWIDTH-1:0]            pkt_q_table_tails_wr_data_a_r;
logic [RB_AWIDTH-1:0]            pkt_q_table_tails_wr_data_a_r2;

// update pkt_q_status to indicate if a pkt queue needs a descriptor
always @(posedge clk) begin
    if (queue_rd_en_r) begin
        pkt_q_needs_dsc <= !pkt_q_status[rd_pkt_queue_r];
        pkt_q_status[rd_pkt_queue_r] <= 1'b1;
    end

    if (rst) begin
        pkt_q_status <= 0;
    end else if (queue_updated) begin
        // update queue status so that we send a descriptor next time
        pkt_q_status[updated_queue_idx] <= 1'b0;
        // FIXME(sadok) this will only work if the queue eventually
        // receives more packets. Otherwise, there will be some residue
        // packets that software will never know about. To fix this, we
        // need to check if the latest tail pointer is greater than the
        // new head that we received. If it is, that means that we need
        // to send an extra descriptor. The logic to send an extra
        // descriptor, however, is quite tricky. We probably need to add
        // a queue with `descriptor requests` to send to the fpga2cpu so
        // that it can send these descriptor when it has a chance -- it
        // may even ignore some of them if it receives a new packet for
        // the queue. Another tricky part is that there may be some race
        // conditions, where this part of the design thinks that the
        // queue is updated but the fpga2cpu is processing a new packet
        // and will not send a descriptor. To overcome this, fpga2cpu
        // should make sure pcie_top has the latest tail, before it
        // decides if it needs to send the descriptor.
    end
end

always @(posedge clk)begin
    dsc_q_table_a_tails_rd_en_r <= dsc_q_table_a_tails.rd_en;
    dsc_q_table_a_tails_rd_en_r2 <= dsc_q_table_a_tails_rd_en_r;
    dsc_q_table_a_heads_rd_en_r <= dsc_q_table_a_heads.rd_en;
    dsc_q_table_a_heads_rd_en_r2 <= dsc_q_table_a_heads_rd_en_r;
    dsc_q_table_a_l_addrs_rd_en_r <= dsc_q_table_a_l_addrs.rd_en;
    dsc_q_table_a_l_addrs_rd_en_r2 <= dsc_q_table_a_l_addrs_rd_en_r;
    dsc_q_table_a_h_addrs_rd_en_r <= dsc_q_table_a_h_addrs.rd_en;
    dsc_q_table_a_h_addrs_rd_en_r2 <= dsc_q_table_a_h_addrs_rd_en_r;

    pkt_q_table_a_tails_rd_en_r <= pkt_q_table_a_tails.rd_en;
    pkt_q_table_a_tails_rd_en_r2 <= pkt_q_table_a_tails_rd_en_r;
    pkt_q_table_a_heads_rd_en_r <= pkt_q_table_a_heads.rd_en;
    pkt_q_table_a_heads_rd_en_r2 <= pkt_q_table_a_heads_rd_en_r;
    pkt_q_table_a_l_addrs_rd_en_r <= pkt_q_table_a_l_addrs.rd_en;
    pkt_q_table_a_l_addrs_rd_en_r2 <= pkt_q_table_a_l_addrs_rd_en_r;
    pkt_q_table_a_h_addrs_rd_en_r <= pkt_q_table_a_h_addrs.rd_en;
    pkt_q_table_a_h_addrs_rd_en_r2 <= pkt_q_table_a_h_addrs_rd_en_r;

    // we used the delayed wr signals for head and tail to use when there are
    // concurrent reads
    dsc_q_table_heads_wr_data_b_r <= dsc_q_table_heads.wr_data[RB_AWIDTH-1:0];
    dsc_q_table_heads_wr_data_b_r2 <= dsc_q_table_heads_wr_data_b_r;
    dsc_q_table_tails_wr_data_a_r <= dsc_q_table_a_tails.wr_data[RB_AWIDTH-1:0];
    dsc_q_table_tails_wr_data_a_r2 <= dsc_q_table_tails_wr_data_a_r;
    
    pkt_q_table_heads_wr_data_b_r <= pkt_q_table_heads.wr_data[RB_AWIDTH-1:0];
    pkt_q_table_heads_wr_data_b_r2 <= pkt_q_table_heads_wr_data_b_r;
    pkt_q_table_tails_wr_data_a_r <= pkt_q_table_a_tails.wr_data[RB_AWIDTH-1:0];
    pkt_q_table_tails_wr_data_a_r2 <= pkt_q_table_tails_wr_data_a_r;

    queue_rd_en_r <= queue_rd_en;
    rd_pkt_queue_r <= rd_pkt_queue;
end

always_comb begin
    dsc_q_table_a_tails.addr = rd_dsc_queue;
    dsc_q_table_a_heads.addr = rd_dsc_queue;
    dsc_q_table_a_l_addrs.addr = rd_dsc_queue;
    dsc_q_table_a_h_addrs.addr = rd_dsc_queue;
    pkt_q_table_a_tails.addr = rd_pkt_queue;
    pkt_q_table_a_heads.addr = rd_pkt_queue;
    pkt_q_table_a_l_addrs.addr = rd_pkt_queue;
    pkt_q_table_a_h_addrs.addr = rd_pkt_queue;

    dsc_q_table_a_tails.rd_en = 0;
    dsc_q_table_a_heads.rd_en = 0;
    dsc_q_table_a_l_addrs.rd_en = 0;
    dsc_q_table_a_h_addrs.rd_en = 0;
    pkt_q_table_a_tails.rd_en = 0;
    pkt_q_table_a_heads.rd_en = 0;
    pkt_q_table_a_l_addrs.rd_en = 0;
    pkt_q_table_a_h_addrs.rd_en = 0;

    dsc_q_table_a_tails.wr_en = 0;
    dsc_q_table_a_heads.wr_en = 0;
    dsc_q_table_a_l_addrs.wr_en = 0;
    dsc_q_table_a_h_addrs.wr_en = 0;
    pkt_q_table_a_tails.wr_en = 0;
    pkt_q_table_a_heads.wr_en = 0;
    pkt_q_table_a_l_addrs.wr_en = 0;
    pkt_q_table_a_h_addrs.wr_en = 0;

    dsc_q_table_a_tails.wr_data = new_dsc_tail;
    pkt_q_table_a_tails.wr_data = new_pkt_tail;

    if (queue_rd_en) begin
        // when reading and writing the same queue, we avoid reading the tail
        // and use the new written tail instead
        dsc_q_table_a_tails.rd_en = !tail_wr_en 
            || (rd_dsc_queue != wr_dsc_queue);
        dsc_q_table_a_heads.rd_en = 1;
        dsc_q_table_a_l_addrs.rd_en = 1;
        dsc_q_table_a_h_addrs.rd_en = 1;
        pkt_q_table_a_tails.rd_en = !tail_wr_en 
            || (rd_pkt_queue != wr_pkt_queue);
        pkt_q_table_a_heads.rd_en = 1;
        pkt_q_table_a_l_addrs.rd_en = 1;
        pkt_q_table_a_h_addrs.rd_en = 1;

        // Concurrent head write from PCIe or JTAG, we bypass the read and use
        // the new written value instead. This is done to prevent concurrent
        // read and write to the same address, which causes undefined behavior.
        if ((dsc_q_table_a_heads.addr == dsc_q_table_heads.addr) 
                && dsc_q_table_heads.wr_en) begin
            dsc_q_table_a_heads.rd_en = 0;
        end
        if ((pkt_q_table_a_heads.addr == pkt_q_table_heads.addr) 
                && pkt_q_table_heads.wr_en) begin
            pkt_q_table_a_heads.rd_en = 0;
        end
    end else if (tail_wr_en) begin
        dsc_q_table_a_tails.wr_en = 1;
        dsc_q_table_a_tails.addr = wr_dsc_queue;
        pkt_q_table_a_tails.wr_en = 1;
        pkt_q_table_a_tails.addr = wr_pkt_queue;
    end

    queue_ready = 
        dsc_q_table_a_tails_rd_en_r2   || dsc_q_table_a_heads_rd_en_r2   ||
        dsc_q_table_a_l_addrs_rd_en_r2 || dsc_q_table_a_h_addrs_rd_en_r2 ||
        pkt_q_table_a_tails_rd_en_r2   || pkt_q_table_a_heads_rd_en_r2   ||
        pkt_q_table_a_l_addrs_rd_en_r2 || pkt_q_table_a_h_addrs_rd_en_r2;

    if (dsc_q_table_a_tails_rd_en_r2) begin
        dsc_tail = dsc_q_table_a_tails.rd_data[RB_AWIDTH-1:0];
    end else begin
        dsc_tail = dsc_q_table_tails_wr_data_a_r2;
    end
    if (pkt_q_table_a_tails_rd_en_r2) begin
        pkt_tail = pkt_q_table_a_tails.rd_data[RB_AWIDTH-1:0];
    end else begin
        pkt_tail = pkt_q_table_tails_wr_data_a_r2;
    end

    if (dsc_q_table_a_heads_rd_en_r2) begin
        dsc_head = dsc_q_table_a_heads.rd_data[RB_AWIDTH-1:0];
    end else begin
        // return the delayed concurrent write
        dsc_head = dsc_q_table_heads_wr_data_b_r2;
    end
    if (pkt_q_table_a_heads_rd_en_r2) begin
        pkt_head = pkt_q_table_a_heads.rd_data[RB_AWIDTH-1:0];
    end else begin
        // return the delayed concurrent write
        pkt_head = pkt_q_table_heads_wr_data_b_r2;
    end

    dsc_buf_addr[31:0] = dsc_q_table_a_l_addrs.rd_data;
    dsc_buf_addr[63:32] = dsc_q_table_a_h_addrs.rd_data;
    pkt_buf_addr[31:0] = pkt_q_table_a_l_addrs.rd_data;
    pkt_buf_addr[63:32] = pkt_q_table_a_h_addrs.rd_data;
end

////////////////////////
// Packet Queue BRAMs //
////////////////////////

bram_true2port #(
    .AWIDTH(PKT_Q_TABLE_AWIDTH),
    .DWIDTH(PKT_Q_TABLE_TAILS_DWIDTH),
    .DEPTH(PKT_Q_TABLE_DEPTH)
)
pkt_q_table_tails_bram (
    .address_a  (pkt_q_table_a_tails.addr[PKT_Q_TABLE_AWIDTH-1:0]),
    .address_b  (pkt_q_table_tails.addr[PKT_Q_TABLE_AWIDTH-1:0]),
    .clock      (clk),
    .data_a     (pkt_q_table_a_tails.wr_data),
    .data_b     (pkt_q_table_tails.wr_data),
    .rden_a     (pkt_q_table_a_tails.rd_en),
    .rden_b     (pkt_q_table_tails.rd_en),
    .wren_a     (pkt_q_table_a_tails.wr_en),
    .wren_b     (pkt_q_table_tails.wr_en),
    .q_a        (pkt_q_table_a_tails.rd_data),
    .q_b        (pkt_q_table_tails.rd_data)
);

bram_true2port #(
    .AWIDTH(PKT_Q_TABLE_AWIDTH),
    .DWIDTH(PKT_Q_TABLE_HEADS_DWIDTH),
    .DEPTH(PKT_Q_TABLE_DEPTH)
)
pkt_q_table_heads_bram (
    .address_a  (pkt_q_table_a_heads.addr[PKT_Q_TABLE_AWIDTH-1:0]),
    .address_b  (pkt_q_table_heads.addr[PKT_Q_TABLE_AWIDTH-1:0]),
    .clock      (clk),
    .data_a     (pkt_q_table_a_heads.wr_data),
    .data_b     (pkt_q_table_heads.wr_data),
    .rden_a     (pkt_q_table_a_heads.rd_en),
    .rden_b     (pkt_q_table_heads.rd_en),
    .wren_a     (pkt_q_table_a_heads.wr_en),
    .wren_b     (pkt_q_table_heads.wr_en),
    .q_a        (pkt_q_table_a_heads.rd_data),
    .q_b        (pkt_q_table_heads.rd_data)
);

bram_true2port #(
    .AWIDTH(PKT_Q_TABLE_AWIDTH),
    .DWIDTH(PKT_Q_TABLE_L_ADDRS_DWIDTH),
    .DEPTH(PKT_Q_TABLE_DEPTH)
)
pkt_q_table_l_addrs_bram (
    .address_a  (pkt_q_table_a_l_addrs.addr[PKT_Q_TABLE_AWIDTH-1:0]),
    .address_b  (pkt_q_table_l_addrs.addr[PKT_Q_TABLE_AWIDTH-1:0]),
    .clock      (clk),
    .data_a     (pkt_q_table_a_l_addrs.wr_data),
    .data_b     (pkt_q_table_l_addrs.wr_data),
    .rden_a     (pkt_q_table_a_l_addrs.rd_en),
    .rden_b     (pkt_q_table_l_addrs.rd_en),
    .wren_a     (pkt_q_table_a_l_addrs.wr_en),
    .wren_b     (pkt_q_table_l_addrs.wr_en),
    .q_a        (pkt_q_table_a_l_addrs.rd_data),
    .q_b        (pkt_q_table_l_addrs.rd_data)
);

bram_true2port #(
    .AWIDTH(PKT_Q_TABLE_AWIDTH),
    .DWIDTH(PKT_Q_TABLE_H_ADDRS_DWIDTH),
    .DEPTH(PKT_Q_TABLE_DEPTH)
)
pkt_q_table_h_addrs_bram (
    .address_a  (pkt_q_table_a_h_addrs.addr[PKT_Q_TABLE_AWIDTH-1:0]),
    .address_b  (pkt_q_table_h_addrs.addr[PKT_Q_TABLE_AWIDTH-1:0]),
    .clock      (clk),
    .data_a     (pkt_q_table_a_h_addrs.wr_data),
    .data_b     (pkt_q_table_h_addrs.wr_data),
    .rden_a     (pkt_q_table_a_h_addrs.rd_en),
    .rden_b     (pkt_q_table_h_addrs.rd_en),
    .wren_a     (pkt_q_table_a_h_addrs.wr_en),
    .wren_b     (pkt_q_table_h_addrs.wr_en),
    .q_a        (pkt_q_table_a_h_addrs.rd_data),
    .q_b        (pkt_q_table_h_addrs.rd_data)
);

////////////////////////////
// Descriptor Queue BRAMs //
////////////////////////////

bram_true2port #(
    .AWIDTH(DSC_Q_TABLE_AWIDTH),
    .DWIDTH(DSC_Q_TABLE_TAILS_DWIDTH),
    .DEPTH(DSC_Q_TABLE_DEPTH)
)
dsc_q_table_tails_bram (
    .address_a  (dsc_q_table_a_tails.addr[DSC_Q_TABLE_AWIDTH-1:0]),
    .address_b  (dsc_q_table_tails.addr[DSC_Q_TABLE_AWIDTH-1:0]),
    .clock      (clk),
    .data_a     (dsc_q_table_a_tails.wr_data),
    .data_b     (dsc_q_table_tails.wr_data),
    .rden_a     (dsc_q_table_a_tails.rd_en),
    .rden_b     (dsc_q_table_tails.rd_en),
    .wren_a     (dsc_q_table_a_tails.wr_en),
    .wren_b     (dsc_q_table_tails.wr_en),
    .q_a        (dsc_q_table_a_tails.rd_data),
    .q_b        (dsc_q_table_tails.rd_data)
);

bram_true2port #(
    .AWIDTH(DSC_Q_TABLE_AWIDTH),
    .DWIDTH(DSC_Q_TABLE_HEADS_DWIDTH),
    .DEPTH(DSC_Q_TABLE_DEPTH)
)
dsc_q_table_heads_bram (
    .address_a  (dsc_q_table_a_heads.addr[DSC_Q_TABLE_AWIDTH-1:0]),
    .address_b  (dsc_q_table_heads.addr[DSC_Q_TABLE_AWIDTH-1:0]),
    .clock      (clk),
    .data_a     (dsc_q_table_a_heads.wr_data),
    .data_b     (dsc_q_table_heads.wr_data),
    .rden_a     (dsc_q_table_a_heads.rd_en),
    .rden_b     (dsc_q_table_heads.rd_en),
    .wren_a     (dsc_q_table_a_heads.wr_en),
    .wren_b     (dsc_q_table_heads.wr_en),
    .q_a        (dsc_q_table_a_heads.rd_data),
    .q_b        (dsc_q_table_heads.rd_data)
);

bram_true2port #(
    .AWIDTH(DSC_Q_TABLE_AWIDTH),
    .DWIDTH(DSC_Q_TABLE_L_ADDRS_DWIDTH),
    .DEPTH(DSC_Q_TABLE_DEPTH)
)
dsc_q_table_l_addrs_bram (
    .address_a  (dsc_q_table_a_l_addrs.addr[DSC_Q_TABLE_AWIDTH-1:0]),
    .address_b  (dsc_q_table_l_addrs.addr[DSC_Q_TABLE_AWIDTH-1:0]),
    .clock      (clk),
    .data_a     (dsc_q_table_a_l_addrs.wr_data),
    .data_b     (dsc_q_table_l_addrs.wr_data),
    .rden_a     (dsc_q_table_a_l_addrs.rd_en),
    .rden_b     (dsc_q_table_l_addrs.rd_en),
    .wren_a     (dsc_q_table_a_l_addrs.wr_en),
    .wren_b     (dsc_q_table_l_addrs.wr_en),
    .q_a        (dsc_q_table_a_l_addrs.rd_data),
    .q_b        (dsc_q_table_l_addrs.rd_data)
);

bram_true2port #(
    .AWIDTH(DSC_Q_TABLE_AWIDTH),
    .DWIDTH(DSC_Q_TABLE_H_ADDRS_DWIDTH),
    .DEPTH(DSC_Q_TABLE_DEPTH)
)
dsc_q_table_h_addrs_bram (
    .address_a  (dsc_q_table_a_h_addrs.addr[DSC_Q_TABLE_AWIDTH-1:0]),
    .address_b  (dsc_q_table_h_addrs.addr[DSC_Q_TABLE_AWIDTH-1:0]),
    .clock      (clk),
    .data_a     (dsc_q_table_a_h_addrs.wr_data),
    .data_b     (dsc_q_table_h_addrs.wr_data),
    .rden_a     (dsc_q_table_a_h_addrs.rd_en),
    .rden_b     (dsc_q_table_h_addrs.rd_en),
    .wren_a     (dsc_q_table_a_h_addrs.wr_en),
    .wren_b     (dsc_q_table_h_addrs.wr_en),
    .q_a        (dsc_q_table_a_h_addrs.rd_data),
    .q_b        (dsc_q_table_h_addrs.rd_data)
);

// unused inputs
assign dsc_q_table_a_heads.wr_data = 32'bx;
assign dsc_q_table_a_l_addrs.wr_data = 32'bx;
assign dsc_q_table_a_h_addrs.wr_data = 32'bx;
assign pkt_q_table_a_heads.wr_data = 32'bx;
assign pkt_q_table_a_l_addrs.wr_data = 32'bx;
assign pkt_q_table_a_h_addrs.wr_data = 32'bx;

endmodule
