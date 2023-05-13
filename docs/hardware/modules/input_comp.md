# Entity: input_comp

- **File**: input_comp.sv
## Diagram

![Diagram](input_comp.svg "Diagram")
## Ports

| Port name            | Direction | Type                | Description |
| -------------------- | --------- | ------------------- | ----------- |
| clk                  | input     |                     |             |
| rst                  | input     |                     |             |
| eth_sop              | input     |                     |             |
| eth_eop              | input     |                     |             |
| eth_data             | input     | [511:0]             |             |
| eth_empty            | input     | [5:0]               |             |
| eth_valid            | input     |                     |             |
| pkt_buffer_address   | output    | [PKTBUF_AWIDTH-1:0] |             |
| pkt_buffer_write     | output    |                     |             |
| pkt_buffer_writedata | output    | flit_t              |             |
| emptylist_out_data   | input     | [PKT_AWIDTH-1:0]    |             |
| emptylist_out_valid  | input     |                     |             |
| emptylist_out_ready  | output    |                     |             |
| pkt_sop              | output    |                     |             |
| pkt_eop              | output    |                     |             |
| pkt_valid            | output    |                     |             |
| pkt_data             | output    | [511:0]             |             |
| pkt_empty            | output    | [5:0]               |             |
| pkt_ready            | input     |                     |             |
| meta_valid           | output    |                     |             |
| meta_data            | output    | metadata_t          |             |
| meta_ready           | input     |                     |             |
