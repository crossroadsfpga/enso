# Getting Started

To use Ensō, you first need to make sure that your system meets the requirements in terms of hardware and software.

## System Requirements

Ensō currently requires an Intel Stratix 10 MX FPGA. Support for other boards might be added in the future.

### Setup

Here we describe the steps to compile and install Ensō.

#### Prepare system

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

#### Dependencies

Ensō has the following dependencies:

- Either gcc (>= 9.0)
- Python (>= 3.9)
- pip
- Meson (>= 0.58)
- Ninja
- libpcap
- wget
- capinfos (for EnsōGen)

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
  libpcap-dev \
  tshark

python3 -m pip install meson ninja
python3 -m pip install -r requirements.txt
```

<!--- TODO(sadok): Instruction with both setup script as well as manual configuration -->

<!--- TODO(sadok): Describe how to load the bitstream and the need for rebooting the machine if it does not show up as a device. (may use scripts/list_enso_nics.sh for that) -->

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
