# Running

Running an application with Ensō requires first loading the bitstream to the FPGA and configuring the NIC. This can be done using the [Ensō CLI tool](enso_cli.md).


## Installing the bitstream

The hardware design is defined using a bitstream. You can automatically download the appropriate bitstream or follow the steps in [Compiling Hardware](compiling_hardware.md) to produce your own (it may take a few hours).

To automatically download and install the appropriate bitstream, run:
```bash
cd <root of enso repository>
./scripts/update_bitstream.sh --download
```

If you want to specify a different bitstream, you can install it by running:
```bash
cd <root of enso repository>
./scripts/update_bitstream.sh <bitstream path>
```

You only need to install the bitstream once or if you want to use a different one.

## Loading the bitstream and configuring the NIC

Before running any software you need to make sure that the FPGA is loaded with the bitstream that you installed.

Use the [`enso` command](enso_cli.md) to load the bitstream and automatically configure the NIC with the default values.
```bash
enso <path to enso repository>  --fpga <FPGA ID>
```

You should use the `--fpga` flag to specify the ID of the FPGA that you want to load. You may use the `scripts/list_enso_nics.sh` script to list the IDs of all compatible FPGAs in your system.

You may also specify other options to configure the NIC. Refer to `enso --help` for more information.

After the FPGA has been loaded and configured, the `enso` command will open the JTAG console. You may use the JTAG console to send extra configuration to the NIC and to retrieve NIC statistics. You can type `help` to get a list of available commands.

Once you are done using the JTAG console, you can press ++ctrl+c++ to quit. You can continue to use the NIC even after the JTAG console has been closed.

The first time you load the NIC, Linux will not recognize it as a PCIe device until you reboot the system. You can use the `scripts/list_enso_nics.sh` script to show all the available Ensō NICs in your system. If the NIC does not show up after you load the bitstream, reboot the system.


## Running an application

Once the NIC has been loaded and you can see the device listed when you run `scripts/list_enso_nics.sh`, you are ready to run an application. Ensō comes with some [example applications](https://github.com/crossroadsfpga/enso/tree/master/software/examples) which are built together with Ensō. You may run any of these without specifying command line arguments to obtain usage information. For example, to obtain instructions on how to run an echo server do:
```bash
cd <root of enso repository>
./build/software/examples/echo
```

This will print the usage information:
```
Usage: ./build/software/examples/echo NB_CORES NB_QUEUES NB_CYCLES

NB_CORES: Number of cores to use.
NB_QUEUES: Number of queues per core.
NB_CYCLES: Number of cycles to busy loop when processing each packet.
```

In Ensō, it is recommended to use at least two queues per core for maximum performance. For instance, this application could be run with:
```bash
./build/software/examples/echo 1 2 0
```

This will use one CPU core, 2 queues and will not busy loop when processing each packet.

!!! note

    You can also refer to [Build an application with Ensō](compiling_software.md#build-an-application-with-enso) for instructions on how to build your own application.
