module  rom_2port_sim  (
    address_a,
    address_b,
    clock,
    q_a,
    q_b);

	parameter DWIDTH = 16;
	parameter AWIDTH = 15;
	parameter MEM_SIZE = 32768;
	parameter INIT_FILE = "./hashtable0.mif";

    input  [AWIDTH-1:0]  address_a;
    input  [AWIDTH-1:0]  address_b;
    input    clock;
    output reg [DWIDTH-1:0]  q_a;
    output reg [DWIDTH-1:0]  q_b;


    reg [DWIDTH-1:0] mem [0:MEM_SIZE-1];
    reg [DWIDTH-1:0]  q_1;
    reg [DWIDTH-1:0]  q_2;
    integer i;
    initial begin
        $readmemh(INIT_FILE, mem);
    end
    always @ (posedge clock) begin
        q_1 <= mem[address_a];
        q_2 <= mem[address_b];
        q_a <= q_1;
        q_b <= q_2;
    end

endmodule
