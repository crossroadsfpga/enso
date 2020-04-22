`include "./my_struct_s.sv"
module flow_table_wrapper(
    input   logic           clk,
    input   logic           rst,
    input   metadata_t      in_meta_data,
    input   logic           in_meta_valid,
    output  logic           in_meta_ready,
    output  metadata_t      out_meta_data,
    output  logic           out_meta_valid,
    input   logic           out_meta_ready,
    output  metadata_t      forward_pkt_data,
    output  logic           forward_pkt_valid,
    input   logic           forward_pkt_ready,
    // status register bus
    input   logic           clk_status,
    input   logic   [29:0]  status_addr,
    input   logic           status_read,
    input   logic           status_write,
    input   logic   [31:0]  status_writedata,
    output  logic   [31:0]  status_readdata,
    output  logic           status_readdata_valid
);

tuple_t         h0_tuple_in;
logic           h0_tuple_in_valid;
logic [31:0]    h0_initval;
logic [31:0]    h0_hashed;
logic           h0_hashed_valid;

tuple_t         h1_tuple_in;
logic           h1_tuple_in_valid;
logic [31:0]    h1_initval;
logic [31:0]    h1_hashed;
logic           h1_hashed_valid;

tuple_t         h2_tuple_in;
logic           h2_tuple_in_valid;
logic [31:0]    h2_initval;
logic [31:0]    h2_hashed;
logic           h2_hashed_valid;

tuple_t         h3_tuple_in;
logic           h3_tuple_in_valid;
logic [31:0]    h3_initval;
logic [31:0]    h3_hashed;
logic           h3_hashed_valid;

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

metadata_t m0;
metadata_t m1;
metadata_t m2;
metadata_t m3;
metadata_t m4;
metadata_t m5;
metadata_t m6;
metadata_t m7;

metadata_t meta_r;

logic rd_valid_a;
logic rd_valid_b;
logic rd_valid_a_r;
logic rd_valid_b_r;

logic ft0_rd_valid_b;
logic ft1_rd_valid_b;
logic ft2_rd_valid_b;
logic ft3_rd_valid_b;
logic ft0_rd_valid_b_r;
logic ft1_rd_valid_b_r;
logic ft2_rd_valid_b_r;
logic ft3_rd_valid_b_r;

//queue

typedef enum
{
    IDLE,
    LOOKUP,
    UPDATE_FT,
    UPDATE_Q,
    INSERT_Q,
    INSERT_WAIT,
    WAIT_Q
} service_t;
service_t s_state;

typedef enum
{
    P_IDLE,
    P_LOOKUP,
    P_NO_EVIC,
    P_EVIC,
    P_WAIT_HASH,
    P_WAIT_NO_EVIC,
    P_WAIT_EVIC,
    P_STATS
} place_t;

place_t p_state;

//Signal for para_Q
logic enq;
fce_t enq_fce;
logic full;
logic deq_req;
logic deq_success;
fce_t deq_fce;
logic empty;
logic lookup;
tuple_t lookup_tuple;
logic hit;
logic hit_valid;
logic [PQ_DEPTH-1:0] hit_bitmap;
logic [PQ_DEPTH-1:0] hit_bitmap_r;
fce_t hit_fce;
logic update;
logic [PQ_DEPTH-1:0] update_bitmap;
fce_t update_fce;
logic delete;
logic [PQ_DEPTH-1:0] delete_bitmap;
logic lock_q;

fce_t empty_entry;

logic [1:0] random = 0;
logic p_valid;

logic s_busy;

logic [FT_SUBTABLE-1:0] ft_hit;
logic [FT_SUBTABLE-1:0] ft_hit_r;
logic [FT_SUBTABLE-1:0] ft_empty;
logic [FT_SUBTABLE-1:0] ft_empty_r;

logic insert;
fce_t insert_fce;
logic evict;
fce_t evict_fce;

logic   [29:0]  status_addr_r;
logic   [STAT_AWIDTH-1:0]   status_addr_sel_r;
logic           status_read_r;
logic           status_write_r;
logic   [31:0]  status_writedata_r;

logic           ft_rd;
logic   [FT_AWIDTH+1:0] ft_rd_addr_r;
logic   [FT_AWIDTH+1:0] ft_rd_addr;
logic           ft_rd_valid;
logic   [31:0]  ft_rd_data;

logic   [31:0]  ft_ctrl;
logic   [31:0]  ft_ctrl_r1;
logic   [31:0]  ft_ctrl_r2;
logic   [31:0]  ft_ctrl_user;
logic   [31:0]  ft_in_pkt;
logic   [31:0]  ft_in_pkt_r1;
logic   [31:0]  ft_in_pkt_r2;
logic   [31:0]  ft_in_pkt_user;
logic   [31:0]  ft_out_pkt;
logic   [31:0]  ft_out_pkt_r1;
logic   [31:0]  ft_out_pkt_r2;
logic   [31:0]  ft_out_pkt_user;
logic   [31:0]  ft_flow_insert;
logic   [31:0]  ft_flow_insert_r1;
logic   [31:0]  ft_flow_insert_r2;
logic   [31:0]  ft_flow_insert_user;
logic   [31:0]  ft_flow_deq;
logic   [31:0]  ft_flow_deq_r1;
logic   [31:0]  ft_flow_deq_r2;
logic   [31:0]  ft_flow_deq_user;
logic   [31:0]  ft_lookup_pkt;
logic   [31:0]  ft_lookup_pkt_r1;
logic   [31:0]  ft_lookup_pkt_r2;
logic   [31:0]  ft_lookup_pkt_user;

logic   [31:0]  ft_conc_flow;
logic   [31:0]  ft_conc_flow_r1;
logic   [31:0]  ft_conc_flow_r2;
logic   [31:0]  ft_conc_flow_user;

logic   [31:0]  ft_current_flow;
logic   [31:0]  ft_current_flow_r1;
logic   [31:0]  ft_current_flow_r2;
logic   [31:0]  ft_current_flow_user;

logic   [31:0]  pkt_cnt_fin;
logic   [31:0]  pkt_cnt_fin_r1;
logic   [31:0]  pkt_cnt_fin_r2;
logic   [31:0]  pkt_cnt_fin_user;

logic   [31:0]  pkt_cnt_ack;
logic   [31:0]  pkt_cnt_ack_r1;
logic   [31:0]  pkt_cnt_ack_r2;
logic   [31:0]  pkt_cnt_ack_user;

logic   [31:0]  pkt_insert_ooo;
logic   [31:0]  pkt_insert_ooo_r1;
logic   [31:0]  pkt_insert_ooo_r2;
logic   [31:0]  pkt_insert_ooo_user;

logic           ft_rd_r1;
logic           ft_rd_r2;
logic           ft_rd_user;
logic   [FT_AWIDTH+1:0] ft_rd_addr_r1;
logic   [FT_AWIDTH+1:0] ft_rd_addr_r2;
logic   [FT_AWIDTH+1:0] ft_rd_addr_user;
logic           ft_rd_valid_r1;
logic           ft_rd_valid_r2;
logic           ft_rd_valid_user;
logic   [31:0]  ft_rd_data_r1;
logic   [31:0]  ft_rd_data_r2;
logic   [31:0]  ft_rd_data_user;

//signal for forwarding
logic f_pkt; //not-forward pkt;

//signals for reassembly
logic r_start;
metadata_t r_in_meta;
fce_t r_in_fce;
 
fce_t r_out_fce;  
logic r_delete;
logic r_stop_fetch;
metadata_t r_fetch_meta;
logic r_fetch_valid;
logic r_done;

///////////////////////////
//Read and Write registers
//////////////////////////
always @(posedge clk_status) begin
    status_addr_r           <= status_addr[7:0];
    status_addr_sel_r       <= status_addr[29:30-STAT_AWIDTH];

    status_read_r           <= status_read;
    status_write_r          <= status_write;
    status_writedata_r      <= status_writedata;
    status_readdata_valid   <= 1'b0;
    status_readdata         <= status_readdata;

    ft_rd <= status_read_r & (status_addr_sel_r == FT_TABLE);
    ft_rd_addr_r         <= status_addr[FT_AWIDTH+1:0];


    if (status_read_r) begin
        if (status_addr_sel_r == FT_REG) begin
            status_readdata_valid <= 1'b1;
            case (status_addr_r)
                8'd0  : status_readdata <= ft_ctrl;
                //8'd1  : status_readdata <= ft_in_pkt;
                //8'd2  : status_readdata <= ft_out_pkt;
                8'd3  : status_readdata <= ft_flow_insert;
                8'd4  : status_readdata <= ft_flow_deq;
                8'd5  : status_readdata <= ft_lookup_pkt;
                8'd6  : status_readdata <= ft_conc_flow;
                8'd7  : status_readdata <= ft_current_flow;
                8'd8  : status_readdata <= pkt_cnt_fin;
                8'd9  : status_readdata <= pkt_cnt_ack;
                8'd10 : status_readdata <= pkt_insert_ooo;

                default : status_readdata <= 32'h345;
            endcase
        //read latency
        end else if (status_addr_sel_r == FT_TABLE) begin
            ft_rd_addr <= ft_rd_addr_r;
        end
    end

    if (ft_rd_valid)begin
        status_readdata <= ft_rd_data;
        status_readdata_valid <= 1;
    end

    if (status_write_r) begin
        if (status_addr_sel_r == FT_REG) begin
            case (status_addr_r)
                8'd0  : ft_ctrl <= status_writedata_r;
            endcase
        end
    end
end

//clk_status -> user_clk sync
always@(posedge clk)begin
    ft_rd_r1 <= ft_rd;
    ft_rd_r2 <= ft_rd_r1;
    ft_rd_user <= ft_rd_r2;
    ft_rd_addr_r1 <= ft_rd_addr;
    ft_rd_addr_r2 <= ft_rd_addr_r1;
    ft_rd_addr_user <= ft_rd_addr_r2;
    ft_ctrl_r1 <= ft_ctrl;
    ft_ctrl_r2 <= ft_ctrl_r1;
    ft_ctrl_user <= ft_ctrl_r2;
end

// user_clk -> clk_status sync
always@(posedge clk_status)begin
    ft_rd_valid_r1 <= ft_rd_valid_user;
    ft_rd_valid_r2 <= ft_rd_valid_r1;
    ft_rd_valid <= ft_rd_valid_r2;
    ft_rd_data_r1 <= ft_rd_data_user;
    ft_rd_data_r2 <= ft_rd_data_r1;
    ft_rd_data <= ft_rd_data_r2;

    ft_in_pkt_r1    <= ft_in_pkt_user;
    ft_in_pkt_r2    <= ft_in_pkt_r1;
    ft_in_pkt       <= ft_in_pkt_r2;
    ft_out_pkt_r1    <= ft_out_pkt_user;
    ft_out_pkt_r2    <= ft_out_pkt_r1;
    ft_out_pkt       <= ft_out_pkt_r2;
    ft_flow_insert_r1    <= ft_flow_insert_user;
    ft_flow_insert_r2    <= ft_flow_insert_r1;
    ft_flow_insert       <= ft_flow_insert_r2;
    ft_flow_deq_r1    <= ft_flow_deq_user;
    ft_flow_deq_r2    <= ft_flow_deq_r1;
    ft_flow_deq       <= ft_flow_deq_r2;
    ft_lookup_pkt_r1    <= ft_lookup_pkt_user;
    ft_lookup_pkt_r2    <= ft_lookup_pkt_r1;
    ft_lookup_pkt       <= ft_lookup_pkt_r2;
    ft_conc_flow_r1    <= ft_conc_flow_user;
    ft_conc_flow_r2    <= ft_conc_flow_r1;
    ft_conc_flow       <= ft_conc_flow_r2;
    ft_current_flow_r1    <= ft_current_flow_user;
    ft_current_flow_r2    <= ft_current_flow_r1;
    ft_current_flow       <= ft_current_flow_r2;
    pkt_cnt_fin_r1    <= pkt_cnt_fin_user;
    pkt_cnt_fin_r2    <= pkt_cnt_fin_r1;
    pkt_cnt_fin       <= pkt_cnt_fin_r2;
    pkt_cnt_ack_r1    <= pkt_cnt_ack_user;
    pkt_cnt_ack_r2    <= pkt_cnt_ack_r1;
    pkt_cnt_ack       <= pkt_cnt_ack_r2;
    pkt_insert_ooo_r1    <= pkt_insert_ooo_user;
    pkt_insert_ooo_r2    <= pkt_insert_ooo_r1;
    pkt_insert_ooo       <= pkt_insert_ooo_r2;
end

//stats
always@(posedge clk)begin
    if(rst)begin
        ft_in_pkt_user <= 0;
        ft_out_pkt_user <= 0;
        ft_lookup_pkt_user <= 0;
        ft_flow_insert_user <= 0;
        ft_flow_deq_user <= 0;
        pkt_cnt_ack_user <= 0;
        pkt_insert_ooo_user <= 0;
    end else begin
        if(in_meta_valid & in_meta_ready)begin
            ft_in_pkt_user <= ft_in_pkt_user + 1'b1;
        end

        if(out_meta_valid & out_meta_ready)begin
            ft_out_pkt_user <= ft_out_pkt_user + 1'b1;
        end

        if(insert)begin
            ft_flow_insert_user <= ft_flow_insert_user + 1'b1;
        end

        if(deq_success)begin
            ft_flow_deq_user <= ft_flow_deq_user + 1'b1;
        end

        if(lookup)begin
            ft_lookup_pkt_user <= ft_lookup_pkt_user + 1'b1;
        end
        //if(h0_hashed_valid)begin
        //    ft_hashed_valid_user <= ft_hashed_valid_user + 1'b1;
        //end

        if(forward_pkt_valid) begin
            pkt_cnt_ack_user <= pkt_cnt_ack_user + 1'b1;
        end

        if(r_done & r_stop_fetch)begin
            pkt_insert_ooo_user <= pkt_insert_ooo_user + 1'b1;
        end

    end
end



/////////Forward pkts/////////////////////////
//ACK pkts with 0 length can be forwarded.
assign f_pkt = (in_meta_data.tcp_flags == (1'b1 << TCP_FACK)) & (in_meta_data.len==0);
//assume no back pressure
always@(posedge clk)begin
    if(rst)begin
        forward_pkt_valid <= 0;
    end else begin
        forward_pkt_valid <= in_meta_valid & f_pkt;
    end
    forward_pkt_data <= in_meta_data;
    forward_pkt_data.pkt_flags <= PKT_FORWARD;
end


//assign out_meta_data = in_meta_data;
//assign out_meta_valid = h0_hashed_valid;
assign in_meta_ready = !s_busy | (f_pkt & in_meta_valid);

//two cycle rd delay
always@(posedge clk)begin
    rd_valid_a_r <= ft0_rden_a;
    rd_valid_b_r <= ft0_rden_b;
    rd_valid_a <= rd_valid_a_r;
    rd_valid_b <= rd_valid_b_r;

    ft0_rd_valid_b_r <= ft0_rden_b;
    ft1_rd_valid_b_r <= ft1_rden_b;
    ft2_rd_valid_b_r <= ft2_rden_b;
    ft3_rd_valid_b_r <= ft3_rden_b;
    ft0_rd_valid_b <= ft0_rd_valid_b_r;
    ft1_rd_valid_b <= ft1_rd_valid_b_r;
    ft2_rd_valid_b <= ft2_rd_valid_b_r;
    ft3_rd_valid_b <= ft3_rd_valid_b_r;
end

assign ft_hit[0] = (lookup_tuple == ft0_q_a.tuple) & ft0_q_a.valid;
assign ft_hit[1] = (lookup_tuple == ft1_q_a.tuple) & ft1_q_a.valid;
assign ft_hit[2] = (lookup_tuple == ft2_q_a.tuple) & ft2_q_a.valid;
assign ft_hit[3] = (lookup_tuple == ft3_q_a.tuple) & ft3_q_a.valid;

assign ft_empty[0] = !ft0_q_b.valid;
assign ft_empty[1] = !ft1_q_b.valid;
assign ft_empty[2] = !ft2_q_b.valid;
assign ft_empty[3] = !ft3_q_b.valid;

always@(posedge clk)begin
    random <= random + 1'b1;
end

//Service FSM
always@(posedge clk)begin
    if(rst)begin
        s_state <= IDLE;
        update <= 1'b0;
        insert <= 1'b0;
        lookup <= 1'b0;
        delete <= 1'b0;
        lock_q <= 1'b0;
        ft_current_flow_user <= 0;
        ft_conc_flow_user <= 0;
        pkt_cnt_fin_user <= 0;
        out_meta_valid <= 1'b0;
    end else begin
        case (s_state)
            IDLE: begin
                //Note the hashed value is truncated. Only the lower bits are
                //used currently.
                update <= 1'b0;
                delete <= 1'b0;
                insert <= 1'b0;
                lookup <= 1'b0;
                lock_q <= 1'b0;
                ft0_rden_a <= 1'b0;
                ft0_wren_a <= 1'b0;
                ft1_rden_a <= 1'b0;
                ft1_wren_a <= 1'b0;
                ft2_rden_a <= 1'b0;
                ft2_wren_a <= 1'b0;
                ft3_rden_a <= 1'b0;
                ft3_wren_a <= 1'b0;
                out_meta_valid <= 1'b0;
                s_busy <= 1'b0;
                r_start <= 0;

                if(h0_hashed_valid)begin
                    s_state <= LOOKUP;
                    ft0_rden_a <= 1'b1;
                    ft0_addr_a <= h0_hashed;
                    ft1_rden_a <= 1'b1;
                    ft1_addr_a <= h1_hashed;
                    ft2_rden_a <= 1'b1;
                    ft2_addr_a <= h2_hashed;
                    ft3_rden_a <= 1'b1;
                    ft3_addr_a <= h3_hashed;

                    lookup <= 1'b1;
                    lookup_tuple <= m7.tuple;
                    meta_r <= m7;
                    //All TCP data pkts are considered as PKT_CHECK
                    if(m7.len!=0)begin
                        meta_r.pkt_flags <= PKT_CHECK;
                    end
                    s_busy <= 1'b1;
                    lock_q <= 1'b1;
                end
            end
            LOOKUP:begin
                lookup <= 1'b0;
                ft0_rden_a <= 1'b0;
                ft1_rden_a <= 1'b0;
                ft2_rden_a <= 1'b0;
                ft3_rden_a <= 1'b0;
                //The entry can only appear in either Q or FT.
                if(hit_valid & hit) begin
                    s_state <= UPDATE_Q;
                    r_start <= 1;
                    r_in_fce <= hit_fce;
                    r_in_meta <= meta_r;
                end


                if (rd_valid_a) begin
                    ft_hit_r <= ft_hit;
                    lock_q <= 1'b0;
                    //hit FT
                    if(ft_hit !=0 )begin
                        s_state <= UPDATE_FT;
                        r_start <= 1;
                        r_in_fce <= 0;
                        if(ft_hit[0])begin
                            r_in_fce <= ft0_q_a;
                        end else if (ft_hit[1])begin
                            r_in_fce <= ft1_q_a;
                        end else if (ft_hit[2])begin
                            r_in_fce <= ft2_q_a;
                        end else if (ft_hit[3])begin
                            r_in_fce <= ft3_q_a;
                        end
                        r_in_meta <= meta_r;
                    end else begin
                        //Do not insert at all
                        if(meta_r.tcp_flags[TCP_FIN] | meta_r.tcp_flags[TCP_RST])begin
                            pkt_cnt_fin_user <= pkt_cnt_fin_user + 1'b1;
                            out_meta_valid <= 1'b1;
                            out_meta_data <= meta_r;
                            s_busy <= 1'b0;
                            s_state <= IDLE;
                        end else begin
                            s_state <= INSERT_Q;
                        end
                    end
                end
            end

            UPDATE_Q: begin
                r_start <= 0;
                if(r_done)begin
                    if(r_delete)begin
                        delete <= 1'b1;
                        delete_bitmap <= hit_bitmap;
                        ft_current_flow_user <= ft_current_flow_user - 1'b1;
                        pkt_cnt_fin_user <= pkt_cnt_fin_user + 1'b1;
                    end else begin
                        update <= 1'b1;
                        update_bitmap <= hit_bitmap;
                        update_fce <= r_out_fce;
                    end
                    
                    s_state <= IDLE;
                    s_busy <= 1'b0;   
                end
                out_meta_valid <= r_fetch_valid;
                out_meta_data <= r_fetch_meta;
            end

            UPDATE_FT:begin
                r_start <= 0;
                if(r_done)begin
                    if(r_delete)begin
                        ft_current_flow_user <= ft_current_flow_user - 1'b1;
                        pkt_cnt_fin_user <= pkt_cnt_fin_user + 1'b1;
                    end
                    //update in priority manner.
                    if(ft_hit_r[0])begin
                        //Addr is not changed yet.
                        ft0_wren_a <= 1'b1;
                        ft0_data_a <= r_out_fce;
                    end else if (ft_hit_r[1])begin
                        //Addr is not changed yet.
                        ft1_wren_a <= 1'b1;
                        ft1_data_a <= r_out_fce;
                    end else if (ft_hit_r[2])begin
                        //Addr is not changed yet.
                        ft2_wren_a <= 1'b1;
                        ft2_data_a <= r_out_fce;
                    end else if (ft_hit_r[3])begin
                        //Addr is not changed yet.
                        ft3_wren_a <= 1'b1;
                        ft3_data_a <= r_out_fce;
                    end
                    s_state <= IDLE;
                    s_busy <= 1'b0;
                end
                out_meta_valid <= r_fetch_valid;
                out_meta_data <= r_fetch_meta;
            end

            INSERT_Q:begin
                s_state <= IDLE;
                s_busy <= 1'b0;
                out_meta_valid <= 1'b1;
                //No Evication at this point
                if(p_state == P_EVIC)begin
                    update <= 1'b1;
                    //lock_q <= 1'b1;
                    //update_bitmap <= 8'b00000001;
                    //update_fce.valid <= 1'b1;
                    //update_fce.tuple <= meta_r.tuple;
                    //update_fce.seq <= meta_r.seq;
                    //update_fce.pointer <= 0;
                    //update_fce.ll_valid <= 1'b0;

                    //out_meta_valid <= 1'b1;
                end else if (!full)begin
                    insert <= 1'b1;
                    insert_fce.valid <= 1'b1;
                    insert_fce.tuple <= meta_r.tuple;
                    if(meta_r.tcp_flags[TCP_SYN])begin
                        insert_fce.seq <= meta_r.seq + 1'b1;
                        insert_fce.last_7_bytes <= {56{1'b1}};
                    end else begin
                        insert_fce.seq <= meta_r.seq + meta_r.len;
                        insert_fce.last_7_bytes <= meta_r.last_7_bytes;
                    end
                    //store current pkt's last_7_bytes
                    insert_fce.pointer <= 0;
                    insert_fce.ll_valid <= 1'b0;
                    out_meta_valid <= 1'b1;
                    out_meta_data <= meta_r;
                    //First pkt of the flow
                    out_meta_data.last_7_bytes <= {56{1'b1}};

                    s_state <= INSERT_WAIT;
                    s_busy <= 1'b1;
                    ft_current_flow_user <= ft_current_flow_user + 1'b1;
                    if (ft_conc_flow_user <= ft_current_flow_user)begin
                        ft_conc_flow_user <= ft_conc_flow_user + 1'b1;
                    end
                end else begin
                    s_state <= WAIT_Q;
                    s_busy <= 1'b1;
                    out_meta_valid <= 1'b0;
                end
            end

            //One cycle delay of insert. make sure the insert complete before
            //next lookup. 
            INSERT_WAIT:begin
                s_busy <= 1'b0;
                insert <= 1'b0;
                out_meta_valid <= 1'b0;
                s_state <= IDLE;
            end

            WAIT_Q:begin
                s_busy <= 1'b1;
                update <= 1'b0;
                lookup <= 1'b0;
                if(!full)begin
                    s_state <= INSERT_Q;
                end
            end
        endcase
    end
end

assign deq_success = deq_req & !lock_q & !empty;
//assign hit_head = hit_valid & hit & (head_out==hit_idx); 
//Placement FSM
always@(posedge clk)begin
    if(rst)begin
        p_state <= P_IDLE;
    end else begin
        case (p_state)
            P_IDLE: begin
                deq_req <= 1'b0;
                evict <= 1'b0;
                ft0_rden_b <= 1'b0;
                ft1_rden_b <= 1'b0;
                ft2_rden_b <= 1'b0;
                ft3_rden_b <= 1'b0;
                if(!empty & !deq_req) begin
                    p_valid <= 1'b1;
                    p_state <= P_WAIT_HASH;
                end       
                if(ft_ctrl_user[0])begin
                    p_state <= P_STATS;
                end
            end
            P_WAIT_HASH: begin
                p_valid <= 1'b0;

                //Note the hashed value is truncated. Only the lower bits are
                //used currently.
                if(p_h0_hashed_valid)begin
                    p_state <= P_LOOKUP;
                    ft0_rden_b <= 1'b1;
                    ft0_addr_b <= p_h0_hashed;
                    ft1_rden_b <= 1'b1;
                    ft1_addr_b <= p_h1_hashed;
                    ft2_rden_b <= 1'b1;
                    ft2_addr_b <= p_h2_hashed;
                    ft3_rden_b <= 1'b1;
                    ft3_addr_b <= p_h3_hashed;
                end
            end
            P_LOOKUP:begin
                ft0_rden_b <= 1'b0;
                ft1_rden_b <= 1'b0;
                ft2_rden_b <= 1'b0;
                ft3_rden_b <= 1'b0;

                if (rd_valid_b) begin
                    ft_empty_r <= ft_empty;
                    //all entries are full
                    if(ft_empty == 0 )begin
                        p_state <= P_EVIC;
                    end else begin
                        p_state <= P_NO_EVIC;
                    end
                end
            end
            //Inserting.
            P_NO_EVIC:begin
                deq_req <= 1'b1;
                
                //If service FSM is lookup and update the Q, just wait.
                //Even if they are not updating the header. (cannot really
                //tell during lookup)
                if(deq_success)begin
                    deq_req <= 1'b0;
                    //No need to lock the FT as only the placement FSM can
                    //insert; ft_empty is determined by ft_addr_b. which is
                    //not changed.
                    p_state <= P_IDLE;
                end
            end
            //TODO fix this, No eviction, dead end for now.
            P_EVIC:begin
                $display("Evict!!!");
                p_state <= P_EVIC;
                //lookup doesn't hit the head of the queue
                //if(!hit_head)begin
                //    //if service FSM is inserting, then update the head instead
                //    if(s_state==INSERT_Q)begin
                //        deq_req <= 1'b0;
                //    end else begin
                //        deq_req <= 1'b1;
                //    end

                //    p_state <= P_WAIT_EVIC;
                //    //latch data before it's gone
                //    ft0_data_b <= deq_fce;
                //    ft1_data_b <= deq_fce;
                //    ft2_data_b <= deq_fce;
                //    ft3_data_b <= deq_fce;
                //end
            end
            //P_WAIT_EVIC:begin
            //    deq_req <= 0;
            //    evict <= 1'b0;
            //    p_state <= P_EVIC;
            //    if(deq_success)begin
            //        //randomly evict 
            //        case(random)
            //            2'd0: begin
            //                if(!((ft0_addr_b == ft0_addr_a) & (ft0_rden_a | ft0_wren_a)))begin
            //                    p_state <= P_IDLE;
            //                    evict <= 1'b1;
            //                    ft0_wren_b <= 1'b1;
            //                    evict_fce <= ft0_q_b;
            //                end
            //            end
            //            2'd1: begin
            //                if(!((ft1_addr_b == ft1_addr_a) & (ft1_rden_a | ft1_wren_a)))begin
            //                    p_state <= P_IDLE;
            //                    evict <= 1'b1;
            //                    ft1_wren_b <= 1'b1;
            //                    evict_fce <= ft1_q_b;
            //                end
            //            end
            //            2'd2: begin
            //                if(!((ft2_addr_b == ft2_addr_a) & (ft2_rden_a | ft2_wren_a)))begin
            //                    p_state <= P_IDLE;
            //                    evict <= 1'b1;
            //                    ft2_wren_b <= 1'b1;
            //                    evict_fce <= ft2_q_b;
            //                end
            //            end
            //            2'd3: begin
            //                if(!((ft3_addr_b == ft3_addr_a) & (ft3_rden_a | ft3_wren_a)))begin
            //                    p_state <= P_IDLE;
            //                    evict <= 1'b1;
            //                    ft3_wren_b <= 1'b1;
            //                    evict_fce <= ft3_q_b;
            //                end
            //            end
            //        endcase
            //    end
            //end
            P_STATS: begin
                if(!ft_ctrl_user[0])begin
                    p_state <= P_IDLE;
                end
                ft0_rden_b <= 1'b0;
                ft1_rden_b <= 1'b0;
                ft2_rden_b <= 1'b0;
                ft3_rden_b <= 1'b0;
                ft_rd_valid_user <= 1'b0;
                case(ft_rd_addr_user[FT_AWIDTH+1:FT_AWIDTH])
                    2'b00:begin
                        if(ft_rd_user)begin
                            ft0_addr_b <= ft_rd_addr_user[FT_AWIDTH-1:0];
                            ft0_rden_b <= 1'b1;
                        end
                        if(ft0_rd_valid_b)begin
                            ft_rd_valid_user <= 1'b1;
                            if(ft0_q_b.valid)begin
                                ft_rd_data_user <= ft0_q_b.seq;
                            end else begin
                                ft_rd_data_user <= 0;
                            end
                        end
                    end
                    2'b01:begin
                        if(ft_rd_user)begin
                            ft1_addr_b <= ft_rd_addr_user[FT_AWIDTH-1:0];
                            ft1_rden_b <= 1'b1;
                        end
                        if(ft1_rd_valid_b)begin
                            ft_rd_valid_user <= 1'b1;
                            if(ft1_q_b.valid)begin
                                ft_rd_data_user <= ft1_q_b.seq;
                            end else begin
                                ft_rd_data_user <= 0;
                            end
                        end
                    end
                    2'b10:begin
                        if(ft_rd_user)begin
                            ft2_addr_b <= ft_rd_addr_user[FT_AWIDTH-1:0];
                            ft2_rden_b <= 1'b1;
                        end
                        if(ft2_rd_valid_b)begin
                            ft_rd_valid_user <= 1'b1;
                            if(ft2_q_b.valid)begin
                                ft_rd_data_user <= ft2_q_b.seq;
                            end else begin
                                ft_rd_data_user <= 0;
                            end
                        end
                    end
                    2'b11:begin
                        if(ft_rd_user)begin
                            ft3_addr_b <= ft_rd_addr_user[FT_AWIDTH-1:0];
                            ft3_rden_b <= 1'b1;
                        end
                        if(ft3_rd_valid_b)begin
                            ft_rd_valid_user <= 1'b1;
                            if(ft3_q_b.valid)begin
                                ft_rd_data_user <= ft3_q_b.seq;
                            end else begin
                                ft_rd_data_user <= 0;
                            end
                        end
                    end
                endcase
            end
        endcase
    end
end

//Write ft from queue side
//using deq as the the write signal, instead of delaying it one cycle.
always@(*)begin
    ft0_data_b = deq_fce;
    ft1_data_b = deq_fce;
    ft2_data_b = deq_fce;
    ft3_data_b = deq_fce;
    ft0_wren_b = 1'b0;
    ft1_wren_b = 1'b0;
    ft2_wren_b = 1'b0;
    ft3_wren_b = 1'b0;

    if(deq_success)begin
        if(ft_empty_r[0])begin
            ft0_wren_b = 1'b1;
        end else if(ft_empty_r[1])begin
            ft1_wren_b = 1'b1;
        end else if(ft_empty_r[2])begin
            ft2_wren_b = 1'b1;
        end else if(ft_empty_r[3])begin
            ft3_wren_b = 1'b1;
        end
    end
end


//handle enqueue
always@(posedge clk)begin

    if(!full)begin
        if(evict)begin
            enq <= 1'b1;
            enq_fce <= evict_fce;
        end else if(insert) begin
            enq <= 1'b1;
            enq_fce <= insert_fce;
        end else begin
            enq <= 1'b0;
        end
    end else begin
        if(evict)begin
            $display("Eviction to a full queue! Flow drop!");
        end
        if(insert)begin
            $display("Insert to a full queue!");
        end
    end
end    

always@(posedge clk)begin
    if (!s_busy) begin
        m0 <= in_meta_data;
        m1 <= m0;
        m2 <= m1;
        m3 <= m2;
        m4 <= m3;
        m5 <= m4;
        m6 <= m5;
        m7 <= m6;
    end    
    //out_meta_data <= m6; 
end


assign h0_tuple_in = in_meta_data.tuple;
assign h1_tuple_in = in_meta_data.tuple;
assign h2_tuple_in = in_meta_data.tuple;
assign h3_tuple_in = in_meta_data.tuple;

assign h0_initval = 32'd0;
assign h1_initval = 32'd1;
assign h2_initval = 32'd2;
assign h3_initval = 32'd3;

assign h0_tuple_in_valid = in_meta_valid & !s_busy & !f_pkt;
assign h1_tuple_in_valid = in_meta_valid & !s_busy & !f_pkt;
assign h2_tuple_in_valid = in_meta_valid & !s_busy & !f_pkt;
assign h3_tuple_in_valid = in_meta_valid & !s_busy & !f_pkt;

assign h0_stall = s_busy;
assign h1_stall = s_busy;
assign h2_stall = s_busy;
assign h3_stall = s_busy;

hash_func hash0(
    .clk            (clk),
    .rst            (rst),
    .stall          (h0_stall),
    .tuple_in       (h0_tuple_in),
    .initval        (h0_initval),
    .tuple_in_valid (h0_tuple_in_valid),
    .hashed         (h0_hashed),
    .hashed_valid   (h0_hashed_valid)
);
hash_func hash1(
    .clk            (clk),
    .rst            (rst),
    .stall          (h1_stall),
    .tuple_in       (h1_tuple_in),
    .initval        (h1_initval),
    .tuple_in_valid (h1_tuple_in_valid),
    .hashed         (h1_hashed),
    .hashed_valid   (h1_hashed_valid)
);
hash_func hash2(
    .clk            (clk),
    .rst            (rst),
    .stall          (h2_stall),
    .tuple_in       (h2_tuple_in),
    .initval        (h2_initval),
    .tuple_in_valid (h2_tuple_in_valid),
    .hashed         (h2_hashed),
    .hashed_valid   (h2_hashed_valid)
);
hash_func hash3(
    .clk            (clk),
    .rst            (rst),
    .stall          (h3_stall),
    .tuple_in       (h3_tuple_in),
    .initval        (h3_initval),
    .tuple_in_valid (h3_tuple_in_valid),
    .hashed         (h3_hashed),
    .hashed_valid   (h3_hashed_valid)
);

assign p_h0_tuple_in = deq_fce.tuple;
assign p_h1_tuple_in = deq_fce.tuple;
assign p_h2_tuple_in = deq_fce.tuple;
assign p_h3_tuple_in = deq_fce.tuple;

assign p_h0_initval = 32'd0;
assign p_h1_initval = 32'd1;
assign p_h2_initval = 32'd2;
assign p_h3_initval = 32'd3;

assign p_h0_tuple_in_valid = p_valid;
assign p_h1_tuple_in_valid = p_valid;
assign p_h2_tuple_in_valid = p_valid;
assign p_h3_tuple_in_valid = p_valid;

assign p_h0_stall = 1'b0;
assign p_h1_stall = 1'b0;
assign p_h2_stall = 1'b0;
assign p_h3_stall = 1'b0;

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

para_Q para_Q_inst(
    .clk(clk),
    .rst(rst),

    //enq logic
    .enq(enq),
    .enq_fce(enq_fce),
    .full(full),

    //deq
    .deq(deq_success),
    .deq_fce(deq_fce),
    .empty(empty),

    //lookup, one cycle delay
    .lookup(lookup),
    .lookup_tuple(lookup_tuple),
    .hit(hit),
    .hit_valid(hit_valid),
    .hit_bitmap(hit_bitmap),
    .hit_fce(hit_fce),

    //update 
    .update(update),
    .update_bitmap(update_bitmap),
    .update_fce(update_fce),

    //delete
    .delete(delete),
    .delete_bitmap(delete_bitmap)
);

flow_reassembly flow_reassembly_inst(
    .clk(clk),
    .rst(rst),
    .start(r_start),
    .in_meta(r_in_meta),
    .in_fce(r_in_fce),
 
    .out_fce(r_out_fce),  
    .delete(r_delete), 
    .stop_fetch(r_stop_fetch),
    .fetch_meta(r_fetch_meta),
    .fetch_valid(r_fetch_valid),
    .done(r_done)
);

endmodule
