`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps
`include "../src/prefetch_rb.sv"
module test_prefetch_rb;

localparam period = 4;

localparam DEPTH = 64;
localparam AWIDTH = ($clog2(DEPTH));
localparam DWIDTH = 32;;

logic [63:0]       cnt;
logic              clk;
logic              rst;
logic [DWIDTH-1:0] wr_data;
logic              wr_en;
logic [DWIDTH-1:0] rd_data;
logic              rd_en;
logic [AWIDTH-1:0] occup;

logic [DWIDTH-1:0] wr_data_cnt;
logic [DWIDTH-1:0] rd_data_cnt;

initial cnt = 0;
initial clk = 0;
initial rst = 1;
initial wr_en = 0;
initial rd_en = 0;

always #(period) clk = ~clk;

function void write();
    // use DEPTH - 2 as it takes an extra clock for occup to reflect the write
    if (occup < (DEPTH - 2)) begin
        wr_data <= wr_data_cnt;
        $display("writing %d", wr_data_cnt);
        wr_en <= 1;
        wr_data_cnt <= wr_data_cnt + 1;
    end
endfunction

function void read();
    if (occup > 0) begin
        $display("Occup: %d", occup);
        rd_en <= 1;
        $display("rd_data_cnt: %d  rd_data: %d", rd_data_cnt, rd_data);
        assert (rd_data_cnt == rd_data);
        rd_data_cnt <= rd_data_cnt + 1;
    end
endfunction

always @(posedge clk) begin
    cnt <= cnt + 1;

    wr_en <= 0;
    rd_en <= 0;

    if (cnt < 10) begin
        rst <= 1;
        wr_data_cnt <= 0;
        rd_data_cnt <= 0;
    end else if (cnt == 10) begin
        rst <= 0;
    end else if (cnt < 20) begin
        write();
        read();
    end else if (cnt < 30) begin
        write();
    end else if (cnt < 50) begin
        write();
        read();
    end else if (cnt < 50 + DEPTH + 10) begin
        // flush
        read();
    end else if (cnt == 50 + DEPTH + 10) begin
        assert(occup == 0);
        $display("wr_data_cnt: %d  rd_data_cnt: %d", wr_data_cnt, rd_data_cnt);
        assert(wr_data_cnt == rd_data_cnt);
    end else if (cnt < 50 + 2 * (DEPTH + 10)) begin
        // write until full
        write();
    end else if (cnt == 50 + 2 * (DEPTH + 10)) begin
        assert(occup == DEPTH-1);
    end else if (cnt < 50 + 3 * (DEPTH + 10)) begin
        // flush
        read();
    end else if (cnt == 50 + 3 * (DEPTH + 10)) begin
        assert(occup == 0);
        $display("wr_data_cnt: %d  rd_data_cnt: %d", wr_data_cnt, rd_data_cnt);
        assert(wr_data_cnt == rd_data_cnt);
    end else if (cnt < 50 + 4 * (DEPTH + 10)) begin
        // write until full
        write();
    end else if (cnt == 50 + 4 * (DEPTH + 10)) begin
        assert(occup == DEPTH-1);
    end else if (cnt < 50 + 5 * (DEPTH + 10)) begin
        // read all values while also writing more
        write();
        read();
    end else if (cnt < 50 + 6 * (DEPTH + 10)) begin
        // flush
        read();
    end else if (cnt == 50 + 6 * (DEPTH + 10)) begin
        assert(occup == 0);
        $display("wr_data_cnt: %d  rd_data_cnt: %d", wr_data_cnt, rd_data_cnt);
        assert(wr_data_cnt == rd_data_cnt);
    end else begin
        $display("done");
        $finish;
    end

    $display("cnt: %d  rd_en: %b  wr_en: %b", cnt, rd_en, wr_en);
    $display("------------------------------------------------");
end

prefetch_rb #(
    .DEPTH(DEPTH),
    .DWIDTH(DWIDTH)
)
prefetch_rb_inst (
    .clk     (clk),
    .rst     (rst),
    .wr_data (wr_data),
    .wr_en   (wr_en),
    .rd_data (rd_data),
    .rd_en   (rd_en),
    .occup   (occup)
);

endmodule
