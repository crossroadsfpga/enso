# Device

The `Device` class is the main entry point for interacting with the hardware device. It is used to [allocate Ensō Pipes](#allocating-ensō-pipes) as well as to [configure the device](#configuring-the-device). It can also be used to efficiently [receive data from multiple pipes](#receiving-data-from-multiple-pipes), avoiding the need to probe each pipe individually.

Every I/O thread in a program should instantiate its own `Device` instance using the [`Device::Create()`](/software/classenso_1_1Device.html#a0680a603967557aef3be2d3c7931967e){target=_blank} factory method. `Device` objects, like pipe objects, are not meant to be thread safe. They are designed to be used by a single thread only.

## Allocating Ensō Pipes

After instantiating a device, the application can allocate Ensō Pipes of any of the three types, using the appropriate method:

- [`Device::AllocateRxPipe()`](/software/classenso_1_1Device.html#a317921d74d678fbd27982d1c995ae9c6){target=_blank} to allocate an [RX Ensō Pipe](rx_enso_pipe.md).
- [`Device::AllocateTxPipe()`](/software/classenso_1_1Device.html#aefb1883e2b2443ffb30e3697fcd8e6bb){target=_blank} to allocate a [TX Ensō Pipe](tx_enso_pipe.md).
- [`Device::AllocateRxTxPipe()`](/software/classenso_1_1Device.html#a44fb96b78e6dc6f0960a5153104f8e19){target=_blank} to allocate an [RX/TX Ensō Pipe](rx_tx_enso_pipe.md).

## Receiving Data from Multiple Pipes

Threads can also use `Device` instances to figure out which pipe has data pending to be received. This is useful when the application needs to receive data from multiple pipes, as it avoids the need to probe each pipe individually.[^1]

[^1]: This is analogous to the `select(2)` system call in POSIX.

To figure out the next pipe with data pending, the application can call [`Device::NextRxPipeToRecv()`](/software/classenso_1_1Device.html#abb95307e3ea14248fc15b250d67c3b0b){target=_blank} or [`Device::NextRxTxPipeToRecv()`](/software/classenso_1_1Device.html#a6ebb5dde347fc643b471ccad63a9ff5a){target=_blank}. This will return the next pipe with data pending to be received, or `nullptr` if no pipe has data pending. Here is an example that receives data from multiple pipes:

```cpp
// Allocate device.
std::unique_ptr<Device> dev = Device::Create();

// Allocate RX pipes.
RxPipe* rx_pipe_1 = dev->AllocateRxPipe();
RxPipe* rx_pipe_2 = dev->AllocateRxPipe();

while (keep_running) {
  // Figure out the next pipe with data pending to be received.
  RxPipe* pipe = dev->NextRxPipeToRecv();

  if (pipe == nullptr) continue;

  pipe->Recv(); // (1)!

  // Do something with the received data.
  // [...]

  pipe->Clear();
}
```

1. :information_source: Refer to the [RX Ensō Pipe](rx_enso_pipe.md) documentation for more information on how to receive data from an Ensō Pipe.

!!! note

    There is an important caveat to consider when using these methods: they do not work if the application has a mix of RX and RX/TX pipes. If you plan to use those methods, make sure you only use one type of RX pipe.

## Configuring the Device

You may also use a `Device` instance to configure the hardware device.

### Hardware Rate Limiter

The hardware implementation includes a rate limiter that can be used to limit the rate at which packets are sent. The rate limiter is applied to all packets sent by the device, regardless of the pipe they are sent on. That means that even if you enable rate limiting from a specific thread, it will affect pipes from all threads. The rate limiter can be enabled by calling [`Device::EnableRateLimiting()`](/software/classenso_1_1Device.html#a74ff96e12ce2385b0447eadd4ededc90){target=_blank} and disabled by calling [`Device::DisableRateLimiting()`](/software/classenso_1_1Device.html#a520234fd5dd585f4c8b0b9fb72adbfb8){target=_blank}.

When enabling the rate limiter, you specify a fraction `num / den` of the maximum hardware flit rate (a flit is 64 bytes). The maximum hardware flit rate is defined by the [`kMaxHardwareFlitRate`](/software/consts_8h.html#a2724b5cbd3bd79652a61696e662c24ce){target=_blank} constant and is 200MHz by default. This will cause packets from all queues to be sent at a rate of `num / den * kMaxHardwareFlitRate` flits per second. Note that this is slightly different from how we typically define throughput and you will need to take the packet sizes into account to set this properly.

For example, suppose that you are sending 64-byte packets. Each packet occupies exactly one flit. For this packet size, line rate at 100Gbps is 148.8Mpps. So if `kMaxHardwareFlitRate` is 200MHz, line rate actually corresponds to a 744/1000 rate. Therefore, if you want to send at 50Gbps (50% of line rate), you can use a 372/1000 (or 93/250) rate.

The other thing to notice is that, while it might be tempting to use a large denominator in order to increase the rate precision. This has the side effect of increasing burstiness. The way the rate limiter is implemented, we send a burst of `num` consecutive flits every `den` cycles. Which means that if `num` is too large, it might overflow the receiver buffer. For instance, in the example above, 93/250 would be a better rate than 372/1000. And 3/8 would be even better with a slight loss in precision.

You can find the maximum packet rate for any packet size by using the expression: `line_rate / ((pkt_size + 20) * 8)`. So for 100Gbps and 128-byte packets we have: `100e9 / ((128 + 20) * 8)` packets per second. Given that each packet is two flits, for `kMaxHardwareFlitRate = 200e6`, the maximum rate is `100e9 / ((128 + 20) * 8) * 2 / 200e6`, which is approximately 125/148. Therefore, if you want to send packets at 20Gbps (20% of line rate), you should use a 25/148 rate.

### Hardware Time Stamping

The hardware implementation can also time stamp packets as they are sent and compute the RTT when they return. This is useful to measure latency. As with the rate limiter, this configuration is applied to all pipes. You can enable time stamping by calling [`Device::EnableTimeStamping()`](/software/classenso_1_1Device.html#a86e350a5dbf6145858c9b3739736c6e0) and disable it by calling [`Device::DisableTimeStamping()`](/software/classenso_1_1Device.html#ae77a9be57a5d8e26009da7fa9239d4b7).

When timestamping is enabled, all outgoing packets will receive a timestamp and all incoming packets will have an RTT (in number of cycles). You may use [`get_pkt_rtt()`](/software/helpers_8h.html#ace30043e3eb62368ccf750a139a16383) to retrieve the RTT for a returning packet. This function will return the RTT in number of cycles. You can convert it to nanoseconds by multiplying it by [`kNsPerTimestampCycle`](/software/consts_8h.html#a512ca8b1b9bae1397e47b3642f1b30ea).
