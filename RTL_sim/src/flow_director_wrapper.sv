`include "./my_struct_s.sv"
module flow_director_wrapper(
    clk,rst,
    in_meta_data,
    in_meta_valid,
    reg_in_meta_almost_full,
    reg_out_meta_data,
    reg_out_meta_valid,
    out_meta_almost_full
);
input clk;
input rst;
input metadata_t in_meta_data;
input in_meta_valid;
output logic reg_in_meta_almost_full;
output metadata_t reg_out_meta_data;
output logic reg_out_meta_valid;
input  out_meta_almost_full;

metadata_t reg_in_meta_data;
logic reg_in_meta_valid;
logic in_meta_almost_full;
metadata_t out_meta_data;
logic out_meta_valid;
logic reg_out_meta_almost_full;

logic [31:0] fd_in_csr_readdata;
logic [31:0] fd_out_csr_readdata;

metadata_t fd_in_meta_data;
logic      fd_in_meta_valid;
logic      fd_in_meta_almost_full;
metadata_t fd_out_meta_data;
logic      fd_out_meta_valid;
logic      fd_out_meta_almost_full;
metadata_t int_meta_data;
logic      int_meta_valid;
logic      int_meta_almost_full;


assign int_meta_ready = !reg_out_meta_almost_full;
assign out_meta_valid = int_meta_valid & int_meta_ready;
assign out_meta_data  = int_meta_data;


hyper_pipe_fd fd_reg_io(
    .clk                     (clk),  
    .rst                     (rst),    
    .in_meta_data            (in_meta_data),                    
    .in_meta_valid           (in_meta_valid), 
    .in_meta_almost_full     (in_meta_almost_full),
    .out_meta_data           (out_meta_data),                    
    .out_meta_valid          (out_meta_valid), 
    .out_meta_almost_full    (out_meta_almost_full),
    .reg_in_meta_data        (reg_in_meta_data),       
    .reg_in_meta_valid       (reg_in_meta_valid),      
    .reg_in_meta_almost_full (reg_in_meta_almost_full),
    .reg_out_meta_data       (reg_out_meta_data),      
    .reg_out_meta_valid      (reg_out_meta_valid),     
    .reg_out_meta_almost_full(reg_out_meta_almost_full)
);


//Input fifo
fifo_wrapper_infill_mlab  #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL(META_WIDTH),
    .FIFO_DEPTH(32),
    .USE_PACKETS(0)
)
fd_in_fifo (
	.clk               (clk),    
	.reset             (rst),      
    .csr_address       (0),
    .csr_read          (1'b1),
    .csr_write         (1'b0),
    .csr_readdata      (fd_in_csr_readdata),
    .csr_writedata     (32'b0),
	.in_data           (reg_in_meta_data),           
	.in_valid          (reg_in_meta_valid),          
	.in_ready          (),           
	.out_data          (fd_in_meta_data),          
	.out_valid         (fd_in_meta_valid),         
	.out_ready         (fd_in_meta_ready)         
);

dc_back_pressure #(
    .FULL_LEVEL(24)
)
bp_fd_in_fifo (
    .clk            (clk),
    .rst            (rst),
    .csr_address    (),
    .csr_read       (),
    .csr_write      (),
    .csr_readdata   (fd_in_csr_readdata),
    .csr_writedata  (),
    .almost_full    (in_meta_almost_full)
);

//real flow director
flow_director flow_director_inst (
	.clk               (clk),                        
	.rst               (rst),              
	.in_meta_data      (fd_in_meta_data),                
	.in_meta_valid     (fd_in_meta_valid),               
	.in_meta_ready     (fd_in_meta_ready),               
	.out_meta_data     (fd_out_meta_data),          
	.out_meta_valid    (fd_out_meta_valid),         
	.out_meta_ready    (fd_out_meta_ready)        
);

//output fifo
fifo_wrapper_infill_mlab  #(
    .SYMBOLS_PER_BEAT(1),
    .BITS_PER_SYMBOL(META_WIDTH),
    .FIFO_DEPTH(32),
    .USE_PACKETS(0)
)
fd_out_fifo (
	.clk               (clk),    
	.reset             (rst),      
    .csr_address       (0),
    .csr_read          (1'b1),
    .csr_write         (1'b0),
    .csr_readdata      (fd_out_csr_readdata),
    .csr_writedata     (32'b0),
	.in_data           (fd_out_meta_data),           
	.in_valid          (fd_out_meta_valid),          
	.in_ready          (fd_out_meta_ready),           
	.out_data          (int_meta_data),          
	.out_valid         (int_meta_valid),         
	.out_ready         (int_meta_ready)         
);

endmodule
