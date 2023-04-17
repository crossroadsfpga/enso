# Running

<!-- To run an application with Ensō, -->

## Installing enso script

To configure and load the enso NIC you should install the enso script. This can even be done in your local machine (e.g., your laptop). It may or may not be the machine you want to run Ensō on.

If you haven't already, clone the enso repository the machine you want to install the script on:
```bash
git clone https://github.com/crossroadsfpga/enso
```

To install the enso script run in the `enso` directory:
```bash
cd enso

# Make sure this python3 is version 3.9 or higher.
python3 -m pip install -e frontend
```

Refer to the [enso script documentation](frontend/README.md) for instructions on how to enable autocompletion or the dependencies you need to run the EnsōGen packet generator.

## Running the enso script in a different machine

If running the enso script in a different machine from the one you will run Ensō, you must make sure that you have ssh access using a password-less key (e.g., using ssh-copy-id) to the machine you will run enso on. You should also have an `~/.ssh/config` configuration file set with configuration to access the machine that you will run enso on.

If you don't yet have a `~/.ssh/config` file, you can create one and add the following lines, replacing everything between `<>` with the correct values:
```bash
Host <machine_name>
  HostName <machine_address>
  IdentityFile <private_key_path>
  User <user_name>
```

`machine_name` is a nickname to the machine. You will use this name to run the enso script.

Next we will describe to use the script to load the bitstream and configure the NIC but you can also use the enso script itself to obtain usage information:
```bash
enso --help
```

## Loading the bitstream to the FPGA

Before running any software you need to make sure that the FPGA is loaded with the latest bitstream. To do so, you must first place the bitstream file in the correct location. You can obtain the latest bitstream file from [here](https://github.com/crossroadsfpga/enso/releases/latest/download/intel_stratix10mx_bitstream.sof) or synthesize it from the source code as described in the [synthesis section](#synthesis).

Copy the bitstream file (`alt_ehipc2_hw.sof`) to `enso/scripts/alt_ehipc2_hw.sof` in the machine with the FPGA, e.g.:
```bash
cp <bitstream_path>/alt_ehipc2_hw.sof <enso_path>/enso/scripts/alt_ehipc2_hw.sof
```

Run the `enso` script to load the bitstream. If running in a different machine, specify the machine name you configured in the `~/.ssh/config` file using the `--host` option.
```bash
enso <enso_path> --host <host> --load-bitstream
```

You can also specify other options to configure the NIC, refer to `enso --help` for more information.


<!-- Runtime configuration -->
