# Ensō

[![docs](https://github.com/crossroadsfpga/enso/actions/workflows/docs.yml/badge.svg)](https://github.com/crossroadsfpga/enso/actions/workflows/docs.yml)
[![DOI](https://zenodo.org/badge/248301431.svg)](https://zenodo.org/badge/latestdoi/248301431)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/crossroadsfpga/enso/master/docs/assets/enso-white.svg">
  <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/crossroadsfpga/enso/master/docs/assets/enso-black.svg">
  <img align="right" width="200" alt="Enso" src="./docs/assets/enso-black.svg">
</picture>

Ensō is a high-performance streaming interface for NIC-application communication.

Ensō's design encompasses both *hardware* and *software*. The hardware component targets an FPGA NIC[^1] and implements the Ensō interface. The software component uses this interface and exposes simple communication primitives called [Ensō Pipes](https://crossroadsfpga.github.io/enso/primitives/rx_enso_pipe/). Applications can use Ensō Pipes to send and receive data in different formats, such as raw packets, application-level messages, or TCP-like byte streams.

[^1]: Network Interface Cards (NICs) are the hardware devices that connect a computer to the network. They are responsible for transmitting data from the CPU to the network and vice versa. FPGAs are reconfigurable hardware devices. They can be reconfigured to implement arbitrary hardware designs. Here we use an FPGA to implement a NIC with the Ensō interface but the same interface could also be implemented in a traditional fixed-function hardware.


## Why Ensō?

Traditionally, NICs expose a *packetized* interface that software (applications or the kernel) must use to communicate with the NIC. Ensō provides two main advantages over this interface:

- **Flexibility:** While NICs were traditionally in charge of delivering raw packets to software, an increasing amount of high-level functionality is now performed on the NIC. The packetized interface, however, forces data to be fragmented into packets that are then scattered across memory. This prevents the NIC and the application from communicating efficiently using higher-level abstractions such as application-level messages or TCP streams. Ensō instead allows the NIC and the application to communicate using a contiguous stream of bytes, which can be used to represent *arbitrary* data.
- **Performance:** By forcing hardware and software to synchronize buffers for every packet, the packetized interface imposes significant per-packet overhead both in terms of CPU cycles as well as PCIe bandwidth. This results in significant performance degradation, in particular when using small requests. Ensō's use of a byte stream interface allows the NIC and the application to exchange multiple packets (or messages) at once, which reduces the number of CPU cycles and PCIe transactions required to communicate each request. Moreover, by placing packets (or messages) contiguously in memory, Ensō makes better use of the CPU prefetcher, vastly reducing the number of cache misses.


## Getting started

- [Setup](https://crossroadsfpga.github.io/enso/getting_started/)
- Understanding the primitives: [RX Ensō Pipe](https://crossroadsfpga.github.io/enso/primitives/rx_enso_pipe/), [TX Ensō Pipe](https://crossroadsfpga.github.io/enso/primitives/tx_enso_pipe/), [RX/TX Ensō Pipe](https://crossroadsfpga.github.io/enso/primitives/rx_tx_enso_pipe/)
- Examples: [Echo Server](https://github.com/crossroadsfpga/enso/blob/master/software/examples/echo.cpp), [Packet Capture](https://github.com/crossroadsfpga/enso/blob/master/software/examples/capture.cpp), [EnsōGen Packet Generator](https://github.com/crossroadsfpga/enso/blob/master/software/examples/ensogen.cpp)
- API References: [Software](https://crossroadsfpga.github.io/enso/software/), [Hardware](https://crossroadsfpga.github.io/enso/hardware/)
