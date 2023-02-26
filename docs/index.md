# Ensō

![Ensō](assets/enso-black.svg){ align=right width="200" }

Ensō is a high-performance streaming interface for NIC-application communication.

Ensō's design encompasses both *hardware* and *software*. The hardware component targets an FPGA-based NIC and implements the Ensō interface. The software component uses this interface and exposes a simple communication primitive called [Ensō Pipe](enso_pipe.md). Applications can use Ensō Pipes to send and receive data in different formats, such as raw packets, application-level messages, or TCP-like byte streams.

*[NIC]: Network Interface Card

## Why Ensō?

Traditionally, NICs expose a *packetized* interface that software (applications or the kernel) must use to communicate with the NIC. Using this packetized interface has two main drawbacks:

- **Flexibility:** While NICs were traditionally in charge of delivering raw packets to software, an increasing amount of high-level functionality is now performed on the NIC. The packetized interface, however, forces data to be fragmented into packets that are then scattered across memory. This prevents the NIC and the application from communicating efficiently using higher-level abstractions such as application-level messages or TCP streams.
- **Performance:** By forcing hardware and software to synchronize buffers for every packet, the packetized interface imposes significant per-packet overhead both in terms of CPU cycles as well as PCIe bandwidth. This results in significant performance degradation, in particular when using small requests.

## Overview

Ensō implements a new paradigm for NIC-application communication that relies on a streaming abstraction. This abstraction allows a contiguous stream of bytes to be exchanged between the NIC and the application. These streams of bytes can be used to represent *arbitrary* data, including packets, application-level messages, or even a TCP-style bytestream.

In Ensō, applications communicate directly with the NIC through [Ensō Pipes](enso_pipe.md).

<!-- - We need something that shows the flexibility here. -->

## Performance

<!-- ## Getting Started


- Getting started
- Primitives
- Examples
- Developer Guide
    - Development Environment
    - Code Style
- Software Reference
- Hardware Reference
    - FPGA Counters
    - FPGA Registers
    - FPGA Memory Mapped Registers
    - Modules (automatically generated)
-->
