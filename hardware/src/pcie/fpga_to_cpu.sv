`include "pcie_consts.sv"

/*
 * This module reads the next packet data and metadata and issues DMAs to write
 * both the packet and the descriptor to main memory.
 */

module fpga_to_cpu (
  input logic clk,
  input logic rst,

  // packet buffer input and status
  input  var flit_lite_t         pkt_buf_in_data,
  input  logic                   pkt_buf_in_valid,
  output logic                   pkt_buf_in_ready,
  output logic [F2C_RB_AWIDTH:0] pkt_buf_occup,

  // metadata buffer input and status
  input  var pkt_meta_with_queues_t metadata_buf_in_data,
  input  logic                      metadata_buf_in_valid,
  output logic                      metadata_buf_in_ready,
  output logic [F2C_RB_AWIDTH:0]    metadata_buf_occup,

  // tx completion notification buffer input and status
  input  var tx_transfer_t tx_compl_buf_in_data,
  input  logic             tx_compl_buf_in_valid,
  output logic             tx_compl_buf_in_ready,
  output logic [31:0]      tx_compl_buf_occup,

  // CPU ring buffer config signals
  input  logic [RB_AWIDTH:0] pkt_rb_size,
  input  logic [RB_AWIDTH:0] dsc_rb_size,

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

  // Counters
  output logic [31:0] dma_queue_full_cnt
);

assign pcie_bas_read = 0;

logic [RB_AWIDTH:0]   dsc_rb_size_r;
logic [RB_AWIDTH:0]   pkt_rb_size_r;
logic [RB_AWIDTH-1:0] dsc_rb_mask;
logic [RB_AWIDTH-1:0] pkt_rb_mask;

always @(posedge clk) begin
  dsc_rb_size_r <= dsc_rb_size;
  pkt_rb_size_r <= pkt_rb_size;
  dsc_rb_mask <= dsc_rb_size - 1;
  pkt_rb_mask <= pkt_rb_size - 1;
end

flit_lite_t pkt_buf_out_data;
logic       pkt_buf_out_ready;
logic       pkt_buf_out_valid;

pkt_meta_with_queues_t  metadata_buf_out_data;
pkt_meta_with_queues_t  metadata_buf_out_data_r;
logic                   metadata_buf_out_valid;
logic                   metadata_buf_out_valid_r;
logic                   metadata_buf_out_ready;

tx_transfer_t tx_compl_buf_out_data;
logic         tx_compl_buf_out_valid;
logic         tx_compl_buf_out_ready;

logic [31:0] dma_queue_full_cnt_r;

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

function void dma_pkt(
  flit_lite_t            data,
  pkt_meta_with_queues_t meta,
  logic [3:0]            flits_in_transfer
  // TODO(sadok) expose byteenable?
);
  if (meta.pkt_q_state.kmem_addr && meta.dsc_q_state.kmem_addr) begin
    // Assume that it is a burst when flits_in_transfer == 0, no need to set
    // address.
    if (flits_in_transfer != 0) begin
      pcie_bas_address_r <=
        meta.pkt_q_state.kmem_addr + 64 * meta.pkt_q_state.tail;
    end

    pcie_bas_byteenable_r <= 64'hffffffffffffffff;
    pcie_bas_writedata_r <= data.data;
    pcie_bas_write_r <= 1;
    pcie_bas_burstcount_r <= flits_in_transfer;

    if (meta.drop) begin
      pcie_bas_write_r <= 0;
    end

    transf_meta.pkt_meta.pkt_q_state.tail <=
      (meta.pkt_q_state.tail + 1) & pkt_rb_mask;
    transf_meta.pkt_meta.size <= meta.size - 1;
  end
endfunction

function logic [3:0] start_burst(
  flit_lite_t            data,
  pkt_meta_with_queues_t meta
);
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
    if (flits_in_transfer > (pkt_rb_size_r[RB_AWIDTH-1:0]
                             - meta.pkt_q_state.tail)) begin
      flits_in_transfer = pkt_rb_size_r[RB_AWIDTH-1:0] - meta.pkt_q_state.tail;
    end

    dma_pkt(data, meta, flits_in_transfer);
    return flits_in_transfer - 1;
  end else begin
    return 0;
  end
endfunction

typedef enum
{
  START_TRANSFER,
  COMPLETE_BURST,
  START_BURST,
  SEND_DESCRIPTOR
} state_t;

state_t state;

// We may set the writing signals even when pcie_bas_waitrequest is set, but we
// must make sure that they remain active until pcie_bas_waitrequest is unset.
// So we are checking this signal not to ensure that we are able to write but
// instead to ensure that any write request in the previous cycle is complete.
logic can_continue_dma;
assign can_continue_dma = pkt_buf_out_valid && !pcie_bas_waitrequest;

pkt_meta_with_queues_t cur_meta;

logic can_send_tx_completion;
logic can_start_transfer;

// Consume requests and issue DMAs
always @(posedge clk) begin
  if (rst | sw_reset) begin
    state <= START_TRANSFER;
    dma_queue_full_cnt_r <= 0;
    pcie_bas_write_r <= 0;
  end else begin
    // Make sure the previous transfer is complete before setting
    // pcie_bas_write_r to 0.
    if (!pcie_bas_waitrequest) begin
      pcie_bas_write_r <= 0;
    end else begin
      dma_queue_full_cnt_r <= dma_queue_full_cnt_r + 1;
    end
    case (state)
      START_TRANSFER: begin
        // Try to send tx completion before the next packet.
        if (can_send_tx_completion) begin
          automatic pcie_tx_dsc_t tx_dsc;

          tx_dsc.signal = 0;
          tx_dsc.addr = tx_compl_buf_out_data.transfer_addr;
          tx_dsc.length = tx_compl_buf_out_data.length;
          tx_dsc.pad = 0;

          pcie_bas_address_r <= tx_compl_buf_out_data.descriptor_addr;
          pcie_bas_byteenable_r <= 64'hffffffffffffffff;
          pcie_bas_writedata_r <= tx_dsc;
          pcie_bas_write_r <= 1;
          pcie_bas_burstcount_r <= 1;
        end else if (can_start_transfer) begin
          automatic logic [3:0] missing_flits_in_transfer;

          transf_meta.pkt_meta <= cur_meta;
          missing_flits_in_transfer = start_burst(pkt_buf_out_data, cur_meta);
          transf_meta.missing_flits_in_transfer <= missing_flits_in_transfer;

          if (missing_flits_in_transfer != 0) begin
            state <= COMPLETE_BURST;
          end else if (cur_meta.size > 1) begin
            // When we can only send a single flit in a burst, we need to jump
            // directly to START_BURST.
            state <= START_BURST;
          end else if (cur_meta.needs_dsc) begin
            state <= SEND_DESCRIPTOR;
          end else begin
            state <= START_TRANSFER;
          end
        end
      end
      COMPLETE_BURST: begin
        if (can_continue_dma) begin
          // Setting flits_in_transfer to 0 indicates that this is continuing a
          // burst.
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
        // Some transfers need multiple bursts, we use this state to issue new
        // bursts to the same transfer.
        if (can_continue_dma) begin
          automatic logic [3:0] missing_flits_in_transfer;

          missing_flits_in_transfer = start_burst(pkt_buf_out_data,
                                                  transf_meta.pkt_meta);
          transf_meta.missing_flits_in_transfer <= missing_flits_in_transfer;

          if (missing_flits_in_transfer != 0) begin
            state <= COMPLETE_BURST;
          end else if (transf_meta.pkt_meta.size > 1) begin
            // When we can only send a single packet in a burst, we need to jump
            // directly to START_BURST.
            state <= START_BURST;
          end else if (transf_meta.pkt_meta.needs_dsc) begin
            state <= SEND_DESCRIPTOR;
          end else begin
            state <= START_TRANSFER;
          end
        end
      end
      SEND_DESCRIPTOR: begin
        if (!pcie_bas_waitrequest) begin
          automatic pcie_rx_dsc_t pcie_pkt_desc;
          automatic queue_state_t dsc_q_state;
          automatic queue_state_t pkt_q_state;

          dsc_q_state = transf_meta.pkt_meta.dsc_q_state;
          pkt_q_state = transf_meta.pkt_meta.pkt_q_state;

          pcie_pkt_desc.signal = 1;
          pcie_pkt_desc.tail = {
            {{$bits(pcie_pkt_desc.tail) - RB_AWIDTH}{1'b0}}, pkt_q_state.tail
          };
          pcie_pkt_desc.queue_id = transf_meta.pkt_meta.pkt_queue_id;
          pcie_pkt_desc.pad = 0;

          // Skip DMA when addresses are not set
          if (pkt_q_state.kmem_addr & dsc_q_state.kmem_addr) begin
            pcie_bas_address_r <= dsc_q_state.kmem_addr + 64 * dsc_q_state.tail;
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
  if (rst | sw_reset) begin
    metadata_buf_out_valid_r <= 0;
  end else begin
    if (!pcie_bas_waitrequest) begin
      pcie_bas_address <= pcie_bas_address_r;
      pcie_bas_byteenable <= pcie_bas_byteenable_r;
      pcie_bas_write <= pcie_bas_write_r;
      pcie_bas_writedata <= pcie_bas_writedata_r;
      pcie_bas_burstcount <= pcie_bas_burstcount_r;

      dma_queue_full_cnt <= dma_queue_full_cnt_r;
    end
    if (metadata_buf_out_ready | !metadata_buf_out_valid_r) begin
      metadata_buf_out_data_r <= metadata_buf_out_data;
      metadata_buf_out_valid_r <= metadata_buf_out_valid;
    end
  end
end

// Check if we are able to DMA the packet or descriptor
always_comb begin
  cur_meta = metadata_buf_out_data_r;

  tx_compl_buf_out_ready = (state == START_TRANSFER) && !pcie_bas_waitrequest;

  can_send_tx_completion = tx_compl_buf_out_ready & tx_compl_buf_out_valid;

  can_start_transfer = !can_send_tx_completion && can_continue_dma 
                       && metadata_buf_out_valid_r;

  metadata_buf_out_ready = can_start_transfer && (state == START_TRANSFER);
  pkt_buf_out_ready = metadata_buf_out_ready || (can_continue_dma
    && (state != SEND_DESCRIPTOR) && (state != START_TRANSFER));
end

logic [31:0] pkt_buf_csr_readdata;
logic [31:0] metadata_buf_csr_readdata;

assign pkt_buf_occup = pkt_buf_csr_readdata[F2C_RB_AWIDTH:0];
assign metadata_buf_occup = metadata_buf_csr_readdata[F2C_RB_AWIDTH:0];

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
  .csr_readdata  (pkt_buf_csr_readdata),
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
  .BITS_PER_SYMBOL($bits(pkt_meta_with_queues_t)),
  .FIFO_DEPTH(F2C_RB_DEPTH)
)
metadata_buf (
  .clk           (clk),
  .reset         (rst),
  .csr_address   (2'b0),
  .csr_read      (1'b1),
  .csr_write     (1'b0),
  .csr_readdata  (metadata_buf_csr_readdata),
  .csr_writedata (32'b0),
  .in_data       (metadata_buf_in_data),
  .in_valid      (metadata_buf_in_valid),
  .in_ready      (metadata_buf_in_ready),
  .out_data      (metadata_buf_out_data),
  .out_valid     (metadata_buf_out_valid),
  .out_ready     (metadata_buf_out_ready | !metadata_buf_out_valid_r)
);

fifo_wrapper_infill #(
  .SYMBOLS_PER_BEAT(1),
  .BITS_PER_SYMBOL($bits(tx_transfer_t)),
  .FIFO_DEPTH(16)
)
tx_compl_buf (
  .clk           (clk),
  .reset         (rst),
  .csr_address   (2'b0),
  .csr_read      (1'b1),
  .csr_write     (1'b0),
  .csr_readdata  (tx_compl_buf_occup),
  .csr_writedata (32'b0),
  .in_data       (tx_compl_buf_in_data),
  .in_valid      (tx_compl_buf_in_valid),
  .in_ready      (tx_compl_buf_in_ready),
  .out_data      (tx_compl_buf_out_data),
  .out_valid     (tx_compl_buf_out_valid),
  .out_ready     (tx_compl_buf_out_ready)
);

endmodule
