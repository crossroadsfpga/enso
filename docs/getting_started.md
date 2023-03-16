# Setup


<!-- ## Requirements

### Hardware

### Software

## Installation

## Building

## Configuring

## Running -->

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
* Either gcc (>= 9.0) or clang (>= 8.0)
* Python (>= 3.9)
* pip
* Meson (>= 0.58)
* Ninja
* libpcap

In Ubuntu 20.04 or other recent Debian-based distributions these dependencies can be obtained with the following commands:
```bash
sudo apt update
sudo apt install \
  python3 \
  python3-pip \
  python3-setuptools \
  python3-wheel \
  gcc-9 \
  g++-9 \
  clang-8 \
  clang++-8 \
  libpcap-dev
sudo pip3 install meson ninja
```

### Compilation

Start by cloning the enso repository, if you haven't already:
```bash
git clone https://github.com/hsadok/enso
```

Prepare the compilation using meson and compile it with ninja.

To use gcc:
```bash
meson setup --native-file gcc.ini build-gcc
```

To use clang:
```bash
meson setup --native-file llvm.ini build-clang
```

To compile:
```bash
cd build-*
ninja
```

### Compilation options

There are a few compile-time options that you may set. You can see all the options with:
```bash
meson configure
```

If you run the above in the build directory, it also shows the current value for each option.

To change one of the options run:
```bash
meson configure -D<option_name>=<value>
```

For instance, to change the batch size and enable latency optimization:
```bash
meson configure -Dbatch_size=64 -Dlatency_opt=true
```

<!--- TODO(sadok): Describe how to synthesize hardware. -->

### Installing enso script

To configure and load the enso NIC you should install the enso script in your *local machine* (e.g., your laptop). This is different from the machine that you will run enso on.

If you haven't already, clone the enso repository in your *local machine*:
```bash
git clone https://github.com/hsadok/enso
```

To install the enso script run in the `enso` directory:
```bash
cd enso
python3 -m pip install -e frontend
```

Refer to the [enso script documentation](frontend/README.md) for instructions on how to enable autocompletion or the dependencies you need to run the EnsōGen packet generator.

Before you can run the script. You must make sure that you have ssh access using a password-less key (e.g., using ssh-copy-id) to the machine you will run enso on. You should also have a `~/.ssh/config` configuration file set in your local machine with configuration to access the machine that you will run enso on.

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

Before running any software you need to make sure that the FPGA is loaded with the latest bitstream. To do so, you must first place the bitstream file in the correct location. You can obtain the bitstream file from [here](https://drive.google.com/drive/folders/1J2YYTNXotdOOeKWvoj_5-heE5qE2dQAC?usp=sharing) or synthesize it from the source code as described in the [synthesis section](#synthesis).

Copy the bitstream file (`alt_ehipc2_hw.sof`) to `enso/hardware_test/alt_ehipc2_hw.sof` in the machine with the FPGA, e.g.:
```bash
cp <bitstream_path>/alt_ehipc2_hw.sof <enso_path>/enso/hardware_test/alt_ehipc2_hw.sof
```

Run the `enso` script in the local machine to load the bitstream in the one with the FPGA:
```bash
enso <host> <remote_enso_path> --load-bitstream
```

You can also specify other options to configure the NIC, refer to `enso --help` for more information.

<!---
## Development Environment

### Software

### Hardware

* Simulation
* Synthesis

-->

## Building Documentation

Install the requirements:
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
