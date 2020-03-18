`include "./my_struct_s.sv"
/* parse the ethnet frame to data for kernel. Convert Big endian to little
* endian */
module parser(clk,rst,
    in_pkt_data,
    in_pkt_valid,
    in_pkt_ready,
    in_pkt_sop,
    in_pkt_eop,
    in_pkt_empty,
    out_pkt_data,
    out_pkt_valid,
    out_pkt_ready,
    out_pkt_sop,
    out_pkt_eop,
    out_pkt_empty,
    in_meta_data,
    in_meta_valid,
    in_meta_ready,
    out_meta_data,
    out_meta_valid,
    out_meta_ready
);
//TODO: IP header/ TCP header bigger than 5 * 32 bits
input clk;
input rst;
input [511:0] in_pkt_data;
input in_pkt_valid;
output logic in_pkt_ready;
input in_pkt_sop;
input in_pkt_eop;
input [5:0] in_pkt_empty;
output logic [511:0] out_pkt_data;
output logic out_pkt_valid;
input  out_pkt_ready;
output logic out_pkt_sop;
output logic out_pkt_eop;
output logic [5:0] out_pkt_empty;
input metadata_t in_meta_data;
input in_meta_valid;
output logic in_meta_ready;
output metadata_t out_meta_data;
output logic out_meta_valid;
input  out_meta_ready;

/*
typedef enum
{
    IDLE,
    READ,
    WAIT
} state_t;
*/

//state_t state;


//First flit
logic [15:0]  eth_type;
logic [3:0]  ip_version;
logic [3:0]  ip_ihl;
//Second flit
logic [5:0]  ip_dscp;
logic [1:0]  ip_ecn;
logic [15:0] ip_len;
logic [15:0] ip_id;
logic [2:0]  ip_flags;
logic [12:0] ip_fo;
logic [7:0]  ip_ttl;
logic [7:0]  ip_prot;
logic [7:0]  ip_chsm;
logic [31:0] ip_sip;
logic [15:0] ip_dip_high;
//Third flit
logic [15:0] ip_dip_low;
logic [15:0] udp_sport;
logic [15:0] udp_dport;
logic [15:0] udp_len;
logic [15:0] udp_chsm;
logic [15:0] tcp_sport;
logic [15:0] tcp_dport;
logic [31:0] tcp_seq;
logic [31:0] tcp_ack;
logic [3:0]  tcp_do;
logic [2:0]  tcp_rsv;
logic        tcp_ns;
logic        tcp_cwr;
logic        tcp_ece;
logic        tcp_urg;
logic        tcp_fack;
logic        tcp_psh;
logic        tcp_rst;
logic        tcp_syn;
logic        tcp_fin;
//Fourth flit
logic [15:0] tcp_win;
logic [15:0] tcp_chsm;
logic [15:0] tcp_urgp;

metadata_t metadata;
logic [PKT_AWIDTH-1:0] temp_pktID;
logic support;

//First flit
assign eth_type = in_pkt_data[128*3+31:128*3+16];      //16
assign ip_version = in_pkt_data[128*3+15:128*3+12];    //4 
assign ip_ihl = in_pkt_data[128*3+11:128*3+8];         //4
assign ip_dscp = in_pkt_data[128*3+7:128*3+2];         //6
assign ip_ecn = in_pkt_data[128*3+1:128*3+0];          //2

//Second flit
assign ip_len = in_pkt_data[128*2+127:128*2+112];      //16
assign ip_id = in_pkt_data[128*2+111:128*2+96];        //16
assign ip_flags = in_pkt_data[128*2+95:128*2+93];      //3
assign ip_fo = in_pkt_data[128*2+92:128*2+80];         //13
assign ip_ttl = in_pkt_data[128*2+79:128*2+72];        //8
assign ip_prot = in_pkt_data[128*2+71:128*2+64];       //8
assign ip_chsm = in_pkt_data[128*2+63:128*2+48];       //16
assign ip_sip = in_pkt_data[128*2+47:128*2+16];        //32
assign ip_dip_high = in_pkt_data[128*2+15:128*2+0];    //16

//Third flit
assign ip_dip_low = in_pkt_data[128+127:128+112];  //16  
assign udp_sport = in_pkt_data[128+111:128+96];    //16
assign udp_dport = in_pkt_data[128+95:128+80];     //16
assign udp_len = in_pkt_data[128+79:128+64];       //16
assign udp_chsm = in_pkt_data[128+63:128+48];      //16

assign tcp_sport = in_pkt_data[128+111:128+96];    //16
assign tcp_dport = in_pkt_data[128+95:128+80];     //16
assign tcp_seq = in_pkt_data[128+79:128+48];       //32
assign tcp_ack = in_pkt_data[128+47:128+16];       //32
assign tcp_do  = in_pkt_data[128+15:128+12];       //4
assign tcp_rsv = in_pkt_data[128+11:128+9];        //3
assign tcp_ns  = in_pkt_data[128+8];           //1
assign tcp_cwr = in_pkt_data[128+7];           //1
assign tcp_ece = in_pkt_data[128+6];           //1
assign tcp_urg = in_pkt_data[128+5];           //1
assign tcp_fack = in_pkt_data[128+4];          //1
assign tcp_psh = in_pkt_data[128+3];           //1
assign tcp_rst = in_pkt_data[128+2];           //1
assign tcp_syn = in_pkt_data[128+1];           //1
assign tcp_fin = in_pkt_data[128+0];           //1

//Fourth flit
assign tcp_win = in_pkt_data[127:112];     //16
assign tcp_chsm = in_pkt_data[111:96];     //16
assign tcp_urgp = in_pkt_data[95:80];      //16

assign support = (eth_type == PROT_ETH) & (ip_version == IP_V4)
            & (ip_ihl == 5) & ((ip_prot == PROT_TCP) | (ip_prot == PROT_UDP));

assign metadata.len = (ip_prot == PROT_TCP) ? (ip_len - (ip_ihl << 2) - (tcp_do << 2)) : (ip_len - (ip_ihl << 2) - 32'd8);
assign metadata.tuple.sIP = ip_sip;
assign metadata.tuple.dIP = {ip_dip_high,ip_dip_low};
assign metadata.tuple.sPort = tcp_sport;
assign metadata.tuple.dPort = tcp_dport;
assign metadata.prot = support ? ((ip_prot == PROT_TCP) ? S_TCP : S_UDP) : NS;
assign metadata.pktID = in_meta_data.pktID;
assign metadata.flits = in_meta_data.flits;
assign metadata.tcp_flags = {tcp_ns,tcp_cwr,tcp_ece,tcp_urg,tcp_fack,tcp_psh,tcp_rst,tcp_syn,tcp_fin};
assign metadata.pkt_flags = PKT_ETH;

assign in_pkt_ready = out_meta_ready;
assign in_meta_ready = out_meta_ready;

//We don't output pkt anything
//But leave the interface in case used in the future.
assign out_pkt_valid = 0;


always @ (posedge clk)
begin
    if(rst)begin
        out_meta_valid <= 0;
    end else begin
        //currently we only take care of the first 64 B. The options are ignored for now.
        if( out_meta_ready &
            in_pkt_valid & in_pkt_sop & in_pkt_eop 
            & in_meta_valid) begin
            out_meta_valid <= 1;
            out_meta_data <= metadata;
        end else begin
            out_meta_valid <= 0;
        end
    end
end

endmodule
