`ifndef CONSTANTS_SV
`define CONSTANTS_SV
// `define SIM //Should comment this during synthesis
// `define NO_PCIE //Should comment this during synthesis
`define USE_BRAM //Replace the esram with BRAM.

// Enables debug logic.
`define DEBUG

`include "common/prim_assert.sv"

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
localparam FT_AWIDTH = ($clog2(FT_DEPTH));

//packet localparam
localparam ETH_HDR_LEN=14;

//packet type
localparam PROT_ETH=16'h0800;
localparam IP_V4 = 4'h4;
localparam PROT_TCP=8'h06;
localparam PROT_UDP=8'h11;

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

localparam PCIE_ADDR_WIDTH = 30;

localparam MAX_RB_DEPTH = 1048576; // in 512 bits (power of two).
localparam RB_AWIDTH = ($clog2(MAX_RB_DEPTH));

localparam C2F_RB_DEPTH = 512; // in 512 bits.
localparam C2F_RB_AWIDTH = ($clog2(C2F_RB_DEPTH));

localparam MAX_PKT_SIZE = 24; // in 512 bits

localparam PCIE_TX_PKT_FIFO_DEPTH = 1024;
localparam PCIE_TX_PKT_FIFO_ALM_FULL_THRESH =
    PCIE_TX_PKT_FIFO_DEPTH - 4 * MAX_PKT_SIZE;

// The MAX_NB_APPS determines the max number of notification buffers, while
// MAX_NB_FLOWS determines the max number of enso pipes.
// Both MAX_NB_APPS and MAX_NB_FLOWS must be powers of two.
// These **must be kept in sync** with the variables with the same name on
// `scripts/hwtest/my_stats.tcl`, `software/include/enso/consts.h`, and
// `software/kernel/linux/intel_fpga_pcie_setup.h`
// TODO(sadok): expose these values from JTAG or MMIO so that software and the
// tcl script can adapt to the bitstream that is loaded at a given moment.
localparam MAX_NB_APPS = 1024;
// localparam MAX_NB_FLOWS = 65536;
localparam MAX_NB_FLOWS = 8192;

// Define the number of packet queue managers that we instantiate.
// localparam NB_PKT_QUEUE_MANAGERS = 32;
localparam NB_PKT_QUEUE_MANAGERS = 16;
localparam PKT_QM_ID_WIDTH = $clog2(NB_PKT_QUEUE_MANAGERS);

localparam APP_IDX_WIDTH = ($clog2(MAX_NB_APPS));
localparam FLOW_IDX_WIDTH = ($clog2(MAX_NB_FLOWS));
localparam BRAM_TABLE_IDX_WIDTH = $clog2(MAX_NB_APPS + MAX_NB_FLOWS);

localparam FLITS_PER_PAGE = 64;

// in number of flits
localparam MMIO_OFFSET = (MAX_NB_APPS + MAX_NB_FLOWS) * FLITS_PER_PAGE;

localparam REG_SIZE = 4; // in bytes
localparam REGS_PER_PKT_Q = 4;
localparam REGS_PER_DSC_Q = 8;
localparam NB_CONTROL_REGS = 4;
localparam NB_QUEUE_REGS = MAX_NB_APPS * REGS_PER_DSC_Q
                         + MAX_NB_FLOWS * REGS_PER_PKT_Q;
localparam JTAG_ADDR_WIDTH = ($clog2(NB_QUEUE_REGS + NB_CONTROL_REGS));

// queue table that keeps state for every queue
localparam PKT_Q_TABLE_DEPTH = MAX_NB_FLOWS;
localparam PKT_Q_TABLE_AWIDTH = ($clog2(PKT_Q_TABLE_DEPTH));
// TODO(sadok) we may save space by only holding an offset to kmem address,
// we also do not need 32 bits for the tail and head
localparam PKT_Q_TABLE_TAILS_DWIDTH = 32;
localparam PKT_Q_TABLE_HEADS_DWIDTH = 32;
localparam PKT_Q_TABLE_L_ADDRS_DWIDTH = 32;
localparam PKT_Q_TABLE_H_ADDRS_DWIDTH = 32;

// TODO(sadok) reduce BRAM sizes to the values bellow (double check)
// localparam PKT_Q_TABLE_TAILS_DWIDTH = 8;
// localparam PKT_Q_TABLE_HEADS_DWIDTH = 8;
// localparam PKT_Q_TABLE_L_ADDRS_DWIDTH = 10;
// localparam PKT_Q_TABLE_H_ADDRS_DWIDTH = 10;

// TODO(sadok) There are lots of tricks we can use to save space, e.g., reduce
// number of bits for addresses given that they are aligned to page size, group
// some queue addresses together and keep only an offset.
localparam DSC_Q_TABLE_DEPTH = MAX_NB_APPS;
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
    logic [FLOW_IDX_WIDTH-1:0]     pkt_queue_id;
    logic [$clog2(MAX_PKT_SIZE):0] size; // in number of flits
} pkt_meta_t;

typedef struct packed
{
    logic sop;
    logic eop;
    logic [5:0] empty;
} flit_meta_t;

typedef struct packed
{
    logic [31:0] sIP;
    logic [31:0] dIP;
    logic [15:0] sPort;
    logic [15:0] dPort;
} tuple_t;
localparam TUPLE_DWIDTH = $bits(tuple_t);

typedef struct packed
{
    logic valid;
    tuple_t tuple;
    logic [31:0] pkt_queue_id;
} fce_t;  // Flow context entry used at the flow table.
localparam FT_DWIDTH = $bits(fce_t);

localparam META_WIDTH = 256;  // Change this will affect hyper_reg_fd.
localparam INT_META_WIDTH =
    8 + TUPLE_DWIDTH + 16 + PKT_AWIDTH + 5 + 9 + 3 + 32 + 32;
localparam PADDING_WIDTH = (META_WIDTH - INT_META_WIDTH);
typedef struct packed
{
    logic [7:0]               prot;
    tuple_t                   tuple;
    logic [15:0]              len;  // Payload length.
    logic [PKT_AWIDTH-1:0]    pktID;
    logic [4:0]               flits;  // Total number of flits.
    logic [8:0]               tcp_flags;
    logic [2:0]               pkt_flags;
    logic [31:0]              pkt_queue_id;
    logic [31:0]              hash;
    logic [PADDING_WIDTH-1:0] padding;
} metadata_t;

// F2C_RB_DEPTH is the number of 512 bits for fpga side rx ring buffer
// (must be a power of two)
localparam F2C_RB_DEPTH = 16384;
localparam F2C_RB_AWIDTH = ($clog2(F2C_RB_DEPTH));
localparam PDU_NUM = 256;

typedef enum logic [63:0] {
    FLOW_TABLE_CONFIG_ID = 1,
    TIMESTAMP_CONFIG_ID = 2,
    RATE_LIMIT_CONFIG_ID = 3,
    FALLBACK_QUEUES_CONFIG_ID = 4
} config_id_t;

typedef struct packed {
    logic [383:0] pad;
    logic [63:0]  config_id;
    logic [63:0]  signal;
} config_flit_t;

typedef struct packed {
    logic [223:0] pad;
    logic [31:0]  pkt_queue_id;
    logic [31:0]  prot;
    tuple_t       tuple;  // 96 bits.
    logic [63:0]  config_id;
    logic [63:0]  signal;
} flow_table_config_t;

typedef struct packed {
    logic [319:0] pad1;
    logic [63:0]  offset;
    logic         enable;  // Set to 1 to enable timestamping.
    logic [62:0]  pad2;
    logic [63:0]  config_id;
    logic [63:0]  signal;
} timestamp_config_t;

typedef struct packed {
    logic [319:0] pad1;
    logic         enable;  // Set to 1 to enable rate-limiting.
    logic [30:0]  pad2;
    logic [15:0]  numerator;  // Set rate numerator.
    logic [15:0]  denominator;  // Set rate denominator.
    logic [63:0]  config_id;
    logic [63:0]  signal;
} rate_limit_config_t;

// We send packets to fallback queues whenever they don't match an entry in the
// flow table. We can send these packets either using a hash of the five-tuple
// or round robin, depending on the value of `enable_rr`.
// If `nb_fallback_queues` is set to 0, packets that don't match an entry in the
// flow table will be dropped.
typedef struct packed {
    logic [255:0] pad1;
    logic         enable_rr;  // Set to 1 to enable round-robin among FB queues.
    logic [62:0]  pad2;
    logic [31:0]  fallback_queue_mask;
    logic [31:0]  nb_fallback_queues;
    logic [63:0]  config_id;
    logic [63:0]  signal;
} fallback_queues_config_t;

function logic [511:0] swap_flit_endianness(logic [511:0] flit);
    automatic integer i = 0;
    automatic logic [511:0] swapped_flit;
    for (i = 0; i < 512/8; i = i + 1) begin
        swapped_flit[512-(i+1)*8 +: 8] = flit[i*8 +: 8];
    end
    return swapped_flit;
endfunction

// Make sure a packet stream is behaving correctly, i.e., that sop cannot be
// asserted twice before eop is asserted.
`define ASSERT_CORRECT_PKT_STREAM(__name, __sop, __eop, __valid, __ready, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST) \
    `ASSERT(__name,                                                            \
        ((__sop) && (__valid) && (__ready) && !(__eop)) |=>                                \
            if ((__valid) && (__ready))                                        \
                !(__sop) throughout ((__eop) && (__valid) && (__ready))[->1],  \
    __clk, __rst)

`ifdef SIM
`define hdisplay(A) if (!tb.error_termination_r) $display("%s", $sformatf A )
// `define hdisplay(A);
`define hwarning(A) if (!tb.error_termination_r) $warning("%s", $sformatf A )
`define herror(A) if (!tb.error_termination_r) $error("%s", $sformatf A )

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

`endif // CONSTANTS_SV
