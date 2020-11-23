`include "./my_struct_s.sv"

/*
 * Ring buffer stored in BRAM that automatically prefetches the next entry.
 * Reads return in the next cycle.
 */

module prefetch_rb #(
    parameter DEPTH, // we assume this is a power of two
    parameter AWIDTH = ($clog2(DEPTH)),
    parameter DWIDTH)
(
    input clk,
    input rst,

    input  logic [DWIDTH-1:0] wr_data,
    input  logic              wr_en,

    output logic [DWIDTH-1:0] rd_data,
    input  logic              rd_en,

    // Occupancy status, check before writing or reading. Must always leave at
    // least one empty spot. Writes beyond that are ignored
    output logic [AWIDTH-1:0] occup
);

generate
    if ((1 << AWIDTH) != DEPTH) begin
        $error("DEPTH must be a power of two");
    end
endgenerate

localparam MAX_OCCUP = DEPTH - 1;
localparam NB_PREFETCH_REGS = 5;

logic [AWIDTH-1:0] bram_wr_addr;
logic [DWIDTH-1:0] bram_wr_data;
logic              bram_wr_en;

logic [AWIDTH-1:0] bram_rd_addr;
logic [DWIDTH-1:0] bram_rd_data; // has always next data, use rd_en to consume
logic              bram_rd_en;

logic [AWIDTH-1:0] head; // advance when writing
logic [AWIDTH-1:0] tail; // advance when reading

// prefetch registers
// pending_rd_data[0] ->  ... -> pending_rd_data[NB_PREFETCH_REGS-1] = rd_data
logic [DWIDTH-1:0] pending_rd_data [NB_PREFETCH_REGS];

logic [$clog2(NB_PREFETCH_REGS)-1:0] pending_reads;

logic valid_wr_en;
logic valid_rd_en;

logic bram_rd_en_r;
logic bram_rd_valid;

logic [AWIDTH-1:0] real_occup;

logic rst_r;

assign real_occup = head - tail;
assign valid_rd_en = rd_en && real_occup > 0;
assign valid_wr_en = wr_en && real_occup < MAX_OCCUP;
assign occup = real_occup - valid_rd_en; // consume right away

assign rd_data = pending_rd_data[NB_PREFETCH_REGS - valid_rd_en - 1];

always @(posedge clk) begin
    bram_wr_en <= 0;
    bram_rd_en <= 0;

    rst_r <= rst;
    if (rst_r) begin
        head <= 0;
        tail <= 0;
        pending_reads <= 0;
    end else begin
        automatic logic [$clog2(NB_PREFETCH_REGS)-1:0] next_pending_reads = 
            pending_reads;
        automatic logic [AWIDTH-1:0] next_occup = real_occup + valid_wr_en -
                                                  valid_rd_en;

        if (valid_rd_en) begin
            integer i;
            for (i = 0; i < NB_PREFETCH_REGS - 1; i = i + 1) begin
                pending_rd_data[i+1] <= pending_rd_data[i];
            end

            if (next_occup >= NB_PREFETCH_REGS) begin
                bram_rd_addr <= tail + NB_PREFETCH_REGS;
                bram_rd_en <= 1;
                next_pending_reads = next_pending_reads + 1;
            end
            tail <= tail + 1;
        end

        bram_rd_en_r <= bram_rd_en;
        bram_rd_valid <= bram_rd_en_r;

        // We store the value read from BRAM is a different register depending
        // on the number of pending reads
        if (bram_rd_valid) begin
            assert (pending_reads > 0);
            next_pending_reads = next_pending_reads - 1;
            if (next_occup <= NB_PREFETCH_REGS) begin
                pending_rd_data[
                    next_pending_reads + NB_PREFETCH_REGS - next_occup
                ] <= bram_rd_data;
            end else begin
                pending_rd_data[next_pending_reads] <= bram_rd_data;
            end
        end

        if (valid_wr_en) begin
            // when we have up to NB_PREFETCH_REGS entries, we bypass the BRAM
            if (next_occup <= NB_PREFETCH_REGS) begin
                pending_rd_data[NB_PREFETCH_REGS - next_occup] <= wr_data;
            end else begin
                bram_wr_data <= wr_data;
                bram_wr_addr <= head;
                bram_wr_en <= 1;
            end
            head <= head + 1;
        end

        pending_reads <= next_pending_reads;
    end
end

bram_simple2port #(
    .AWIDTH(AWIDTH),
    .DWIDTH(DWIDTH),
    .DEPTH(DEPTH)
)
pkt_descs (
    .clock      (clk),
    .data       (bram_wr_data),
    .rdaddress  (bram_rd_addr),
    .rden       (bram_rd_en),
    .wraddress  (bram_wr_addr),
    .wren       (bram_wr_en),
    .q          (bram_rd_data)
);

endmodule
