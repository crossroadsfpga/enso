`ifndef MY_STRUCT_S
`define MY_STRUCT_S
`define SIM //Should comment this during synthesis
`define NO_PCIE //Should comment this during synthesis

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
parameter PKT_ETH=0;//send to ETH
parameter PKT_DROP=1; //DROP pkt
parameter PKT_PCIE=2; //send to PCIE

//my_stats
parameter STAT_AWIDTH = 5;
parameter BASE_REG = 5'b10_000; //(5'b10000);
parameter TOP_REG = 5'b10_001;
parameter LATENCY_HIST = 5'b10_100; // (5'b10100);
parameter PCIE = 5'b10_101;
parameter TX_TRACK = 5'b11_000; //(5'b11000);

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

//1 + 96 + 64 = 195
parameter FT_DWIDTH = (1+TUPLE_DWIDTH+64);
typedef struct packed
{
    logic valid;
    tuple_t tuple;
    logic [63:0] pcie_address;
} fce_t; //Flow context entry

parameter META_WIDTH=256; //Change this will affect hyper_reg_fd
parameter INT_META_WIDTH=(8+TUPLE_DWIDTH+16+PKT_AWIDTH+5+9+3+64);
parameter PADDING_WIDTH = (META_WIDTH - INT_META_WIDTH);
typedef struct packed
{
    logic [7:0] prot;
    tuple_t tuple;
    logic [15:0] len;//payload length
    logic [PKT_AWIDTH-1:0] pktID;
    logic [4:0] flits; //total number of flits
    logic [8:0] tcp_flags;
    logic [2:0] pkt_flags;
    logic [63:0] pcie_address;
    logic [PADDING_WIDTH-1:0] padding;
} metadata_t; //Metadata

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
    logic [191:0] padding;
    logic [63:0] pcie_address;
    logic [31:0] action;
    logic [31:0] pdu_flit;
    logic [31:0] pdu_size;
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

parameter PDU_META_WIDTH=(TUPLE_DWIDTH+64);
typedef struct packed
{
    tuple_t tuple;
    logic [63:0] pcie_address;
} pdu_metadata_t; //Metadata

`endif
