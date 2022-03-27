
`include "./constants.sv"
`timescale 1 ps / 1 ps

module input_comp (
    input  logic         clk,
    input  logic         rst,

    input  logic         eth_sop,
    input  logic         eth_eop,
    input  logic [511:0] eth_data,
    input  logic [5:0]   eth_empty,
    input  logic         eth_valid,

    output logic [PKTBUF_AWIDTH-1:0] pkt_buffer_address,
    output logic                     pkt_buffer_write,
    output flit_t                    pkt_buffer_writedata,

    input  logic [PKT_AWIDTH-1:0] emptylist_out_data,
    input  logic                  emptylist_out_valid,
    output logic                  emptylist_out_ready,

    output logic         pkt_sop,
    output logic         pkt_eop,
    output logic         pkt_valid,
    output logic [511:0] pkt_data,
    output logic [5:0]   pkt_empty,
    input  logic         pkt_ready,

    output logic         meta_valid,
    output metadata_t    meta_data,
    input  logic         meta_ready

);

// Every pkt struct is 2 KB, which is 32 entries.
logic [PKTBUF_AWIDTH-1:0]   pkt_buffer_address_r;
logic         pkt_buffer_write_r;
flit_t        pkt_buffer_writedata_r;

logic [PKT_AWIDTH-1:0] pkt_id;
metadata_t empty_meta;
logic [4:0] flits;
logic [511:0] eth_data_r;

assign pkt_empty = 0;
assign empty_meta = 0;

always @(posedge clk) begin
    if (rst) begin
        pkt_buffer_write <= 0;
    end else begin
        pkt_buffer_address <= pkt_buffer_address_r;
        pkt_buffer_write <= pkt_buffer_write_r;
        pkt_buffer_writedata <= pkt_buffer_writedata_r;
    end
end

assign emptylist_out_ready = eth_valid & eth_sop;

logic drop_pkt;

always@ (posedge clk) begin
    pkt_buffer_write_r <= 1'b0;
    pkt_buffer_writedata_r <= {eth_sop, eth_eop, eth_empty, eth_data};

    pkt_valid <= 0;
    meta_valid <= 0;

    meta_data <= empty_meta;
    meta_valid <= 0;

    pkt_sop <= 0;
    pkt_eop <= 0;

    if (rst) begin
        drop_pkt <= 0;
        flits <= 0;
    end else begin
        if (eth_valid) begin
            automatic logic [PKT_AWIDTH-1:0] current_pkt_id = pkt_id;
            automatic logic drop_current_flit = drop_pkt;
            automatic logic [4:0] current_nb_flits = flits;

            if (!eth_sop) begin  // Receiving the rest of the packet.
                pkt_buffer_address_r <= pkt_buffer_address_r + 1'b1;
                pkt_buffer_write_r <= !drop_current_flit;

                current_nb_flits = current_nb_flits + 1'b1;
            end else if (emptylist_out_valid) begin
                // We can only grab the next packet if there is a packet buffer
                // available.
                pkt_buffer_address_r <= (emptylist_out_data << 5);
                pkt_buffer_write_r <= 1'b1;

                current_pkt_id = emptylist_out_data;
                drop_current_flit = 0;
                current_nb_flits = 1;
            end else begin
                drop_current_flit = 1;
                $error("Ran out of buffer space, dropping packet.");
            end

            if (eth_eop & !drop_current_flit) begin
                // Pass the header to parser.
                pkt_sop <= 1;
                pkt_eop <= 1;
                pkt_valid <= 1;

                // Pass the metadata to parser.
                meta_data.pktID <= current_pkt_id;
                meta_data.flits <= current_nb_flits;
                meta_valid <= 1;
            end

            pkt_id <= current_pkt_id;
            drop_pkt <= drop_current_flit;
            flits <= current_nb_flits;
        end
    end
end

always @(posedge clk) begin
    if (eth_valid & eth_sop) begin
        pkt_data <= eth_data;
    end

    eth_data_r <= eth_data;
end

endmodule
