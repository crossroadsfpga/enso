# Entity: hash_func

- **File**: hash_func.sv
## Diagram

![Diagram](hash_func.svg "Diagram")
## Ports

| Port name      | Direction | Type    | Description |
| -------------- | --------- | ------- | ----------- |
| clk            | input     |         |             |
| rst            | input     |         |             |
| stall          | input     |         |             |
| initval        | input     | [31:0]  |             |
| tuple_in       | input     | tuple_t |             |
| tuple_in_valid | input     |         |             |
| hashed_valid   | output    |         |             |
| hashed         | output    | [31:0]  |             |
