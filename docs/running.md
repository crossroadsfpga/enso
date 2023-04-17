# Running

Running an application with Ensō requires first loading the bitstream to the FPGA and configuring the NIC. This can be done using the `enso` script.


## Installing the `enso` script

To configure and load the Ensō NIC you should install the `enso` script. If you haven't already, clone the enso repository the machine you want to install the script on:
```bash
git clone https://github.com/crossroadsfpga/enso
```

To install the `enso` script run:
```bash
cd <root of enso repository>
python3 -m pip install -e frontend  # Make sure this python is version >=3.9.
```

Refer to the [enso script documentation](https://github.com/crossroadsfpga/enso/blob/master/frontend/README.md) for instructions on how to enable autocompletion.

Next we will describe how to use the script to load the bitstream and configure the NIC but you can also use the `enso` script itself to obtain usage information:
```bash
enso --help
```

If after installing the `enso` script you still get an error saying that the `enso` command is not found, you may need to add the `bin` directory of the python installation to your `PATH`. Refer to [this stackoverflow answer](https://stackoverflow.com/a/62151306/2027390) for more information on how to do this.

## Installing the bitstream

You can use the `scripts/update_bitstream.sh` script to either automatically download and install the appropriate bitstream from the github repository or to install a bitstream that you built following the steps in [Compiling Hardware](compiling_hardware.md).

To automatically download and install the appropriate bitstream from the github repository, run:
```bash
cd <root of enso repository>
./scripts/update_bitstream.sh --download
```

## Loading Bitstream and Configuring the NIC

Before running any software you need to make sure that the FPGA is loaded with the latest bitstream.

Run the `enso` script to load the bitstream.
```bash
enso <enso_path>
```

You can also specify other options to configure the NIC, refer to `enso --help` for more information.


<!-- Runtime configuration -->

<!--- TODO(sadok): Describe how to load the bitstream and the need for rebooting the machine if it does not show up as a device. (may use scripts/list_enso_nics.sh for that) -->


## Running the `enso` script in a different machine

You do not need to run the `enso` script in the same machine as the one you will run Ensō. You may also choose to run it from your laptop, for example. This machine can even have a different operating system, e.g., macOS.

If running the `enso` script in a different machine from the one you will run Ensō, you must make sure that you have ssh access using a password-less key (e.g., using ssh-copy-id) to the machine you will run Ensō on. You should also have an `~/.ssh/config` configuration file set with configuration to access the machine that you will run enso on.

If you don't yet have a `~/.ssh/config` file, you can create one and add the following lines, replacing everything between `<>` with the correct values:
```bash
Host <machine_name>
  HostName <machine_address>
  IdentityFile <private_key_path>
  User <user_name>
```

`machine_name` is a nickname to the machine. You will use this name to run the `enso` script using the `--host` option.
