# Entity: esram_wrapper

- **File**: esram_wrapper.sv
## Diagram

![Diagram](esram_wrapper.svg "Diagram")
## Ports

| Port name      | Direction | Type                | Description |
| -------------- | --------- | ------------------- | ----------- |
| clk_esram_ref  | input     |                     |             |
| esram_pll_lock | output    |                     |             |
| clk_esram      | output    |                     |             |
| clk_esram      | output    |                     |             |
| wren           | input     |                     |             |
| wraddress      | input     | [PKTBUF_AWIDTH-1:0] |             |
| wrdata         | input     | [519:0]             |             |
| rden           | input     |                     |             |
| rdaddress      | input     | [PKTBUF_AWIDTH-1:0] |             |
| rd_valid       | output    |                     |             |
| rddata         | output    | [519:0]             |             |
## Instantiations

- esrm_sim: bram_simple2port
- esram_0: esram
