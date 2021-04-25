`ifndef PCIE_CONSTS_SV
`define PCIE_CONSTS_SV

`include "../constants.sv"

function logic [RB_AWIDTH-1:0] get_new_pointer(
    logic [RB_AWIDTH-1:0] pointer,
    logic [RB_AWIDTH-1:0] upd_sz,
    logic [30:0] buf_sz
);
    if (pointer + upd_sz >= buf_sz) begin
        return pointer + upd_sz - buf_sz;
    end else begin
        return pointer + upd_sz;
    end
endfunction

interface bram_interface_io #(
    parameter ADDR_WIDTH=BRAM_TABLE_IDX_WIDTH,
    parameter DATA_WIDTH=32
);
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] wr_data;
    logic [DATA_WIDTH-1:0] rd_data;
    logic rd_en;
    logic wr_en;

    // the module that *owns* the BRAM
    modport owner (
        input  addr, wr_data, rd_en, wr_en,
        output rd_data
    );

    // the module that *uses* the BRAM
    modport user (
        input  rd_data,
        output addr, wr_data, rd_en, wr_en
    );
endinterface

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
    queue_state_t                  dsc_q_state;
    queue_state_t                  pkt_q_state;
} pkt_meta_with_queues_t;

`endif // PCIE_CONSTS_SV
