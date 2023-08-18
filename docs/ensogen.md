# EnsōGen Packet Generator

EnsōGen is a software packet generator built on top of the Ensō NIC interface. It can send packets from a pcap and receive them back at 100Gbps line rate using a single CPU core. EnsōGen is included with Ensō as one of its example applications.

## Running

EnsōGen is built as part of Ensō. Make sure to follow the instructions in [Compiling Software](compiling_software.md) to build Ensō and that you have the [`enso` command](enso_cli.md) installed.

You should use the `scripts/ensogen.sh` script to run EnsōGen:

```bash
cd <path to enso repo>
./scripts/ensogen.sh <path to pcap file> <rate in Gbps> --pcie-addr <pcie address> --count <number of packets>
```

Both `<pcie address>` and `<number of packets>` are optional but it's recommended to specify `<pcie address>` if you have more than one NIC in your system. If `<number of packets>` is not specified, EnsōGen will send packets indefinitely until you stop it with ++ctrl+c++.

Recall that you may obtain the PCIe address of all Ensō NICs in your system by running `scripts/list_enso_nics.sh`.

The `scripts/ensogen.sh` script makes it easier to run EnsōGen by automatically figuring out the hardware rate limiter parameters based on the input pcap file and the desired rate.

You may also choose to run EnsōGen manually. Run the following command to see the available options:

```bash
cd <path to enso repo>
sudo ./build/software/examples/ensogen --help
```

All these options are also available through the `scripts/ensogen.sh` script.

## Other features

- **Save:** You can save the statistics EnsōGen collects to a file by using the `--save SAVE_FILE` option. This will save the statistics in a csv file called `SAVE_FILE`.
- **RTT:** You can also use EnsōGen to measure RTT. It uses hardware timestamping and can keep track of RTTs with 5ns precision. To enable RTT measurement, run EnsōGen with the `--rtt` flag.
- **RTT Histogram**: The `--rtt` option will report the average RTT among all packets. You can also enable RTT histogram to record the RTT of *every* packet. This allows you to generate RTT CDFs as well as calculate relevant metrics such as 99th percentile latency. To enable RTT histogram, run EnsōGen with the `--rtt-hist HIST_FILE`. This will save the RTT histogram in a file called `HIST_FILE`.
