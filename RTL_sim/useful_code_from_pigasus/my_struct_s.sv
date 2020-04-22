`define SIM

//packet buffer
//STORE 1024 pkts, each pkts takes 32 * 512 bits = 2 KB.
//32 * 1024 = 32768 entries.
parameter PKT_NUM = 2688;

//15 = 10(2^10=1024) + 5 (32=2^5)
parameter PKTBUF_AWIDTH = ($clog2(PKT_NUM)+5);
parameter PKTBUF_DEPTH = (32 * PKT_NUM);

//PKT_ID width, which is the index to the 32-entries block
parameter PKT_AWIDTH = ($clog2(PKT_NUM));

//Flow table
parameter FT_SUBTABLE = 4;
parameter FT_SIZE = 8192;
parameter FT_DEPTH = (FT_SIZE/FT_SUBTABLE);
parameter FT_AWIDTH= ($clog2(FT_DEPTH));
parameter PQ_DEPTH = 8;
parameter PQ_AWIDTH = ($clog2(PQ_DEPTH));

//Linked list
//Assume at most half of packets are
parameter LL_DEPTH=(PKT_NUM/2);
parameter LL_AWIDTH=($clog2(LL_DEPTH));
parameter HEADER_OFFSET=1;


//packet parameter
parameter ETH_HDR_LEN=14;

//packet type
parameter PROT_ETH=16'h0800;
parameter IP_V4 = 4'h4;
parameter PROT_TCP=8'h06;
parameter PROT_UDP=8'h11;

parameter NS=8'hFF;//reserved
parameter S_UDP=PROT_UDP;
parameter S_TCP=PROT_TCP;

//TCP flags
parameter TCP_FIN=0;
parameter TCP_SYN=1;
parameter TCP_RST=2;
parameter TCP_PSH=3;
parameter TCP_FACK=4;
parameter TCP_URG=5;
parameter TCP_ECE=6;
parameter TCP_CWR=7;
parameter TCP_NS=8;

//PKT flags
parameter PKT_FORWARD=0;//do not send to string matcher
parameter PKT_DROP=1; //do not send out
parameter PKT_CHECK=2; //send to string matcher and remove the pktID for now
parameter PKT_OOO=3; //remove the pktID but do not send out
parameter PKT_FORWARD_OOO=4; //send out but do not remove the pktID
parameter PKT_DONE=5; //after check in string matcher.

//my_stats
parameter STAT_AWIDTH = 5;
parameter BASE_REG = 5'b10_000; //(5'b10000);
parameter TOP_REG = 5'b10_001;
parameter FT_REG = 5'b10_010;//(5'b10010);
parameter RULEID = 5'b10_011;
parameter LATENCY_HIST = 5'b10_100; // (5'b10100);
parameter PCIE = 5'b10_101;
parameter DRAM = 5'b10_110;
parameter TEST2 = 5'b10_111;
parameter TX_TRACK = 5'b11_000; //(5'b11000);
parameter FT_TABLE = 5'b11_100; //(5'b11100);

//pdu_flags
parameter PDU_NO = 2'b00;
parameter PDU_FIRST = 2'b01;
parameter PDU_MIDDLE = 2'b10;
parameter PDU_LAST = 2'b11;

typedef struct packed
{
    logic sop;
    logic eop;
    logic [5:0] empty;
    logic [511:0] data;
} flit_t;

typedef struct packed
{
    logic sop;
    logic eop;
    logic [511:0] data;
} flit_lite_t;

typedef struct packed
{
    logic sop;
    logic eop;
    logic [5:0] empty;
} flit_meta_t;


//This is the linked-list entry
//1 +32+16+16+10+1+56 = 133
parameter LL_DWIDTH = (1+32+16+16+PKT_AWIDTH+1+56);
typedef struct packed
{
    logic valid; //Valid
    logic [31:0] seq; //Sequence
    logic [15:0] len; //length
    logic [LL_AWIDTH-1:0] next; //next
    logic [PKT_AWIDTH-1:0] pktID; //pktID
    logic [4:0] flits;
    logic last; //last
    logic [55:0] last_7_bytes; //last
} entry_t;

//96 bits
parameter TUPLE_DWIDTH = (32+32+16+16);
typedef struct packed
{
    logic [31:0] sIP; 
    logic [31:0] dIP; 
    logic [15:0] sPort; 
    logic [15:0] dPort; 
} tuple_t;


typedef struct packed
{
    logic [255:0] padding;

    logic [31:0] c2f_kmem_high; // higher 32 bit of kernel memory, FPGA read only
    logic [31:0] c2f_kmem_low; // lower 32 bit of kernel memory, FPGA read only
    logic [31:0] c2f_head; //head pointer, FPGA read only
    logic [31:0] c2f_tail; //tail pointer, CPU read only

    logic [31:0] f2c_kmem_high; // higher 32 bit of kernel memory, FPGA read only
    logic [31:0] f2c_kmem_low; // lower 32 bit of kernel memory, FPGA read only
    logic [31:0] f2c_head; //head pointer, FPGA read only
    logic [31:0] f2c_tail; //tail pointer, CPU read only
} pcie_block_t;

//1 + 96 + 32 + 9 + 1 + 56 = 195
parameter FT_DWIDTH = (1+TUPLE_DWIDTH+32+LL_AWIDTH+1+56);
typedef struct packed
{
    logic valid;
    tuple_t tuple;
    logic [31:0] seq;
    logic [LL_AWIDTH-1:0] pointer;
    logic ll_valid;
    logic [55:0] last_7_bytes;
} fce_t; //Flow context entry

//8 + 96 + 32+ 16+12+6+5+9+9+3+2 + 56 = 254
parameter META_WIDTH=(8+TUPLE_DWIDTH+32+16+PKT_AWIDTH+6+5+9+9+3+2+56);
typedef struct packed
{
    logic [7:0] prot;
    tuple_t tuple;
    logic [31:0] seq;
    logic [15:0] len;//payload length
    logic [PKT_AWIDTH-1:0] pktID;
    logic [5:0] empty;
    logic [4:0] flits; //total number of flits
    logic [8:0] hdr_len; //in bytes
    logic [8:0] tcp_flags;
    logic [2:0] pkt_flags;
    logic [1:0] pdu_flag;
    logic [55:0] last_7_bytes;
} metadata_t; //Metadata


parameter RID_WIDTH = 16;

parameter RULE_S_WIDTH = (RID_WIDTH + 1);

typedef struct packed
{
    logic  last;
    logic [RID_WIDTH-1:0] data;
} rule_s_t; //Metadata


//PDU_DEPTH is number of 512 bits for fpga side f2c ring buffer 
parameter PDU_DEPTH = 4096;
parameter PDU_AWIDTH = ($clog2(PDU_DEPTH));
//PDU_ID_DEPTH is number of PDUs we buffer on FPGA side
parameter PDU_NUM = 256;
parameter PDUBUF_AWIDTH = ($clog2(PDU_NUM)+5);
parameter PDUBUF_DEPTH = (32 * PDU_NUM);
parameter PDUID_WIDTH = ($clog2(PDU_NUM));
typedef struct packed
{
    logic [223:0] padding;
    logic [31:0] action;
    logic [31:0] pdu_flit;
    logic [31:0] pdu_size; 
    logic [31:0] num_ruleID; 
    logic [31:0] prot; 
    tuple_t tuple; 
    logic [31:0] pdu_id; 
} pdu_hdr_t;

//Ring buffer 
//Used for FPGA-CPU communication. Some fields are FPGA read only, used for
//CPU indicatings FPGA info. Some fields are CPU read only, used for FPGA
//indicating CPU info. 
//The higher half is used for CPU ring buffer registers
//The bottom half is used as PDU header for each PDU transfer.
parameter RB_DEPTH = 8191; //in 512 bits. 
parameter RB_AWIDTH = ($clog2(RB_DEPTH));

parameter C2F_RB_DEPTH = 512; //in 512 bits.
parameter C2F_RB_AWIDTH = ($clog2(C2F_RB_DEPTH));


//Actions
parameter ACTION_NOCHECK = 0;
parameter ACTION_NOMATCH = 1;
parameter ACTION_MATCH   = 2;
parameter ACTION_CHECK   = 3;

parameter ACTION_WIDTH = 4;
//parameter ACTION_S_WIDTH = (ACTION_WIDTH+PDUID_WIDTH);
//typedef struct packed
//{
//    logic [ACTION_WIDTH-1:0]     action;
//    logic [PDUID_AWIDTH-1:0]      pdu_id;
//} action_t;


parameter PDU_META_WIDTH=(PDUID_WIDTH+ACTION_WIDTH+5+11);
typedef struct packed
{
    logic [PDUID_WIDTH-1:0] pdu_id;
    logic [ACTION_WIDTH-1:0]     action;
    logic [4:0] flits; //total number of flits
    logic [10:0] pdu_size;
} pdu_metadata_t; //Metadata


//DRAM
parameter DDR_WR_WIDTH=(27+512);
typedef struct packed
{
    logic [26:0] addr;
    logic [511:0]   data;
} ddr_wr_t;

parameter DDR_RD_WIDTH=(27);
typedef struct packed
{
    logic [26:0] addr;
} ddr_rd_t;

parameter DDR_REQ_WIDTH=(27+512+1);
typedef struct packed
{
    logic        wr; //0 means 0.
    logic [26:0] addr;
    logic [511:0]   data;
} ddr_req_t;

