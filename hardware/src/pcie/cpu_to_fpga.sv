`include "pcie_consts.sv"

/*
 * This module implements the communication from the CPU to the FPGA (TX). It is
 * also responsible for managing the TX descriptor queue BRAMs.
 */

module cpu_to_fpga  #(
    parameter NB_QUEUES,
    parameter QUEUE_ID_WIDTH=$clog2(NB_QUEUES)
)(
  input logic clk,
  input logic rst,

  // Packet buffer output.
  output logic         out_pkt_sop,
  output logic         out_pkt_eop,
  output logic         out_pkt_valid,
  output logic [511:0] out_pkt_data,
  output logic [5:0]   out_pkt_empty,
  input  logic         out_pkt_ready,
  input  logic [31:0]  out_pkt_occup,

  // PCIe Read Data Mover (RDDM) signals.
  input  logic         pcie_rddm_desc_ready,
  output logic         pcie_rddm_desc_valid,
  output logic [173:0] pcie_rddm_desc_data,
  input  logic         pcie_rddm_prio_ready,
  output logic         pcie_rddm_prio_valid,
  output logic [173:0] pcie_rddm_prio_data,
  input  logic         pcie_rddm_tx_valid,
  input  logic [31:0]  pcie_rddm_tx_data,
  input  logic [63:0]  pcie_rddm_address,
  input  logic         pcie_rddm_write,
  input  logic [511:0] pcie_rddm_writedata,
  input  logic [63:0]  pcie_rddm_byteenable,

  // BRAM signals for TX descriptor queues.
  bram_interface_io.owner q_table_tails,
  bram_interface_io.owner q_table_heads,
  bram_interface_io.owner q_table_l_addrs,
  bram_interface_io.owner q_table_h_addrs,

  // Config signals.
  input logic [RB_AWIDTH:0] rb_size,

  // Counters.
  output logic [31:0] ignored_dsc_cnt
);

typedef struct packed {
  logic [DSC_Q_TABLE_TAILS_DWIDTH-1:0]   tail;
  logic [DSC_Q_TABLE_HEADS_DWIDTH-1:0]   head;
  logic [DSC_Q_TABLE_L_ADDRS_DWIDTH-1:0] l_addr;
  logic [DSC_Q_TABLE_H_ADDRS_DWIDTH-1:0] h_addr;
  logic [QUEUE_ID_WIDTH-1:0]             queue_id;
} q_state_t;

typedef struct packed {
  logic [QUEUE_ID_WIDTH-1:0]           queue_id;
  logic [19:0]                         total_bytes;
  logic [DSC_Q_TABLE_HEADS_DWIDTH-1:0] head;
} meta_t;

// Used to encode metadata in the destination address used by the RDDM.
typedef struct packed {
  logic [63 - 1 - DSC_Q_TABLE_HEADS_DWIDTH - QUEUE_ID_WIDTH - 6:0] pad1;
  logic descriptor; // If 1: descriptor. If 0: packet.
  logic [DSC_Q_TABLE_HEADS_DWIDTH-1:0] head;
  logic [QUEUE_ID_WIDTH-1:0] queue_id;
  logic [5:0] pad2; // must be 64-byte aligned
} rddm_dst_addr_t;

q_state_t    dsc_reads_queue_in_data;
logic        dsc_reads_queue_in_valid;
logic        dsc_reads_queue_in_ready;
q_state_t    dsc_reads_queue_out_data;
logic        dsc_reads_queue_out_valid;
logic        dsc_reads_queue_out_ready;
logic [31:0] dsc_reads_queue_occup;

logic [$bits(pcie_rddm_desc_data)-1:0] rddm_desc_queue_in_data;
logic        rddm_desc_queue_in_valid;
logic        rddm_desc_queue_in_ready;
logic [31:0] rddm_desc_queue_occup;

logic [$bits(pcie_rddm_prio_data)-1:0] rddm_prio_queue_in_data;
logic        rddm_prio_queue_in_valid;
logic        rddm_prio_queue_in_ready;
logic [31:0] rddm_prio_queue_occup;

meta_t       meta_queue_in_data;
logic        meta_queue_in_valid;
logic        meta_queue_in_ready;
meta_t       meta_queue_out_data;
logic        meta_queue_out_valid;
logic        meta_queue_out_ready;
logic [31:0] meta_queue_occup;

logic [511:0] pkt_queue_in_data;
logic         pkt_queue_in_valid;
logic         pkt_queue_in_ready;
logic [511:0] pkt_queue_out_data;
logic         pkt_queue_out_valid;
logic         pkt_queue_out_ready;
logic [31:0]  pkt_queue_occup;

localparam META_QUEUE_LEN = 64;  // In number of descriptors.
localparam PKT_QUEUE_LEN = 1024;  // In flits.

logic out_pkt_alm_full;
assign out_pkt_alm_full = out_pkt_occup > PCIE_TX_PKT_FIFO_ALM_FULL_THRESH;

logic dsc_reads_queue_alm_full;
assign dsc_reads_queue_alm_full = dsc_reads_queue_occup > 10;

logic rddm_desc_queue_alm_full;
assign rddm_desc_queue_alm_full = rddm_desc_queue_occup > 8;

logic rddm_prio_queue_alm_full;
assign rddm_prio_queue_alm_full = rddm_prio_queue_occup > 8;

logic meta_queue_alm_full;
assign meta_queue_alm_full = meta_queue_occup > (META_QUEUE_LEN / 2);

logic pkt_queue_alm_full;
assign pkt_queue_alm_full = pkt_queue_occup > (PKT_QUEUE_LEN / 2);

// The BRAM port b's are exposed outside the module while port a's are only used
// internally.
bram_interface_io q_table_a_tails();
bram_interface_io q_table_a_heads();
bram_interface_io q_table_a_l_addrs();
bram_interface_io q_table_a_h_addrs();

logic can_issue_dma_rd;
assign can_issue_dma_rd = !rddm_desc_queue_alm_full & !rddm_prio_queue_alm_full
                          & !meta_queue_alm_full & !meta_queue_alm_full;

logic q_table_a_tails_rd_en_r1;
logic q_table_a_tails_rd_en_r2;

logic [PKT_Q_TABLE_TAILS_DWIDTH-1:0] tail;
logic [PKT_Q_TABLE_TAILS_DWIDTH-1:0] tail_r1;
logic [PKT_Q_TABLE_TAILS_DWIDTH-1:0] tail_r2;

logic [QUEUE_ID_WIDTH-1:0] queue_id;
logic [QUEUE_ID_WIDTH-1:0] queue_id_r1;
logic [QUEUE_ID_WIDTH-1:0] queue_id_r2;

// Define mask associated with rb_size. Assume that rb_size is a power of two.
logic [RB_AWIDTH-1:0] rb_mask;
always @(posedge clk) begin
    rb_mask <= rb_size - 1;
end

// Monitor tail pointer updates from the CPU to fetch more descriptors.
// FIXME(sadok): If the tail is updated too often, the PCIe core may
//               backpressure. If this causes the queue to get full, some
//               descriptors may never be read. This should not happen under
//               normal circumstances but it should still be addressed.
always @(posedge clk) begin
  q_table_a_tails.rd_en <= 0;
  q_table_a_l_addrs.rd_en <= 0;
  q_table_a_h_addrs.rd_en <= 0;

  if (q_table_tails.wr_en & !dsc_reads_queue_alm_full) begin
    tail <= q_table_tails.wr_data;
    q_table_a_tails.rd_en <= 1;
    q_table_a_tails.addr <= q_table_tails.addr;
    q_table_a_l_addrs.rd_en <= 1;
    q_table_a_l_addrs.addr <= q_table_tails.addr;
    q_table_a_h_addrs.rd_en <= 1;
    q_table_a_h_addrs.addr <= q_table_tails.addr;
    queue_id <= q_table_tails.addr;
  end

  q_table_a_tails_rd_en_r1 <= q_table_a_tails.rd_en;
  q_table_a_tails_rd_en_r2 <= q_table_a_tails_rd_en_r1;
  tail_r1 <= tail;
  tail_r2 <= tail_r1;
  queue_id_r1 <= queue_id;
  queue_id_r2 <= queue_id_r1;
end

// Monitor tail writes where no descriptor read was issued, this counter should
// remain zero for correctness.
always @(posedge clk) begin
  if (rst) begin
    ignored_dsc_cnt <= 0;
  end else begin
    if (q_table_tails.wr_en & dsc_reads_queue_alm_full) begin
      ignored_dsc_cnt <= ignored_dsc_cnt + 1;
    end
  end
end

logic [QUEUE_ID_WIDTH:0] last_queues [2];  // Extra bit to represent invalid.
logic [PKT_Q_TABLE_TAILS_DWIDTH-1:0] last_tails [2];

// Whenever a queue state read completes, we enqueue it to dsc_reads_queue.
always @(posedge clk) begin
  dsc_reads_queue_in_valid <= 0;
  last_queues[0][QUEUE_ID_WIDTH] <= 1;  // Invalid queue.

  if (q_table_a_tails_rd_en_r2 && (tail_r2 != q_table_a_tails.rd_data)) begin
    dsc_reads_queue_in_data.queue_id <= queue_id_r2;
    dsc_reads_queue_in_data.tail <= tail_r2;
    dsc_reads_queue_in_data.l_addr <= q_table_a_l_addrs.rd_data;
    dsc_reads_queue_in_data.h_addr <= q_table_a_h_addrs.rd_data;

    // Use the old tail as the "head". The actual head is only updated after all
    // the packets associated with a descriptor are DMAed from memory. However,
    // the last tail may be outdated as we need two cycles to write to the BRAM.
    if (last_queues[0] == queue_id_r2) begin
      dsc_reads_queue_in_data.head <= last_tails[0];
    end else if (last_queues[1] == queue_id_r2) begin
      dsc_reads_queue_in_data.head <= last_tails[1];
    end else begin
      dsc_reads_queue_in_data.head <= q_table_a_tails.rd_data;
    end

    last_queues[0] <= {1'b0, queue_id_r2};
    last_tails[0] <= tail_r2;

    dsc_reads_queue_in_valid <= 1;
  end

  last_queues[1] <= last_queues[0];
  last_tails[1] <= last_tails[0];
end

// When set, a second DMA is pending for the same read request.
logic second_dma_req_pending;
assign dsc_reads_queue_out_ready = !second_dma_req_pending;

q_state_t dsc_reads_queue_out_data_r;

// Send descriptor to RDDM to read latest descriptors for a given TX dsc queue.
// It consumes the queue state from dsc_reads_queue and enqueues descriptors to
// the rddm_prio_queue.
always @(posedge clk) begin
  automatic rddm_dst_addr_t dst_addr = 0;
  automatic rddm_desc_t rddm_desc = 0;
  rddm_desc.single_dst = 1;
  rddm_desc.descriptor_id = 2;  // Make sure this remains different from the
                                // one used in the `desc` queue.
  dst_addr.descriptor = 1;

  rddm_prio_queue_in_valid <= 0;
  second_dma_req_pending <= 0;

  // Previous request wrapped around, send second DMA before processing next
  // request.
  if (second_dma_req_pending) begin
    rddm_desc.src_addr[31:0] = dsc_reads_queue_out_data_r.l_addr;
    rddm_desc.src_addr[63:32] = dsc_reads_queue_out_data_r.h_addr;

    dst_addr.queue_id = dsc_reads_queue_out_data_r.queue_id;
    dst_addr.head = 0;
    rddm_desc.dst_addr = dst_addr;

    rddm_desc.nb_dwords = dsc_reads_queue_out_data_r.tail << 4;

    rddm_prio_queue_in_valid <= 1;
    rddm_prio_queue_in_data <= rddm_desc;

  end else if (dsc_reads_queue_out_valid & dsc_reads_queue_out_ready) begin
    rddm_desc.src_addr[31:0] = dsc_reads_queue_out_data.l_addr;
    rddm_desc.src_addr[63:32] = dsc_reads_queue_out_data.h_addr;
    rddm_desc.src_addr += dsc_reads_queue_out_data.head << 6;

    dst_addr.queue_id = dsc_reads_queue_out_data.queue_id;
    dst_addr.head = dsc_reads_queue_out_data.head;
    rddm_desc.dst_addr = dst_addr;

    // Check if request wraps around.
    if (dsc_reads_queue_out_data.tail > dsc_reads_queue_out_data.head) begin
      rddm_desc.nb_dwords =
        (dsc_reads_queue_out_data.tail - dsc_reads_queue_out_data.head) << 4;
    end else begin
      // Wraps around, need to send two read requests only if tail is not 0.
      if (dsc_reads_queue_out_data.tail != 0) begin
        second_dma_req_pending <= 1;
      end
      rddm_desc.nb_dwords = (rb_size - dsc_reads_queue_out_data.head) << 4;
    end

    rddm_prio_queue_in_valid <= 1;
    rddm_prio_queue_in_data <= rddm_desc;
  end

  dsc_reads_queue_out_data_r <= dsc_reads_queue_out_data;
end

logic [DSC_Q_TABLE_HEADS_DWIDTH-1:0] last_head;
logic [QUEUE_ID_WIDTH:0]             last_queue_id;  // Extra bit to represent
                                                     // invalid.

// Reacts to MM writes from RDDM. Descriptor writes cause a metadata to be
// enqueued to the `meta_queue` and also trigger a DMA read for the associated
// packets (which are enqueued to the `rddm_desc_queue`). Packet writes are
// enqueued to the `pkt_queue`.
always @(posedge clk) begin
  rddm_desc_queue_in_valid <= 0;
  meta_queue_in_valid <= 0;
  pkt_queue_in_valid <= 0;

  if (rst) begin
    last_queue_id[QUEUE_ID_WIDTH] <= 1;  // Invalid queue.
  end else if (pcie_rddm_write) begin
    automatic rddm_dst_addr_t rddm_dst_addr = pcie_rddm_address;

    // TODO(sadok): group multiple descriptors in the same cache line?
    if (rddm_dst_addr.descriptor) begin  // Received a descriptor.
      automatic pcie_tx_dsc_t tx_dsc = pcie_rddm_writedata;
      automatic meta_t meta;
      automatic rddm_desc_t rddm_desc = 0;

      rddm_desc.single_dst = 1;
      rddm_desc.descriptor_id = 1;  // Make sure this remains different from the
                                    // one used in the `prio` queue.

      // TODO(sadok): should check values in the descriptor to make sure they
      // are "reasonable." A bad actor may exploit this to read memory that they
      // do not have access to.
      assert(tx_dsc.length != 0);
      rddm_desc.nb_dwords = ((tx_dsc.length - 1) >> 2) + 1;

      rddm_desc.src_addr = tx_dsc.addr;

      rddm_dst_addr.descriptor = 0;  // Indicates that this is reading a packet.
      rddm_desc.dst_addr = rddm_dst_addr;

      // Number of bytes to ignore at the last flit.
      // rddm_desc.dst_addr[QUEUE_ID_WIDTH+1 +: 6] = -tx_dsc.length[5:0];

      rddm_desc_queue_in_valid <= 1;
      rddm_desc_queue_in_data <= rddm_desc;

      if (rddm_dst_addr.queue_id != last_queue_id) begin
        last_queue_id <= rddm_dst_addr.queue_id;
        last_head <= rddm_dst_addr.head;
      end else begin
        rddm_dst_addr.head = (last_head + 1) & rb_mask;
        last_head <= rddm_dst_addr.head;
      end

      meta.queue_id = rddm_dst_addr.queue_id;
      meta.total_bytes = tx_dsc.length;
      meta.head = rddm_dst_addr.head;

      meta_queue_in_valid <= 1;
      meta_queue_in_data <= meta;
    end else begin  // Received a packet.
      pkt_queue_in_data <= pcie_rddm_writedata;
      pkt_queue_in_valid <= 1;
    end
  end
end

logic [19:0] pending_bytes;

// Ready signals for meta_queue and pkt_queue.
always_comb begin
  meta_queue_out_ready =
    (pending_bytes == 0) & !out_pkt_alm_full & pkt_queue_out_valid;
  if (pending_bytes > 0) begin
    pkt_queue_out_ready = !out_pkt_alm_full;
  end else begin
    pkt_queue_out_ready = meta_queue_out_ready;
  end
end

logic [QUEUE_ID_WIDTH-1:0] cur_queue;
logic [QUEUE_ID_WIDTH-1:0] cur_head;

// Consume packets and send them out setting sop and eop.
// (Assuming raw sockets for now, that means that headers are populated by
// software).
always @(posedge clk) begin
  q_table_a_heads.wr_en <= 0;

  out_pkt_sop <= 0;
  out_pkt_eop <= 0;
  out_pkt_valid <= 0;
  out_pkt_empty <= 0;

  if (rst) begin
    pending_bytes <= 0;
  end else begin
    automatic logic [QUEUE_ID_WIDTH-1:0] head;
    automatic logic [19:0] next_pending_bytes = pending_bytes;
    head = meta_queue_out_data.head;

    if ((pending_bytes > 0) & pkt_queue_out_valid & pkt_queue_out_ready) begin
      // HACK(sadok): hardcode 64-byte packet. Should look at the header in the
      //              first flit to determine when to set eop.
      next_pending_bytes = pending_bytes - 64;
      out_pkt_eop <= 1;
      out_pkt_sop <= 1;

      out_pkt_data <= pkt_queue_out_data;
      out_pkt_empty <= 0;  // TODO(sadok): handle unaligned packets.
      out_pkt_valid <= 1;
      
    end else if (meta_queue_out_ready & meta_queue_out_valid) begin
      cur_queue <= meta_queue_out_data.queue_id;
      cur_head <= meta_queue_out_data.head;
      head = meta_queue_out_data.head;
      // HACK(sadok): hardcode 64-byte packet. Should look at the header in the
      //              first flit to determine when to set eop.
      next_pending_bytes = meta_queue_out_data.total_bytes - 64;
      out_pkt_eop <= 1;
      out_pkt_sop <= 1;

      out_pkt_data <= pkt_queue_out_data;
      out_pkt_empty <= 0;  // TODO(sadok): handle unaligned packets.
      out_pkt_valid <= 1;
    end

    if (next_pending_bytes == 0) begin
      q_table_a_heads.wr_data <= (head + 1) & rb_mask;
      q_table_a_heads.wr_en <= 1;
    end
    pending_bytes <= next_pending_bytes;
  end
end

assign q_table_a_heads.rd_en = 0;

assign q_table_a_tails.wr_en = 0;
assign q_table_a_l_addrs.wr_en = 0;
assign q_table_a_h_addrs.wr_en = 0;


////////////
// Queues //
////////////

fifo_wrapper_infill_mlab #(
  .SYMBOLS_PER_BEAT(1),
  .BITS_PER_SYMBOL($bits(q_state_t)),
  .FIFO_DEPTH(16)
) dsc_reads_queue (
  .clk           (clk),
  .reset         (rst),
  .csr_address   (2'b0),
  .csr_read      (1'b1),
  .csr_write     (1'b0),
  .csr_readdata  (dsc_reads_queue_occup),
  .csr_writedata (32'b0),
  .in_data       (dsc_reads_queue_in_data),
  .in_valid      (dsc_reads_queue_in_valid),
  .in_ready      (dsc_reads_queue_in_ready),
  .out_data      (dsc_reads_queue_out_data),
  .out_valid     (dsc_reads_queue_out_valid),
  .out_ready     (dsc_reads_queue_out_ready)
);

fifo_wrapper_infill_mlab #(
  .SYMBOLS_PER_BEAT(1),
  .BITS_PER_SYMBOL($bits(pcie_rddm_desc_data)),
  .FIFO_DEPTH(16)
) rddm_desc_queue (
  .clk           (clk),
  .reset         (rst),
  .csr_address   (2'b0),
  .csr_read      (1'b1),
  .csr_write     (1'b0),
  .csr_readdata  (rddm_desc_queue_occup),
  .csr_writedata (32'b0),
  .in_data       (rddm_desc_queue_in_data),
  .in_valid      (rddm_desc_queue_in_valid),
  .in_ready      (rddm_desc_queue_in_ready),
  .out_data      (pcie_rddm_desc_data),
  .out_valid     (pcie_rddm_desc_valid),
  .out_ready     (pcie_rddm_desc_ready)
);

fifo_wrapper_infill_mlab #(
  .SYMBOLS_PER_BEAT(1),
  .BITS_PER_SYMBOL($bits(pcie_rddm_prio_data)),
  .FIFO_DEPTH(16)
) rddm_prio_queue (
  .clk           (clk),
  .reset         (rst),
  .csr_address   (2'b0),
  .csr_read      (1'b1),
  .csr_write     (1'b0),
  .csr_readdata  (rddm_prio_queue_occup),
  .csr_writedata (32'b0),
  .in_data       (rddm_prio_queue_in_data),
  .in_valid      (rddm_prio_queue_in_valid),
  .in_ready      (rddm_prio_queue_in_ready),
  .out_data      (pcie_rddm_prio_data),
  .out_valid     (pcie_rddm_prio_valid),
  .out_ready     (pcie_rddm_prio_ready)
);

fifo_wrapper_infill_mlab #(
  .SYMBOLS_PER_BEAT(1),
  .BITS_PER_SYMBOL($bits(meta_queue_in_data)),
  .FIFO_DEPTH(META_QUEUE_LEN)
) meta_queue (
  .clk           (clk),
  .reset         (rst),
  .csr_address   (2'b0),
  .csr_read      (1'b1),
  .csr_write     (1'b0),
  .csr_readdata  (meta_queue_occup),
  .csr_writedata (32'b0),
  .in_data       (meta_queue_in_data),
  .in_valid      (meta_queue_in_valid),
  .in_ready      (meta_queue_in_ready),
  .out_data      (meta_queue_out_data),
  .out_valid     (meta_queue_out_valid),
  .out_ready     (meta_queue_out_ready)
);

fifo_wrapper_infill_mlab #(
  .SYMBOLS_PER_BEAT(1),
  .BITS_PER_SYMBOL($bits(pkt_queue_in_data)),
  .FIFO_DEPTH(PKT_QUEUE_LEN)
) pkt_queue (
  .clk           (clk),
  .reset         (rst),
  .csr_address   (2'b0),
  .csr_read      (1'b1),
  .csr_write     (1'b0),
  .csr_readdata  (pkt_queue_occup),
  .csr_writedata (32'b0),
  .in_data       (pkt_queue_in_data),
  .in_valid      (pkt_queue_in_valid),
  .in_ready      (pkt_queue_in_ready),
  .out_data      (pkt_queue_out_data),
  .out_valid     (pkt_queue_out_valid),
  .out_ready     (pkt_queue_out_ready)
);

// Delay writes from MMIO/JTAG by two cycles so that we have time to read the
// old value before the update.
logic [DSC_Q_TABLE_TAILS_DWIDTH-1:0] q_table_b_tails_wr_data_r1;
logic [DSC_Q_TABLE_TAILS_DWIDTH-1:0] q_table_b_tails_wr_data_r2;
logic q_table_b_tails_wr_en_r1;
logic q_table_b_tails_wr_en_r2;

always @(posedge clk) begin
  q_table_b_tails_wr_data_r1 <= q_table_tails.wr_data;
  q_table_b_tails_wr_data_r2 <= q_table_b_tails_wr_data_r1;
  q_table_b_tails_wr_en_r1 <= q_table_tails.wr_en;
  q_table_b_tails_wr_en_r2 <= q_table_b_tails_wr_en_r1;
end

//////////////////////////////
// TX DSC Queue State BRAMs //
//////////////////////////////

bram_true2port #(
  .AWIDTH(QUEUE_ID_WIDTH),
  .DWIDTH(DSC_Q_TABLE_TAILS_DWIDTH),
  .DEPTH(NB_QUEUES)
) q_table_tails_bram (
  .address_a (q_table_a_tails.addr[QUEUE_ID_WIDTH-1:0]),
  .address_b (q_table_tails.addr[QUEUE_ID_WIDTH-1:0]),
  .clock     (clk),
  .data_a    (q_table_a_tails.wr_data),
  .data_b    (q_table_b_tails_wr_data_r2),
  .rden_a    (q_table_a_tails.rd_en),
  .rden_b    (q_table_tails.rd_en),
  .wren_a    (q_table_a_tails.wr_en),
  .wren_b    (q_table_b_tails_wr_en_r2),
  .q_a       (q_table_a_tails.rd_data),
  .q_b       (q_table_tails.rd_data)
);

bram_true2port #(
  .AWIDTH(QUEUE_ID_WIDTH),
  .DWIDTH(DSC_Q_TABLE_HEADS_DWIDTH),
  .DEPTH(NB_QUEUES)
) q_table_heads_bram (
  .address_a (q_table_a_heads.addr[QUEUE_ID_WIDTH-1:0]),
  .address_b (q_table_heads.addr[QUEUE_ID_WIDTH-1:0]),
  .clock     (clk),
  .data_a    (q_table_a_heads.wr_data),
  .data_b    (q_table_heads.wr_data),
  .rden_a    (q_table_a_heads.rd_en),
  .rden_b    (q_table_heads.rd_en),
  .wren_a    (q_table_a_heads.wr_en),
  .wren_b    (q_table_heads.wr_en),
  .q_a       (q_table_a_heads.rd_data),
  .q_b       (q_table_heads.rd_data)
);

bram_true2port #(
  .AWIDTH(QUEUE_ID_WIDTH),
  .DWIDTH(DSC_Q_TABLE_L_ADDRS_DWIDTH),
  .DEPTH(NB_QUEUES)
) q_table_l_addrs_bram (
  .address_a (q_table_a_l_addrs.addr[QUEUE_ID_WIDTH-1:0]),
  .address_b (q_table_l_addrs.addr[QUEUE_ID_WIDTH-1:0]),
  .clock     (clk),
  .data_a    (q_table_a_l_addrs.wr_data),
  .data_b    (q_table_l_addrs.wr_data),
  .rden_a    (q_table_a_l_addrs.rd_en),
  .rden_b    (q_table_l_addrs.rd_en),
  .wren_a    (q_table_a_l_addrs.wr_en),
  .wren_b    (q_table_l_addrs.wr_en),
  .q_a       (q_table_a_l_addrs.rd_data),
  .q_b       (q_table_l_addrs.rd_data)
);

bram_true2port #(
  .AWIDTH(QUEUE_ID_WIDTH),
  .DWIDTH(DSC_Q_TABLE_H_ADDRS_DWIDTH),
  .DEPTH(NB_QUEUES)
) q_table_h_addrs_bram (
  .address_a (q_table_a_h_addrs.addr[QUEUE_ID_WIDTH-1:0]),
  .address_b (q_table_h_addrs.addr[QUEUE_ID_WIDTH-1:0]),
  .clock     (clk),
  .data_a    (q_table_a_h_addrs.wr_data),
  .data_b    (q_table_h_addrs.wr_data),
  .rden_a    (q_table_a_h_addrs.rd_en),
  .rden_b    (q_table_h_addrs.rd_en),
  .wren_a    (q_table_a_h_addrs.wr_en),
  .wren_b    (q_table_h_addrs.wr_en),
  .q_a       (q_table_a_h_addrs.rd_data),
  .q_b       (q_table_h_addrs.rd_data)
);

// Unused inputs.
assign q_table_a_tails.wr_data = 32'bx;
assign q_table_a_l_addrs.wr_data = 32'bx;
assign q_table_a_h_addrs.wr_data = 32'bx;

endmodule
