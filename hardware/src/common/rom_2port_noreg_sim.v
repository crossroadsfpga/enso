module  rom_2port_noreg_sim  (
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
    integer i;
    initial begin
        $readmemh(INIT_FILE, mem);
    end
    always @ (posedge clock) begin
        q_a <= mem[address_a];
        q_b <= mem[address_b];
    end

endmodule
