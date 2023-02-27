/*
 * Copyright (c) 2023, Carnegie Mellon University
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted (subject to the limitations in the disclaimer
 * below) provided that the following conditions are met:
 *
 *      * Redistributions of source code must retain the above copyright notice,
 *      this list of conditions and the following disclaimer.
 *
 *      * Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *      * Neither the name of the copyright holder nor the names of its
 *      contributors may be used to endorse or promote products derived from
 *      this software without specific prior written permission.
 *
 * NO EXPRESS OR IMPLIED LICENSES TO ANY PARTY'S PATENT RIGHTS ARE GRANTED BY
 * THIS LICENSE. THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
 * NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * @file
 * @brief Enso Pipe API. We define RX, TX, and RX/TX pipes as well as the Device
 * class that manages them. All of these classes are quite coupled, so we define
 * them all in this file.
 *
 * @author Hugo Sadok <sadok@cmu.edu>
 */

#ifndef SOFTWARE_INCLUDE_NORMAN_PIPE_H_
#define SOFTWARE_INCLUDE_NORMAN_PIPE_H_

#include <norman/helpers.h>
#include <norman/internals.h>

#include <array>
#include <cassert>
#include <functional>
#include <iostream>
#include <memory>
#include <string>
#include <vector>

// Avoid exposing `intel_fpga_pcie_api.hpp` externally.
class IntelFpgaPcieDev;

namespace norman {

class RxPipe;
class TxPipe;
class RxTxPipe;

class PktIterator;
class PeekPktIterator;

uint32_t external_peek_next_batch_from_queue(
    struct RxEnsoPipeInternal* enso_pipe,
    struct NotificationBufPair* notification_buf_pair, void** buf);

/**
 * @brief A class that represents a device.
 *
 * Should be instantiated using the factory method `Create()`. Use separate
 * instances for each thread.
 *
 * Example:
 * @code
 *    uint16_t core_id = 0;
 *    uint32_t nb_pipes = 4;
 *    std::string pcie_addr = "0000:01:00.0";
 *    auto device = Device::Create(core_id, nb_pipes, pcie_addr);
 * @endcode
 */
class Device {
 public:
  static constexpr uint32_t kMaxPendingTxRequests = MAX_PENDING_TX_REQUESTS;

  /**
   * @brief Factory method to create a device.
   *
   * @param nb_rx_pipes The number of RX Pipes to create. TODO(sadok): This
   *                    should not be needed.
   * @param core_id The core ID of the thread that will access the device. If
   *                -1, uses the current core.
   * @param pcie_addr The PCIe address of the device. If empty, uses the first
   *                  device found.
   * @return A unique pointer to the device. May be null if the device cannot be
   *         created.
   */
  static std::unique_ptr<Device> Create(
      uint32_t nb_rx_pipes, int16_t core_id = -1,
      const std::string& pcie_addr = "") noexcept;

  Device(const Device&) = delete;
  Device& operator=(const Device&) = delete;
  Device(Device&&) = delete;
  Device& operator=(Device&&) = delete;

  ~Device();

  /**
   * @brief Allocates an RX pipe.
   *
   * @return A pointer to the pipe. May be null if the pipe cannot be created.
   */
  RxPipe* AllocateRxPipe() noexcept;

  /**
   * @brief Allocates a TX pipe.
   *
   * @param buf Buffer address to use for the pipe. It must be a pinned
   *            hugepage. If not specified, the buffer is allocated internally.
   * @return A pointer to the pipe. May be null if the pipe cannot be created.
   */
  TxPipe* AllocateTxPipe(uint8_t* buf = nullptr) noexcept;

  /**
   * @brief Allocates an RX/TX pipe.
   *
   * @return A pointer to the pipe. May be null if the pipe cannot be created.
   */
  RxTxPipe* AllocateRxTxPipe() noexcept;

  /**
   * @brief Gets the next RxPipe that has data pending.
   *
   * @warning This function can only be used when there are *only* RX pipes.
   * Trying to use this function when there are RX/TX pipes will result in
   * undefined behavior.
   *
   * @return A pointer to the pipe. May be nullptr if no pipe has data pending.
   */
  RxPipe* NextRxPipeToRecv();

  /**
   * @brief Gets the next RxTxPipe that has data pending.
   *
   * @warning This function can only be used when there are *only* RX/TX pipes.
   * Trying to use this function when there are RX pipes allocated will result
   * in undefined behavior.
   *
   * @return A pointer to the pipe. May be nullptr if no pipe has data pending.
   */
  RxTxPipe* NextRxTxPipeToRecv();

  /**
   * @brief Process completions for all pipes associated with this device.
   */
  void ProcessCompletions();

 private:
  struct TxPendingRequest {
    uint32_t pipe_id;
    uint32_t nb_bytes;
  };

  /**
   * Use `Create` factory method to instantiate objects externally.
   */
  Device(uint32_t nb_rx_pipes, int16_t core_id,
         const std::string& pcie_addr) noexcept
      : kPcieAddr(pcie_addr), kNbRxPipes(nb_rx_pipes), core_id_(core_id) {
#ifndef NDEBUG
    std::cerr << "Warning: assertions are enabled. Performance may be affected."
              << std::endl;
#endif  // NDEBUG
    rx_pipes_.reserve(kNbRxPipes);
  }

  /**
   * @brief Initializes the device.
   *
   * @return 0 on success and a non-zero error code on failure.
   */
  int Init() noexcept;

  /**
   * @brief Sends a certain number of bytes to the device. This is designed to
   * be used by a TxPipe object.
   *
   * @param tx_enso_pipe_id The ID of the TxPipe.
   * @param phys_addr The physical address of the buffer region to send.
   * @param nb_bytes The number of bytes to send.
   * @return The number of bytes sent.
   */
  void Send(uint32_t tx_enso_pipe_id, uint64_t phys_addr, uint32_t nb_bytes);

  friend class RxPipe;
  friend class TxPipe;
  friend class RxTxPipe;

  const std::string kPcieAddr;
  const uint32_t kNbRxPipes;

  IntelFpgaPcieDev* fpga_dev_;
  struct NotificationBufPair notification_buf_pair_;
  int16_t core_id_;
  uint16_t bdf_;
  void* uio_mmap_bar2_addr_;

  std::vector<RxPipe*> rx_pipes_;
  std::vector<TxPipe*> tx_pipes_;
  std::vector<RxTxPipe*> rx_tx_pipes_;

  uint32_t tx_pr_head_ = 0;
  uint32_t tx_pr_tail_ = 0;
  std::array<TxPendingRequest, kMaxPendingTxRequests + 1> tx_pending_requests_;
  static constexpr uint32_t kPendingTxRequestsBufMask = kMaxPendingTxRequests;
  static_assert((kMaxPendingTxRequests & (kMaxPendingTxRequests + 1)) == 0,
                "kMaxPendingTxRequests + 1 must be a power of 2");
};

/**
 * @brief A class that represents an RX Enso Pipe.
 *
 * Should be instantiated using a Device object.
 *
 * Example:
 * @code
 *    Device* device = Device::Create(core_id, nb_pipes, pcie_addr);
 *    RxPipe* rx_pipe = device->AllocateRxPipe();
 *    rx_pipe->Bind(...);
 *
 *    auto batch = rx_pipe->RecvPkts();
 *    for (auto pkt : batch) {
 *      // Do something with the packet.
 *    }
 *    rx_pipe->Clear();
 * @endcode
 */
class RxPipe {
 public:
  /**
   * @brief A class that represents a batch of messages.
   *
   * @param T An iterator for the particular message type. Refer to
   *          `norman::PktIterator` for an example of a raw packet iterator.
   */
  template <typename T>
  class MessageBatch {
   public:
    constexpr T begin() { return T(kBuf, kMessageLimit, this); }
    constexpr T begin() const { return T(kBuf, kMessageLimit, this); }
    constexpr T end() { return T(kBuf + kAvailableBytes, kMessageLimit, this); }
    constexpr T end() const {
      return T(kBuf + kAvailableBytes, kMessageLimit, this);
    }

    /**
     * Number of bytes processed by the iterator.
     */
    uint32_t processed_bytes() const { return processed_bytes_; }

    /**
     * Number of bytes available in the batch. It may include more messages than
     * `kMessageLimit`, in which case, iterating over the batch will result in
     * fewer bytes. After iterating over the batch, the total number of bytes
     * iterated over can be obtained by calling `processed_bytes()`.
     */
    const uint32_t kAvailableBytes;

    /**
     * @brief Maximum number of messages in the batch.
     */
    const int32_t kMessageLimit;

    uint8_t* const kBuf;

   private:
    /**
     * Can only be constructed by RxPipe.
     *
     * @param buf A pointer to the start of the batch.
     * @param available_bytes The number of bytes available in the batch.
     * @param message_limit The maximum number of messages in the batch.
     * @param pipe The pipe that created this batch.
     */
    constexpr MessageBatch(uint8_t* buf, uint32_t available_bytes,
                           int32_t message_limit, RxPipe* pipe)
        : kAvailableBytes(available_bytes),
          kMessageLimit(message_limit),
          kBuf(buf),
          pipe_(pipe) {}

    friend class RxPipe;
    friend T;

    uint32_t processed_bytes_ = 0;
    RxPipe* pipe_;
  };

  RxPipe(const RxPipe&) = delete;
  RxPipe& operator=(const RxPipe&) = delete;
  RxPipe(RxPipe&&) = delete;
  RxPipe& operator=(RxPipe&&) = delete;

  /**
   * @brief Binds the pipe to a given flow entry. Can be called multiple times.
   *
   * Currently the hardware ignores the source IP and source port for UDP
   * packets. You MUST set them to 0 when binding.
   *
   * @param dst_port Destination port.
   * @param src_port Source port.
   * @param dst_ip Destination IP.
   * @param src_ip Source IP.
   * @param protocol Protocol.
   */
  int Bind(uint16_t dst_port, uint16_t src_port, uint32_t dst_ip,
           uint32_t src_ip, uint32_t protocol);

  /**
   * @brief Receives a batch of bytes.
   *
   * @param buf A pointer that will be set to the start of the received bytes.
   * @param max_nb_bytes The maximum number of bytes to receive.
   *
   * @return The number of bytes received.
   */
  uint32_t Recv(uint8_t** buf, uint32_t max_nb_bytes);

  /**
   * @brief Receives a batch of bytes without removing them from the queue.
   *
   * @param buf A pointer that will be set to the start of the received bytes.
   * @param max_nb_bytes The maximum number of bytes to receive.
   *
   * @return The number of bytes received.
   */
  uint32_t Peek(uint8_t** buf, uint32_t max_nb_bytes);

  /**
   * @brief Confirms a certain number of bytes have been received.
   *
   * This will make sure that the next call to `Recv` or `Peek` will return a
   * buffer that starts at the next byte after the last confirmed byte.
   *
   * When using `Recv`, this is not necessary, as `Recv` will automatically
   * confirm the bytes received. You may use this to confirm bytes received by
   * `Peek`.
   *
   * @param nb_bytes The number of bytes to confirm (must be a multiple of 64).
   */
  constexpr void ConfirmBytes(uint32_t nb_bytes) {
    uint32_t rx_tail = internal_rx_pipe_.rx_tail;
    rx_tail = (rx_tail + nb_bytes / 64) % ENSO_PIPE_SIZE;
    internal_rx_pipe_.rx_tail = rx_tail;
  }

  /**
   * @brief Returns the number of bytes allocated in the pipe, i.e., the number
   * of bytes owned by the application.
   *
   * @return The number of bytes allocated in the pipe.
   */
  constexpr uint32_t capacity() const {
    uint32_t rx_head = internal_rx_pipe_.rx_head;
    uint32_t rx_tail = internal_rx_pipe_.rx_tail;
    return ((rx_head - rx_tail) % ENSO_PIPE_SIZE) * 64;
  }

  /**
   * @brief Receives a batch of generic messages.
   *
   * @param T An iterator for the particular message type. Refer to
   *          `norman::PktIterator` for an example of a raw packet
   *          iterator.
   * @param max_nb_messages The maximum number of messages to receive. If set to
   *                        -1, all messages in the pipe will be received.
   *
   * @return A MessageBatch object that can be used to iterate over the received
   *         messages.
   */
  template <typename T>
  constexpr MessageBatch<T> RecvMessages(int32_t max_nb_messages = -1) {
    void* buf = nullptr;
    uint32_t recv = external_peek_next_batch_from_queue(
        &internal_rx_pipe_, notification_buf_pair_, &buf);
    return MessageBatch<T>((uint8_t*)buf, recv, max_nb_messages, this);
  }

  /**
   * @brief Receives a batch of packets.
   *
   * @param max_nb_pkts The maximum number of packets to receive. If set to -1,
   *                    all packets in the pipe will be received.
   *
   * @return A MessageBatch object that can be used to iterate over the received
   *         packets.
   */
  inline MessageBatch<PktIterator> RecvPkts(int32_t max_nb_pkts = -1) {
    return RecvMessages<PktIterator>(max_nb_pkts);
  }

  /**
   * @brief Receives a batch of packets without removing them from the queue.
   *
   * @param max_nb_pkts The maximum number of packets to receive. If set to -1,
   *                    all packets in the pipe will be received.
   *
   * @return A MessageBatch object that can be used to iterate over the received
   *         packets.
   */
  inline MessageBatch<PeekPktIterator> PeekPkts(int32_t max_nb_pkts = -1) {
    return RecvMessages<PeekPktIterator>(max_nb_pkts);
  }

  /**
   * @brief Frees a given number of bytes previously received on the RxPipe.
   *
   * @param nb_bytes The number of bytes to free.
   */
  void Free(uint32_t nb_bytes);

  /**
   * @brief Prefetches the next batch of bytes to be received on the RxPipe.
   */
  void Prefetch();

  /**
   * @brief Frees all bytes previously received on the RxPipe.
   */
  void Clear();

  /**
   * @brief Returns the pipe's internal buffer.
   *
   * @return A pointer to the start of the pipe's internal buffer.
   */
  inline uint8_t* buf() const { return (uint8_t*)internal_rx_pipe_.buf; }

  /**
   * @brief Returns the pipe's ID.
   *
   * @return The pipe's ID.
   */
  inline enso_pipe_id_t id() const { return kId; }

 private:
  /**
   * RxPipes can only be instantiated from a `Device` object, using the
   * `AllocateRxPipe()` method.
   *
   * @param id The ID of the pipe.
   * @param device The `Device` object that instantiated this pipe.
   */
  explicit RxPipe(enso_pipe_id_t id, Device* device) noexcept
      : kId(id), notification_buf_pair_(&(device->notification_buf_pair_)) {}

  /**
   * RxPipes cannot be deallocated from outside. The `Device` object is in
   * charge of deallocating them.
   */
  ~RxPipe();

  /**
   * @brief Initializes the RX pipe.
   *
   * @param enso_pipe_regs The Enso Pipe registers.
   *
   * @return 0 on success and a non-zero error code on failure.
   */
  int Init(volatile struct QueueRegs* enso_pipe_regs) noexcept;

  friend class Device;

  const enso_pipe_id_t kId;  ///< The ID of the pipe.
  struct RxEnsoPipeInternal internal_rx_pipe_;
  struct NotificationBufPair* notification_buf_pair_;
};

/**
 * @brief A class that represents a TX Enso Pipe.
 *
 * Should be instantiated using a Device object.
 *
 * Example:
 * @code
 *    norman::Device* device = norman::Device::Create(core_id, nb_pipes,
 *                                                    pcie_addr);
 *    norman::TxPipe* tx_pipe = device->AllocateTxPipe();
 *    uint8_t* buf = tx_pipe->AllocateBuf(data_size);
 *
 *    // AllocateBuf with a non-zero argument may block waiting for the capacity
 *    // to be free. Alternatively, one may use AllocateBuf with data_size = 0
 *    // and use and useTryExtendBuf to avoid blocking, potentially dropping
 *    // data instead of waiting.
 *
 *    // Fill the buffer with data.
 *    [...]
 *
 *    // Send the data and retrieve a new buffer.
 *    tx_pipe->SendAndFree(data_size);
 *    buf = tx_pipe.AllocateBuf(data_size);
 * @endcode
 */
class TxPipe {
 public:
  TxPipe(const TxPipe&) = delete;
  TxPipe& operator=(const TxPipe&) = delete;
  TxPipe(TxPipe&&) = delete;
  TxPipe& operator=(TxPipe&&) = delete;

  /**
   * @brief Allocate a buffer in the pipe.
   *
   * There can only be a single buffer allocated at a time for a given Pipe.
   * Calling this function again when a buffer is already allocated will return
   * the same address.
   *
   * The buffer capacity can be retrieved by calling `capacity()`. Note that the
   * buffer capacity can increase without notice but will never decrease. The
   * user can also explicitly request for the buffer to be extended by calling
   * `ExtendBufToTarget()`.
   *
   * The buffer is valid until the user calls `SendAndFree()`. In which case,
   * the buffer will be freed and a new one must be allocated by calling this
   * function again.
   *
   * If `SendAndFree()` only partially sends the buffer, the previous buffer
   * address will still not be valid. But allocating a new buffer will return a
   * a buffers that starts with the remaining data.
   *
   * @warning The capacity will never be go beyond `TxPipe::kMaxCapacity`.
   *          Therefore, specifying a `target_capacity` larger than
   *          `TxPipe::kMaxCapacity` will cause this function to block forever.
   *
   * @param target_capacity Target capacity of the buffer. It will block until
   *                        the buffer is at least this big. May set it to 0 to
   *                        avoid blocking.
   *
   * @return The allocated buffer address.
   */
  uint8_t* AllocateBuf(uint32_t target_capacity) {
    ExtendBufToTarget(target_capacity);
    return buf_ + app_begin_;
  }

  /**
   * @brief Sends and deallocates a given number of bytes.
   *
   * After calling this function, the previous buffer address is no longer
   * valid. Accessing it will lead to undefined behavior.
   *
   * @note The user must use `AllocateBuf()` to allocate a new buffer after
   * calling this function.
   *
   * The pipe's capacity will also be reduced by the number of bytes sent. If
   * sending more bytes than the pipe's current capacity, the behavior is
   * undefined. The user must also make sure not to modify the sent bytes after
   * calling this function.
   *
   * @param nb_bytes The number of bytes to send. Must be a multiple of
   *                 `kQuantumSize`.
   */
  inline void SendAndFree(uint32_t nb_bytes) {
    uint64_t phys_addr = buf_phys_addr_ + app_begin_;
    assert(((app_end_ - app_begin_) & kBufMask) + nb_bytes <= kMaxCapacity);
    assert(nb_bytes <= kMaxCapacity);
    assert(nb_bytes / kQuantumSize * kQuantumSize == nb_bytes);

    app_begin_ = (app_begin_ + nb_bytes) & kBufMask;

    device_->Send(kId, phys_addr, nb_bytes);
  }

  /**
   * @brief Explicitly requests a best-effort buffer extension.
   *
   * Will check for completed transmissions to try to extend the capacity of the
   * currently allocated buffer. After this, capacity will be at least as large
   * as it was before. The user can continue to use the same buffer address as
   * before.
   *
   * User may use `capacity()` to check the total number of available bytes
   * after calling this function or simply use the return value.
   *
   * @note The capacity will never be extended beyond `TxPipe::kMaxCapacity`.
   *
   * @return The new buffer capacity after extending.
   */
  inline uint32_t TryExtendBuf() {
    device_->ProcessCompletions();
    return capacity();
  }

  /**
   * @brief Explicitly requests a buffer extension with a target capacity.
   *
   * Different from `TryExtendBuf()`, this function will block until the
   * capacity is at least as large as the target capacity. Other than that the
   * behavior is the same.
   *
   * User may use `capacity()` to check the total number of available bytes
   * after calling this function or simply use the return value.
   *
   * @warning The capacity will never be extended beyond `TxPipe::kMaxCapacity`.
   *          Therefore, specifying a target capacity larger than
   *          `TxPipe::kMaxCapacity` will block forever.
   *
   * @return The new buffer capacity after extending.
   */
  inline uint32_t ExtendBufToTarget(uint32_t target_capacity) {
    uint32_t _capacity = capacity();
    assert(target_capacity <= kMaxCapacity);
    while (_capacity < target_capacity) {
      _capacity = TryExtendBuf();
    }
    return _capacity;
  }

  /**
   * @brief Returns the allocated buffer's current available capacity.
   *
   * The buffer capacity can increase without notice but will never decrease.
   * The user can use this function to check the current capacity.
   *
   * @return The capacity of the allocated buffer in bytes.
   */
  inline uint32_t capacity() const {
    return (app_end_ - app_begin_ - 1) & kBufMask;
  }

  /**
   * @brief Returns the number of bytes that are currently being transmitted.
   *
   * @return Number of bytes pending transmission.
   */
  inline uint32_t pending_transmission() const {
    return kMaxCapacity - ((app_end_ - app_begin_) & kBufMask);
  }

  /**
   * The size of a "buffer quantum" in bytes. This is the minimum unit that can
   * be sent at a time. Every transfer should be a multiple of this size.
   */
  static constexpr uint32_t kQuantumSize = 64;

  /**
   * Maximum capacity achievable by the pipe. There should always be at least
   * one buffer quantum available.
   */
  static constexpr uint32_t kMaxCapacity = ENSO_PIPE_SIZE * 64 - kQuantumSize;

  /**
   * @brief Returns the pipe's ID.
   *
   * @return The pipe's ID.
   */
  inline enso_pipe_id_t id() const { return kId; }

 private:
  /**
   * TxPipes can only be instantiated from a `Device` object, using the
   * `AllocateTxPipe()` method.
   *
   * @param id The pipe's ID.
   * @param device The `Device` object that instantiated this pipe.
   * @param buf Buffer address to use for the pipe. It must be a pinned
   *            hugepage. If not specified, the buffer is allocated internally.
   */
  explicit TxPipe(uint32_t id, Device* device, uint8_t* buf = nullptr) noexcept
      : kId(id), device_(device), buf_(buf), internal_buf_(buf == nullptr) {}

  /**
   * TxPipes cannot be deallocated from outside. The `Device` object is in
   * charge of deallocating them.
   */
  ~TxPipe();

  /**
   * @brief Initializes the TX pipe.
   *
   * @return 0 on success and a non-zero error code on failure.
   */
  int Init() noexcept;

  /**
   * @brief Notifies the Pipe that a given number of bytes have been sent.
   *
   * Should be used by the `Device` object only.
   *
   * @param nb_bytes The number of bytes that have been sent.
   */
  inline void NotifyCompletion(uint32_t nb_bytes) {
    app_end_ = (app_end_ + nb_bytes) & kBufMask;
  }

  friend class Device;

  const enso_pipe_id_t kId;  ///< The ID of the pipe.
  Device* device_;
  uint8_t* buf_;
  bool internal_buf_;       // If true, the buffer is allocated internally.
  uint32_t app_begin_ = 0;  // The next byte to be sent.
  uint32_t app_end_ = 0;    // The next byte to be allocated.
  uint64_t buf_phys_addr_;

  static constexpr uint32_t kBufMask = (kMaxCapacity + kQuantumSize) - 1;
  static_assert((kBufMask & (kBufMask + 1)) == 0,
                "(kBufMask + 1) must be a power of 2");

  // Buffer layout:
  //                                     | app_begin_          | app_end_
  //                                     v                     v
  //    +---+------------------------+---+---------------------+--------+
  //    |   |  Waiting transmission  |   |  Available to user  |        |
  //    +---+------------------------+---+---------------------+--------+
  //        ^                        ^
  //        | hw_begin_              | hw_end_
  //
  // The area available to the user is between `app_begin_` and `app_end_`.
  // The area between `hw_begin_` and `hw_end_` is waiting to be transmitted.
  //
  // SendAndFree() will advance `app_begin_` by `nb_bytes_`, reducing the
  // available space to the user. The size of the available region can be
  // obtained by calling `capacity()`.
  //
  // To reclaim space, the user must call `Extend()`, which will check for
  // completions and potentially advance the `hw_begin_`. We can then advance
  // `app_end_` to match `hw_begin_`, increasing the available space to the
  // user.
  //
  // All the buffer pointers (i.e., app_begin_, app_end_, hw_begin_, hw_end_)
  // are in units of 64 bytes. The buffer itself is a circular buffer, so
  // `app_end_` can be smaller than `app_begin_`.
  //
  // Currently app_begin_ == hw_end_ and app_end_ == hw_begin_. But this may
  // change in the future. One reason it might be useful to change this is that
  // currently `Device::Send()` blocks when the notification buffer is full. If
  // we make sending non-blocking, it may be useful to let the hw_*_ and app_*_
  // pointers diverge.
};

/**
 * @brief A class that represents an RX/TX Enso Pipe.
 *
 * This is suitable for applications that need to modify data in place and send
 * them back. Should be instantiated using a Device object.
 *
 * @see RxPipe for a description of the common methods for RX.
 *
 * Different from a TxPipe, an RxTxPipe can only be used to send data that has
 * been received, after potentially modifying it in place. Therefore, it lacks
 * most of the methods that are available in TxPipe.
 *
 * Example:
 * @code
 *    auto device = Device::Create(core_id, nb_pipes, pcie_addr);
 *    norman::RxTxPipe* rx_tx_pipe = device->AllocateRxTxPipe();
 *    rx_tx_pipe->Bind(...);
 *
 *    auto batch = rx_tx_pipe->RecvPkts();
 *    for (auto pkt : batch) {
 *      // Do something with the packet.
 *    }
 *    rx_tx_pipe->Send(batch_length);
 * @endcode
 */
class RxTxPipe {
 public:
  RxTxPipe(const RxTxPipe&) = delete;
  RxTxPipe& operator=(const RxTxPipe&) = delete;
  RxTxPipe(RxTxPipe&&) = delete;
  RxTxPipe& operator=(RxTxPipe&&) = delete;

  /**
   * @copydoc RxPipe::Bind
   */
  inline int Bind(uint16_t dst_port, uint16_t src_port, uint32_t dst_ip,
                  uint32_t src_ip, uint32_t protocol) {
    return rx_pipe_->Bind(dst_port, src_port, dst_ip, src_ip, protocol);
  }

  /**
   * @copydoc RxPipe::Recv
   */
  inline uint32_t Recv(uint8_t** buf, uint32_t max_nb_bytes) {
    device_->ProcessCompletions();
    return rx_pipe_->Recv(buf, max_nb_bytes);
  }

  /**
   * @copydoc RxPipe::Peek
   */
  inline uint32_t Peek(uint8_t** buf, uint32_t max_nb_bytes) {
    device_->ProcessCompletions();
    return rx_pipe_->Peek(buf, max_nb_bytes);
  }

  /**
   * @copydoc RxPipe::ConfirmBytes
   */
  inline void ConfirmBytes(uint32_t nb_bytes) {
    rx_pipe_->ConfirmBytes(nb_bytes);
  }

  /**
   * @copydoc RxPipe::RecvMessages
   */
  template <typename T>
  inline RxPipe::MessageBatch<T> RecvMessages(int32_t max_nb_messages = -1) {
    device_->ProcessCompletions();
    return rx_pipe_->RecvMessages<T>(max_nb_messages);
  }

  /**
   * @copydoc RxPipe::RecvPkts
   */
  inline RxPipe::MessageBatch<PktIterator> RecvPkts(int32_t max_nb_pkts = -1) {
    device_->ProcessCompletions();
    return rx_pipe_->RecvPkts(max_nb_pkts);
  }

  /**
   * @copydoc RxPipe::PeekPkts
   */
  inline RxPipe::MessageBatch<PeekPktIterator> PeekPkts(
      int32_t max_nb_pkts = -1) {
    device_->ProcessCompletions();
    return rx_pipe_->PeekPkts(max_nb_pkts);
  }

  /**
   * @brief Prefetches the next batch of bytes to be received on the RxTxPipe.
   */
  inline void Prefetch() { rx_pipe_->Prefetch(); }

  /**
   * @brief Sends a given number of bytes.
   *
   * You can only send bytes that have been received and confirmed. Such as
   * using Recv or a combination of Peek and ConfirmRecvBytes, as well as the
   * equivalent methods for messages.
   *
   * @param nb_bytes The number of bytes to send.
   */
  inline void Send(uint32_t nb_bytes) {
    tx_pipe_->SendAndFree(nb_bytes);
    last_tx_pipe_capacity_ -= nb_bytes;
  }

  /**
   * @brief Process completions for this pipe, potentially freeing up space to
   * receive more data.
   */
  inline void ProcessCompletions() {
    uint32_t new_capacity = tx_pipe_->capacity();

    // If the capacity has increased, we need to free up space in the RX pipe.
    if (new_capacity > last_tx_pipe_capacity_) {
      rx_pipe_->Free(new_capacity - last_tx_pipe_capacity_);
      last_tx_pipe_capacity_ = new_capacity;
    }
  }

  /**
   * @copydoc RxPipe::id
   */
  inline enso_pipe_id_t rx_id() const { return rx_pipe_->id(); }

  /**
   * @copydoc TxPipe::id
   */
  inline enso_pipe_id_t tx_id() const { return tx_pipe_->id(); }

 private:
  /**
   * Threshold for processing completions. If the RX pipe's capacity is greater
   * than this threshold, we process completions.
   */
  static constexpr uint32_t kCompletionsThreshold = ENSO_PIPE_SIZE * 64 / 2;

  /**
   * RxTxPipes can only be instantiated from a Device object, using the
   * `AllocateRxTxPipe()` method.
   *
   * @param id The ID of the pipe.
   * @param device The `Device` object that instantiated this pipe.
   */
  explicit RxTxPipe(Device* device) noexcept : device_(device) {}

  /**
   * RxTxPipes cannot be deallocated from outside. The `Device` object is in
   * charge of deallocating them.
   */
  ~RxTxPipe() = default;

  /**
   * @brief Initializes the RX/TX pipe.
   *
   * @return 0 on success and a non-zero error code on failure.
   */
  int Init() noexcept;

  friend class Device;

  Device* device_;
  RxPipe* rx_pipe_;
  TxPipe* tx_pipe_;
  uint32_t last_tx_pipe_capacity_;
};

/**
 * @brief Base class to represent a packet within a batch.
 *
 * It is designed to be used as an iterator. It tracks the number of missing
 * packets such that `operator!=` returns false whenever the limit is reached.
 *
 * `operator++` should be implemented by a derived class.
 */
template <typename T>
class PktIteratorBase {
 public:
  constexpr uint8_t* operator*() { return addr_; }

  /**
   * This is the only way to check if the iterator has reached the end of the
   * batch. It is necessary because the iterator is designed to be used in a
   * range-based for loop.
   */
  constexpr bool operator!=(const PktIteratorBase& other) const {
    return (missing_pkts_ != 0) && (next_addr_ <= other.addr_);
  }

 protected:
  /**
   * Only MessageBatch can instantiate a PktIteratorBase object.
   *
   * @param addr The address of the first packet.
   * @param pkt_limit The maximum number of packets to receive.
   * @param batch The batch associated with this iterator.
   */
  constexpr PktIteratorBase(uint8_t* addr, int32_t pkt_limit,
                            RxPipe::MessageBatch<T>* batch)
      : addr_(addr),
        next_addr_(get_next_pkt(addr)),
        missing_pkts_(pkt_limit),
        batch_(batch) {}

  /**
   * @brief Advances the iterator to the next packet.
   *
   * @return The number of bytes that have been processed by this iterator.
   */
  constexpr inline uint32_t AdvancePkt() {
    // We need to retrieve the next packet before we expose the current one to
    // the user. This prevents potential packet modifications from interfering
    // with the iterator.

    uint32_t nb_bytes = next_addr_ - addr_;

    addr_ = next_addr_;
    next_addr_ = get_next_pkt(addr_);

    --missing_pkts_;

    return nb_bytes;
  }

  friend class RxPipe::MessageBatch<T>;

  uint8_t* addr_;
  uint8_t* next_addr_;
  int32_t missing_pkts_;
  RxPipe::MessageBatch<T>* batch_;
};

/**
 * @brief A class that represents a packet within a batch.
 *
 * @see PktIteratorBase.
 */
class PktIterator : public PktIteratorBase<PktIterator> {
 public:
  /**
   * @brief Advances the iterator to the next packet.
   *
   * @return The iterator itself.
   */
  constexpr PktIteratorBase& operator++() {
    uint32_t nb_bytes = AdvancePkt();
    batch_->processed_bytes_ += nb_bytes;
    batch_->pipe_->ConfirmBytes(nb_bytes);
    return *this;
  }

 private:
  /**
   * @note Only MessageBatch can instantiate a PktIterator object.
   * @see PktIteratorBase::PktIteratorBase().
   */
  constexpr PktIterator(uint8_t* addr, int32_t pkt_limit,
                        RxPipe::MessageBatch<PktIterator>* batch)
      : PktIteratorBase<PktIterator>(addr, pkt_limit, batch) {}

  friend class RxPipe::MessageBatch<PktIterator>;
};

/**
 * @brief A class that represents a packet within a batch.
 *
 * It is designed to be used as an iterator. It tracks the number of missing
 * packets such that `operator!=` returns false whenever the limit is reached.
 *
 * The difference between this class and `PktIterator` is that this class does
 * not free the packets after they are iterated over.
 */
class PeekPktIterator : public PktIteratorBase<PeekPktIterator> {
 public:
  constexpr PeekPktIterator& operator++() {
    uint32_t nb_bytes = AdvancePkt();
    batch_->processed_bytes_ += nb_bytes;
    return *this;
  }

 private:
  /**
   * Only MessageBatch can instantiate a PeekPktIterator object.
   *
   * @param addr The address of the first packet.
   * @param pkt_limit The maximum number of packets to receive.
   * @param batch The batch associated with this iterator.
   */
  constexpr PeekPktIterator(uint8_t* addr, int32_t pkt_limit,
                            RxPipe::MessageBatch<PeekPktIterator>* batch)
      : PktIteratorBase<PeekPktIterator>(addr, pkt_limit, batch) {}

  friend class RxPipe::MessageBatch<PeekPktIterator>;
};

}  // namespace norman

#endif  // SOFTWARE_INCLUDE_NORMAN_PIPE_H_
