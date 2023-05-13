# Entity: bram_mux

- **File**: bram_mux.sv
## Diagram

![Diagram](bram_mux.svg "Diagram")
## Description

 Use to join multiple BRAM blocks into one (adds 1 cycle delay for write and
 2 cycles for read)

## Generics

| Generic name | Type | Value     | Description |
| ------------ | ---- | --------- | ----------- |
| NB_BRAMS     |      | undefined |             |
## Ports

| Port name | Direction | Type | Description |
| --------- | --------- | ---- | ----------- |
| clk       | input     |      |             |
| in        | input     |      |             |
| out       | input     |      |             |
