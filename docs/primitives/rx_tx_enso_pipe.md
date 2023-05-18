# RX/TX Ensō Pipe

RX/TX Ensō Pipes are designed for applications that modify received data in place and then send it back to the NIC without the need to impose copy overhead. They can be seen as a combination of an [RX](rx_enso_pipe.md) and [TX](tx_enso_pipe.md) Ensō Pipes, containing a subset of their functionality.

RX/TX Ensō Pipes can receive data from the NIC in the same way as RX Ensō Pipes. Therefore, applications can use analogous functions to receive data. Refer to the [RX Ensō Pipe](rx_enso_pipe.md) documentation for more information about each of those functions:

- Receiving byte streams: [`RxTxPipe::Recv()`](/software/classenso_1_1RxTxPipe.html#ae5d2972f0bbe6aebb8e0521884a1557f){target=_blank}, [`RxTxPipe::Peek()`](/software/classenso_1_1RxTxPipe.html#a5026cb7e8ea1a5b335fbc77dcfe92c53){target=_blank}
- Receiving raw packets:  [`RxTxPipe::RecvPkts()`](/software/classenso_1_1RxTxPipe.html#a98b9f150a91474e0a529cfb7668f7e2a){target=_blank}, [`RxTxPipe::PeekPkts()`](/software/classenso_1_1RxTxPipe.html#a7ec0707e4a3adcc4f9a6c23d2d97d1c9){target=_blank}
- Receiving generic messages: [`RxTxPipe::RecvMessages()`](/software/classenso_1_1RxTxPipe.html#a2619d7dd5d8efbf3d12095360d529cff){target=_blank}

Different from RX Ensō Pipes, however, RX/TX Ensō Pipes do not support freeing the data received from the NIC. Instead, all received data is automatically freed after transmission.

To send data back to the NIC, applications should call [`RxTxPipe::SendAndFree()`](/software/classenso_1_1RxTxPipe.html#a8d4c4987842afe0a5754ac36cb54e7f4){target=_blank}. Note that only data that was previously received can be sent back to the NIC, RX/TX Ensō Pipes do not support extending the buffer as in a TX Ensō Pipe.

The following example shows how to use RX/TX Ensō Pipes to echo received packets back to the NIC after incrementing their payload:

```cpp
RxTxPipe* pipe = dev->AllocateRxTxPipe(); // (1)!
assert(pipe != nullptr);

while (keep_running) {
  auto batch = pipe->RecvPkts();
  if (unlikely(batch.available_bytes() == 0)) {
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

- [`echo.cpp`](https://github.com/crossroadsfpga/enso/blob/master/software/examples/echo.cpp){target=_blank}
- [`echo_event.cpp`](https://github.com/crossroadsfpga/enso/blob/master/software/examples/echo_event.cpp){target=_blank}
