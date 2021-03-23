`include "./my_struct_s.sv"

/*
 * Ring buffer stored in BRAM that automatically prefetches the next entry.
 * Can write and read in all cycles. But writes take a cycle to update occup.
 * Therefore it is not safe to write if occup >= DEPTH-2.
 * Can use the value in rd_data in the same cycle, as long as occup > 0.
 * Setting rd_en to 1 consumes the value and makes a new value available in the
 * following cycle.
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
logic [DWIDTH-1:0] bram_rd_data; // has next data, use rd_en to consume
logic              bram_rd_en;

logic [AWIDTH-1:0] head; // advance when writing
logic [AWIDTH-1:0] tail; // advance when reading

// prefetch registers
// pending_rd_data[0] ->  ... -> pending_rd_data[NB_PREFETCH_REGS-1] = rd_data
logic [DWIDTH-1:0] pending_rd_data [NB_PREFETCH_REGS];

logic valid_wr_en;
logic valid_rd_en;

logic bram_rd_en_r1;
logic bram_rd_en_r2;

logic [AWIDTH-1:0] bram_rd_addr_r1;
logic [AWIDTH-1:0] bram_rd_addr_r2;

logic [AWIDTH-1:0] real_occup;

logic rst_r;

assign real_occup = head - tail;
assign valid_rd_en = rd_en && real_occup > 0;
assign valid_wr_en = wr_en && real_occup < MAX_OCCUP;
assign occup = real_occup - valid_rd_en; // consume right away

assign rd_data = pending_rd_data[NB_PREFETCH_REGS - valid_rd_en - 1];

// simulation-time assertions
always @(posedge clk) begin
    if (rd_en) begin
        assert(real_occup > 0) else $fatal;
    end
    if (wr_en) begin
        assert(real_occup < MAX_OCCUP) else $fatal;
    end
end

always @(posedge clk) begin
    bram_wr_en <= 0;
    bram_rd_en <= 0;

    rst_r <= rst;
    if (rst_r) begin
        head <= 0;
        tail <= 0;
    end else begin
        automatic logic [AWIDTH-1:0] next_occup = occup + valid_wr_en;

        if (valid_rd_en) begin
            integer i;
            for (i = 0; i < NB_PREFETCH_REGS - 1; i = i + 1) begin
                pending_rd_data[i+1] <= pending_rd_data[i];
            end

            if (real_occup > NB_PREFETCH_REGS) begin
                bram_rd_addr <= {tail + NB_PREFETCH_REGS}[AWIDTH-1:0];
                bram_rd_en <= 1;
            end
            tail = tail + 1'b1;
        end

        bram_rd_en_r1 <= bram_rd_en;
        bram_rd_en_r2 <= bram_rd_en_r1;
        bram_rd_addr_r1 <= bram_rd_addr;
        bram_rd_addr_r2 <= bram_rd_addr_r1;

        // Store result of a prefetch
        if (bram_rd_en_r2) begin
            automatic logic [AWIDTH-1:0] pref_dest = {tail - bram_rd_addr_r2 +
                (NB_PREFETCH_REGS - 1)}[AWIDTH-1:0];
            pending_rd_data[pref_dest] <= bram_rd_data;
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
            head <= head + 1'b1;
        end
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
