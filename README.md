# Ensō

[![docs](https://github.com/crossroadsfpga/enso/actions/workflows/docs.yml/badge.svg)](https://github.com/crossroadsfpga/enso/actions/workflows/docs.yml)

## System Requirements

Ensō currently requires an Intel Stratix 10 MX FPGA. Support for other boards might be added in the future.

## Setup

Here we describe the steps to compile and install Ensō.

### Prepare system

Setup hugepages:

```bash
mkdir -p /mnt/huge
(mount | grep /mnt/huge) > /dev/null || mount -t hugetlbfs hugetlbfs /mnt/huge
for i in /sys/devices/system/node/node[0-9]*
do
	echo 16384 > "$i"/hugepages/hugepages-2048kB/nr_hugepages
done
```

<!-- TODO(sadok): Make hugepage allocation permanent. -->

<!-- TODO(sadok): Describe how to setup quartus project. -->

### Dependencies

Ensō has the following dependencies:

- Either gcc (>= 9.0)
- Python (>= 3.9)
- pip
- Meson (>= 0.58)
- Ninja
- libpcap
- wget

There are also python dependencies listed in `requirements.txt` that can be installed with `pip`.

In Ubuntu 20.04 or other recent Debian-based distributions these dependencies can be obtained with the following commands:
```bash
sudo apt update
sudo apt install \
  python3.9 \
  python3-pip \
  python3-setuptools \
  python3-wheel \
  gcc-9 \
  g++-9 \
  libpcap-dev

python3 -m pip install meson ninja
python3 -m pip install -r requirements.txt
```

<!--- TODO(sadok): Instruction with both setup script as well as manual configuration -->

<!--- TODO(sadok): Describe how to load the bitstream and the need for rebooting the machine if it does not show up as a device. (may use scripts/check_pcie.sh for that) -->

To be able to load or synthesize the hardware, you also need to install [Intel Quartus 19.3](https://fpgasoftware.intel.com/19.3/?edition=pro) as well as the Stratix 10 device support (same link).

You should also make sure that `quartus` and its tools are in your `PATH`. You may do so by adding the following lines to your `~/.bashrc` file:

```bash
# Make sure this points to the Quartus installation directory.
export quartus_dir=

export INTELFPGAOCLSDKROOT="$quartus_dir/19.3/hld"
export QUARTUS_ROOTDIR="$quartus_dir/19.3/quartus"
export QSYS_ROOTDIR="$quartus_dir/19.3/qsys/bin"
export IP_ROOTDIR="$quartus_dir/19.3/ip/"
export PATH=$quartus_dir/19.3/quartus/bin:$PATH
export PATH=$quartus_dir/19.3/modelsim_ase/linuxaloem:$PATH
export PATH=$quartus_dir/19.3/quartus/sopc_builder/bin:$PATH
```

**Note.** Some distributions (e.g., Ubuntu) include code in the `.bashrc` file to prevent it from running in non-interactive environments. This might prevent the above lines from running in some settings. Consider commenting out the following lines in the `.bashrc` file:

```bash
# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac
```

### Compilation

Start by cloning the enso repository, if you haven't already:
```bash
git clone https://github.com/crossroadsfpga/enso
```

Prepare the compilation using meson and compile it with ninja.

Setup to use gcc:
```bash
meson setup --native-file gcc.ini build-gcc
```

Compile:
```bash
cd build-gcc
ninja
```

### [Optional] Compilation options

There are a few compile-time options that you may set. You can see all the options with:
```bash
meson configure
```

If you run the above in the build directory, it also shows the current value for each option.

To change one of the options run:
```bash
meson configure -D<option_name>=<value>
```

For instance, to enable latency optimization:
```bash
meson configure -Dlatency_opt=true
```

<!--- TODO(sadok): Describe how to synthesize hardware. -->

### Installing enso script

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

### [Optional] Running the enso script in a different machine

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

### Loading the bitstream to the FPGA

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

<!---
## Development Environment

### Software

### Hardware

* Simulation
* Synthesis

-->

## [Optional] Building Documentation

You can access Ensō's documentation at [https://crossroadsfpga.github.io/enso/](https://crossroadsfpga.github.io/enso/). But if you would like to contribute to the documentation, you may choose to also build it locally.

Install the requirements, this assumes that you already have pip and npm installed:

```bash
sudo apt update
sudo apt install doxygen python3-pip npm
python3 -m pip install -r docs/requirements.txt
sudo npm install -g teroshdl
```

To build the documentation, run (from the build directory):

```bash
meson compile docs
```

While writing documentation, you can use the following command to automatically rebuild the documentation when you make changes:

```bash
mkdocs serve
```

Note that this does not automatically rebuild the hardware and software API reference. You need to rerun `meson compile docs` to do that.
