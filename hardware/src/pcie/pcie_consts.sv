`ifndef PCIE_CONSTS_SV
`define PCIE_CONSTS_SV

`include "../constants.sv"

localparam PCIE_WRDM_BASE_ADDR = 32'h4000_0000;
localparam PCIE_RDDM_BASE_ADDR = 32'h4000_0000;

typedef struct packed
{
    logic [31:0] tail;
    logic [31:0] head;
    logic [63:0] kmem_addr;
} queue_state_t;

typedef struct packed
{
    logic [APP_IDX_WIDTH-1:0]      dsc_queue_id;
    logic [FLOW_IDX_WIDTH-1:0]     pkt_queue_id;
    logic [$clog2(MAX_PKT_SIZE):0] size; // in number of flits
    logic                          needs_dsc;
    logic                          drop;
    queue_state_t                  dsc_q_state;
    queue_state_t                  pkt_q_state;
} pkt_meta_with_queues_t;

typedef struct packed
{
    logic [319:0] pad;
    logic [63:0]  tail;
    logic [63:0]  queue_id;
    logic [63:0]  signal; // Should always be 0x1.
} pcie_rx_dsc_t;

typedef struct packed
{
    logic [363:0] pad;
    logic [19:0]  length; // In bytes (up to 1MB).
    logic [63:0]  addr; // Physical address of the data.
    logic [63:0]  signal; // 0x1 if set from software, 0x0 if set from hardware.
} pcie_tx_dsc_t;

typedef struct packed
{
    logic [19:0] length; // In bytes (up to 1MB).
    logic [63:0] transfer_addr; // Physical address of the data.
    logic [63:0] descriptor_addr; // Physical address of the descriptor.
} tx_transfer_t;

typedef struct packed
{
    logic [13:0] pad;
    logic [7:0]  descriptor_id;
    logic [2:0]  app_spec;
    logic        single_dst;  // When unset, dst address is incremented at every
                              // transfer.
    logic [1:0]  reserved;
    logic [17:0] nb_dwords;  // Up to 1MB.
    logic [63:0] dst_addr;  // Avalon address.
    logic [63:0] src_addr;  // PCIe address.
} rddm_desc_t;

`endif // PCIE_CONSTS_SV
