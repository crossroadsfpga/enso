// (C) 2001-2019 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.



`timescale 1 ps / 1 ps
// baeckler - 02-07-2010
// combine variable latency Avalon MM read ports
// issue a timeout read if none of the clients respond

module alt_aeuex_avalon_mm_read_combine #(
	parameter DAT_WIDTH = 32,
	parameter TIMEOUT = 7, // 2^N ticks // bumped up from 4 to 7 due to slow serif response
	parameter NUM_CLIENTS = 2
)(
	input clk,
	input arst,

	input host_read,
	output reg [DAT_WIDTH-1:0] host_readdata,
	output reg host_readdata_valid,
	output host_waitrequest,
	
	input [NUM_CLIENTS-1:0] client_readdata_valid,
	input [NUM_CLIENTS*DAT_WIDTH-1:0] client_readdata		
);

/////////////////////////
// input registers
/////////////////////////

reg [NUM_CLIENTS-1:0] client_readdata_valid_r;
reg [NUM_CLIENTS*DAT_WIDTH-1:0] client_readdata_r;
always @(posedge clk) begin
	client_readdata_valid_r <= client_readdata_valid;
	client_readdata_r <= client_readdata;
end

/////////////////////////
// read mux
/////////////////////////

reg timeout_read = 1'b0;
initial host_readdata_valid = 1'b0;
always @(posedge clk) begin
	host_readdata_valid <= (|client_readdata_valid_r) | timeout_read;
end

// value to read if nobody answers
wire [DAT_WIDTH-1:0] tconst = 32'h12345678;

wire [DAT_WIDTH-1:0] rmux;
genvar i, j;
generate
	for (j=0; j<DAT_WIDTH; j=j+1) begin : rmx
		wire [NUM_CLIENTS-1:0] mbits;
		for (i=0; i<NUM_CLIENTS; i=i+1) begin : rs
			assign mbits[i] = client_readdata_valid_r[i] &
				client_readdata_r[i*DAT_WIDTH+j];
		end	
		assign rmux[j] = (|mbits) | (timeout_read & tconst[j]);
	end	
endgenerate

always @(posedge clk) begin
	host_readdata <= rmux;
end

/////////////////////////
// decide when to timeout
/////////////////////////

reg [TIMEOUT:0] timer = 0;
reg read_pending = 1'b0;
assign host_waitrequest = read_pending;

//always @(posedge clk) begin
always @(posedge clk or posedge arst) begin
   if (arst) begin
        timeout_read <= 1'b0;
        timer <= 0;
        read_pending <= 1'b0;
    end
    else begin
	timeout_read <= 1'b0;
	if (host_read & !read_pending) begin
		timer <= 0;
		read_pending <= 1'b1;				
	end
	else begin
		if (read_pending) begin
			if (timeout_read) begin
				timer <= 0;
				read_pending <= 1'b0;
			end
			else if (|client_readdata_valid_r) begin
				// one of the clients is answering
				timer <= 0;
				read_pending <= 1'b0;
			end
			else if (timer[TIMEOUT]) begin
				// call a timeout
				timeout_read <= 1'b1;
			end
			else begin
				// wait
				timer <= timer + 1'b1;
			end
		end
		else begin
			// nothing pending
			timeout_read <= 1'b0;
			timer <= 0;
		end
	end
   end
end

endmodule
