# Getting Started

To use Ensō, you first need to make sure that your system meets the requirements in terms of hardware and software.

## System requirements

Ensō currently requires an Intel Stratix 10 MX FPGA. Support for other boards might be added in the future. Ensō's codebase also assumes an x86-64 architecture and that the system is running Linux. Ensō was extensively tested on Ubuntu 16.04, but it should work on other Linux distributions as well.

In what follows, we describe how to setup the software and install the required dependencies.

### Dependencies

Ensō has the following dependencies:

- GCC (>= 9.0)
- Python (>= 3.9)
- pip
- Meson (>= 0.58)
- Ninja
- libpcap
- wget
- capinfos (for EnsōGen)

There are also python dependencies listed in `requirements.txt` that can be installed with `pip`.

If you are using Ubuntu 20.04 or other recent Debian-based distribution, you may be able to use the `setup.sh` script to install all the dependencies. The script is located at the root of the [Ensō repository](https://github.com/crossroadsfpga/enso). To run it, simply execute:

```bash
./setup.sh
```

In Ubuntu 20.04 or other recent Debian-based distributions these dependencies can also be manually installed with the following commands:
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

sudo python3 -m pip install meson ninja  # Installing system-wide.
python3 -m pip install -r requirements.txt
```

### Huge pages

Ensō requires 2MB huge pages to be allocated in the system. You may use the following snippet adapted from [ixy](https://github.com/emmericp/ixy/blob/master/setup-hugetlbfs.sh) to allocate them. In this example, we allocate 2,048 2MB huge pages per NUMA node.

```bash
mkdir -p /mnt/huge
(mount | grep /mnt/huge) > /dev/null || mount -t hugetlbfs hugetlbfs /mnt/huge
for i in /sys/devices/system/node/node[0-9]*
do
	echo 2048 > "$i"/hugepages/hugepages-2048kB/nr_hugepages
done
```

### Quartus

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

!!! note

    Some distributions (e.g., Ubuntu) include code in the `.bashrc` file to prevent it from running in non-interactive environments. This might prevent the above lines from running in some settings. You should remove or comment out the following lines in the `.bashrc` file:

    ```bash
    # If not running interactively, don't do anything
    case $- in
        *i*) ;;
          *) return;;
    esac
    ```
