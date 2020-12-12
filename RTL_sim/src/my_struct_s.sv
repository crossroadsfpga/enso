`ifndef MY_STRUCT_S
`define MY_STRUCT_S
// `define SIM //Should comment this during synthesis
// `define NO_PCIE //Should comment this during synthesis
`define USE_BRAM //Replace the esram with BRAM.

//packet buffer
//STORE 1024 pkts, each pkts takes 32 * 512 bits = 2 KB.
//32 * 1024 = 32768 entries.
`ifdef USE_BRAM
localparam PKT_NUM = 1024;
`else
localparam PKT_NUM = 2688;
`endif

//15 = 10(2^10=1024) + 5 (32=2^5)
localparam PKTBUF_AWIDTH = ($clog2(PKT_NUM)+5);
localparam PKTBUF_DEPTH = (32 * PKT_NUM);

//PKT_ID width, which is the index to the 32-entries block
localparam PKT_AWIDTH = ($clog2(PKT_NUM));

//Flow table
localparam FT_SUBTABLE = 4;
localparam FT_SIZE = 8192;
localparam FT_DEPTH = (FT_SIZE/FT_SUBTABLE);
localparam FT_AWIDTH= ($clog2(FT_DEPTH));

//packet localparam
localparam ETH_HDR_LEN=14;

//packet type
localparam PROT_ETH=16'h0800;
localparam IP_V4 = 4'h4;
localparam PROT_TCP=8'h06;
localparam PROT_UDP=8'h11;

localparam NS=8'hFF;//reserved
localparam S_UDP=PROT_UDP;
localparam S_TCP=PROT_TCP;

//TCP flags
localparam TCP_FIN=0;
localparam TCP_SYN=1;
localparam TCP_RST=2;
localparam TCP_PSH=3;
localparam TCP_FACK=4;
localparam TCP_URG=5;
localparam TCP_ECE=6;
localparam TCP_CWR=7;
localparam TCP_NS=8;

//PKT flags
localparam PKT_ETH=0;//send to ETH
localparam PKT_DROP=1; //DROP pkt
localparam PKT_PCIE=2; //send to PCIE

//my_stats
localparam STAT_AWIDTH = 5;
localparam BASE_REG = 5'b10_000; //(5'b10000);
localparam TOP_REG = 5'b10_001;
localparam LATENCY_HIST = 5'b10_100; // (5'b10100);
localparam PCIE = 5'b10_101;
localparam TX_TRACK = 5'b11_000; //(5'b11000);

//Ring buffer 
//Used for FPGA-CPU communication. Some fields are FPGA read only, used for
//CPU indicatings FPGA info. Some fields are CPU read only, used for FPGA
//indicating CPU info. 
//The higher half is used for CPU ring buffer registers
//The bottom half is used as PDU header for each PDU transfer.
localparam MAX_RB_DEPTH = 1048575; // in 512 bits.
localparam RB_AWIDTH = ($clog2(MAX_RB_DEPTH));

localparam C2F_RB_DEPTH = 512; // in 512 bits.
localparam C2F_RB_AWIDTH = ($clog2(C2F_RB_DEPTH));

localparam MAX_PKT_SIZE = 24; // in 512 bits

localparam MAX_NB_APPS = 4096; // If we change this, must also change software
localparam APP_IDX_WIDTH = ($clog2(MAX_NB_APPS));
localparam FLITS_PER_PAGE = 64;
localparam RB_BRAM_OFFSET = MAX_NB_APPS * FLITS_PER_PAGE; // in number of flits

localparam PCIE_ADDR_WIDTH = 30;

localparam REG_SIZE = 4; // in bytes
localparam REGS_PER_PAGE = 8;
localparam NB_STATUS_REGS = MAX_NB_APPS * REGS_PER_PAGE;
localparam STATS_REGS_WIDTH = ($clog2(NB_STATUS_REGS));
localparam JTAG_ADDR_WIDTH = ($clog2(NB_STATUS_REGS+1)); // includes control reg

// queue table that keeps state for every queue
localparam PKT_Q_TABLE_DEPTH = MAX_NB_APPS;
localparam PKT_Q_TABLE_AWIDTH = ($clog2(PKT_Q_TABLE_DEPTH));
// TODO(sadok) we may save space by only holding an offset to kmem address,
// we also do not need 32 bits for the tail and head 
localparam PKT_Q_TABLE_TAILS_DWIDTH = 32;
localparam PKT_Q_TABLE_HEADS_DWIDTH = 32;
localparam PKT_Q_TABLE_L_ADDRS_DWIDTH = 32;
localparam PKT_Q_TABLE_H_ADDRS_DWIDTH = 32;

// TODO(sadok) For now every descriptor queue has only one associated packet
// queue, this should change. There are also lots of tricks we can use to save
// space, e.g., reduce number of bits for addresses given that they are aligned
// to page size, group some queue addresses together and keep only an offset.
localparam DSC_Q_TABLE_DEPTH = PKT_Q_TABLE_DEPTH;
localparam DSC_Q_TABLE_AWIDTH = ($clog2(DSC_Q_TABLE_DEPTH));
// TODO(sadok) we may save space by only holding an offset to kmem address,
// we also do not need 32 bits for the tail and head 
localparam DSC_Q_TABLE_TAILS_DWIDTH = 32;
localparam DSC_Q_TABLE_HEADS_DWIDTH = 32;
localparam DSC_Q_TABLE_L_ADDRS_DWIDTH = 32;
localparam DSC_Q_TABLE_H_ADDRS_DWIDTH = 32;

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
    logic [APP_IDX_WIDTH-1:0] queue_id;
    logic [16:0] size; // in number of flits TODO(sadok) this is much bigger
                       // than the MTU, consider using the expression below:
    // logic [$clog2(MAX_PKT_SIZE)-1:0] size; // in number of flits
} pkt_desc_t;

typedef struct packed
{
    logic sop;
    logic eop;
    logic [5:0] empty;
} flit_meta_t;

//96 bits
localparam TUPLE_DWIDTH = (32+32+16+16);
typedef struct packed
{
    logic [31:0] sIP; 
    logic [31:0] dIP; 
    logic [15:0] sPort; 
    logic [15:0] dPort; 
} tuple_t;

localparam PDU_META_WIDTH=(TUPLE_DWIDTH+64);

typedef struct packed
{
    logic [13:0] func_nb; // function number
    logic [7:0] desc_id; // descriptor ID (8 bits)
    logic [2:0] app_spec; // application specific
    logic reserved;
    logic single_src; // single source
    logic immediate;
    logic [17:0] nb_dwords; // number of dwords up to 1MB
    logic [63:0] dst_addr; // destination PCIe address
    logic [63:0] saddr_data; // src addr, or data when `immediate` is set
} pcie_desc_t;

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
localparam FT_DWIDTH = (1+TUPLE_DWIDTH+64);
typedef struct packed
{
    logic valid;
    tuple_t tuple;
    logic [63:0] queue_id;
} fce_t; //Flow context entry

localparam META_WIDTH=256; //Change this will affect hyper_reg_fd
localparam INT_META_WIDTH=(8+TUPLE_DWIDTH+16+PKT_AWIDTH+5+9+3+64);
localparam PADDING_WIDTH = (META_WIDTH - INT_META_WIDTH);
typedef struct packed
{
    logic [7:0] prot;
    tuple_t tuple;
    logic [15:0] len;//payload length
    logic [PKT_AWIDTH-1:0] pktID;
    logic [4:0] flits; //total number of flits
    logic [8:0] tcp_flags;
    logic [2:0] pkt_flags;
    logic [63:0] queue_id;
    logic [PADDING_WIDTH-1:0] padding;
} metadata_t; //Metadata

// PDU_DEPTH is the number of 512 bits for fpga side f2c ring buffer
// (must be a power of two)
localparam PDU_DEPTH = 8192;
localparam PDU_AWIDTH = ($clog2(PDU_DEPTH));
localparam PDU_NUM = 256;
localparam PDUBUF_AWIDTH = ($clog2(PDU_NUM)+5);
localparam PDUBUF_DEPTH = (32 * PDU_NUM);
localparam PDUID_WIDTH = ($clog2(PDU_NUM));
typedef struct packed
{
    logic [191:0] padding;
    logic [63:0] queue_id;
    logic [31:0] action;
    logic [31:0] pdu_flit;
    logic [31:0] pdu_size;
    logic [31:0] prot;
    tuple_t tuple;
    logic [31:0] pdu_id;
} pdu_hdr_t;

typedef struct packed
{
    logic [31:0] f2c_tail;
    logic [31:0] f2c_head;
    logic [63:0] f2c_kmem_addr;
} queue_state_t;

typedef struct packed
{
    tuple_t tuple;
    logic [63:0] queue_id;
} pdu_metadata_t; //Metadata

`ifdef SIM
// `define hdisplay(A) if (!tb.error_termination_r) $display("%s", $sformatf A );
`define hdisplay(A);
`define hwarning(A) if (!tb.error_termination_r) $warning("%s", $sformatf A );
`define herror(A) if (!tb.error_termination_r) $error("%s", $sformatf A );

function void hterminate(string s);
    `herror((s));
    force tb.error_termination = 1;
endfunction

`else // not SIM

`define hdisplay(A);
`define hwarning(A);
`define herror(A);

function void hterminate(string s);
endfunction

`endif // SIM

`endif
