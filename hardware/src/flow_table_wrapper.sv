`include "./constants.sv"
module flow_table_wrapper(
    input logic clk,
    input logic rst,

    // Packet data.
    input  var   metadata_t in_meta_data,
    input  logic            in_meta_valid,
    output logic            in_meta_ready,
    output var   metadata_t out_meta_data,
    output logic            out_meta_valid,
    input  logic            out_meta_ready,

    // Control data.
    input  var   flow_table_config_t in_control_data,
    input  logic                     in_control_valid,
    output logic                     in_control_ready,
    output logic                     out_control_done,

    // Counter.
    output logic [31:0] eviction_cnt
);

// Service FSM hashing.
tuple_t         s_h0_tuple_in;
logic           s_h0_tuple_in_valid;
logic [31:0]    s_h0_initval;
logic [31:0]    s_h0_hashed;
logic           s_h0_hashed_valid;

tuple_t         s_h1_tuple_in;
logic           s_h1_tuple_in_valid;
logic [31:0]    s_h1_initval;
logic [31:0]    s_h1_hashed;
logic           s_h1_hashed_valid;

tuple_t         s_h2_tuple_in;
logic           s_h2_tuple_in_valid;
logic [31:0]    s_h2_initval;
logic [31:0]    s_h2_hashed;
logic           s_h2_hashed_valid;

tuple_t         s_h3_tuple_in;
logic           s_h3_tuple_in_valid;
logic [31:0]    s_h3_initval;
logic [31:0]    s_h3_hashed;
logic           s_h3_hashed_valid;

// Placement FSM hashing.
tuple_t         p_h0_tuple_in;
logic           p_h0_tuple_in_valid;
logic [31:0]    p_h0_initval;
logic [31:0]    p_h0_hashed;
logic           p_h0_hashed_valid;

tuple_t         p_h1_tuple_in;
logic           p_h1_tuple_in_valid;
logic [31:0]    p_h1_initval;
logic [31:0]    p_h1_hashed;
logic           p_h1_hashed_valid;

tuple_t         p_h2_tuple_in;
logic           p_h2_tuple_in_valid;
logic [31:0]    p_h2_initval;
logic [31:0]    p_h2_hashed;
logic           p_h2_hashed_valid;

tuple_t         p_h3_tuple_in;
logic           p_h3_tuple_in_valid;
logic [31:0]    p_h3_initval;
logic [31:0]    p_h3_hashed;
logic           p_h3_hashed_valid;

// Subtables.
logic [FT_AWIDTH-1:0]   ft0_addr_a;
logic [FT_AWIDTH-1:0]   ft0_addr_b;
fce_t                   ft0_data_a;
fce_t                   ft0_data_b;
logic                   ft0_rden_a;
logic                   ft0_rden_b;
logic                   ft0_wren_a;
logic                   ft0_wren_b;
fce_t                   ft0_q_a;
fce_t                   ft0_q_b;

logic [FT_AWIDTH-1:0]   ft1_addr_a;
logic [FT_AWIDTH-1:0]   ft1_addr_b;
fce_t                   ft1_data_a;
fce_t                   ft1_data_b;
logic                   ft1_rden_a;
logic                   ft1_rden_b;
logic                   ft1_wren_a;
logic                   ft1_wren_b;
fce_t                   ft1_q_a;
fce_t                   ft1_q_b;

logic [FT_AWIDTH-1:0]   ft2_addr_a;
logic [FT_AWIDTH-1:0]   ft2_addr_b;
fce_t                   ft2_data_a;
fce_t                   ft2_data_b;
logic                   ft2_rden_a;
logic                   ft2_rden_b;
logic                   ft2_wren_a;
logic                   ft2_wren_b;
fce_t                   ft2_q_a;
fce_t                   ft2_q_b;

logic [FT_AWIDTH-1:0]   ft3_addr_a;
logic [FT_AWIDTH-1:0]   ft3_addr_b;
fce_t                   ft3_data_a;
fce_t                   ft3_data_b;
logic                   ft3_rden_a;
logic                   ft3_rden_b;
logic                   ft3_wren_a;
logic                   ft3_wren_b;
fce_t                   ft3_q_a;
fce_t                   ft3_q_b;

// Pipeline stages for S hashing.
metadata_t s_m0;
metadata_t s_m1;
metadata_t s_m2;
metadata_t s_m3;
metadata_t s_m4;
metadata_t s_m5;
metadata_t s_m6;
metadata_t s_m7;
metadata_t s_meta_r;
metadata_t s_meta_r1;
metadata_t s_meta_r2;
tuple_t s_lookup_tuple;
tuple_t s_lookup_tuple_r1;
tuple_t s_lookup_tuple_r2;

// Pipeline stages for P hashing.
flow_table_config_t p_c0;
flow_table_config_t p_c1;
flow_table_config_t p_c2;
flow_table_config_t p_c3;
flow_table_config_t p_c4;
flow_table_config_t p_c5;
flow_table_config_t p_c6;
flow_table_config_t p_c7;
fce_t p_insert_fce_r;
tuple_t p_lookup_tuple;

logic rd_valid_a;
logic rd_valid_b;
logic rd_valid_a_r;
logic rd_valid_b_r;

typedef enum {
    S_IDLE,
    S_LOOKUP
} service_t;
service_t s_state;

typedef enum {
    P_IDLE,
    P_LOOKUP,
    P_UPDATE,
    P_INSERT_EVIC,
    P_INSERT_NO_EVIC
} place_t;
place_t p_state;

logic [FT_SUBTABLE-1:0] s_ft_hit;
logic [FT_SUBTABLE-1:0] p_ft_hit;
logic [FT_SUBTABLE-1:0] p_ft_hit_r;
logic [FT_SUBTABLE-1:0] p_ft_empty;
logic [FT_SUBTABLE-1:0] p_ft_empty_r;

logic s_busy;
logic p_busy;
assign in_meta_ready = !s_busy;
// Using out_meta_ready as "stall" signal for this pipeline. 
assign s_busy = !out_meta_ready;

assign in_control_ready = !p_busy;

// Two cycle read delay.
always@(posedge clk) begin
    rd_valid_b_r <= ft0_rden_b;
    rd_valid_b <= rd_valid_b_r;
end

assign s_ft_hit[0] = (s_lookup_tuple_r2 == ft0_q_a.tuple) & ft0_q_a.valid;
assign s_ft_hit[1] = (s_lookup_tuple_r2 == ft1_q_a.tuple) & ft1_q_a.valid;
assign s_ft_hit[2] = (s_lookup_tuple_r2 == ft2_q_a.tuple) & ft2_q_a.valid;
assign s_ft_hit[3] = (s_lookup_tuple_r2 == ft3_q_a.tuple) & ft3_q_a.valid;

assign p_ft_hit[0] = (p_lookup_tuple == ft0_q_b.tuple) & ft0_q_b.valid;
assign p_ft_hit[1] = (p_lookup_tuple == ft1_q_b.tuple) & ft1_q_b.valid;
assign p_ft_hit[2] = (p_lookup_tuple == ft2_q_b.tuple) & ft2_q_b.valid;
assign p_ft_hit[3] = (p_lookup_tuple == ft3_q_b.tuple) & ft3_q_b.valid;

assign p_ft_empty[0] = !ft0_q_b.valid;
assign p_ft_empty[1] = !ft1_q_b.valid;
assign p_ft_empty[2] = !ft2_q_b.valid;
assign p_ft_empty[3] = !ft3_q_b.valid;

// Lookup from Port A of the BRAM. Fully pipelined.  
// Entry is updated by CPU through port B of the BRAM. 
always@(posedge clk) begin
    if (rst) begin
        ft0_rden_a <= 1'b0;
        ft0_wren_a <= 1'b0;
        ft1_rden_a <= 1'b0;
        ft1_wren_a <= 1'b0;
        ft2_rden_a <= 1'b0;
        ft2_wren_a <= 1'b0;
        ft3_rden_a <= 1'b0;
        ft3_wren_a <= 1'b0;
        out_meta_valid <= 1'b0;
        s_meta_r <= 0;
        s_meta_r1 <= 0;
        s_meta_r2 <= 0;
        s_lookup_tuple <= 0;
        s_lookup_tuple_r1 <= 0;
        s_lookup_tuple_r2 <= 0;
    end else begin
        // Stall the pipeline if the downstream is not ready.
        if (!s_busy) begin
            // Default values.
            ft0_rden_a <= 1'b0;
            ft1_rden_a <= 1'b0;
            ft2_rden_a <= 1'b0;
            ft3_rden_a <= 1'b0;
            out_meta_valid <= 1'b0;

            // Read whenever hashed value is valid.
            // Stage 0.
            if (s_h0_hashed_valid) begin
                ft0_rden_a <= 1'b1;
                ft0_addr_a <= s_h0_hashed[FT_AWIDTH-1:0];
                ft1_rden_a <= 1'b1;
                ft1_addr_a <= s_h1_hashed[FT_AWIDTH-1:0];
                ft2_rden_a <= 1'b1;
                ft2_addr_a <= s_h2_hashed[FT_AWIDTH-1:0];
                ft3_rden_a <= 1'b1;
                ft3_addr_a <= s_h3_hashed[FT_AWIDTH-1:0];

                s_meta_r <= s_m7;
                s_lookup_tuple <= s_m7.tuple;
            end

            // Stage 1.
            rd_valid_a_r <= ft0_rden_a;
            s_meta_r1 <= s_meta_r;
            s_lookup_tuple_r1 <= s_lookup_tuple;
            
            // Stage 2.
            rd_valid_a <= rd_valid_a_r;
            s_meta_r2 <= s_meta_r1;
            s_lookup_tuple_r2 <= s_lookup_tuple_r1;

            // Stage 3.
            // Assign output whenever the rd data is valid (should be two cycles
            // later). 
            if (rd_valid_a) begin
                out_meta_valid <= 1'b1;
                out_meta_data <= s_meta_r2;

                if (s_ft_hit != 0) begin
                    if (s_ft_hit[0]) begin
                        out_meta_data.pkt_queue_id <= ft0_q_a.pkt_queue_id;
                    end
                    else if (s_ft_hit[1]) begin
                        out_meta_data.pkt_queue_id <= ft1_q_a.pkt_queue_id;
                    end
                    else if (s_ft_hit[2]) begin
                        out_meta_data.pkt_queue_id <= ft2_q_a.pkt_queue_id;
                    end
                    else if (s_ft_hit[3]) begin
                        out_meta_data.pkt_queue_id <= ft3_q_a.pkt_queue_id;
                    end
                end
                else begin
                    // Queue id with all 1s indicates drop.
                    out_meta_data.pkt_queue_id <= '1;
                end
            end
        end
    end
end 


// Placement FSM.
always@(posedge clk) begin
    if (rst) begin
        p_state <= P_IDLE;
        out_control_done <= 1'b0;
        eviction_cnt <= 0;
    end
    else begin
        case (p_state)
            P_IDLE: begin
                p_busy <= 1'b0;
                ft0_rden_b <= 1'b0;
                ft0_wren_b <= 1'b0;
                ft1_rden_b <= 1'b0;
                ft1_wren_b <= 1'b0;
                ft2_rden_b <= 1'b0;
                ft2_wren_b <= 1'b0;
                ft3_rden_b <= 1'b0;
                ft3_wren_b <= 1'b0;
                out_control_done <= 1'b0;

                if (p_h0_hashed_valid) begin
                    ft0_rden_b <= 1'b1;
                    ft0_addr_b <= p_h0_hashed[FT_AWIDTH-1:0];
                    ft1_rden_b <= 1'b1;
                    ft1_addr_b <= p_h1_hashed[FT_AWIDTH-1:0];
                    ft2_rden_b <= 1'b1;
                    ft2_addr_b <= p_h2_hashed[FT_AWIDTH-1:0];
                    ft3_rden_b <= 1'b1;
                    ft3_addr_b <= p_h3_hashed[FT_AWIDTH-1:0];

                    p_busy <= 1'b1;
                    p_state <= P_LOOKUP;
                    p_lookup_tuple <= p_c7.tuple;
                    p_insert_fce_r.valid <= 1'b1;
                    p_insert_fce_r.tuple <= p_c7.tuple;
                    p_insert_fce_r.pkt_queue_id <= p_c7.pkt_queue_id;
                end
            end

            P_LOOKUP: begin
                ft0_rden_b <= 1'b0;
                ft1_rden_b <= 1'b0;
                ft2_rden_b <= 1'b0;
                ft3_rden_b <= 1'b0;

                if (rd_valid_b) begin
                    p_ft_hit_r <= p_ft_hit;
                    p_ft_empty_r <= p_ft_empty;

                    // Update an existing entry.
                    if (p_ft_hit != 0) begin
                        p_state <= P_UPDATE;
                    end
                    else if (p_ft_empty != 0) begin
                        p_state <= P_INSERT_NO_EVIC;
                    end
                    else begin
                        p_state <= P_INSERT_EVIC;
                    end
                end
            end

            P_UPDATE: begin
                if (p_ft_hit_r[0]) begin
                    ft0_wren_b <= 1'b1;
                    ft0_data_b <= p_insert_fce_r;
                end
                else if (p_ft_hit_r[1]) begin
                    ft1_wren_b <= 1'b1;
                    ft1_data_b <= p_insert_fce_r;
                end
                else if (p_ft_hit_r[2]) begin
                    ft2_wren_b <= 1'b1;
                    ft2_data_b <= p_insert_fce_r;
                end
                else if (p_ft_hit_r[3]) begin
                    ft3_wren_b <= 1'b1;
                    ft3_data_b <= p_insert_fce_r;
                end

                p_busy <= 1'b0;
                p_state <= P_IDLE;
                out_control_done <= 1'b1;
            end

            P_INSERT_NO_EVIC: begin
                if (p_ft_empty_r[0]) begin
                    ft0_wren_b <= 1'b1;
                    ft0_data_b <= p_insert_fce_r;
                end
                else if (p_ft_empty_r[1]) begin
                    ft1_wren_b <= 1'b1;
                    ft1_data_b <= p_insert_fce_r;
                end
                else if (p_ft_empty_r[2]) begin
                    ft2_wren_b <= 1'b1;
                    ft2_data_b <= p_insert_fce_r;
                end
                else if (p_ft_empty_r[3]) begin
                    ft3_wren_b <= 1'b1;
                    ft3_data_b <= p_insert_fce_r;
                end

                p_busy <= 1'b0;
                p_state <= P_IDLE;
                out_control_done <= 1'b1;
            end

            P_INSERT_EVIC: begin
                // Unimplemented!
                eviction_cnt <= eviction_cnt + 1;
                p_state <= P_IDLE;
                `hdisplay(("Flow Table: Eviction!"));
            end
        endcase
    end
end

always @(posedge clk) begin
    if (!s_busy) begin
        s_m0 <= in_meta_data;
        s_m1 <= s_m0;
        s_m2 <= s_m1;
        s_m3 <= s_m2;
        s_m4 <= s_m3;
        s_m5 <= s_m4;
        s_m6 <= s_m5;
        s_m7 <= s_m6;
    end
end

assign s_h0_tuple_in = in_meta_data.tuple;
assign s_h1_tuple_in = in_meta_data.tuple;
assign s_h2_tuple_in = in_meta_data.tuple;
assign s_h3_tuple_in = in_meta_data.tuple;

assign s_h0_initval = 32'd0;
assign s_h1_initval = 32'd1;
assign s_h2_initval = 32'd2;
assign s_h3_initval = 32'd3;

assign s_h0_tuple_in_valid = in_meta_valid & in_meta_ready;
assign s_h1_tuple_in_valid = in_meta_valid & in_meta_ready;
assign s_h2_tuple_in_valid = in_meta_valid & in_meta_ready;
assign s_h3_tuple_in_valid = in_meta_valid & in_meta_ready;

assign s_h0_stall = s_busy;
assign s_h1_stall = s_busy;
assign s_h2_stall = s_busy;
assign s_h3_stall = s_busy;

hash_func s_hash0(
    .clk            (clk),
    .rst            (rst),
    .stall          (s_h0_stall),
    .tuple_in       (s_h0_tuple_in),
    .initval        (s_h0_initval),
    .tuple_in_valid (s_h0_tuple_in_valid),
    .hashed         (s_h0_hashed),
    .hashed_valid   (s_h0_hashed_valid)
);
hash_func s_hash1(
    .clk            (clk),
    .rst            (rst),
    .stall          (s_h1_stall),
    .tuple_in       (s_h1_tuple_in),
    .initval        (s_h1_initval),
    .tuple_in_valid (s_h1_tuple_in_valid),
    .hashed         (s_h1_hashed),
    .hashed_valid   (s_h1_hashed_valid)
);
hash_func s_hash2(
    .clk            (clk),
    .rst            (rst),
    .stall          (s_h2_stall),
    .tuple_in       (s_h2_tuple_in),
    .initval        (s_h2_initval),
    .tuple_in_valid (s_h2_tuple_in_valid),
    .hashed         (s_h2_hashed),
    .hashed_valid   (s_h2_hashed_valid)
);
hash_func s_hash3(
    .clk            (clk),
    .rst            (rst),
    .stall          (s_h3_stall),
    .tuple_in       (s_h3_tuple_in),
    .initval        (s_h3_initval),
    .tuple_in_valid (s_h3_tuple_in_valid),
    .hashed         (s_h3_hashed),
    .hashed_valid   (s_h3_hashed_valid)
);

always @(posedge clk) begin
    if (!p_busy) begin
        p_c0 <= in_control_data;
        p_c1 <= p_c0;
        p_c2 <= p_c1;
        p_c3 <= p_c2;
        p_c4 <= p_c3;
        p_c5 <= p_c4;
        p_c6 <= p_c5;
        p_c7 <= p_c6;
    end
end

assign p_h0_tuple_in = in_control_data.tuple;
assign p_h1_tuple_in = in_control_data.tuple;
assign p_h2_tuple_in = in_control_data.tuple;
assign p_h3_tuple_in = in_control_data.tuple;

assign p_h0_initval = 32'd0;
assign p_h1_initval = 32'd1;
assign p_h2_initval = 32'd2;
assign p_h3_initval = 32'd3;

assign p_h0_tuple_in_valid = in_control_valid & !p_busy;
assign p_h1_tuple_in_valid = in_control_valid & !p_busy;
assign p_h2_tuple_in_valid = in_control_valid & !p_busy;
assign p_h3_tuple_in_valid = in_control_valid & !p_busy;

assign p_h0_stall = p_busy;
assign p_h1_stall = p_busy;
assign p_h2_stall = p_busy;
assign p_h3_stall = p_busy;

hash_func p_hash0(
    .clk            (clk),
    .rst            (rst),
    .stall          (p_h0_stall),
    .tuple_in       (p_h0_tuple_in),
    .initval        (p_h0_initval),
    .tuple_in_valid (p_h0_tuple_in_valid),
    .hashed         (p_h0_hashed),
    .hashed_valid   (p_h0_hashed_valid)
);
hash_func p_hash1(
    .clk            (clk),
    .rst            (rst),
    .stall          (p_h1_stall),
    .tuple_in       (p_h1_tuple_in),
    .initval        (p_h1_initval),
    .tuple_in_valid (p_h1_tuple_in_valid),
    .hashed         (p_h1_hashed),
    .hashed_valid   (p_h1_hashed_valid)
);
hash_func p_hash2(
    .clk            (clk),
    .rst            (rst),
    .stall          (p_h2_stall),
    .tuple_in       (p_h2_tuple_in),
    .initval        (p_h2_initval),
    .tuple_in_valid (p_h2_tuple_in_valid),
    .hashed         (p_h2_hashed),
    .hashed_valid   (p_h2_hashed_valid)
);
hash_func p_hash3(
    .clk            (clk),
    .rst            (rst),
    .stall          (p_h3_stall),
    .tuple_in       (p_h3_tuple_in),
    .initval        (p_h3_initval),
    .tuple_in_valid (p_h3_tuple_in_valid),
    .hashed         (p_h3_hashed),
    .hashed_valid   (p_h3_hashed_valid)
);

assign ft0_data_a = 0;
assign ft1_data_a = 0;
assign ft2_data_a = 0;
assign ft3_data_a = 0;

bram_true2port  #(
    .AWIDTH(FT_AWIDTH),
    .DWIDTH(FT_DWIDTH),
    .DEPTH(FT_DEPTH)
)
FT_0 (
    .address_a  (ft0_addr_a),
    .address_b  (ft0_addr_b),
    .clock      (clk),
    .data_a     (ft0_data_a),
    .data_b     (ft0_data_b),
    .rden_a     (ft0_rden_a),
    .rden_b     (ft0_rden_b),
    .wren_a     (ft0_wren_a),
    .wren_b     (ft0_wren_b),
    .q_a        (ft0_q_a),
    .q_b        (ft0_q_b)
);

bram_true2port  #(
    .AWIDTH(FT_AWIDTH),
    .DWIDTH(FT_DWIDTH),
    .DEPTH(FT_DEPTH)
)
FT_1 (
    .address_a  (ft1_addr_a),
    .address_b  (ft1_addr_b),
    .clock      (clk),
    .data_a     (ft1_data_a),
    .data_b     (ft1_data_b),
    .rden_a     (ft1_rden_a),
    .rden_b     (ft1_rden_b),
    .wren_a     (ft1_wren_a),
    .wren_b     (ft1_wren_b),
    .q_a        (ft1_q_a),
    .q_b        (ft1_q_b)
);

bram_true2port  #(
    .AWIDTH(FT_AWIDTH),
    .DWIDTH(FT_DWIDTH),
    .DEPTH(FT_DEPTH)
)
FT_2 (
    .address_a  (ft2_addr_a),
    .address_b  (ft2_addr_b),
    .clock      (clk),
    .data_a     (ft2_data_a),
    .data_b     (ft2_data_b),
    .rden_a     (ft2_rden_a),
    .rden_b     (ft2_rden_b),
    .wren_a     (ft2_wren_a),
    .wren_b     (ft2_wren_b),
    .q_a        (ft2_q_a),
    .q_b        (ft2_q_b)
);

bram_true2port  #(
    .AWIDTH(FT_AWIDTH),
    .DWIDTH(FT_DWIDTH),
    .DEPTH(FT_DEPTH)
)
FT_3 (
    .address_a  (ft3_addr_a),
    .address_b  (ft3_addr_b),
    .clock      (clk),
    .data_a     (ft3_data_a),
    .data_b     (ft3_data_b),
    .rden_a     (ft3_rden_a),
    .rden_b     (ft3_rden_b),
    .wren_a     (ft3_wren_a),
    .wren_b     (ft3_wren_b),
    .q_a        (ft3_q_a),
    .q_b        (ft3_q_b)
);

endmodule
