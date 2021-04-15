`ifndef PCIE_CONSTS_SV
`define PCIE_CONSTS_SV

`include "../constants.sv"

typedef struct
{
   logic [BRAM_TABLE_IDX_WIDTH-1:0] addr;
   logic [31:0] wr_data;
   logic [31:0] rd_data;
   logic rd_en;
   logic rd_en_r;
   logic rd_en_r2;
   logic wr_en;
} bram_interface_t;

typedef struct
{
   bram_interface_t tails;
   bram_interface_t heads;
   bram_interface_t l_addrs;
   bram_interface_t h_addrs;
} queue_interface_t;

`endif // PCIE_CONSTS_SV
