`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
`include "../src/constants.sv"
`include "../src/pcie/pcie_consts.sv"

module test_pcie_top;

`ifndef NB_DSC_QUEUES
`define NB_DSC_QUEUES 2
`endif

`ifndef NB_PKT_QUEUES
`define NB_PKT_QUEUES 4
`endif

`define ENABLE_ZERO_PCIE 0

generate
  // We assume this during the test, it does not necessarily hold in general.
  if (((`NB_PKT_QUEUES / `NB_DSC_QUEUES) * `NB_DSC_QUEUES) != `NB_PKT_QUEUES)
  begin
    $error("NB_PKT_QUEUES must be a multiple of NB_DSC_QUEUES");
  end
endgenerate

localparam pcie_period = 4;
localparam status_period = 10;
localparam nb_dsc_queues = `NB_DSC_QUEUES;
localparam nb_pkt_queues = `NB_PKT_QUEUES;
localparam pkt_per_dsc_queue = nb_pkt_queues / nb_dsc_queues;
localparam pkt_size = 64; // in bytes
localparam req_size = pkt_size/4; // in dwords

// #cycles to wait before updating the head pointer for the packet queue
localparam update_head_delay = 64;

localparam target_nb_requests = 256;

// size of the host buffer used by each queue (in flits)
localparam DSC_BUF_SIZE = 8192;
localparam PKT_BUF_SIZE = 8192;
let max(a,b) = (a > b) ? a : b;
localparam RAM_SIZE = max(DSC_BUF_SIZE, PKT_BUF_SIZE);
localparam RAM_ADDR_LEN = $clog2(RAM_SIZE);

logic [63:0] cnt;
logic        clk;
logic        rst;

logic         pcie_wrdm_desc_ready;
logic         pcie_wrdm_desc_valid;
logic [173:0] pcie_wrdm_desc_data;
logic         pcie_wrdm_prio_ready;
logic         pcie_wrdm_prio_valid;
logic [173:0] pcie_wrdm_prio_data;
logic         pcie_wrdm_tx_valid;
logic [31:0]  pcie_wrdm_tx_data;

logic         pcie_rddm_desc_ready;
logic         pcie_rddm_desc_valid;
logic [173:0] pcie_rddm_desc_data;
logic         pcie_rddm_prio_ready;
logic         pcie_rddm_prio_valid;
logic [173:0] pcie_rddm_prio_data;
logic         pcie_rddm_tx_valid;
logic [31:0]  pcie_rddm_tx_data;

logic                       pcie_bas_waitrequest;
logic [63:0]                pcie_bas_address;
logic [63:0]                pcie_bas_byteenable;
logic                       pcie_bas_read;
logic [511:0]               pcie_bas_readdata;
logic                       pcie_bas_readdatavalid;
logic                       pcie_bas_write;
logic [511:0]               pcie_bas_writedata;
logic [3:0]                 pcie_bas_burstcount;
logic [1:0]                 pcie_bas_response;

logic [PCIE_ADDR_WIDTH-1:0] pcie_address_0;
logic                       pcie_write_0;
logic                       pcie_read_0;
logic                       pcie_readdatavalid_0;
logic [511:0]               pcie_readdata_0;
logic [511:0]               pcie_writedata_0;
logic [63:0]                pcie_byteenable_0;

logic [63:0]  pcie_rddm_address;
logic         pcie_rddm_write;
logic [511:0] pcie_rddm_writedata;
logic [63:0]  pcie_rddm_byteenable;

logic pcie_rx_pkt_buf_ready;
logic pcie_rx_meta_buf_ready;

flit_lite_t             pcie_rx_pkt_buf_data;
logic                   pcie_rx_pkt_buf_valid;
logic [F2C_RB_AWIDTH:0] pcie_rx_pkt_buf_occup;

pkt_meta_t              pcie_rx_meta_buf_data;
logic                   pcie_rx_meta_buf_valid;
logic [F2C_RB_AWIDTH:0] pcie_rx_meta_buf_occup;

logic         pcie_tx_pkt_sop;
logic         pcie_tx_pkt_eop;
logic         pcie_tx_pkt_valid;
logic [511:0] pcie_tx_pkt_data;
logic [5:0]   pcie_tx_pkt_empty;
logic         pcie_tx_pkt_ready;
logic [31:0]  pcie_tx_pkt_occup;

logic          disable_pcie;
logic          sw_reset;
logic [31:0]   pcie_core_full_cnt;
logic [31:0]   rx_dma_dsc_cnt;
logic [31:0]   rx_dma_dsc_drop_cnt;
logic [31:0]   rx_dma_pkt_flit_cnt;
logic [31:0]   rx_dma_pkt_flit_drop_cnt;
logic [31:0]   cpu_dsc_buf_full_cnt;
logic [31:0]   cpu_pkt_buf_full_cnt;

logic                       clk_status;
logic [PCIE_ADDR_WIDTH-1:0] status_addr;
logic                       status_read;
logic                       status_write;
logic [31:0]                status_writedata;
logic [31:0]                status_readdata;
logic                       status_readdata_valid;

logic stop;
logic error_termination;
logic [31:0] stop_cnt;

// Host RAM
logic [511:0] ram[nb_pkt_queues + nb_dsc_queues * 2][RAM_SIZE];

logic [BRAM_TABLE_IDX_WIDTH:0] expected_pkt_queue;  // Extra bit on purpose.
logic [BRAM_TABLE_IDX_WIDTH:0] cfg_queue;  // Extra bit on purpose.
logic [nb_pkt_queues-1:0] pending_pkt_tails_valid;
logic [31:0] pending_pkt_tails[nb_pkt_queues];
logic [31:0] last_pkt_heads[nb_pkt_queues];
logic [31:0] tx_pkt_heads[nb_pkt_queues];
logic [31:0] tx_dsc_tails[nb_dsc_queues];
logic [31:0] tx_dsc_heads[nb_dsc_queues];

logic [31:0] last_upd_pkt_q;
logic [31:0] last_upd_dsc_q;
logic [31:0] pkt_q_consume_delay_cnt;
logic [63:0] rx_cnt;
logic [63:0] req_cnt;
logic [63:0] start_wait;
logic        startup_ready;
logic [2:0]  burst_offset; // max of 8 flits per burst
logic [3:0]  burst_size;
logic [$clog2(MAX_PKT_SIZE)-1:0] pdu_flit_cnt;

logic tx_dsc_tail_pending;
logic dma_write_pending;

logic [$bits(pcie_rddm_desc_data)-1:0] rddm_desc_queue_data;
logic        rddm_desc_queue_valid;
logic        rddm_desc_queue_ready;
logic [31:0] rddm_desc_queue_occup;

logic [$bits(pcie_rddm_desc_data)-1:0] rddm_prio_queue_data;
logic        rddm_prio_queue_valid;
logic        rddm_prio_queue_ready;
logic [31:0] rddm_prio_queue_occup;

logic [17:0] pending_dma_write_dwords;
logic [63:0] pending_dma_write_dst_addr;
logic [63:0] pending_dma_write_src_addr;

initial cnt = 0;
initial clk = 0;
initial clk_status = 0;
initial rst = 1;
initial stop = 0;
initial error_termination = 0;

always #(pcie_period) clk = ~clk;
always #(status_period) clk_status = ~clk_status;

assign dma_write_pending = pending_dma_write_dwords > 0;
assign rddm_prio_queue_ready = !dma_write_pending;
assign rddm_desc_queue_ready = !dma_write_pending & !rddm_prio_queue_valid;

typedef enum
{
  SETUP_0,
  SETUP_1,
  WAIT,
  RUN
} control_state_t;

control_state_t control_state;

always @(posedge clk) begin
  automatic logic next_pcie_write_0;
  cnt <= cnt + 1;

  next_pcie_write_0 = 0;
  pcie_read_0 <= 0;

  pcie_rddm_write <= 0;

  if (cnt < 10) begin  // Reset.
    automatic integer c;
    rst <= 1;
    pcie_bas_waitrequest <= 0;
    pcie_address_0 <= 0;

    pcie_writedata_0 <= 0;
    pcie_byteenable_0 <= 0;
    rx_cnt <= 0;
    req_cnt <= 0;
    stop_cnt <= 0;
    pdu_flit_cnt <= 0;
    expected_pkt_queue <= 0;
    cfg_queue <= 0;
    start_wait <= 0;
    startup_ready <= 0;
    burst_offset <= 0;
    burst_size <= 0;

    control_state <= SETUP_0;

    last_upd_pkt_q <= 0;
    last_upd_dsc_q <= 0;
    pkt_q_consume_delay_cnt <= 0;

    pending_pkt_tails_valid <= 0;

    tx_dsc_tail_pending <= 0;

    pending_dma_write_dwords <= 0;

    for (c = 0; c < nb_pkt_queues; c++) begin
      pending_pkt_tails[c] <= 0;
      last_pkt_heads[c] <= 0;
      tx_pkt_heads[c] <= 0;
      tx_dsc_tails[c] <= 0;
      tx_dsc_heads[c] <= 0;
    end
  end else begin
    case (control_state)
     SETUP_0: begin
      if (cnt == 10) begin
        rst <= 0;
      end else begin
        automatic logic [APP_IDX_WIDTH] dsc_queue_id;

        // Set pkt queues.
        next_pcie_write_0 = 1;
        pcie_address_0 <= cfg_queue << 12;
        pcie_writedata_0 <= 0;
        pcie_byteenable_0 <= 0;

        dsc_queue_id = cfg_queue / (nb_pkt_queues / nb_dsc_queues);

        // Pkt queue address.
        // Note that we are placing queues 32 bit apart in the address space.
        // This is done to simplify the test and is not a requirement. We also
        // write the the corresponding descriptor queue id to the LSB.
        pcie_writedata_0[64 +: 64] <= 64'ha000000000000000 +
                                      (cfg_queue << 32) + dsc_queue_id;
        pcie_byteenable_0[8 +: 8] <= 8'hff;

        if (cfg_queue == nb_pkt_queues - 1) begin
          control_state <= SETUP_1;
          cfg_queue <= 0;
        end else begin
          cfg_queue <= cfg_queue + 1;
        end
      end
     end
     SETUP_1: begin
      // Set dsc queues.
      next_pcie_write_0 = 1;
      pcie_address_0 <= (cfg_queue + MAX_NB_FLOWS) << 12;
      pcie_writedata_0 <= 0;
      pcie_byteenable_0 <= 0;

      // Dsc queue address.
      // We place dsc queues after pkt queues in the address space but
      // this is done to simplify the test and is not a requirement.

      // RX dsc queue.
      pcie_writedata_0[64 +: 64] <= 64'hb000000000000000 +
        ((cfg_queue + nb_pkt_queues) << 32);
      pcie_byteenable_0[8 +: 8] <= 8'hff;

      // TX dsc queue (after all RX dsc queues).
      pcie_writedata_0[192 +: 64] <= 64'hb000000000000000 +
        ((cfg_queue + nb_pkt_queues + nb_dsc_queues) << 32);
      pcie_byteenable_0[24 +: 8] <= 8'hff;

      if (cfg_queue == nb_dsc_queues - 1) begin
        control_state <= WAIT;
        cfg_queue <= 0;
      end else begin
        cfg_queue <= cfg_queue + 1;
      end
     end
     WAIT: begin
      if (start_wait == 0) begin
        start_wait <= cnt;
      end else if (cnt == start_wait + 10) begin
        startup_ready <= 1;
        control_state <= RUN;
      end
     end
     RUN: begin
      if (stop_cnt == 0 && req_cnt == target_nb_requests) begin
        automatic integer i;
        automatic logic all_ready = 1;
        for (i = 0; i < nb_pkt_queues; i++) begin
          // if (pending_pkt_tails[i] !=
          //         target_nb_requests/nb_pkt_queues) begin
          if (pending_pkt_tails_valid[i]) begin
            all_ready = 0;
            break;
          end
        end
        if (all_ready) begin
          stop_cnt <= 20;
        end
      end

      if (pcie_bas_write) begin
        automatic logic [31:0] cur_queue;
        automatic logic [31:0] cur_address;

        cur_queue = pcie_bas_address[32 +: BRAM_TABLE_IDX_WIDTH+1];

        if (pcie_bas_burstcount != 0) begin
          burst_offset = 0;
          burst_size <= pcie_bas_burstcount;
        end else if (burst_offset + 1 >= burst_size) begin
          $error("Requests beyond burst size.");
        end else begin
          burst_offset = burst_offset + 1;
        end

        cur_address = pcie_bas_address[6 +: RAM_ADDR_LEN] + burst_offset;

        if (cur_queue < nb_pkt_queues) begin // pkt queue
          assert(cur_queue == expected_pkt_queue) else $fatal;

          pdu_flit_cnt = pdu_flit_cnt + 1;

          // check payload
          assert(req_cnt == pcie_bas_writedata[511:480]) else $fatal;

          // last packet flit
          if (pdu_flit_cnt == (req_size + (16 - 1))/16) begin
            req_cnt <= req_cnt + 1;
            pdu_flit_cnt = 0;
            if ((expected_pkt_queue + 1) < nb_pkt_queues) begin
              expected_pkt_queue <= expected_pkt_queue + 1;
            end else begin
              expected_pkt_queue <= 0;
            end
          end
        end else if (cur_queue < nb_pkt_queues + nb_dsc_queues) begin
          // rx dsc queue
          automatic logic [31:0] pkt_per_dsc_queue;
          automatic logic [31:0] expected_dsc_queue;
          automatic pcie_rx_dsc_t pcie_pkt_desc;

          // dsc queues can receive only one flit per burst
          assert(pcie_bas_burstcount == 1) else $fatal;

          pcie_pkt_desc = pcie_bas_writedata;

          assert(pcie_pkt_desc.signal == 1) else $fatal;

          // This is due to how we configured the queue addresses
          // (dsc queues after pkt queues) as well as how we send
          // packets (round robin among pkt queues).
          pkt_per_dsc_queue = nb_pkt_queues / nb_dsc_queues;
          expected_dsc_queue = nb_pkt_queues +
            (expected_pkt_queue - 1) % nb_pkt_queues / pkt_per_dsc_queue;

          // assert(cur_queue == expected_dsc_queue) else $fatal;

          // update dsc queue here
          next_pcie_write_0 = 1;
          pcie_address_0 <= (cur_queue - nb_pkt_queues + MAX_NB_FLOWS) << 12;
          pcie_writedata_0 <= 0;
          pcie_byteenable_0 <= 0;

          pcie_writedata_0[32 +: 32] <= cur_address;
          pcie_byteenable_0[4 +: 4] <= 4'hf;

          // // Should not receive a descriptor to the same queue
          // // before software advanced the head for this queue.
          // assert(pending_pkt_tails_valid[
          //     pcie_pkt_desc.queue_id] == 0) else $fatal;

          // Save tail so we can advance the head later.
          pending_pkt_tails[pcie_pkt_desc.queue_id] <= pcie_pkt_desc.tail;
          pending_pkt_tails_valid[pcie_pkt_desc.queue_id] <= 1'b1;
        end else begin  // tx dsc queue
          automatic logic [31:0] pkt_buf_queue;
          automatic logic [31:0] pkt_buf_head;
          automatic logic [31:0] tx_dsc_buf_queue;
          automatic pcie_tx_dsc_t tx_dsc = pcie_bas_writedata;
          assert(tx_dsc.signal == 0) else $fatal;

          // Figure out queue and head from address.
          pkt_buf_queue = tx_dsc.addr[32 +: BRAM_TABLE_IDX_WIDTH];
          pkt_buf_head = (tx_dsc.addr[6 +: RAM_ADDR_LEN]
                          + tx_dsc.length / 64) % PKT_BUF_SIZE;

          // Advance head pointer for corresponding pkt queue.
          next_pcie_write_0 = 1;
          pcie_address_0 <= pkt_buf_queue << 12;
          pcie_writedata_0 <= 0;
          pcie_byteenable_0 <= 0;
          last_pkt_heads[pkt_buf_queue] <= pkt_buf_head;

          pcie_writedata_0[32 +: 32] <= pkt_buf_head;
          pcie_byteenable_0[4 +: 4] <= 4'hf;

          // Advance corresponding TX dsc queue head.
          tx_dsc_buf_queue = cur_queue - nb_pkt_queues - nb_dsc_queues;
          tx_dsc_heads[tx_dsc_buf_queue]
            <= (tx_dsc_heads[tx_dsc_buf_queue] + 1) % DSC_BUF_SIZE;
        end

        // Check if address out of bound.
        if (cur_address > RAM_SIZE) begin
          $error("Address out of bound");
        end else begin
          ram[cur_queue][cur_address] <= pcie_bas_writedata;
        end

        rx_cnt <= rx_cnt + 1;
      end

      if (pkt_q_consume_delay_cnt != 0) begin
        pkt_q_consume_delay_cnt--;
      end

      // If not trying to write anything, we can try to advance one of
      // the head pointers.
      if (next_pcie_write_0 == 0) begin
        automatic integer i;

        // A TX dsc tail pointer needs to be written.
        if (tx_dsc_tail_pending) begin
          tx_dsc_tail_pending <= 0;

          next_pcie_write_0 = 1;
          pcie_address_0 <= (MAX_NB_FLOWS + last_upd_dsc_q) << 12;
          pcie_writedata_0 <= 0;
          pcie_byteenable_0 <= 0;

          pcie_writedata_0[128 +: 32] <= tx_dsc_tails[last_upd_dsc_q];
          pcie_byteenable_0[16 +: 4] <= 4'hf;

        // Enqueue TX descriptor with latest available data for one
        // of the queues.
        end else if (pkt_q_consume_delay_cnt == 0) begin
          for (i = 0; i < nb_pkt_queues; i++) begin
            automatic integer pkt_q = (i + last_upd_pkt_q + 1) % nb_pkt_queues;
            automatic integer dsc_q = pkt_q / pkt_per_dsc_queue;
            automatic integer free_slot =
              (tx_dsc_heads[dsc_q] - tx_dsc_tails[dsc_q] - 1) % DSC_BUF_SIZE;

            // Check if TX dsc buffer has enough room for at
            // least 2 descriptors.
            if (free_slot < 2) begin
              continue;
            end
            if (pending_pkt_tails_valid[pkt_q]) begin
              automatic logic [31:0] tx_dsc_q_addr;
              automatic logic [31:0] rx_pkt_buf_tail;
              automatic logic [31:0] rx_pkt_buf_head;
              automatic logic [31:0] tx_pkt_buf_head;
              automatic logic [63:0] pkt_buf_base_addr;

              rx_pkt_buf_tail = pending_pkt_tails[pkt_q];
              rx_pkt_buf_head = last_pkt_heads[pkt_q];
              tx_pkt_buf_head = tx_pkt_heads[pkt_q];

              next_pcie_write_0 = 1;
              pcie_address_0 <= pkt_q << 12;
              pcie_writedata_0 <= 0;
              pcie_byteenable_0 <= 0;

              // pcie_writedata_0[32 +: 32] <= rx_pkt_buf_tail;

              // Write same value again, just to inform that
              // we can receive another descriptor.
              pcie_writedata_0[32 +: 32] <= rx_pkt_buf_head;
              pcie_byteenable_0[4 +: 4] <= 4'hf;

              pending_pkt_tails_valid[pkt_q] <= 0;

              last_upd_pkt_q = pkt_q;
              last_upd_dsc_q <= dsc_q;
              // last_pkt_heads[pkt_q] <=
              //     pending_pkt_tails[pkt_q];

              // Enqueue TX descriptor.
              pkt_buf_base_addr = 64'ha000000000000000 + (pkt_q << 32);
              tx_dsc_q_addr = nb_pkt_queues + nb_dsc_queues + dsc_q;
              if (rx_pkt_buf_tail > tx_pkt_buf_head) begin
                automatic pcie_tx_dsc_t tx_dsc = 0;
                tx_dsc.signal = 1;
                tx_dsc.addr = pkt_buf_base_addr + tx_pkt_buf_head * 64;
                tx_dsc.length = (rx_pkt_buf_tail - tx_pkt_buf_head) * 64;

                ram[tx_dsc_q_addr][tx_dsc_tails[dsc_q]] <= tx_dsc;
                tx_dsc_tails[dsc_q] <= (tx_dsc_tails[dsc_q] + 1) % DSC_BUF_SIZE;
              end else begin  // Data wrap around buffer.
                automatic pcie_tx_dsc_t tx_dsc = 0;
                tx_dsc.signal = 1;
                tx_dsc.addr = pkt_buf_base_addr + tx_pkt_buf_head * 64;
                tx_dsc.length = (DSC_BUF_SIZE - tx_pkt_buf_head) * 64;

                ram[tx_dsc_q_addr][tx_dsc_tails[dsc_q]] <= tx_dsc;

                // Send second descriptor.
                tx_dsc.addr = pkt_buf_base_addr;
                tx_dsc.length = rx_pkt_buf_tail * 64;

                ram[tx_dsc_q_addr][(tx_dsc_tails[dsc_q] + 1) % DSC_BUF_SIZE] <=
                  tx_dsc;

                // Ignore second descriptor if it has zero length.
                if (tx_dsc.length == 0) begin
                  tx_dsc_tails[dsc_q]
                    <= (tx_dsc_tails[dsc_q] + 1) % DSC_BUF_SIZE;
                end else begin
                  tx_dsc_tails[dsc_q]
                    <= (tx_dsc_tails[dsc_q] + 2) % DSC_BUF_SIZE; 
                end
              end

              tx_pkt_heads[pkt_q] <= rx_pkt_buf_tail;
              tx_dsc_tail_pending <= 1'b1;

              break;
            end
          end

          if (last_upd_pkt_q == nb_pkt_queues - 1) begin
            pkt_q_consume_delay_cnt <= update_head_delay;
          end
        end
      end

      // RDDM Mock:

      // If DMA is larger than a flit, we need to send multiple writes. If
      // `dma_write_pending` is set, there are some writes pending.
      if (dma_write_pending) begin
        automatic logic [31:0] cur_queue;
        automatic logic [31:0] cur_address;

        cur_queue = pending_dma_write_src_addr[32 +: BRAM_TABLE_IDX_WIDTH+1];
        cur_address = pending_dma_write_src_addr[6 +: RAM_ADDR_LEN];

        // Write data using RDDM Avalon-MM interface.
        pcie_rddm_write <= 1;
        pcie_rddm_address <= pending_dma_write_dst_addr;
        pcie_rddm_byteenable <= ~64'h0;
        pcie_rddm_writedata <= ram[cur_queue][cur_address];

        if (pending_dma_write_dwords > 16) begin
          pending_dma_write_dwords <= pending_dma_write_dwords - 16;
          pending_dma_write_src_addr <= pending_dma_write_src_addr + 64;
        end else begin
          pending_dma_write_dwords <= 0;
        end
      end else if ((rddm_desc_queue_ready & rddm_desc_queue_valid)
          | (rddm_prio_queue_ready & rddm_prio_queue_valid)) begin
        automatic logic [31:0] cur_queue;
        automatic logic [31:0] cur_address;
        automatic rddm_desc_t rddm_desc;

        // `prio` queue has priority over `desc` queue.
        if (rddm_prio_queue_valid) begin
          rddm_desc = rddm_prio_queue_data;
          assert(!rddm_desc_queue_ready) else $fatal;
        end else begin
          rddm_desc = rddm_desc_queue_data;
        end

        cur_queue = rddm_desc.src_addr[32 +: BRAM_TABLE_IDX_WIDTH+1];
        cur_address = rddm_desc.src_addr[6 +: RAM_ADDR_LEN];

        // Address must be aligned to double dword but here we assume cache line
        // alignment to make things easier.
        assert(rddm_desc.src_addr[5:0] == 0) else $fatal;
        assert(rddm_desc.nb_dwords[3:0] == 0) else $fatal;

        // Only single_dst is implemented in this mock.
        assert(rddm_desc.single_dst) else $fatal;

        // When setting single_dst, the dst_addr must be 64-byte aligned.
        assert(rddm_desc.dst_addr[5:0] == 0) else $fatal;

        // Write data to FPGA using RDDM Avalon-MM interface.
        pcie_rddm_write <= 1;
        pcie_rddm_address <= rddm_desc.dst_addr;  // From descriptor.
        pcie_rddm_byteenable <= ~64'h0;
        pcie_rddm_writedata <= ram[cur_queue][cur_address];

        // If DMA is larger than a flit, we need to send multiple writes.
        if (rddm_desc.nb_dwords > 16) begin
          pending_dma_write_dwords <= rddm_desc.nb_dwords - 16;
          pending_dma_write_dst_addr <= rddm_desc.dst_addr;
          pending_dma_write_src_addr <= rddm_desc.src_addr + 64;
        end else begin
          pending_dma_write_dwords <= 0;
        end
      end

      // TODO(sadok): Advance head pointer for corresponding pkt queue.
      // if (next_pcie_write_0 == 0) begin
      // end
     end
    endcase
  end

  if (stop_cnt != 0) begin
    stop_cnt <= stop_cnt - 1;
    if (stop_cnt == 1) begin
      stop <= 1;
    end
  end

  pcie_write_0 <= next_pcie_write_0;
end

typedef enum
{
  GEN_START_WAIT,
  GEN_IDLE,
  GEN_DATA
} gen_state_t;

flit_lite_t  out_pkt_queue_data;
logic        out_pkt_queue_valid;
logic        out_pkt_queue_ready;
logic [31:0] out_pkt_queue_occup;

pkt_meta_t   out_meta_queue_data;
logic        out_meta_queue_valid;
logic        out_meta_queue_ready;
logic [31:0] out_meta_queue_occup;

logic out_pkt_queue_alm_full;
assign out_pkt_queue_alm_full = out_pkt_queue_occup > 8;

logic out_meta_queue_alm_full;
assign out_meta_queue_alm_full = out_meta_queue_occup > 8;

gen_state_t                gen_state;
logic [FLOW_IDX_WIDTH-1:0] pkt_queue_id;
logic [31:0]               nb_requests;
logic [F2C_RB_AWIDTH-1:0]     flits_written;
logic [32:0]               transmit_cycles;

logic can_insert_pkt;
assign can_insert_pkt = !out_pkt_queue_alm_full & !out_meta_queue_alm_full;

// Generate requests
always @(posedge clk) begin
  out_pkt_queue_valid <= 0;
  out_meta_queue_valid <= 0;

  if (rst) begin
    gen_state <= GEN_START_WAIT;
    flits_written <= 0;
    pkt_queue_id <= 0;
    nb_requests <= 0;
    transmit_cycles <= 0;
  end else begin
    case (gen_state)
      GEN_START_WAIT: begin
        if (startup_ready) begin
           gen_state <= GEN_IDLE;
        end
      end
      GEN_IDLE: begin
        if (nb_requests < target_nb_requests) begin
          pkt_queue_id <= 0;
          flits_written <= 0;
          gen_state <= GEN_DATA;
        end
      end
      GEN_DATA: begin
        if (can_insert_pkt) begin
          out_pkt_queue_valid <= 1;
          out_pkt_queue_data.data <= {
            nb_requests, 32'h00000000, 64'h0000babe0000face,
            64'h0000babe0000face, 64'h0000babe0000face,
            64'h0000babe0000face, 64'h0000babe0000face,
            64'h0000babe0000face, 64'h0000babe0000face
          };

          flits_written <= flits_written + 1;

          // first block
          out_pkt_queue_data.sop <= (flits_written == 0);

          if ((flits_written + 1) * 16 >= req_size) begin
            out_pkt_queue_data.eop <= 1; // last block
            nb_requests <= nb_requests + 1;
            flits_written <= 0;

            // write descriptor
            out_meta_queue_valid <= 1;
            out_meta_queue_data.pkt_queue_id <= pkt_queue_id;
            out_meta_queue_data.size <= (req_size + (16 - 1))/16;

            if (nb_requests + 1 == target_nb_requests) begin
              gen_state <= GEN_IDLE;
            end else begin
              if ((pkt_queue_id + 1) == nb_pkt_queues) begin
                pkt_queue_id = 0;
              end else begin
                pkt_queue_id = pkt_queue_id + 1;
              end
            end
          end else begin
            out_pkt_queue_data.eop <= 0;
          end
        end
      end
      default: gen_state <= GEN_IDLE;
    endcase

    // count cycles until we go back to the IDLE state and there are no more
    // pending packets in the ring buffer
    if (gen_state != GEN_IDLE || pcie_rx_pkt_buf_occup != 0) begin
      transmit_cycles <= transmit_cycles + 1;
    end
  end
end

logic [31:0] tx_sop_cnt;
logic [31:0] tx_eop_cnt;
logic [31:0] rddm_write_pkt_cnt;
logic [31:0] rddm_write_dsc_cnt;

initial tx_sop_cnt = 0;
initial tx_eop_cnt = 0;
initial rddm_write_pkt_cnt = 0;
initial rddm_write_dsc_cnt = 0;

assign pcie_tx_pkt_ready = 1;
assign pcie_tx_pkt_occup = 0;

// Check TX packets
always @(posedge clk) begin
  if (pcie_tx_pkt_valid) begin
    // TODO(sadok): Also check packets' payload (pcie_tx_pkt_data and
    //              pcie_tx_pkt_empty).
    if (pcie_tx_pkt_sop) begin
      tx_sop_cnt <= tx_sop_cnt + 1;
    end
    if (pcie_tx_pkt_eop) begin
      tx_eop_cnt <= tx_eop_cnt + 1;
    end
  end

  if (pcie_rddm_write) begin
    automatic logic [31:0] cur_queue;
    automatic rddm_desc_t rddm_desc = pcie_rddm_address;
    cur_queue = rddm_desc.src_addr[32 +: BRAM_TABLE_IDX_WIDTH+1];

    if (cur_queue >= (nb_pkt_queues + nb_dsc_queues)) begin
      rddm_write_dsc_cnt <= rddm_write_dsc_cnt + 1;
    end else begin
      rddm_write_pkt_cnt <= rddm_write_pkt_cnt + 1;
    end
  end
end

// Queue that holds incoming RDDM descriptors with regular prioity (desc).
fifo_wrapper_infill_mlab #(
  .SYMBOLS_PER_BEAT(1),
  .BITS_PER_SYMBOL($bits(pcie_rddm_desc_data)),
  .FIFO_DEPTH(16)
)
rddm_desc_queue (
  .clk           (clk),
  .reset         (rst),
  .csr_address   (2'b0),
  .csr_read      (1'b1),
  .csr_write     (1'b0),
  .csr_readdata  (rddm_desc_queue_occup),
  .csr_writedata (32'b0),
  .in_data       (pcie_rddm_desc_data),
  .in_valid      (pcie_rddm_desc_valid),
  .in_ready      (pcie_rddm_desc_ready),
  .out_data      (rddm_desc_queue_data),
  .out_valid     (rddm_desc_queue_valid),
  .out_ready     (rddm_desc_queue_ready)
);

// Queue that holds incoming RDDM descriptors with elevated priority (prio).
fifo_wrapper_infill_mlab #(
  .SYMBOLS_PER_BEAT(1),
  .BITS_PER_SYMBOL($bits(pcie_rddm_desc_data)),
  .FIFO_DEPTH(16)
)
rddm_prio_queue (
  .clk           (clk),
  .reset         (rst),
  .csr_address   (2'b0),
  .csr_read      (1'b1),
  .csr_write     (1'b0),
  .csr_readdata  (rddm_prio_queue_occup),
  .csr_writedata (32'b0),
  .in_data       (pcie_rddm_prio_data),
  .in_valid      (pcie_rddm_prio_valid),
  .in_ready      (pcie_rddm_prio_ready),
  .out_data      (rddm_prio_queue_data),
  .out_valid     (rddm_prio_queue_valid),
  .out_ready     (rddm_prio_queue_ready)
);

fifo_wrapper_infill_mlab #(
  .SYMBOLS_PER_BEAT(1),
  .BITS_PER_SYMBOL($bits(pcie_rx_pkt_buf_data)),
  .FIFO_DEPTH(16)
)
out_pkt_queue (
  .clk           (clk),
  .reset         (rst),
  .csr_address   (2'b0),
  .csr_read      (1'b1),
  .csr_write     (1'b0),
  .csr_readdata  (out_pkt_queue_occup),
  .csr_writedata (32'b0),
  .in_data       (out_pkt_queue_data),
  .in_valid      (out_pkt_queue_valid),
  .in_ready      (out_pkt_queue_ready),
  .out_data      (pcie_rx_pkt_buf_data),
  .out_valid     (pcie_rx_pkt_buf_valid),
  .out_ready     (pcie_rx_pkt_buf_ready)
);

fifo_wrapper_infill_mlab #(
  .SYMBOLS_PER_BEAT(1),
  .BITS_PER_SYMBOL($bits(pcie_rx_meta_buf_data)),
  .FIFO_DEPTH(16)
)
out_meta_queue (
  .clk           (clk),
  .reset         (rst),
  .csr_address   (2'b0),
  .csr_read      (1'b1),
  .csr_write     (1'b0),
  .csr_readdata  (out_meta_queue_occup),
  .csr_writedata (32'b0),
  .in_data       (out_meta_queue_data),
  .in_valid      (out_meta_queue_valid),
  .in_ready      (out_meta_queue_ready),
  .out_data      (pcie_rx_meta_buf_data),
  .out_valid     (pcie_rx_meta_buf_valid),
  .out_ready     (pcie_rx_meta_buf_ready)
);

typedef enum{
  CONFIGURE_0,
  CONFIGURE_1,
  READ_MEMORY,
  READ_PCIE_START,
  READ_PCIE_PKT_Q,
  READ_PCIE_DSC_Q,
  ZERO_PCIE
} c_state_t;

c_state_t conf_state;

logic [31:0] read_pcie_cnt;

//Configure
//Read and display pkt/flow cnts
always @(posedge clk_status) begin
  status_read <= 0;
  status_write <= 0;
  status_writedata <= 0;
  if (rst) begin
    status_addr <= 0;
    if (`ENABLE_ZERO_PCIE) begin
      read_pcie_cnt <= 0;
    end else begin
      read_pcie_cnt <= 1;
    end
    conf_state <= CONFIGURE_0;
  end else begin
    case (conf_state)
      CONFIGURE_0: begin
        automatic logic [25:0] pkt_buf_size = PKT_BUF_SIZE;
        status_addr <= 30'h2A00_0000;
        status_write <= 1;

        `ifdef NO_PCIE
          // pcie disabled
          status_writedata <= {5'b00000, pkt_buf_size, 1'b1};
        `else
          // pcie enabled
          status_writedata <= {5'b00000, pkt_buf_size, 1'b0};
        `endif
        conf_state <= CONFIGURE_1;
      end
      CONFIGURE_1: begin
        automatic logic [25:0] dsc_buf_size = DSC_BUF_SIZE;
        status_addr <= 30'h2A00_0001;
        status_write <= 1;

        status_writedata <= {6'h0, dsc_buf_size};
        conf_state <= READ_MEMORY;
      end
      READ_MEMORY: begin
        if (stop || error_termination) begin
          automatic integer q;
          automatic integer pkt_q;
          automatic integer i;
          automatic integer j;
          automatic integer k;

          for (q = 0; q < nb_dsc_queues; q = q + 1) begin
            $display("RX Descriptor queue: %d", q);
            // printing only the beginning of each buffer,
            // may print the entire thing instead
            for (i = 0; i < 10; i = i + 1) begin
            // for (i = 0; i < RAM_SIZE; i = i + 1) begin
              for (j = 0; j < 8; j = j + 1) begin
                $write("%h:", i*64+j*8);
                for (k = 0; k < 8; k = k + 1) begin
                  $write(" %h",
                    ram[q+nb_pkt_queues][i][j*64+k*8 +: 8]);
                end
                $write("\n");
              end
              $write("\n");
            end
            $display("TX Descriptor queue: %d", q);
            for (i = 0; i < 10; i = i + 1) begin
            // for (i = 0; i < RAM_SIZE; i = i + 1) begin
              for (j = 0; j < 8; j = j + 1) begin
                $write("%h:", i*64+j*8);
                for (k = 0; k < 8; k = k + 1) begin
                  $write(" %h",
                    ram[q+nb_pkt_queues+nb_dsc_queues][i][j*64+k*8 +: 8]);
                end
                $write("\n");
              end
              $write("\n");
            end

            $display("Packet queues:");
            for (pkt_q = q*pkt_per_dsc_queue;
              pkt_q < (q+1)*pkt_per_dsc_queue; pkt_q = pkt_q + 1)
            begin
              $display("Packet queue: %d", pkt_q);
              for (i = 0; i < 10; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                  $write("%h:", i*64+j*8);
                  for (k = 0; k < 8; k = k + 1) begin
                    $write(" %h",
                      ram[pkt_q][i][j*64+k*8 +: 8]);
                  end
                  $write("\n");
                end
                $write("\n");
              end
            end
          end
          conf_state <= READ_PCIE_START;
        end
      end
      READ_PCIE_START: begin
        if (stop || error_termination) begin
          status_read <= 1;
          status_addr <= 30'h2A00_0000;
          conf_state <= READ_PCIE_PKT_Q;
          $display("read_pcie:");
          $display("status + pkt queues:");
        end
      end
      READ_PCIE_PKT_Q: begin
        if (status_readdata_valid) begin
          $display("%d: 0x%8h", status_addr[JTAG_ADDR_WIDTH-1:0],
               status_readdata);
          status_addr = status_addr + 1;
          status_read <= 1;
          if (status_addr == (
              30'h2A00_0000 + REGS_PER_PKT_Q * nb_pkt_queues
              + NB_CONTROL_REGS)
            ) begin
            status_addr <= 30'h2A00_0000
              + REGS_PER_PKT_Q * MAX_NB_FLOWS
              + NB_CONTROL_REGS;
            status_writedata <= 0;
            conf_state <= READ_PCIE_DSC_Q;
            $display("dsc queues:");
          end
        end
      end
      READ_PCIE_DSC_Q: begin
        if (status_readdata_valid) begin
          $display("%d: 0x%8h", status_addr[JTAG_ADDR_WIDTH-1:0],
               status_readdata);
          status_addr = status_addr + 1;
          if (status_addr == (30'h2A00_0000 + REGS_PER_PKT_Q * MAX_NB_FLOWS
                              + REGS_PER_DSC_Q * nb_dsc_queues + NB_CONTROL_REGS)
            ) begin
            read_pcie_cnt <= read_pcie_cnt + 1;
            if (read_pcie_cnt == 1) begin
              $display("TX stats:");
              $display("SOP cnt: %d", tx_sop_cnt);
              $display("EOP cnt: %d", tx_eop_cnt);
              $display("Flits read from memory (pkt): %d", rddm_write_pkt_cnt);
              $display("Flits read from memory (dsc): %d", rddm_write_dsc_cnt);
              $finish;
            end else begin
              status_addr = 30'h2A00_0000;
              status_write <= 1;
              status_writedata <= 0;
              conf_state <= ZERO_PCIE;
            end
          end else begin
            status_read <= 1;
          end
        end
      end
      ZERO_PCIE: begin
        if (status_addr == (30'h2A00_0000
            + REGS_PER_PKT_Q * MAX_NB_FLOWS
            + REGS_PER_DSC_Q * MAX_NB_APPS
            + NB_CONTROL_REGS)
          ) begin
          conf_state <= READ_PCIE_START;
          $display("After zeroing PCIe:");
        end else begin
          status_write <= 1;
          status_writedata <= 0;
          status_addr <= status_addr + 1;
        end
      end
    endcase
  end
end

assign pcie_bas_readdata = 0;
assign pcie_bas_readdatavalid = 0;
assign pcie_bas_response = 0;

assign pdumeta_cnt = 0;

pcie_top pcie (
  .pcie_clk                 (clk),
  .pcie_reset_n             (!rst),
  .pcie_wrdm_desc_ready     (pcie_wrdm_desc_ready),
  .pcie_wrdm_desc_valid     (pcie_wrdm_desc_valid),
  .pcie_wrdm_desc_data      (pcie_wrdm_desc_data),
  .pcie_wrdm_prio_ready     (pcie_wrdm_prio_ready),
  .pcie_wrdm_prio_valid     (pcie_wrdm_prio_valid),
  .pcie_wrdm_prio_data      (pcie_wrdm_prio_data),
  .pcie_wrdm_tx_valid       (pcie_wrdm_tx_valid),
  .pcie_wrdm_tx_data        (pcie_wrdm_tx_data),
  .pcie_rddm_desc_ready     (pcie_rddm_desc_ready),
  .pcie_rddm_desc_valid     (pcie_rddm_desc_valid),
  .pcie_rddm_desc_data      (pcie_rddm_desc_data),
  .pcie_rddm_prio_ready     (pcie_rddm_prio_ready),
  .pcie_rddm_prio_valid     (pcie_rddm_prio_valid),
  .pcie_rddm_prio_data      (pcie_rddm_prio_data),
  .pcie_rddm_tx_valid       (pcie_rddm_tx_valid),
  .pcie_rddm_tx_data        (pcie_rddm_tx_data),
  .pcie_bas_waitrequest     (pcie_bas_waitrequest),
  .pcie_bas_address         (pcie_bas_address),
  .pcie_bas_byteenable      (pcie_bas_byteenable),
  .pcie_bas_read            (pcie_bas_read),
  .pcie_bas_readdata        (pcie_bas_readdata),
  .pcie_bas_readdatavalid   (pcie_bas_readdatavalid),
  .pcie_bas_write           (pcie_bas_write),
  .pcie_bas_writedata       (pcie_bas_writedata),
  .pcie_bas_burstcount      (pcie_bas_burstcount),
  .pcie_bas_response        (pcie_bas_response),
  .pcie_address_0           (pcie_address_0),
  .pcie_write_0             (pcie_write_0),
  .pcie_read_0              (pcie_read_0),
  .pcie_readdatavalid_0     (pcie_readdatavalid_0),
  .pcie_readdata_0          (pcie_readdata_0),
  .pcie_writedata_0         (pcie_writedata_0),
  .pcie_byteenable_0        (pcie_byteenable_0),
  .pcie_rddm_address        (pcie_rddm_address),
  .pcie_rddm_write          (pcie_rddm_write),
  .pcie_rddm_writedata      (pcie_rddm_writedata),
  .pcie_rddm_byteenable     (pcie_rddm_byteenable),
  .pcie_rx_pkt_buf_data     (pcie_rx_pkt_buf_data),
  .pcie_rx_pkt_buf_valid    (pcie_rx_pkt_buf_valid),
  .pcie_rx_pkt_buf_ready    (pcie_rx_pkt_buf_ready),
  .pcie_rx_pkt_buf_occup    (pcie_rx_pkt_buf_occup),
  .pcie_rx_meta_buf_data    (pcie_rx_meta_buf_data),
  .pcie_rx_meta_buf_valid   (pcie_rx_meta_buf_valid),
  .pcie_rx_meta_buf_ready   (pcie_rx_meta_buf_ready),
  .pcie_rx_meta_buf_occup   (pcie_rx_meta_buf_occup),
  .pcie_tx_pkt_sop          (pcie_tx_pkt_sop),
  .pcie_tx_pkt_eop          (pcie_tx_pkt_eop),
  .pcie_tx_pkt_valid        (pcie_tx_pkt_valid),
  .pcie_tx_pkt_data         (pcie_tx_pkt_data),
  .pcie_tx_pkt_empty        (pcie_tx_pkt_empty),
  .pcie_tx_pkt_ready        (pcie_tx_pkt_ready),
  .pcie_tx_pkt_occup        (pcie_tx_pkt_occup),
  .disable_pcie             (disable_pcie),
  .sw_reset                 (sw_reset),
  .pcie_core_full_cnt       (pcie_core_full_cnt),
  .rx_dma_dsc_cnt           (rx_dma_dsc_cnt),
  .rx_dma_dsc_drop_cnt      (rx_dma_dsc_drop_cnt),
  .rx_dma_pkt_flit_cnt      (rx_dma_pkt_flit_cnt),
  .rx_dma_pkt_flit_drop_cnt (rx_dma_pkt_flit_drop_cnt),
  .cpu_dsc_buf_full_cnt     (cpu_dsc_buf_full_cnt),
  .cpu_pkt_buf_full_cnt     (cpu_pkt_buf_full_cnt),
  .clk_status               (clk_status),
  .status_addr              (status_addr),
  .status_read              (status_read),
  .status_write             (status_write),
  .status_writedata         (status_writedata),
  .status_readdata          (status_readdata),
  .status_readdata_valid    (status_readdata_valid)
);

endmodule
