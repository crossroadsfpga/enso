`include "./constants.sv"

module hash_func(clk,rst,
    stall,
    tuple_in,
    initval,
    tuple_in_valid,
    hashed,
    hashed_valid
);
input clk;
input rst;
input stall;
input [31:0] initval;
input tuple_t tuple_in;
input tuple_in_valid;
output logic hashed_valid;
output logic [31:0] hashed;

//deadbeef + length + initval
logic [31:0] a;
logic [31:0] b;
logic [31:0] c;
logic [31:0] a1;
logic [31:0] b1;
logic [31:0] c1;
logic [31:0] a2;
logic [31:0] b2;
logic [31:0] c2;
logic [31:0] a3;
logic [31:0] b3;
logic [31:0] c3;
logic [31:0] a4;
logic [31:0] b4;
logic [31:0] c4;
logic [31:0] a5;
logic [31:0] b5;
logic [31:0] c5;
logic [31:0] a6;
logic [31:0] b6;
logic [31:0] c6;

logic valid;
logic valid1;
logic valid2;
logic valid3;
logic valid4;
logic valid5;
logic valid6;

logic [3:0] round;
logic [95:0] key;
assign key = {tuple_in.sIP,tuple_in.sPort,tuple_in.dIP,tuple_in.dPort};

//pipelined design
always@(posedge clk)begin
    if(!stall)begin
        valid <= tuple_in_valid;
        valid1 <= valid;
        valid2 <= valid1;
        valid3 <= valid2;
        valid4 <= valid3;
        valid5 <= valid4;
        valid6 <= valid5;
        hashed_valid <= valid6;

        a <= 32'hdeadbefb + key[31:0] + initval;
        b <= 32'hdeadbefb + key[63:32] + initval;
        c <= 32'hdeadbefb + key[95:64] + initval;

        a1 <= a;
        b1 <= b;
        c1 <= (c ^ b) - {b[17:0],b[31:18]};

        a2 <= (a1 ^ c1) - {c1[20:0],c1[31:21]};
        b2 <= b1;
        c2 <= c1;

        a3 <= a2;
        b3 <= (b2 ^ a2) - {a2[6:0],a2[31:7]};
        c3 <= c2;

        a4 <= a3;
        b4 <= b3;
        c4 <= (c3 ^ b3) - {b3[15:0],b3[31:16]};

        a5 <= (a4 ^ c4) - {c4[27:0],c4[31:28]};
        b5 <= b4;
        c5 <= c4;

        a6 <= a5;
        b6 <= (b5 ^ a5) - {a5[17:0],a5[31:18]};
        c6 <= c5;

        hashed <= (c6 ^ b6) - {b6[7:0],b6[31:8]};
    end
end

//State machine design
/*
always@(posedge clk)begin
    if(rst)begin
        hashed_valid <= 1'b0;
        round <= 4'd0;
    end else begin
        case (round)
            4'd0: begin
                hashed_valid <= 1'b0;
                a <= 32'hdeadbefb;
                b <= 32'hdeadbefb;
                c <= 32'hdeadbefb;
                if(start)begin
                    round <= round + 1'b1;
                    c <= c + key[95:64];
                    b <= b + key[63:32];
                    a <= a + key[31:0];
                end
            end
            4'd1: begin
                //b left rot 14
                c <= (c ^ b) - {b[17:0],b[31:18]};
                round <= round + 1'b1;
            end
            4'd2: begin
                //c left rot 11
                a <= (a ^ c) - {c[20:0],c[31:21]};
                round <= round + 1'b1;
            end
            4'd3: begin
                //a left rot 25
                b <= (b ^ a) - {a[6:0],a[31:7]};
                round <= round + 1'b1;
            end
            4'd4: begin
                //b left rot 16
                c <= (c ^ b) - {b[15:0],b[31:16]};
                round <= round + 1'b1;
            end
            4'd5: begin
                //c left rot 4
                a <= (a ^ c) - {c[27:0],c[31:28]};
                round <= round + 1'b1;
            end
            4'd6: begin
                //a left rot 14
                b <= (b ^ a) - {a[17:0],a[31:18]};
                round <= round + 1'b1;
            end
            4'd7: begin
                //b left rot 24
                hashed <= (c ^ b) - {b[7:0],b[31:8]};
                round <= 0;
                hashed_valid <= 1'b1;
            end
        endcase
    end
end
*/

endmodule
