`include "pcie_consts.sv"

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
