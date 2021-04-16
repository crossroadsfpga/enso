`ifndef PCIE_CONSTS_SV
`define PCIE_CONSTS_SV

`include "../constants.sv"

// TODO(sadok): Parameterize data width and address width
interface bram_interface_io;
   logic [BRAM_TABLE_IDX_WIDTH-1:0] addr;
   logic [31:0] wr_data;
   logic [31:0] rd_data;
   logic rd_en;
   logic wr_en;

	// the module that *owns* the BRAM
	modport owner (
		input  addr, wr_data, rd_en, wr_en,
		output rd_data
	);

	// the module that *uses* the BRAM
	modport user (
		input rd_data,
      output addr, wr_data, rd_en, wr_en
	);
endinterface

typedef struct packed
{
    logic [APP_IDX_WIDTH-1:0]      dsc_queue_id;
    logic [FLOW_IDX_WIDTH-1:0]     pkt_queue_id;
    logic [$clog2(MAX_PKT_SIZE):0] size; // in number of flits
    queue_state_t                  pkt_q_state;
} pkt_dsc_with_pkt_q_t;

`endif // PCIE_CONSTS_SV
