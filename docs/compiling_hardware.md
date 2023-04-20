# Compiling Hardware

Here we describe how to compile the hardware to produce a bitstream. This bitstream implements the Ensō NIC and can be loaded into the FPGA.

The following steps assume that you have already [installed Quartus](getting_started.md#quartus).

!!! warning

    Synthesizing the hardware can take hours. If you do not need to make hardware changes, you should skip this part and automatically download the appropriate bitstream by running:
    ```bash
    cd <root of enso repository>
    ./scripts/update_bitstream.sh --download
    ```

## Generate IP cores

Before synthesizing the bitstream for the first time, you need to generate the IP cores that are used by the hardware. To do so, run the following commands:

```bash
cd <root of enso repository>
./scripts/generate_ips.sh
```

## Synthesize the hardware

After generating the IP cores, you can now synthesize the hardware by running:

```bash
cd <root of enso repository>
./synthesize.sh
```

The resulting bitstream will be placed the the directory where you ran the command and it will be named `enso_0.sof`. If the design does not meet timing, the bitstream will be saved as `neg_slack_enso_0.sof`.

!!! note

    The above command will use a single seed to synthesize the hardware. It is often advantageous to synthesize with multiple seeds to increase the probability of finding a design that meets timing. If you have enough memory, you can synthesize with multiple seeds in parallel. (Requires GNU Parallel to be installed.)
    
    To do so, you can specify multiple seeds when running the command. For example, to synthesize with seeds 1, 2, 3, and 4, run:

    ```bash
    cd <root of enso repository>
    ./synthesize.sh 1 2 3 4
    ```

    This will run a separate synthesis for each seed and save the resulting bitstreams as `enso_{seed}.sof`, e.g., `enso_1.sof`, `enso_2.sof`.
