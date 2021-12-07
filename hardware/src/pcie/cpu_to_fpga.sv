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

  // TX completion buffer output.
  output var tx_transfer_t tx_compl_buf_data,
  output logic             tx_compl_buf_valid,
  input  logic             tx_compl_buf_ready,
  input  logic [31:0]      tx_compl_buf_occup,

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
  output logic         pcie_rddm_waitrequest,

  // BRAM signals for TX descriptor queues.
  bram_interface_io.owner q_table_tails,
  bram_interface_io.owner q_table_heads,
  bram_interface_io.owner q_table_l_addrs,
  bram_interface_io.owner q_table_h_addrs,

  // Config signals.
  input logic [RB_AWIDTH:0] rb_size,
  input logic [31:0]        inflight_desc_limit,

  // Counters.
  output logic [31:0] ignored_dsc_cnt,
  output logic [31:0] queue_full_signals,
  output logic [31:0] dsc_cnt,
  output logic [31:0] empty_tail_cnt,
  output logic [31:0] dsc_read_cnt,
  output logic [31:0] pkt_read_cnt,
  output logic [31:0] batch_cnt,
  output logic [31:0] max_inflight_dscs,
  output logic [31:0] max_nb_req_dscs
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
  logic [63:0]                         transfer_addr;
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

logic [$bits(pcie_rddm_desc_data)-1:0] rddm_prio_queue_in_data;
logic        rddm_prio_queue_in_valid;
logic        rddm_prio_queue_in_ready;
logic [31:0] rddm_desc_queue_occup;

logic [$bits(pcie_rddm_prio_data)-1:0] rddm_desc_queue_in_data;
logic        rddm_desc_queue_in_valid;
logic        rddm_desc_queue_in_ready;
logic [31:0] rddm_prio_queue_occup;

logic [$bits(pcie_rddm_prio_data)-1:0] rddm_desc_queue_in_data_r;
logic        rddm_desc_queue_in_valid_r;

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

logic [31:0] inflight_descriptors;

localparam RDDM_WREQ_ALLOWANCE = 16;

localparam RDDM_PRIO_QUEUE_LEN = 1024;
localparam RDDM_DESC_QUEUE_LEN = RDDM_PRIO_QUEUE_LEN/2;
localparam META_QUEUE_LEN = 1024;  // In number of descriptors.
localparam PKT_QUEUE_LEN = 512;  // In flits.

localparam MAX_TX_DSC_BATCH = RDDM_PRIO_QUEUE_LEN/4;

logic out_pkt_alm_full;
assign out_pkt_alm_full = out_pkt_occup > PCIE_TX_PKT_FIFO_ALM_FULL_THRESH;

logic tx_compl_buf_alm_full;
assign tx_compl_buf_alm_full = tx_compl_buf_occup > 10;

logic dsc_reads_queue_alm_full;
assign dsc_reads_queue_alm_full = dsc_reads_queue_occup > 10;

logic rddm_desc_queue_alm_full;
assign rddm_desc_queue_alm_full =
  rddm_desc_queue_occup > (RDDM_DESC_QUEUE_LEN - MAX_TX_DSC_BATCH);

// Backpressure PCIe core only when packet queue is too full. Note that this
// does not include backpressure signals from the `meta_queue` and from the
// `rddm_prio_queue`. This is on purpose, as backpressuring the PCIe core when
// these queues are almost full can cause a deadlock. The reason for this is
// that these queues need packets read from PCIe in order to advance. If we
// backpressure the PCIe core, it will not be able to output these packets.
// So instead of backpressuring the PCIe core we must prevent the meta_queue and
// rddm_prio_queue from overflowing by stopping request for new descriptors to
// be sent to the PCIe core in the first place. Look at the logic to assert the
// `rddm_desc_queue_out_ready` signal.
assign pcie_rddm_waitrequest =
    pkt_queue_occup >= (PKT_QUEUE_LEN - RDDM_WREQ_ALLOWANCE * 2);

// The BRAM port b's are exposed outside the module while port a's are only used
// internally.
bram_interface_io q_table_a_tails();
bram_interface_io q_table_a_heads();
bram_interface_io q_table_a_l_addrs();
bram_interface_io q_table_a_h_addrs();

// These interfaces share the BRAM ports with JTAG/MMIO. They are only used to
// read the address when sending a completion notification.
bram_interface_io q_table_b_l_addrs();
bram_interface_io q_table_b_h_addrs();

logic [QUEUE_ID_WIDTH-1:0] compl_q_table_l_addrs_addr;
logic [QUEUE_ID_WIDTH-1:0] compl_q_table_h_addrs_addr;

logic compl_q_table_l_addrs_rd_en;
logic compl_q_table_h_addrs_rd_en;

logic can_issue_dma_rd;

// Cannot issue a DMA read if one of the queues is almost full or if there is
// read for BRAM port A in the current cycle (q_table_a_tails.rd_en). When there
// is a read for port A, there will be a write in the following cycle, which
// could conflict with the current read if they are accessing the same address.
assign can_issue_dma_rd = !dsc_reads_queue_alm_full & !q_table_a_tails.rd_en;

logic q_table_a_tails_rd_en_r1;
logic q_table_a_tails_rd_en_r2;

logic [PKT_Q_TABLE_TAILS_DWIDTH-1:0] tail;
logic [PKT_Q_TABLE_TAILS_DWIDTH-1:0] tail_r1;
logic [PKT_Q_TABLE_TAILS_DWIDTH-1:0] tail_r2;

logic [QUEUE_ID_WIDTH-1:0] queue_id;
logic [QUEUE_ID_WIDTH-1:0] queue_id_r1;
logic [QUEUE_ID_WIDTH-1:0] queue_id_r2;

logic q_table_a_tails_wr_en;
logic q_table_a_tails_wr_en_r;

logic [DSC_Q_TABLE_TAILS_DWIDTH-1:0] q_table_a_tails_wr_data;
logic [DSC_Q_TABLE_TAILS_DWIDTH-1:0] q_table_a_tails_wr_data_r;

logic [QUEUE_ID_WIDTH-1:0] q_table_a_tails_rd_addr;

logic [QUEUE_ID_WIDTH-1:0] q_table_a_tails_wr_addr;
logic [QUEUE_ID_WIDTH-1:0] q_table_a_tails_wr_addr_r;

// Define mask associated with rb_size. Assume that rb_size is a power of two.
logic [RB_AWIDTH-1:0] rb_mask;
always @(posedge clk) begin
  rb_mask <= rb_size - 1;
end

// HACK(sadok): assume single descriptor queue.
logic ignored_tail_set;
logic [PKT_Q_TABLE_TAILS_DWIDTH-1:0] ignored_tail;

// Fetch queue state and write new tail in the following cycle.
function void consume_tx_queue(
  logic [QUEUE_ID_WIDTH-1:0] addr,
  logic [PKT_Q_TABLE_TAILS_DWIDTH-1:0] new_tail
);
  q_table_a_tails.rd_en <= 1;
  q_table_a_tails_rd_addr <= addr;
  q_table_a_l_addrs.rd_en <= 1;
  q_table_a_l_addrs.addr <= addr;
  q_table_a_h_addrs.rd_en <= 1;
  q_table_a_h_addrs.addr <= addr;
  queue_id <= addr;

  tail <= new_tail;

  // Write tail only in the next cycle, so we can read the current tail first.
  q_table_a_tails_wr_en <= 1;
  q_table_a_tails_wr_data <= new_tail;
  q_table_a_tails_wr_addr <= addr;
endfunction

// Monitor tail pointer updates from the CPU to fetch more descriptors.
// FIXME(sadok): If the tail is updated too often, the PCIe core may
//               backpressure. If this causes the queue to get full, some
//               descriptors may never be read.
always @(posedge clk) begin
  q_table_a_tails.rd_en <= 0;
  q_table_a_l_addrs.rd_en <= 0;
  q_table_a_h_addrs.rd_en <= 0;

  q_table_a_tails_wr_en <= 0;
  q_table_a_tails_wr_en_r <= q_table_a_tails_wr_en;
  q_table_a_tails_wr_data_r <= q_table_a_tails_wr_data;
  q_table_a_tails_wr_addr_r <= q_table_a_tails_wr_addr;

  if (rst) begin
    ignored_tail_set <= 0;
  end else if (q_table_tails.wr_en) begin
    if (can_issue_dma_rd) begin
      consume_tx_queue(q_table_tails.addr, q_table_tails.wr_data);
      ignored_tail_set <= 0; // HACK(sadok): assume single descriptor queue.
    end else begin
      // HACK(sadok): assume single descriptor queue.
      ignored_tail_set <= 1;
      ignored_tail <= q_table_tails.wr_data;
    end
  end else if (ignored_tail_set & can_issue_dma_rd) begin
    // HACK(sadok): assume single descriptor queue.
    consume_tx_queue(0, ignored_tail);
    ignored_tail_set <= 0;
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
    if (q_table_tails.wr_en & !can_issue_dma_rd) begin
      ignored_dsc_cnt <= ignored_dsc_cnt + 1;
    end
  end
end

// Whenever a queue state read completes, we enqueue it to dsc_reads_queue.
always @(posedge clk) begin
  dsc_reads_queue_in_valid <= 0;

  if (rst) begin
    empty_tail_cnt <= 0;
  end

  if (q_table_a_tails_rd_en_r2) begin
    automatic logic [31:0] head;
    dsc_reads_queue_in_data.queue_id <= queue_id_r2;
    dsc_reads_queue_in_data.tail <= tail_r2;
    dsc_reads_queue_in_data.l_addr <= q_table_a_l_addrs.rd_data;
    dsc_reads_queue_in_data.h_addr <= q_table_a_h_addrs.rd_data;

    head = q_table_a_tails.rd_data;
    dsc_reads_queue_in_data.head <= head;

    // Don't bother sending if there is nothing to read.
    if (head != tail_r2) begin
      dsc_reads_queue_in_valid <= 1;
    end else begin
      empty_tail_cnt <= empty_tail_cnt + 1;
    end
  end
end

logic [31:0] dsc_cnt_r1;
logic [31:0] dsc_cnt_r2;

typedef enum
{
  START_TRANSFER,
  DELAY,
  CONTINUE_TRANSFER
} state_t;

state_t state;

assign dsc_reads_queue_out_ready = (state == START_TRANSFER)
                                   & !rddm_desc_queue_alm_full;

q_state_t last_dsc_reads_queue_out_data;
q_state_t last_dsc_reads_queue_out_data_r;

function void dma_rd_descriptor(
  q_state_t q_state
);
  automatic rddm_dst_addr_t dst_addr = 0;
  automatic rddm_desc_t rddm_desc = 0;
  automatic logic [DSC_Q_TABLE_HEADS_DWIDTH-1:0] nb_flits;
  
  rddm_desc.single_dst = 1;
  rddm_desc.descriptor_id = 2;  // Make sure this remains different from the
                                // one used in the `prio` queue.

  rddm_desc.src_addr[31:0] = q_state.l_addr;
  rddm_desc.src_addr[63:32] = q_state.h_addr;
  rddm_desc.src_addr += q_state.head << 6;

  dst_addr.descriptor = 1;
  dst_addr.queue_id = q_state.queue_id;
  dst_addr.head = q_state.head;
  rddm_desc.dst_addr = dst_addr;

  last_dsc_reads_queue_out_data <= q_state;

  // Unless we need to send multiple transfers, we should go to START_TRANSFER. 
  state <= START_TRANSFER;

  // Check if request wraps around.
  if (q_state.tail > q_state.head) begin
    nb_flits = q_state.tail - q_state.head;
  end else begin
    nb_flits = rb_size - q_state.head;

    // Since it wraps around, need to send at least two read requests if tail is
    // not 0.
    if (q_state.tail != 0) begin
      state <= DELAY;
    end
  end

  // Limit number of descriptors fetch at once to MAX_TX_DSC_BATCH.
  if (nb_flits > MAX_TX_DSC_BATCH) begin
    nb_flits = MAX_TX_DSC_BATCH;
    state <= DELAY;
  end

  last_dsc_reads_queue_out_data.head <= (q_state.head + nb_flits) & rb_mask;

  rddm_desc.nb_dwords = nb_flits << 4;
  dsc_cnt_r2 <= dsc_cnt_r2 + nb_flits;

  rddm_desc_queue_in_valid_r <= 1;
  rddm_desc_queue_in_data_r <= rddm_desc;
endfunction

// Send descriptor to RDDM to read latest descriptors for a given TX dsc queue.
// It consumes the queue state from dsc_reads_queue and enqueues PCIe core
// RDDM descriptors to the rddm_prio_queue.
always @(posedge clk) begin
  rddm_desc_queue_in_valid_r <= 0;

  rddm_desc_queue_in_data <= rddm_desc_queue_in_data_r;
  rddm_desc_queue_in_valid <= rddm_desc_queue_in_valid_r;

  dsc_cnt <= dsc_cnt_r1;
  dsc_cnt_r1 <= dsc_cnt_r2;

  last_dsc_reads_queue_out_data_r <= last_dsc_reads_queue_out_data;

  if (rst) begin
    dsc_cnt_r2 <= 0;
    state <= START_TRANSFER;
  end else begin
    case (state)
      START_TRANSFER: begin
        // Consume next read request from dsc_reads_queue.
        if (dsc_reads_queue_out_valid & dsc_reads_queue_out_ready) begin
          dma_rd_descriptor(dsc_reads_queue_out_data);
        end
      end
      // Introducing delay to help with timing.
      DELAY: begin
        state <= CONTINUE_TRANSFER;
      end
      CONTINUE_TRANSFER: begin
        dma_rd_descriptor(last_dsc_reads_queue_out_data_r);
      end
    endcase
  end
end

logic [DSC_Q_TABLE_HEADS_DWIDTH-1:0] last_head;
logic [QUEUE_ID_WIDTH:0]             last_queue_id;  // Extra bit to represent
                                                     // invalid.

logic meta_queue_in_valid_r;
meta_t meta_queue_in_data_r;

// Reacts to MM writes from RDDM. Descriptor writes cause a metadata to be
// enqueued to the `meta_queue` and also trigger a DMA read for the associated
// packets (which are enqueued to the `rddm_desc_queue`). Packet writes are
// enqueued to the `pkt_queue`.
always @(posedge clk) begin
  rddm_prio_queue_in_valid <= 0;
  meta_queue_in_valid_r <= 0;
  pkt_queue_in_valid <= 0;

  meta_queue_in_valid <= meta_queue_in_valid_r;
  meta_queue_in_data <= meta_queue_in_data_r;

  if (rst) begin
    last_queue_id[QUEUE_ID_WIDTH] <= 1;  // Invalid queue.
    dsc_read_cnt <= 0;
    pkt_read_cnt <= 0;
  end else if (pcie_rddm_write) begin
    automatic rddm_dst_addr_t rddm_dst_addr = pcie_rddm_address;

    // TODO(sadok): group multiple descriptors in the same cache line?
    if (rddm_dst_addr.descriptor) begin  // Received a descriptor.
      automatic pcie_tx_dsc_t tx_dsc = pcie_rddm_writedata;
      automatic meta_t meta;
      automatic rddm_desc_t rddm_desc = 0;

      rddm_desc.single_dst = 1;
      rddm_desc.descriptor_id = 1;  // Make sure this remains different from the
                                    // one used in the `desc` queue.

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

      rddm_prio_queue_in_valid <= 1;
      rddm_prio_queue_in_data <= rddm_desc;

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
      meta.transfer_addr = tx_dsc.addr;

      meta_queue_in_valid_r <= 1;
      meta_queue_in_data_r <= meta;

      dsc_read_cnt <= dsc_read_cnt + 1;
    end else begin  // Received a packet.
      pkt_queue_in_data <= pcie_rddm_writedata;
      pkt_queue_in_valid <= 1;

      pkt_read_cnt <= pkt_read_cnt + 1;
    end
  end
end

logic [19:0] batch_pending_bytes;
logic [19:0] pkt_pending_bytes;
logic transfer_done;
logic ready_for_next_pkt;

logic external_address_access;

// Ready signals for meta_queue and pkt_queue.
always_comb begin
  if (transfer_done) begin
    meta_queue_out_ready = !out_pkt_alm_full & !tx_compl_buf_alm_full
                           & pkt_queue_out_valid;
    pkt_queue_out_ready = meta_queue_out_ready;
  end else begin
    meta_queue_out_ready = 0;
    pkt_queue_out_ready = !out_pkt_alm_full & !tx_compl_buf_alm_full;
  end

  // If there is an access from JTAG/MMIO, we need to stall.
  external_address_access = q_table_l_addrs.rd_en | q_table_h_addrs.rd_en
                           | q_table_l_addrs.wr_en | q_table_h_addrs.wr_en;
  if (external_address_access) begin
    meta_queue_out_ready = 0;
    pkt_queue_out_ready = 0;
  end
end

meta_t cur_meta;

logic addr_rd_en;
logic addr_rd_en_r1;
logic addr_rd_en_r2;

logic [63:0] compl_transf_addr;
logic [63:0] compl_transf_addr_r1;
logic [63:0] compl_transf_addr_r2;

logic [19:0] compl_length;
logic [19:0] compl_length_r1;
logic [19:0] compl_length_r2;

logic [DSC_Q_TABLE_HEADS_DWIDTH-1:0] compl_head;
logic [DSC_Q_TABLE_HEADS_DWIDTH-1:0] compl_head_r1;
logic [DSC_Q_TABLE_HEADS_DWIDTH-1:0] compl_head_r2;

logic [QUEUE_ID_WIDTH-1:0] addr_addr;

logic         out_pkt_sop_r;
logic         out_pkt_eop_r;
logic         out_pkt_valid_r;
logic [511:0] out_pkt_data_r;
logic [5:0]   out_pkt_empty_r;

function void done_sending_batch(
  meta_t meta
);
  // Write latest head.
  q_table_a_heads.addr <= meta.queue_id;
  q_table_a_heads.wr_data <= (meta.head + 1) & rb_mask;
  q_table_a_heads.wr_en <= 1;
  
  // Read address to send completion notification.
  addr_rd_en <= 1;
  addr_addr <= meta.queue_id;

  // Save remaining metadata for completion notification.
  compl_transf_addr <= meta.transfer_addr;
  compl_length <= meta.total_bytes;
  compl_head <= meta.head;

  batch_cnt <= batch_cnt + 1;
endfunction

function void send_flit(
  logic [19:0] bytes_remaining,
  meta_t meta
);
  automatic logic [15:0] pkt_len_be = pkt_queue_out_data[16*8 +: 16];
  automatic logic [15:0] pkt_len_le = {pkt_len_be[7:0], pkt_len_be[15:8]};
  automatic logic [19:0] current_pkt_pending_bytes;

  out_pkt_data_r <= pkt_queue_out_data;
  out_pkt_empty_r <= 0;  // TODO(sadok): handle unaligned packets.
  out_pkt_valid_r <= 1;

  if (ready_for_next_pkt) begin
    out_pkt_sop_r <= 1;
    current_pkt_pending_bytes = pkt_len_le; // TODO(sadok): L2 header/trailer?
  end else begin
    current_pkt_pending_bytes = pkt_pending_bytes;
  end

  if (current_pkt_pending_bytes <= 64) begin
    out_pkt_eop_r <= 1;
    ready_for_next_pkt <= 1;
    pkt_pending_bytes <= 0;
  end else begin
    ready_for_next_pkt <= 0;
    pkt_pending_bytes <= current_pkt_pending_bytes - 64;
  end

  if (bytes_remaining <= 64) begin
    done_sending_batch(meta);
    transfer_done <= 1;
    batch_pending_bytes <= 0;
  end else begin
    transfer_done <= 0;
    batch_pending_bytes <= bytes_remaining - 64;
  end
endfunction

// Consume packets and send them out setting sop and eop.
// (Assuming raw sockets for now, that means that headers are populated by
// software).
always @(posedge clk) begin
  q_table_a_heads.wr_en <= 0;

  out_pkt_sop_r <= 0;
  out_pkt_eop_r <= 0;
  out_pkt_valid_r <= 0;
  out_pkt_empty_r <= 0;

  out_pkt_sop <= out_pkt_sop_r;
  out_pkt_eop <= out_pkt_eop_r;
  out_pkt_valid <= out_pkt_valid_r;
  out_pkt_data <= out_pkt_data_r;
  out_pkt_empty <= out_pkt_empty_r;

  // If there is an access from JTAG/MMIO, we need to retry the read.
  if (!external_address_access) begin
    addr_rd_en <= 0;
    addr_rd_en_r1 <= addr_rd_en;
  end
  addr_rd_en_r2 <= addr_rd_en_r1;

  if (rst) begin
    transfer_done <= 1;
    ready_for_next_pkt <= 1;
    batch_cnt <= 0;
  end else begin
    if (!transfer_done & pkt_queue_out_valid & pkt_queue_out_ready) begin
      send_flit(batch_pending_bytes, cur_meta);
    end else if (meta_queue_out_ready & meta_queue_out_valid) begin
      cur_meta <= meta_queue_out_data;
      send_flit(meta_queue_out_data.total_bytes, meta_queue_out_data);
    end
  end
end

// Once the address read is complete we can finally enqueue the completion
// notification.
always @(posedge clk) begin
  tx_compl_buf_valid <= 0;

  compl_transf_addr_r1 <= compl_transf_addr;
  compl_transf_addr_r2 <= compl_transf_addr_r1;

  compl_length_r1 <= compl_length;
  compl_length_r2 <= compl_length_r1;

  compl_head_r1 <= compl_head;
  compl_head_r2 <= compl_head_r1;

  if (addr_rd_en_r2) begin
    automatic tx_transfer_t tx_completion;

    tx_completion.descriptor_addr[31:0] = q_table_b_l_addrs.rd_data;
    tx_completion.descriptor_addr[63:32] = q_table_b_h_addrs.rd_data;
    tx_completion.descriptor_addr += compl_head_r2 << 6;

    tx_completion.transfer_addr = compl_transf_addr_r2;
    tx_completion.length = compl_length_r2;

    tx_compl_buf_valid <= 1;
    tx_compl_buf_data <= tx_completion;
  end
end

assign q_table_a_heads.rd_en = 0;

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

logic pcie_rddm_desc_ready_r1;
logic pcie_rddm_desc_ready_r2;
logic pcie_rddm_desc_ready_r3;

logic pcie_rddm_prio_ready_r1;
logic pcie_rddm_prio_ready_r2;
logic pcie_rddm_prio_ready_r3;

logic rddm_desc_queue_out_valid;
logic rddm_desc_queue_out_ready;

logic rddm_prio_queue_out_valid;
logic rddm_prio_queue_out_ready;

// Adjusting to the ready latency of 3 cycles imposed by the RDDM.
always @(posedge clk) begin
  pcie_rddm_desc_ready_r1 <= pcie_rddm_desc_ready;
  pcie_rddm_desc_ready_r2 <= pcie_rddm_desc_ready_r1;
  pcie_rddm_desc_ready_r3 <= pcie_rddm_desc_ready_r2;

  pcie_rddm_prio_ready_r1 <= pcie_rddm_prio_ready;
  pcie_rddm_prio_ready_r2 <= pcie_rddm_prio_ready_r1;
  pcie_rddm_prio_ready_r3 <= pcie_rddm_prio_ready_r2;
end

logic has_enough_credit;
logic has_enough_credit_r;
logic [31:0] nb_requested_descriptors;

always_comb begin
  automatic rddm_desc_t rddm_desc = pcie_rddm_desc_data;

  if (rddm_desc_queue_out_valid) begin
    nb_requested_descriptors = rddm_desc.nb_dwords >> 4;
  end else begin
    nb_requested_descriptors = 0;
  end
  
  // Limit the number of in-flight requested descriptors. `inflight_desc_limit`
  // is configurable through JTAG.
  has_enough_credit =
    (inflight_descriptors + nb_requested_descriptors) <= inflight_desc_limit;

  rddm_desc_queue_out_ready = pcie_rddm_desc_ready_r3 & has_enough_credit_r;
  pcie_rddm_desc_valid = rddm_desc_queue_out_valid & rddm_desc_queue_out_ready;
  rddm_prio_queue_out_ready = pcie_rddm_prio_ready_r3;
  pcie_rddm_prio_valid = rddm_prio_queue_out_valid & rddm_prio_queue_out_ready;
end

// Keep track of in-flight descriptors. Whenever the PCIe core consumes the
// descriptor we increment by the number of requested descriptors. Whenever a
// descriptor arrives we decrement.
always @(posedge clk) begin
  has_enough_credit_r <= has_enough_credit;
  if (rst) begin
    inflight_descriptors <= 0;
    max_inflight_dscs <= 0;
    max_nb_req_dscs <= 0;
  end else begin
    automatic rddm_dst_addr_t rddm_dst_addr = pcie_rddm_address;
    automatic logic descriptor_arrived;

    descriptor_arrived = pcie_rddm_write & rddm_dst_addr.descriptor;
    if (pcie_rddm_desc_valid) begin
      inflight_descriptors <=
        inflight_descriptors + nb_requested_descriptors - descriptor_arrived;
    end else begin
      inflight_descriptors <= inflight_descriptors - descriptor_arrived;
    end

    if (inflight_descriptors > max_inflight_dscs) begin
      max_inflight_dscs <= inflight_descriptors;
    end
    if (nb_requested_descriptors > max_nb_req_dscs) begin
      max_nb_req_dscs <= nb_requested_descriptors;
    end
  end
end

fifo_wrapper_infill_mlab #(
  .SYMBOLS_PER_BEAT(1),
  .BITS_PER_SYMBOL($bits(pcie_rddm_desc_data)),
  .FIFO_DEPTH(RDDM_DESC_QUEUE_LEN)
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
  .out_valid     (rddm_desc_queue_out_valid),
  .out_ready     (rddm_desc_queue_out_ready)
);

fifo_wrapper_infill_mlab #(
  .SYMBOLS_PER_BEAT(1),
  .BITS_PER_SYMBOL($bits(pcie_rddm_prio_data)),
  .FIFO_DEPTH(RDDM_PRIO_QUEUE_LEN)
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
  .out_valid     (rddm_prio_queue_out_valid),
  .out_ready     (rddm_prio_queue_out_ready)
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

// Check if queues are being used correctly.
always @(posedge clk) begin
  queue_full_signals[31:7] <= 0;
  if (rst) begin
    queue_full_signals[6:0] <= 0;
  end else begin
    if (!dsc_reads_queue_in_ready & dsc_reads_queue_in_valid) begin
      queue_full_signals[0] <= 1;
      $fatal;
    end
    if (!rddm_prio_queue_in_ready & rddm_prio_queue_in_valid) begin
      queue_full_signals[1] <= 1;
      $fatal;
    end
    if (!rddm_desc_queue_in_ready & rddm_desc_queue_in_valid) begin
      queue_full_signals[2] <= 1;
      $fatal;
    end
    if (!meta_queue_in_ready & meta_queue_in_valid) begin
      queue_full_signals[3] <= 1;
      $fatal;
    end
    if (!pkt_queue_in_ready & pkt_queue_in_valid) begin
      queue_full_signals[4] <= 1;
      $fatal;
    end
    if (!tx_compl_buf_ready & tx_compl_buf_valid) begin
      queue_full_signals[5] <= 1;
      $fatal;
    end
    if (!out_pkt_ready & out_pkt_valid) begin
      queue_full_signals[6] <= 1;
      $fatal;
    end
  end
end

logic [QUEUE_ID_WIDTH-1:0] q_table_a_tails_addr;

always_comb begin
  // Tails write address to port A is delayed by 1 cycle.
  if (q_table_a_tails.rd_en) begin
    q_table_a_tails_addr = q_table_a_tails_rd_addr;
  end else begin
    q_table_a_tails_addr = q_table_a_tails_wr_addr_r;
  end

  compl_q_table_l_addrs_rd_en = addr_rd_en;
  compl_q_table_h_addrs_rd_en = addr_rd_en;

  compl_q_table_l_addrs_addr = addr_addr;
  compl_q_table_h_addrs_addr = addr_addr;

  if (external_address_access) begin
    q_table_b_l_addrs.addr = q_table_l_addrs.addr;
    q_table_b_h_addrs.addr = q_table_h_addrs.addr;

    q_table_b_l_addrs.rd_en = q_table_l_addrs.rd_en;
    q_table_b_h_addrs.rd_en = q_table_h_addrs.rd_en;
  end else begin
    q_table_b_l_addrs.addr = compl_q_table_l_addrs_addr;
    q_table_b_h_addrs.addr = compl_q_table_h_addrs_addr;

    q_table_b_l_addrs.rd_en = compl_q_table_l_addrs_rd_en;
    q_table_b_h_addrs.rd_en = compl_q_table_h_addrs_rd_en;
  end

  q_table_b_l_addrs.wr_data = q_table_l_addrs.wr_data;
  q_table_b_h_addrs.wr_data = q_table_h_addrs.wr_data;

  q_table_b_l_addrs.wr_en = q_table_l_addrs.wr_en;
  q_table_b_h_addrs.wr_en = q_table_h_addrs.wr_en;

  q_table_l_addrs.rd_data = q_table_b_l_addrs.rd_data;
  q_table_h_addrs.rd_data = q_table_b_h_addrs.rd_data;
end

//////////////////////////////
// TX DSC Queue State BRAMs //
//////////////////////////////

bram_true2port #(
  .AWIDTH(QUEUE_ID_WIDTH),
  .DWIDTH(DSC_Q_TABLE_TAILS_DWIDTH),
  .DEPTH(NB_QUEUES)
) q_table_tails_bram (
  .address_a (q_table_a_tails_addr),
  .address_b (q_table_tails.addr[QUEUE_ID_WIDTH-1:0]),
  .clock     (clk),
  .data_a    (q_table_a_tails_wr_data_r),
  .data_b    (),
  .rden_a    (q_table_a_tails.rd_en),
  .rden_b    (q_table_tails.rd_en),
  .wren_a    (q_table_a_tails_wr_en_r),
  .wren_b    (1'b0),
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
  .address_b (q_table_b_l_addrs.addr[QUEUE_ID_WIDTH-1:0]),
  .clock     (clk),
  .data_a    (q_table_a_l_addrs.wr_data),
  .data_b    (q_table_b_l_addrs.wr_data),
  .rden_a    (q_table_a_l_addrs.rd_en),
  .rden_b    (q_table_b_l_addrs.rd_en),
  .wren_a    (q_table_a_l_addrs.wr_en),
  .wren_b    (q_table_b_l_addrs.wr_en),
  .q_a       (q_table_a_l_addrs.rd_data),
  .q_b       (q_table_b_l_addrs.rd_data)
);

bram_true2port #(
  .AWIDTH(QUEUE_ID_WIDTH),
  .DWIDTH(DSC_Q_TABLE_H_ADDRS_DWIDTH),
  .DEPTH(NB_QUEUES)
) q_table_h_addrs_bram (
  .address_a (q_table_a_h_addrs.addr[QUEUE_ID_WIDTH-1:0]),
  .address_b (q_table_b_h_addrs.addr[QUEUE_ID_WIDTH-1:0]),
  .clock     (clk),
  .data_a    (q_table_a_h_addrs.wr_data),
  .data_b    (q_table_b_h_addrs.wr_data),
  .rden_a    (q_table_a_h_addrs.rd_en),
  .rden_b    (q_table_b_h_addrs.rd_en),
  .wren_a    (q_table_a_h_addrs.wr_en),
  .wren_b    (q_table_b_h_addrs.wr_en),
  .q_a       (q_table_a_h_addrs.rd_data),
  .q_b       (q_table_b_h_addrs.rd_data)
);

// Unused inputs.
assign q_table_a_l_addrs.wr_data = 32'bx;
assign q_table_a_h_addrs.wr_data = 32'bx;

endmodule
