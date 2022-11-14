`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
`include "../src/constants.sv"
`include "../src/pcie/pcie_consts.sv"

module test_queue_manager;

localparam PERIOD = 4;

localparam NB_QUEUES = 4;  // Must be at least 2.
localparam RB_SIZE = 64;
localparam NB_PKTS = 8;
localparam PKT_SIZE = 4;  // In number of flits.

generate
    if (NB_QUEUES < 2) begin
        $error("NB_QUEUES must be at least 2");
    end
endgenerate

localparam QUEUE_ADDR_WIDTH = $clog2(NB_QUEUES);

logic clk;
logic rst;
logic [63:0] cnt;

initial clk = 0;
initial rst = 1;
initial cnt = 0;

always #(PERIOD) clk = ~clk;

pkt_meta_with_queues_t in_data;
logic                  in_data_valid;
logic                  in_data_ready;
pkt_meta_with_queues_t out_data;
logic                  out_data_valid;
logic                  out_data_ready;

queue_state_t out_q_state;
pkt_meta_with_queues_t out_meta_extra;
logic out_meta_valid;
logic out_drop;
logic out_meta_ready;

bram_interface_io #(.ADDR_WIDTH(QUEUE_ADDR_WIDTH)) q_table_tails();
bram_interface_io #(.ADDR_WIDTH(QUEUE_ADDR_WIDTH)) q_table_heads();
bram_interface_io #(.ADDR_WIDTH(QUEUE_ADDR_WIDTH)) q_table_l_addrs();
bram_interface_io #(.ADDR_WIDTH(QUEUE_ADDR_WIDTH)) q_table_h_addrs();

virtual bram_interface_io.user #(
    .ADDR_WIDTH(QUEUE_ADDR_WIDTH)) q_table_tails_user = q_table_tails.user;
virtual bram_interface_io.user #(
    .ADDR_WIDTH(QUEUE_ADDR_WIDTH)) q_table_heads_user = q_table_heads.user;
virtual bram_interface_io.user #(
    .ADDR_WIDTH(QUEUE_ADDR_WIDTH)) q_table_l_addrs_user = q_table_l_addrs.user;
virtual bram_interface_io.user #(
    .ADDR_WIDTH(QUEUE_ADDR_WIDTH)) q_table_h_addrs_user = q_table_h_addrs.user;

logic [RB_AWIDTH:0] rb_size;
logic [31:0] full_cnt;
logic [31:0] pkt_rx_cnt;
logic [31:0] pkt_tx_cnt;

logic [QUEUE_ADDR_WIDTH-1:0] cur_queue;
logic [$clog2(RB_SIZE)-1:0] expected_tail;

initial rb_size = RB_SIZE;

logic [31:0] queue_occup;
logic queue_almost_full;
assign queue_almost_full = queue_occup > 4;

logic rd_en_r1;
logic rd_en_r2;

always @(posedge clk) begin
    in_data_valid <= 0;
    out_meta_ready <= 0;

    q_table_tails_user.wr_en <= 0;
    q_table_heads_user.wr_en <= 0;
    q_table_l_addrs_user.wr_en <= 0;
    q_table_h_addrs_user.wr_en <= 0;
    q_table_tails_user.rd_en <= 0;
    q_table_heads_user.rd_en <= 0;
    q_table_l_addrs_user.rd_en <= 0;
    q_table_h_addrs_user.rd_en <= 0;
    cur_queue <= 0;

    rd_en_r1 <= q_table_tails_user.rd_en;
    rd_en_r2 <= rd_en_r1;

    if (cnt < 10) begin
        cnt <= cnt + 1;
        pkt_rx_cnt <= 0;
        pkt_tx_cnt <= 0;
    end else if (cnt == 10) begin
        rst <= 0;
        cnt <= cnt + 1;
    end else if (cnt == 11) begin
        // Populate some queues
        q_table_l_addrs_user.addr <= cur_queue;
        q_table_l_addrs_user.wr_data <= cur_queue << 16;
        q_table_l_addrs_user.wr_en <= 1;
        q_table_h_addrs_user.addr <= cur_queue;
        q_table_h_addrs_user.wr_data <= cur_queue;
        q_table_h_addrs_user.wr_en <= 1;

        // Avoid using 0 address.
        q_table_h_addrs_user.wr_data[31] <= 1'b1;

        cur_queue <= cur_queue + 1;

        if (cur_queue + 1 == NB_QUEUES) begin
            cnt <= cnt + 1;
            cur_queue <= 0;
            expected_tail <= 0;
        end
    end else if (cnt == 12) begin
        // Send NB_PKTS packets to the same queue and consume all of them.
        automatic logic [QUEUE_ADDR_WIDTH-1:0] queue_id = 1;

        // Feed packets.
        if (!queue_almost_full && (pkt_tx_cnt < NB_PKTS)) begin
            in_data_valid <= 1;
            in_data.pkt_queue_id <= queue_id;
            in_data.size <= PKT_SIZE;
            in_data.drop_data <= 1'bx;
            in_data.drop_meta <= 1'bx;
            pkt_tx_cnt <= pkt_tx_cnt + 1;
        end

        out_meta_ready <= 1; // Signal that we can consume packets.

        // Consume packets.
        if (out_meta_valid) begin
            automatic logic [63:0] expected_addr =
                ((queue_id << 32) | (queue_id << 16));
            expected_addr[63] = 1'b1;

            pkt_rx_cnt <= pkt_rx_cnt + 1;

            assert(out_drop == 0) else $fatal;
            assert(out_q_state.head == 0) else $fatal;
            assert(out_q_state.tail == expected_tail) else $fatal;
            assert(out_q_state.kmem_addr == expected_addr) else $fatal;

            expected_tail <= expected_tail + PKT_SIZE;

            if (pkt_tx_cnt == NB_PKTS && (pkt_rx_cnt + 1) == NB_PKTS) begin
                cnt <= cnt + 1;
                expected_tail <= 0;
                pkt_rx_cnt <= 0;
                pkt_tx_cnt <= 0;

                // Advance the head.
                q_table_heads_user.addr <= queue_id;
                q_table_heads_user.wr_data <= expected_tail + PKT_SIZE;
                q_table_heads_user.wr_en <= 1;
            end
        end
     end else if (cnt == 13) begin
        // Fill a different queue with packets to make sure that it can drop
        // packets once the RB becomes full.
        automatic logic [QUEUE_ADDR_WIDTH-1:0] queue_id = 0;

        // Feed packets.
        if (!queue_almost_full && (pkt_tx_cnt < RB_SIZE/PKT_SIZE)) begin
            in_data_valid <= 1;
            in_data.pkt_queue_id <= queue_id;
            in_data.size <= PKT_SIZE;
            in_data.drop_data <= 1'bx;
            in_data.drop_meta <= 1'bx;
            pkt_tx_cnt <= pkt_tx_cnt + 1;
        end

        out_meta_ready <= 1;  // Signal that we can consume packets.

        // Consume packets.
        if (out_meta_valid) begin
            automatic logic [63:0] expected_addr =
                ((queue_id << 32) | (queue_id << 16));
            expected_addr[63] = 1'b1;

            pkt_rx_cnt <= pkt_rx_cnt + 1;
            assert(out_q_state.head == 0) else $fatal;

            if ((pkt_rx_cnt + 1) == RB_SIZE/PKT_SIZE) begin
                // This packet should be dropped.
                cnt <= cnt + 1;
                assert(out_drop == 1) else $fatal;

                // Advance the head.
                q_table_heads_user.addr <= queue_id;
                q_table_heads_user.wr_data <= expected_tail;
                q_table_heads_user.wr_en <= 1;
            end else begin
                assert(out_drop == 0) else $fatal;
                assert(out_q_state.tail == expected_tail) else $fatal;
                assert(out_q_state.kmem_addr == expected_addr) else $fatal;
                expected_tail <= expected_tail + PKT_SIZE;
            end
        end
    end else if (cnt < 30) begin
        cnt <= cnt + 1; // Make sure there is enough time for the new head value
                        // to propagate.
    end else if (cnt == 30) begin
        // Check tail and head for queue 0.
        q_table_heads_user.addr <= 0;
        q_table_heads_user.rd_en <= 1;
        q_table_tails_user.addr <= 0;
        q_table_tails_user.rd_en <= 1;
        if (rd_en_r2) begin
            cnt <= cnt + 1;
            pkt_tx_cnt <= 0;
            pkt_rx_cnt <= 0;
            assert(q_table_heads_user.rd_data == expected_tail) else $fatal;
            assert(q_table_tails_user.rd_data == expected_tail) else $fatal;
        end
    end else if (cnt == 31) begin
        // Send interleaved packets to different queues, increasing gap.
        const int nb_pkts = 17;
        automatic int queue_seq[] = new[nb_pkts];
        queue_seq = '{0, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 0};

        // Feed packets.
        if (!queue_almost_full && (pkt_tx_cnt < nb_pkts)) begin
            automatic logic [QUEUE_ADDR_WIDTH-1:0] queue_id =
                queue_seq[pkt_tx_cnt];
            in_data_valid <= 1;
            in_data.pkt_queue_id <= queue_id;
            in_data.size <= PKT_SIZE;
            in_data.drop_data <= 1'bx;
            in_data.drop_meta <= 1'bx;
            pkt_tx_cnt <= pkt_tx_cnt + 1;
        end

        out_meta_ready <= 1; // Signal that we can consume packets.

        // Consume packets.
        if (out_meta_valid) begin
            automatic logic [QUEUE_ADDR_WIDTH-1:0] queue_id =
                queue_seq[pkt_rx_cnt];
            automatic logic [63:0] expected_addr =
                ((queue_id << 32) | (queue_id << 16));
            expected_addr[63] = 1'b1;

            pkt_rx_cnt <= pkt_rx_cnt + 1;

            assert(out_drop == 0) else $fatal;
            assert(out_q_state.kmem_addr == expected_addr) else $fatal;

            if (queue_id == 0) begin
                assert(out_q_state.tail == expected_tail) else $fatal;
                expected_tail <= expected_tail + PKT_SIZE;
            end

            if (pkt_tx_cnt == nb_pkts && (pkt_rx_cnt + 1) == nb_pkts) begin
                cnt <= cnt + 1;
                pkt_rx_cnt <= 0;
                pkt_tx_cnt <= 0;
            end
        end
    end else if (cnt == 32) begin
        $finish;
    end
end

fifo_wrapper_infill_mlab #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL($bits(pkt_meta_with_queues_t)),
    .FIFO_DEPTH(8)
)
queue (
    .clk           (clk),
    .reset         (rst),
    .csr_address   (2'b0),
    .csr_read      (1'b1),
    .csr_write     (1'b0),
    .csr_readdata  (queue_occup),
    .csr_writedata (32'b0),
    .in_data       (in_data),
    .in_valid      (in_data_valid),
    .in_ready      (in_data_ready),
    .out_data      (out_data),
    .out_valid     (out_data_valid),
    .out_ready     (out_data_ready)
);

queue_manager #(
    .NB_QUEUES(NB_QUEUES),
    .EXTRA_META_BITS($bits(in_data)),
    .UNIT_POINTER(0)
)
queue_manager_inst (
    .clk             (clk),
    .rst             (rst),
    .in_pass_through (1'b0),
    .in_queue_id     (out_data.pkt_queue_id[QUEUE_ADDR_WIDTH-1:0]),
    .in_size         (out_data.size),
    .in_meta_extra   (out_data),
    .in_meta_valid   (out_data_valid),
    .in_meta_ready   (out_data_ready),
    .out_q_state     (out_q_state),
    .out_meta_extra  (out_meta_extra),
    .out_meta_valid  (out_meta_valid),
    .out_drop        (out_drop),
    .out_meta_ready  (out_meta_ready),
    .q_table_tails   (q_table_tails),
    .q_table_heads   (q_table_heads),
    .q_table_l_addrs (q_table_l_addrs),
    .q_table_h_addrs (q_table_h_addrs),
    .rb_size         (rb_size),
    .full_cnt        (full_cnt)
);

endmodule
