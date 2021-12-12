`include "pcie_consts.sv"

/*
 * This module specializes the generic queue manager to packet queues.
 * 
 * It is also reponsible for determining when to send descriptors for incoming
 * packets. It sends descriptors reactively to head pointer updates from
 * software. The first packet for every queue is accompanied by a descriptor.
 * The following packets for the same queue will only have a descriptor after
 * sofware consumed the first one. This keeps the invariant that we only have
 * a single decriptor for each queue at any given moment.
 */

module pkt_queue_manager #(
    parameter NB_QUEUES
)(
    input logic clk,
    input logic rst,

    // input metadata stream
    input  var pkt_meta_with_queues_t in_meta_data,
    input  logic                      in_meta_valid,
    output logic                      in_meta_ready,

    // output metadata stream
    output var pkt_meta_with_queues_t out_meta_data,
    output logic                      out_meta_valid,
    input  logic                      out_meta_ready,

    // BRAM signals for queues
    bram_interface_io.owner q_table_tails,
    bram_interface_io.owner q_table_heads,
    bram_interface_io.owner q_table_l_addrs,
    bram_interface_io.owner q_table_h_addrs,

    // config signals
    input logic [RB_AWIDTH:0] rb_size,

    // counters
    output logic [31:0] full_cnt
);

pkt_meta_with_queues_t out_meta_extra;
queue_state_t out_q_state;
logic out_drop;

localparam QUEUE_ID_WIDTH = $clog2(NB_QUEUES);

// Consider only the MSBs that we need to index NB_QUEUES, this lets us use the
// LSBs outside the module as an index to the packet queue manager instance.
function logic [QUEUE_ID_WIDTH-1:0] local_queue_id(
    logic [$bits(in_meta_data.pkt_queue_id)-1:0] queue_id
);
    return queue_id[$bits(in_meta_data.pkt_queue_id)-1 -: QUEUE_ID_WIDTH];
endfunction

pkt_meta_with_queues_t out_queue_in_data;
logic                  out_queue_in_valid;
logic                  out_queue_in_ready;
pkt_meta_with_queues_t out_queue_out_data;
logic                  out_queue_out_valid;
logic                  out_queue_out_ready;

bram_interface_io #(
    .ADDR_WIDTH(QUEUE_ID_WIDTH),
    .DATA_WIDTH(1)
) pkt_q_status_interf_a();
bram_interface_io #(
    .ADDR_WIDTH(QUEUE_ID_WIDTH),
    .DATA_WIDTH(1)
) pkt_q_status_interf_b();

logic queue_manager_out_meta_ready;
logic queue_manager_out_meta_valid;

logic [31:0] out_queue_occup;
logic out_queue_almost_full;
assign out_queue_almost_full = out_queue_occup > 4;
assign queue_manager_out_meta_ready = !out_queue_almost_full;

pkt_meta_with_queues_t delayed_metadata [3];
logic                  pkt_q_status_interf_a_rd_en_r [2];

logic [QUEUE_ID_WIDTH-1:0] delayed_queue [3];
logic [QUEUE_ID_WIDTH:0]   last_queues [3];  // Extra bit to represent invalid.
logic                      last_queue_status [3];

function void set_queue_status(
    logic [QUEUE_ID_WIDTH-1:0] queue_id,
    logic status
);
    last_queue_status[0] <= status;
    pkt_q_status_interf_b.wr_data <= status;
    pkt_q_status_interf_b.addr <= queue_id;
    pkt_q_status_interf_b.wr_en <= 1;
endfunction

// Fetch next pkt queue status.
always @(posedge clk) begin
    pkt_q_status_interf_a.rd_en <= 0;
    pkt_q_status_interf_a.wr_en <= 0;
    pkt_q_status_interf_b.rd_en <= 0;
    pkt_q_status_interf_b.wr_en <= 0;

    pkt_q_status_interf_a_rd_en_r[0] <= pkt_q_status_interf_a_rd_en_r[1];
    pkt_q_status_interf_a_rd_en_r[1] <= pkt_q_status_interf_a.rd_en;
    delayed_metadata[0] <= delayed_metadata[1];
    delayed_metadata[1] <= delayed_metadata[2];
    delayed_queue[0] <= delayed_queue[1];
    delayed_queue[1] <= delayed_queue[2];
    last_queues[2] <= last_queues[1];
    last_queues[1] <= last_queues[0];
    last_queues[0] <= -1;

    last_queue_status[2] <= last_queue_status[1];
    last_queue_status[1] <= last_queue_status[0];

    out_queue_in_valid <= 0;

    if (queue_manager_out_meta_ready & queue_manager_out_meta_valid) begin
        automatic logic [QUEUE_ID_WIDTH-1:0] local_q;

        // Fetch next state.
        local_q = local_queue_id(out_meta_extra.pkt_queue_id);
        delayed_metadata[2] <= out_meta_extra;
        delayed_metadata[2].pkt_q_state <= out_q_state;
        delayed_metadata[2].drop <= out_drop;
        delayed_metadata[2].needs_dsc <= out_meta_extra.needs_dsc & !out_drop;

        delayed_queue[2] <= local_q;
        pkt_q_status_interf_a.addr <= local_q;
        pkt_q_status_interf_a.rd_en <= 1;
    end

    if (pkt_q_status_interf_a_rd_en_r[0]) begin
        automatic logic needs_dsc = !pkt_q_status_interf_a.rd_data;
        automatic logic queue_empty = 1'b0;

        out_queue_in_data <= delayed_metadata[0];

        // Packet to the same queue arrived in the last 3 cycles.
        if (last_queues[0] == delayed_queue[0]) begin
            needs_dsc = !last_queue_status[0];
        end else if (last_queues[1] == delayed_queue[0]) begin
            needs_dsc = !last_queue_status[1];
        end else if (last_queues[2] == delayed_queue[0]) begin
            needs_dsc = !last_queue_status[2];
        end

        out_queue_in_data.needs_dsc <= needs_dsc;
        out_queue_in_valid <= 1;

        // Metadata with `descriptor_only` set orginates from a head pointer
        // update while metadata with `needs_dsc` set means that it originates
        // from a head update that was merged to a packet to the same queue.
        if (delayed_metadata[0].needs_dsc) begin
            out_queue_in_data.needs_dsc <= 1;
        end else if (delayed_metadata[0].descriptor_only) begin
            out_queue_in_data.needs_dsc <= 1;

            // HACK(sadok): assume dsc queue id 0.
            out_queue_in_data.dsc_queue_id <= 0;

            if (delayed_metadata[0].pkt_q_state.head ==
                    delayed_metadata[0].pkt_q_state.tail) begin
                queue_empty = 1'b1;

                // No descriptor needed now, do not send descriptor-only meta.
                out_queue_in_data.drop <= 1;
                out_queue_in_data.needs_dsc <= 0;
            end
        end

        // If queue is empty, next packet should have a descriptor.
        set_queue_status(delayed_queue[0], !queue_empty);

        last_queues[0] <= delayed_queue[0];
    end
end

logic [QUEUE_ID_WIDTH-1:0] in_local_queue_id;
assign in_local_queue_id = local_queue_id(in_meta_data.pkt_queue_id);

queue_manager #(
    .NB_QUEUES(NB_QUEUES),
    .EXTRA_META_BITS($bits(in_meta_data)),
    .UNIT_POINTER(0)
)
queue_manager_inst (
    .clk             (clk),
    .rst             (rst),
    .in_pass_through (in_meta_data.descriptor_only),
    .in_queue_id     (in_local_queue_id),
    .in_size         (in_meta_data.size),
    .in_meta_extra   (in_meta_data),
    .in_meta_valid   (in_meta_valid),
    .in_meta_ready   (in_meta_ready),
    .out_q_state     (out_q_state),
    .out_drop        (out_drop),
    .out_meta_extra  (out_meta_extra),
    .out_meta_valid  (queue_manager_out_meta_valid),
    .out_meta_ready  (queue_manager_out_meta_ready),
    .q_table_tails   (q_table_tails),
    .q_table_heads   (q_table_heads),
    .q_table_l_addrs (q_table_l_addrs),
    .q_table_h_addrs (q_table_h_addrs),
    .rb_size         (rb_size),
    .full_cnt        (full_cnt)
);

fifo_wrapper_infill_mlab #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL($bits(pkt_meta_with_queues_t)),
    .FIFO_DEPTH(8)
)
out_queue (
    .clk           (clk),
    .reset         (rst),
    .csr_address   (2'b0),
    .csr_read      (1'b1),
    .csr_write     (1'b0),
    .csr_readdata  (out_queue_occup),
    .csr_writedata (32'b0),
    .in_data       (out_queue_in_data),
    .in_valid      (out_queue_in_valid),
    .in_ready      (out_queue_in_ready),
    .out_data      (out_queue_out_data),
    .out_valid     (out_queue_out_valid),
    .out_ready     (out_queue_out_ready)
);

always_comb begin
    out_meta_data = out_queue_out_data;
    out_meta_valid = out_queue_out_valid;
    out_queue_out_ready = out_meta_ready;
end

logic no_confl_pkt_q_status_interf_a_rd_en;
logic no_confl_pkt_q_status_interf_a_rd_data;
logic pkt_q_status_interf_b_wr_data_r;
logic pkt_q_status_interf_b_wr_data_r2;
logic conflict_rd_wr;
logic conflict_rd_wr_r;
logic conflict_rd_wr_r2;

// handle concurrent read and write to same pkt_q_status_bram address
always_comb begin
    conflict_rd_wr = pkt_q_status_interf_a.rd_en & pkt_q_status_interf_b.wr_en
        & (pkt_q_status_interf_a.addr == pkt_q_status_interf_b.addr);
    if (conflict_rd_wr) begin
        no_confl_pkt_q_status_interf_a_rd_en = 0;
    end else begin
        no_confl_pkt_q_status_interf_a_rd_en = pkt_q_status_interf_a.rd_en;
    end
    if (conflict_rd_wr_r2) begin
        pkt_q_status_interf_a.rd_data = pkt_q_status_interf_b_wr_data_r2;
    end else begin
        pkt_q_status_interf_a.rd_data = no_confl_pkt_q_status_interf_a_rd_data;
    end
end

always @(posedge clk) begin
    // save write so we can return it to a concurrent read 2 cycles later
    pkt_q_status_interf_b_wr_data_r <= pkt_q_status_interf_b.wr_data;
    pkt_q_status_interf_b_wr_data_r2 <= pkt_q_status_interf_b_wr_data_r;
    conflict_rd_wr_r <= conflict_rd_wr;
    conflict_rd_wr_r2 <= conflict_rd_wr_r;
end

// Bit vector holding the status of every pkt queue
// (i.e., if they need a descriptor or not).
bram_true2port #(
    .AWIDTH(QUEUE_ID_WIDTH),
    .DWIDTH(1),
    .DEPTH(NB_QUEUES)
)
pkt_q_status_bram (
    .address_a  (pkt_q_status_interf_a.addr),
    .address_b  (pkt_q_status_interf_b.addr),
    .clock      (clk),
    .data_a     (pkt_q_status_interf_a.wr_data),
    .data_b     (pkt_q_status_interf_b.wr_data),
    .rden_a     (no_confl_pkt_q_status_interf_a_rd_en),
    .rden_b     (pkt_q_status_interf_b.rd_en),
    .wren_a     (pkt_q_status_interf_a.wr_en),
    .wren_b     (pkt_q_status_interf_b.wr_en),
    .q_a        (no_confl_pkt_q_status_interf_a_rd_data),
    .q_b        (pkt_q_status_interf_b.rd_data)
);

endmodule
