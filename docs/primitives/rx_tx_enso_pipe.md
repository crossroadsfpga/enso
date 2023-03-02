# RX/TX Ensō Pipe

RX/TX Ensō Pipes are designed for applications that modify received data in place and then send it back to the NIC without the need to impose copy overhead. They can be seen as a combination of an [RX](rx_enso_pipe.md) and [TX](tx_enso_pipe.md) Ensō Pipes, containing a subset of their functionality.

RX/TX Ensō Pipes can receive data from the NIC in the same way as RX Ensō Pipes. Therefore, applications can use analogous functions to receive data. Refer to the [RX Ensō Pipe](rx_enso_pipe.md) documentation for more information about each of those functions:

- Receiving byte streams: [`RxTxPipe::Recv()`](/software/classnorman_1_1RxTxPipe.html#a4b4b52b7f57cafdd0c2dc159be877342){target=_blank}, [`RxTxPipe::Peek()`](/software/classnorman_1_1RxTxPipe.html#a62d7ce7613b76a9ee05cec93d9a1a0e2){target=_blank}
- Receiving raw packets:  [`RxTxPipe::RecvPkts()`](/software/classnorman_1_1RxTxPipe.html#a79abab182c0903227314b3ded58c3630){target=_blank}, [`RxTxPipe::PeekPkts()`](/software/classnorman_1_1RxTxPipe.html#a874b13ecb7db93d588a97e196715be81){target=_blank}
- Receiving generic messages: [`RxTxPipe::RecvMessages()`](/software/classnorman_1_1RxTxPipe.html#a7d8f02a5fc533daaec933147748c2945){target=_blank}

Different from RX Ensō Pipes, however, RX/TX Ensō Pipes do not support freeing the data received from the NIC. Instead, all received data is automatically freed after transmission.

To send data back to the NIC, applications should call [`RxTxPipe::SendAndFree()`](/software/classnorman_1_1RxTxPipe.html#ae5e3f69fc3bd877dfd588fbab513e08d){target=_blank}. Note that only data that was previously received can be sent back to the NIC, RX/TX Ensō Pipes do not support extending the buffer as in a TX Ensō Pipe.

The following example shows how to use RX/TX Ensō Pipes to echo received packets back to the NIC after incrementing their payload:

```cpp
RxTxPipe* pipe = dev->AllocateRxTxPipe(); // (1)!
assert(pipe != nullptr);

while (keep_running) {
  auto batch = pipe->RecvPkts();
  if (unlikely(batch.kAvailableBytes == 0)) {
    continue;
  }
  for (auto pkt : batch) {
    ++pkt[59];  // Increment payload.
  }
  pipe->SendAndFree(batch.processed_bytes());
}
```

1. :information_source: Note that you should use a [Device](device.md) instance to allocate an RX/TX Ensō Pipe.

In this example we poll the RX/TX Ensō Pipe for new packets. If there are no packets available, we skip the current iteration of the loop. Otherwise, we increment the payload of each packet and send them back to the NIC.


## Examples

The following examples use RX/TX Ensō Pipes:

- [`new_echo.cpp`](https://github.com/hsadok/norman/blob/master/software/examples/new_echo.cpp){target=_blank}
- [`new_echo_event.cpp`](https://github.com/hsadok/norman/blob/master/software/examples/new_echo_event.cpp){target=_blank}
