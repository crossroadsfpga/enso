
# TX Ensō Pipe

TX Ensō Pipes work in reverse to [RX Ensō Pipes](rx_enso_pipe.md) and are used to *transmit* data to the NIC. To send data through a TX Ensō Pipe, the application allocates a buffer within the pipe, fill it with data and then send it.

## Allocating a buffer

TX Ensō Pipes manage memory through a simple best-effort allocator. The allocator will always try to return the largest contiguous buffer possible within a given TX Ensō Pipe. The allocated buffer's capacity can also implicitly *increase* at any point but it will never implicitly *decrease*.

To request a buffer, the application calls [`TxPipe::AllocateBuf()`](/software/classnorman_1_1TxPipe.html#a127dfe62e3c1d3d31c35f9c0ce8cf2d9){target=_blank} with a target size. This will return a buffer with size at least as large as the target. Each pipe can only allocate a single buffer at a time. If the application calls `TxPipe::AllocateBuf()` while a buffer is still valid, the function will return the same buffer. Since the buffer's capacity can implicitly increase, the application can always retrieve the current capacity by calling [`TxPipe::capacity()`](/software/classnorman_1_1TxPipe.html#a951f71a687a903d17e8a0879703a3c68){target=_blank}.


!!! note

    The application should never call `TxPipe::AllocateBuf()` with a target larger than the TX Ensō Pipe's overall capacity ([`TxPipe::kMaxCapacity`](/software/classnorman_1_1TxPipe.html#a2058e57cc5e990ea05f6f49312aea7de){target=_blank}). Doing so would cause the function to block indefinitely.



## Transmitting data

Once ready to send data, the application calls [`TxPipe::SendAndFree()`](/software/classnorman_1_1TxPipe.html#a58c280e8eb93ef8816018c1bda484b51){target=_blank}, specifying the amount of data to be sent. This will send the data and free the buffer.

Here is an example of how to use a `TxPipe`:

```cpp
norman::TxPipe* tx_pipe = device->AllocateTxPipe(); // (1)!

// Allocate a buffer.
uint8_t* buf = tx_pipe->AllocateBuf(data_size);

// Fill the buffer with data.
// [...]

// Send the data.
tx_pipe->SendAndFree(data_size);

// The previous buffer is now invalid, allocate a new one.
buf = tx_pipe.AllocateBuf(data_size2);

```

1. :information_source: This is using a [Device](device.md) instance to allocate a TX Ensō Pipe.

In the previous example, we knew the amount of data to be transmitted and we explicitly specified it as the target when calling `TxPipe::AllocateTxPipe()`. This works well for smaller transfers or when we know the pipe's capacity is large enough to hold the data. However, if the target is too large, it will cause `TxPipe::AllocateTxPipe()` to block waiting for enough free space in the TX Ensō Pipe. To avoid this, one may use the TxPipe in a different way. Instead of explicitly setting a target size when allocating the buffer, we can let the pipe dictate how much data that can be sent at a given time. For example:

```cpp
norman::TxPipe* tx_pipe = device->AllocateTxPipe();

// Allocate a buffer. Note that we request a buffer of size 0, this is
// guaranteed to never block.
uint8_t* buf = tx_pipe->AllocateBuf(0);

// Retrieve the buffer's current capacity.
uint32_t data_size = tx_pipe->capacity();

// Fill the buffer with data, up to the buffer's capacity.
// [...]

// Send the data.
tx_pipe->SendAndFree(data_size);

// The previous buffer is now invalid, allocate a new one.
buf = tx_pipe.AllocateBuf(0);
```

## Partial transfers

So far we have always transmitted the entire allocated buffer. However, sometimes it is useful to send only a portion of the buffer. This can be easily achieved by calling `TxPipe::SendAndFree()` with a size smaller than the buffer's capacity. The function will send the specified amount of data, starting from the beginning of the buffer, ignoring all data after the specified size.

Things get more interesting when the part of the buffer that was not sent needs to be used in a subsequent transfer. For instance, the buffer may contain an incomplete message that should be completed before it is sent in the next transfer. In this case, the application can rely on the fact that the data that was not sent will be available in the next buffer allocated using `TxPipe::AllocateBuf()`.

The following diagram illustrates this behavior. At step ①, the application allocates Buffer 1 using `TxPipe::AllocateBuf()`. At step ②, the application partially fills the buffer with data but sends only a portion of it using `TxPipe::SendAndFree()`. At step ③, the application allocates Buffer 2 using `TxPipe::AllocateBuf()`. The new buffer starts with the unsent data from the previous buffer.

<figure markdown>
  ![TX Ensō Pipe partial transfer](/assets/tx_pipe_partial_sent.svg){ width="550" }
  <figcaption>Example of a partial transfer. The unsent data is available in the next buffer returned by TxPipe::AllocateBuf().</figcaption>
</figure>

## Extending a buffer

Since the buffer size can implicitly increase at any point, the application can fetch the current buffer's capacity by calling `TxPipe::capacity()`. The application can also explicitly request a buffer extension by calling [`TxPipe::TryExtendBuf()`](/software/classnorman_1_1TxPipe.html#a5b9d26eb32f1c13d33f581dfb736437f){target=_blank} or [`TxPipe::ExtendBufToTarget()`](/software/classnorman_1_1TxPipe.html#ac556ecc4046b255f0f5547d3d3d3de98){target=_blank}. When calling `TxPipe::TryExtendBuf()`, the TX Ensō Pipe allocator will actively check for completions to try to extend the allocated buffer's capacity but it will not block. When calling `TxPipe::ExtendBufToTarget()`, the TX Ensō Pipe allocator will block until the requested capacity is available.

Note that the previous buffer is not invalidated after calling `TxPipe::TryExtendBuf()` or `TxPipe::ExtendBufToTarget()`. Buffers only become invalid after calling `TxPipe::SendAndFree()`.


## Summary

- `TxPipe::AllocateBuf()` will return the maximum contiguous buffer possible for a given TX Ensō Pipe.
- Applications can use `TxPipe::AllocateBuf()` to allocate a buffer of a minimum target size or they can use `TxPipe::AllocateBuf(0)` to avoid blocking.
- The allocated buffer's capacity can be retrieved by calling `TxPipe::capacity()`.
- The allocated buffer's capacity can implicitly *increase* at any point but it will never implicitly *decrease*.
- If needed, the application can request a buffer extension by calling `TxPipe::TryExtendBuf()` or `TxPipe::ExtendBufToTarget()`.
- The buffer returned by `TxPipe::AllocateBuf()` is valid until we call `TxPipe::SendAndFree()`. Even explicit extensions do not invalidate the buffer.
- After calling `TxPipe::SendAndFree()`, the application should call `TxPipe::AllocateBuf()` again to get a new buffer.
- If the buffer was only partially sent, the new allocated buffer will start with the remaining data.
- The application should not try to modify data from a sent buffer, doing so will result in undefined behavior.
