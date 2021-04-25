`include "../constants.sv"
`include "pcie_consts.sv"

/*
 * This module fetches reads the packet data and metadata and issues DMAs to 
 * write both the packet and the descriptor to main memory.
 */

module fpga_to_cpu (
    input logic clk,
    input logic rst,

    // packet buffer input and status
    input  var flit_lite_t           pkt_buf_in_data,
    input  logic                     pkt_buf_in_valid,
    output logic                     pkt_buf_in_ready,
    output logic [F2C_RB_AWIDTH-1:0] pkt_buf_occup,

    // metadata buffer input and status
    input  var pkt_meta_with_queues_t metadata_buf_in_data,
    input  logic                      metadata_buf_in_valid,
    output logic                      metadata_buf_in_ready,
    output logic [F2C_RB_AWIDTH-1:0]  metadata_buf_occup,

    // CPU ring buffer config signals
    input  logic [25:0] pkt_rb_size,
    input  logic [25:0] dsc_rb_size,

    // PCIe BAS
    input  logic         pcie_bas_waitrequest,
    output logic [63:0]  pcie_bas_address,
    output logic [63:0]  pcie_bas_byteenable,
    output logic         pcie_bas_read,
    input  logic [511:0] pcie_bas_readdata,
    input  logic         pcie_bas_readdatavalid,
    output logic         pcie_bas_write,
    output logic [511:0] pcie_bas_writedata,
    output logic [3:0]   pcie_bas_burstcount,
    input  logic [1:0]   pcie_bas_response,

    // Counter reset
    input logic sw_reset,

    // Counters TODO(sadok) MAKE SURE TO INCREMENT THOSE!
    output logic [31:0] dma_queue_full_cnt,
    output logic [31:0] cpu_pkt_buf_full_cnt,
    output logic [31:0] cpu_dsc_buf_full_cnt
);

// assign wr_base_addr = 0;
// assign wr_base_addr_valid = 0;
// assign almost_full = 0;
assign pcie_bas_read = 0;

flit_lite_t pkt_buf_out_data;
logic       pkt_buf_out_ready;
logic       pkt_buf_out_valid;

pkt_meta_t  metadata_buf_out_data;
logic       metadata_buf_out_ready;
logic       metadata_buf_out_valid;

logic [31:0] dma_queue_full_cnt_r;
logic [31:0] cpu_dsc_buf_full_cnt_r;
logic [31:0] cpu_pkt_buf_full_cnt_r;

logic [63:0]  pcie_bas_address_r;
logic [63:0]  pcie_bas_byteenable_r;
logic         pcie_bas_write_r;
logic [511:0] pcie_bas_writedata_r;
logic [3:0]   pcie_bas_burstcount_r;

typedef struct packed
{
    pkt_meta_with_queues_t pkt_meta;
    logic [3:0] missing_flits_in_transfer;
} transf_meta_t;

transf_meta_t transf_meta;

function pkt_meta_with_queues_t dma_pkt(
    flit_lite_t            data,
    pkt_meta_with_queues_t meta,
    logic [3:0]            flits_in_transfer
    // TODO(sadok) expose byteenable?
);
    if (meta.pkt_q_state.kmem_addr && meta.dsc_q_state.kmem_addr) begin
        automatic pkt_meta_with_queues_t return_meta;

        // Assume that it is a burst when flits_in_transfer == 0, no need to set 
        // address.
        if (flits_in_transfer != 0) begin
            pcie_bas_address_r <= meta.pkt_q_state.kmem_addr
                                  + 64 * meta.pkt_q_state.tail;
        end

        pcie_bas_byteenable_r <= 64'hffffffffffffffff;
        pcie_bas_writedata_r <= data.data;
        pcie_bas_write_r <= 1;
        pcie_bas_burstcount_r <= flits_in_transfer;

        return_meta = meta;
        return_meta.pkt_q_state.tail = get_new_pointer(
            meta.pkt_q_state.tail, 1, pkt_rb_size[RB_AWIDTH-1:0]
        );
        return_meta.size = meta.size - 1;

        return return_meta;
    end
    return meta;
endfunction

function transf_meta_t start_burst(
    flit_lite_t            data,
    pkt_meta_with_queues_t meta
);
    automatic transf_meta_t return_meta;
    // Skip when addresses are not defined.
    if (meta.pkt_q_state.kmem_addr && meta.dsc_q_state.kmem_addr) begin
        automatic logic [3:0] flits_in_transfer;

        // max 8 flits per burst
        if (meta.size > 8) begin
            flits_in_transfer = 8;
        end else begin
            flits_in_transfer = meta.size[3:0];
        end

        if (meta.size == 1) begin
            assert(data.sop);
        end

        // The DMA transfer cannot go across the buffer limit.
        if (flits_in_transfer > (pkt_rb_size[RB_AWIDTH-1:0] 
                                - meta.pkt_q_state.tail)) begin
            flits_in_transfer = pkt_rb_size[RB_AWIDTH-1:0]
                                - meta.pkt_q_state.tail;
        end

        return_meta.pkt_meta = dma_pkt(data, meta, flits_in_transfer);
        return_meta.missing_flits_in_transfer = flits_in_transfer - 1;
    end else begin
        return_meta.pkt_meta = meta;
        return_meta.missing_flits_in_transfer = 0;
    end
    return return_meta; 
endfunction

logic [RB_AWIDTH-1:0] dsc_free_slot;
logic [RB_AWIDTH-1:0] pkt_free_slot;

// TODO(sadok) We should check if there is room much earlier in the pipeline.
// The way it is currently implemented, we are advancing the ring buffer
// pointers in the queue management modules so when we get here we have no
// choice -- we must DMA the packet. The problem is that this may cause
// head-of-line blocking.
function logic is_ready_to_dma(
    pkt_meta_with_queues_t meta
);
    // Always have at least one slot not occupied in both the
    // descriptor ring buffer and the packet ring buffer
    if (meta.dsc_q_state.tail >= meta.dsc_q_state.head) begin
        dsc_free_slot = dsc_rb_size[RB_AWIDTH-1:0] - meta.dsc_q_state.tail
                        + meta.dsc_q_state.head - 1'b1;
    end else begin
        dsc_free_slot = meta.dsc_q_state.head - meta.dsc_q_state.tail - 1'b1;
    end
    if (meta.pkt_q_state.tail >= meta.pkt_q_state.head) begin
        pkt_free_slot = pkt_rb_size[RB_AWIDTH-1:0] - meta.pkt_q_state.tail
                        + meta.pkt_q_state.head - 1'b1;
    end else begin
        pkt_free_slot = meta.pkt_q_state.head - meta.pkt_q_state.tail - 1'b1;
    end

    // We may set the writing signals even when pcie_bas_waitrequest
    // is set, but we must make sure that they remain active until
    // pcie_bas_waitrequest is unset. So we are checking this signal
    // not to ensure that we are able to write but instead to make
    // sure that any write request in the previous cycle is complete
    return (pkt_free_slot >= meta.size) && (dsc_free_slot != 0)
        && pkt_buf_out_valid && metadata_buf_out_valid && !pcie_bas_waitrequest;
endfunction

pkt_meta_with_queues_t cur_meta;

logic can_start_transfer;
logic can_continue_transfer;

logic rst_r;

typedef enum
{
    START_TRANSFER,
    COMPLETE_BURST,
    START_BURST,
    SEND_DESCRIPTOR
} state_t;

state_t state;

// Consume requests and issue DMAs
always @(posedge clk) begin
    rst_r <= rst;

    // Make sure the previous transfer is complete before setting
    // pcie_bas_write_r to 0.
    if (!pcie_bas_waitrequest) begin
        pcie_bas_write_r <= 0;
    end else begin
        dma_queue_full_cnt_r <= dma_queue_full_cnt_r + 1;
    end

    if (rst_r | sw_reset) begin
        state <= START_TRANSFER;
        dma_queue_full_cnt_r <= 0;
        cpu_dsc_buf_full_cnt_r <= 0;
        cpu_pkt_buf_full_cnt_r <= 0;
        pcie_bas_write_r <= 0;
    end else begin
        case (state)
            START_TRANSFER: begin
                if (can_start_transfer) begin
                    automatic transf_meta_t next_transf_meta;

                    $display("Can start transfer! (cur_meta.needs_dsc: %b)", cur_meta.needs_dsc);
                    $display("pcie_bas_write: %b  pcie_bas_write_r: %b", pcie_bas_write, pcie_bas_write_r);
                    next_transf_meta = start_burst(pkt_buf_out_data, cur_meta);
                    transf_meta <= next_transf_meta;

                    if (next_transf_meta.missing_flits_in_transfer != 0) begin
                        state <= COMPLETE_BURST;
                    end else if (cur_meta.size > 1) begin
                        // When we can only send a single packet in a burst, we
                        // need to jump directly to START_BURST.
                        state <= START_BURST;
                    end else if (cur_meta.needs_dsc) begin
                        state <= SEND_DESCRIPTOR;
                    end else begin
                        $display("-> START_TRANSFER");
                        state <= START_TRANSFER;
                    end
                end
            end
            COMPLETE_BURST: begin
                if (can_continue_transfer) begin
                    $display("COMPLETE_BURST: Can continue transfer!");
                    // Setting flits_in_transfer to 0 indicates that this is
                    // continuing a burst.
                    transf_meta.pkt_meta <= 
                        dma_pkt(pkt_buf_out_data, transf_meta.pkt_meta, 0);
                    transf_meta.missing_flits_in_transfer <=
                        transf_meta.missing_flits_in_transfer - 1;

                    // last flit in burst
                    if (transf_meta.missing_flits_in_transfer == 1) begin
                        if (transf_meta.pkt_meta.size > 1) begin
                            state <= START_BURST;
                        end else if (transf_meta.pkt_meta.needs_dsc) begin
                            state <= SEND_DESCRIPTOR;
                        end else begin
                            state <= START_TRANSFER;
                        end
                    end
                end
            end
            START_BURST: begin
                // Some transfers need multiple bursts, we use this state to
                // issue new bursts to the same transfer.

                if (can_continue_transfer) begin
                    $display("START_BURST: Can continue transfer!");
                    transf_meta <=
                        start_burst(pkt_buf_out_data, transf_meta.pkt_meta);

                    if (transf_meta.pkt_meta.size > 1) begin
                        state <= COMPLETE_BURST;
                    end else if (transf_meta.pkt_meta.needs_dsc) begin
                        state <= SEND_DESCRIPTOR;
                    end else begin
                        state <= START_TRANSFER;
                    end
                end
            end
            SEND_DESCRIPTOR: begin
                if (can_continue_transfer) begin
                    automatic pcie_pkt_dsc_t pcie_pkt_desc;

                    $display("SEND_DESCRIPTOR: Can continue transfer!");
                    pcie_pkt_desc.signal = 1;
                    pcie_pkt_desc.tail = {
                        {{$bits(pcie_pkt_desc.tail) - RB_AWIDTH}{1'b0}},
                        transf_meta.pkt_meta.pkt_q_state.tail
                    };
                    pcie_pkt_desc.queue_id = transf_meta.pkt_meta.pkt_queue_id;
                    pcie_pkt_desc.pad = 0;

                    // Skip DMA when addresses are not set
                    if (transf_meta.pkt_meta.pkt_q_state.kmem_addr
                        && transf_meta.pkt_meta.dsc_q_state.kmem_addr)
                    begin
                        pcie_bas_address_r <= 
                            transf_meta.pkt_meta.dsc_q_state.kmem_addr
                            + 64 * transf_meta.pkt_meta.dsc_q_state.tail;
                        pcie_bas_byteenable_r <= 64'hffffffffffffffff;
                        pcie_bas_writedata_r <= pcie_pkt_desc;
                        pcie_bas_write_r <= 1;
                        pcie_bas_burstcount_r <= 1;
                    end

                    state <= START_TRANSFER;
                end
            end
        endcase
    end
end

// Extra registers to help with timing.
always @(posedge clk) begin
    if (!pcie_bas_waitrequest) begin
        pcie_bas_address <= pcie_bas_address_r;
        pcie_bas_byteenable <= pcie_bas_byteenable_r;
        pcie_bas_write <= pcie_bas_write_r;
        pcie_bas_writedata <= pcie_bas_writedata_r;
        pcie_bas_burstcount <= pcie_bas_burstcount_r;

        dma_queue_full_cnt <= dma_queue_full_cnt_r;
        cpu_dsc_buf_full_cnt <= cpu_dsc_buf_full_cnt_r;
        cpu_pkt_buf_full_cnt <= cpu_pkt_buf_full_cnt_r;
    end
end

// Check if we are able to DMA the packet or descriptor
always_comb begin
    cur_meta = metadata_buf_out_data;

    can_start_transfer = is_ready_to_dma(cur_meta);
    can_continue_transfer = is_ready_to_dma(transf_meta.pkt_meta);

    metadata_buf_out_ready = can_start_transfer && (state == START_TRANSFER);
    pkt_buf_out_ready = metadata_buf_out_ready ||
                        (can_continue_transfer && (state != SEND_DESCRIPTOR));
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
    .in_data       (pkt_buf_in_data),
    .in_valid      (pkt_buf_in_valid),
    .in_ready      (pkt_buf_in_ready),
    .out_data      (pkt_buf_out_data),
    .out_valid     (pkt_buf_out_valid),
    .out_ready     (pkt_buf_out_ready)
);

// Metadata buffer. This was sized considering the worst case -- where all
// packets are min-sized. We may use a smaller buffer here to save BRAM.
fifo_wrapper_infill #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL($bits(pkt_meta_t)),
    .FIFO_DEPTH(F2C_RB_DEPTH)
)
metadata_buf (
    .clk           (clk),
    .reset         (rst),
    .csr_address   (2'b0),
    .csr_read      (1'b1),
    .csr_write     (1'b0),
    .csr_readdata  (metadata_buf_occup),
    .csr_writedata (32'b0),
    .in_data       (metadata_buf_in_data),
    .in_valid      (metadata_buf_in_valid),
    .in_ready      (metadata_buf_in_ready),
    .out_data      (metadata_buf_out_data),
    .out_valid     (metadata_buf_out_valid),
    .out_ready     (metadata_buf_out_ready)
);

endmodule
