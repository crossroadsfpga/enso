# Entity: flow_director

- **File**: flow_director.sv
## Diagram

![Diagram](flow_director.svg "Diagram")
## Ports

| Port name          | Direction | Type   | Description                                                                                                                   |
| ------------------ | --------- | ------ | ----------------------------------------------------------------------------------------------------------------------------- |
| clk                | input     |        |                                                                                                                               |
| rst                | input     |        |                                                                                                                               |
| in_meta_data       | input     |        |                                                                                                                               |
| in_meta_valid      | input     |        |                                                                                                                               |
| in_meta_ready      | output    |        |                                                                                                                               |
| out_meta_data      | output    |        |                                                                                                                               |
| out_meta_valid     | output    |        |                                                                                                                               |
| out_meta_ready     | input     |        |                                                                                                                               |
| nb_fallback_queues | input     | [31:0] | Configure number of fallback queues. We send packets to fallback queues whenever they don't match an entry in the flow table. |
| enable_rr          | input     |        | Enable packet round robin for fallback queues. When disabled, use a hash of the five-tuple instead.                           |
