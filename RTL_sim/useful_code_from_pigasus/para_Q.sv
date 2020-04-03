`include "./my_struct_s.sv"
module para_Q(
    input logic clk,
    input logic rst,

    //enq logic
    input logic enq,
    input fce_t enq_fce,
    output logic full,

    //deq
    input logic deq,
    output fce_t deq_fce,
    output logic empty,

    //lookup, one cycle delay
    input logic lookup,
    input tuple_t lookup_tuple,

    output logic hit,
    output logic hit_valid,
    output logic [PQ_DEPTH-1:0] hit_bitmap,
    output fce_t hit_fce,

    //update 
    input logic update,
    input logic [PQ_DEPTH-1:0] update_bitmap,
    input fce_t update_fce,

    //delete 
    input logic delete,
    input logic [PQ_DEPTH-1:0] delete_bitmap
);


fce_t entry [0:PQ_DEPTH-1];
fce_t empty_entry;
logic [PQ_DEPTH-1:0] hit_bm;
logic [PQ_DEPTH-1:0] valid_vec;
logic [PQ_DEPTH-1:0] shift_vec;
logic [PQ_DEPTH-1:0] delete_vec;
logic [PQ_AWIDTH:0] cnt;


int i;

always@(*)begin
    for(i = 0; i<PQ_DEPTH;i++)begin
        valid_vec[i] = entry[i].valid;
        hit_bm[i] = (entry[i].tuple == lookup_tuple) & entry[i].valid;
    end
end

assign empty_entry = 0;

assign full = (valid_vec == {PQ_DEPTH{1'b1}});
assign empty = (valid_vec == 0);


//The head shift or delete will trigger the shift in tail
//Note this is a carry logic
assign shift_vec[0] = deq | delete_vec[0];
assign shift_vec[1] = shift_vec[0] | delete_vec[1];
assign shift_vec[2] = shift_vec[1] | delete_vec[2];
assign shift_vec[3] = shift_vec[2] | delete_vec[3];
assign shift_vec[4] = shift_vec[3] | delete_vec[4];
assign shift_vec[5] = shift_vec[4] | delete_vec[5];
assign shift_vec[6] = shift_vec[5] | delete_vec[6];
assign shift_vec[7] = shift_vec[6] | delete_vec[7];

assign delete_vec = delete ? delete_bitmap : 0;


//Dequeue from head(0), entry to the last empty entry
assign deq_fce = entry[0];

//cnt valid entries
always@(*)begin
    cnt = 0;
    case(valid_vec)
        8'b00000000:begin
            cnt = 0;
        end
        8'b00000001:begin
            cnt = 1;
        end
        8'b00000011:begin
            cnt = 2;
        end
        8'b00000111:begin
            cnt = 3;
        end
        8'b00001111:begin
            cnt = 4;
        end
        8'b00011111:begin
            cnt = 5;
        end
        8'b00111111:begin
            cnt = 6;
        end
        8'b01111111:begin
            cnt = 7;
        end
        8'b11111111:begin
            cnt = 8;
        end
    endcase
end

//assign lock = lookup | (state == UPDATE);
//update and lookup never happens in one cycle.
//lookup,update,delete,deq,enq never happens in one cycle for now.
always@(posedge clk)begin
    if(rst)begin
        hit_valid <= 1'b0;
        for(i=0;i<PQ_DEPTH;i++)begin
            entry[i] <= 0;
        end
    end else begin
        //Shift logic to support both deq and delete in the middle
        //If shift_i , ith element will be overwritten by i+1 element.
        for(i=0;i<PQ_DEPTH-1;i++)begin
            if(shift_vec[i])begin
                entry[i] <= entry[i+1];
            end
        end

        if(shift_vec[PQ_DEPTH-1])begin
            entry[PQ_DEPTH-1] <= 0;
        end

        hit_valid <= 1'b0;


        if (lookup)begin
            hit_valid <= 1'b1;
            hit <= (hit_bm != 0);
            hit_bitmap <= hit_bm;
            case(hit_bm)
                8'b00000001: begin
                    hit_fce <= entry[0]; 
                end
                8'b00000010: begin 
                    hit_fce <= entry[1]; 
                end
                8'b00000100: begin 
                    hit_fce <= entry[2]; 
                end
                8'b00001000: begin 
                    hit_fce <= entry[3]; 
                end
                8'b00010000: begin 
                    hit_fce <= entry[4]; 
                end
                8'b00100000: begin 
                    hit_fce <= entry[5]; 
                end
                8'b01000000: begin 
                    hit_fce <= entry[6]; 
                end
                8'b10000000: begin 
                    hit_fce <= entry[7]; 
                end
            endcase
        end

        if(update)begin
            case(update_bitmap)
                8'b00000001: entry[0] <= update_fce;
                8'b00000010: entry[1] <= update_fce;
                8'b00000100: entry[2] <= update_fce;
                8'b00001000: entry[3] <= update_fce;
                8'b00010000: entry[4] <= update_fce;
                8'b00100000: entry[5] <= update_fce;
                8'b01000000: entry[6] <= update_fce;
                8'b10000000: entry[7] <= update_fce;
            endcase
        end 
        
        //make sure at the out 
        if(enq)begin
            if(full)begin
                $display("Insert to full Queue!");
            end else begin
                //not shift would happen when cnt is 0.
                if(shift_vec[cnt])begin
                    entry[cnt-1] <= enq_fce;
                end else begin
                    entry[cnt] <= enq_fce;
                end
            end
        end
    end
end

endmodule
