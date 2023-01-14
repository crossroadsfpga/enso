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
class intel_fpga_pcie_dev;

namespace norman {

class Device;
class PktIterator;
class PeekPktIterator;

uint32_t external_peek_next_batch_from_queue(
    struct RxEnsoPipeInternal* enso_pipe,
    struct NotificationBufPair* notification_buf_pair, void** buf);

/**
 * A class that represents an RX Enso Pipe.
 *
 * Should be instantiated using a Device object.
 *
 * Example:
 *    auto device = Device::Create(core_id, nb_pipes, pcie_addr);
 *    RxPipe* rx_pipe = device->AllocateRxPipe();
 *    rx_pipe->Bind(...);
 *
 *    auto batch = rx_pipe->RecvPkts(64);
 *    for (auto pkt : batch) {
 *      // Do something with the packet.
 *    }
 *    rx_pipe->FreeAllBytes();
 */
class RxPipe {
 public:
  /**
   * A class that represents a batch of packets.
   *
   * @param T An iterator for the particular message type. Refer to
   *          `norman::PktIterator` for an example of a raw packet iterator.
   */
  template <typename T>
  class MessageBatch {
   public:
    constexpr T begin() { return T(kBuf, kMessageLimit, pipe_); }
    constexpr T begin() const { return T(kBuf, kMessageLimit, pipe_); }
    constexpr T end() {
      return T(kBuf + kAvailableBytes, kMessageLimit, pipe_);
    }
    constexpr T end() const {
      return T(kBuf + kAvailableBytes, kMessageLimit, pipe_);
    }

    /**
     * Number of bytes available in the batch. It may include more packets than
     * `kMessageLimit`, in which case, iterating over the batch will result in
     * fewer bytes.
     */
    const uint32_t kAvailableBytes;

    /**
     * Maximum number of packets in the batch.
     */
    const uint32_t kMessageLimit;

    uint8_t* const kBuf;

   private:
    /**
     * Can only be constructed by RxPipe.
     *
     * @param buf A pointer to the start of the batch.
     * @param available_bytes The number of bytes available in the batch.
     * @param message_limit The maximum number of messages in the batch.
     * @param ConfirmBytesFunction A function that will be called to confirm
     *                             the bytes associated with each packet.
     */
    constexpr MessageBatch(uint8_t* buf, uint32_t available_bytes,
                           uint32_t message_limit, RxPipe* pipe)
        : kAvailableBytes(available_bytes),
          kMessageLimit(message_limit),
          kBuf(buf),
          pipe_(pipe) {}

    friend class RxPipe;

    RxPipe* pipe_;
  };

  RxPipe(const RxPipe&) = delete;
  RxPipe& operator=(const RxPipe&) = delete;
  RxPipe(RxPipe&&) = delete;
  RxPipe& operator=(RxPipe&&) = delete;

  /**
   * Binds the pipe to a given flow entry. Can be called multiple times.
   */
  int Bind();

  /**
   * Cleans all flow entries associated with queue.
   */
  int CleanBind();

  /**
   * Receives a batch of bytes.
   *
   * @param buf A pointer that will be set to the start of the received bytes.
   * @param max_nb_bytes The maximum number of bytes to receive.
   *
   * @return The number of bytes received or a negative error code.
   */
  uint32_t RecvBytes(uint8_t** buf, uint32_t max_nb_bytes);

  /**
   * Receives a batch of bytes without removing them from the queue.
   *
   * @param buf A pointer that will be set to the start of the received bytes.
   * @param max_nb_bytes The maximum number of bytes to receive.
   *
   * @return The number of bytes received or a negative error code.
   */
  uint32_t PeekRecvBytes(uint8_t** buf, uint32_t max_nb_bytes);

  /**
   * Confirms a certain number of bytes have been received. This will make sure
   * that the next call to `RecvBytes` or `PeekRecvBytes` will return a buffer
   * that starts at the next byte after the last confirmed byte.
   *
   * When using `RecvBytes`, this is not necessary, as `RecvBytes` will
   * automatically confirm the bytes received. You may use this to confirm bytes
   * received by `PeekRecvBytes`.
   *
   * @param nb_bytes The number of bytes to confirm (must be a multiple of 64).
   */
  void ConfirmBytes(uint32_t nb_bytes) {
    uint32_t enso_pipe_head = internal_rx_pipe_.rx_tail;
    enso_pipe_head = (enso_pipe_head + nb_bytes / 64) % ENSO_PIPE_SIZE;
    internal_rx_pipe_.rx_tail = enso_pipe_head;
  }

  /**
   * Receives a batch of generic messages.
   *
   * @param T An iterator for the particular message type. Refer to
   *          `norman::PktIterator` for an example of a raw packet iterator.
   * @param max_nb_messages The maximum number of messages to receive.
   * @return A MessageBatch object that can be used to iterate over the received
   *         messages.
   */
  template <typename T>
  MessageBatch<T> RecvMessages(uint32_t max_nb_messages) {
    void* buf;
    uint32_t recv = external_peek_next_batch_from_queue(
        &internal_rx_pipe_, notification_buf_pair_, &buf);
    return MessageBatch<T>((uint8_t*)buf, recv, max_nb_messages, this);
  }

  /**
   * Receives a batch of packets.
   *
   * @param max_nb_pkts The maximum number of packets to receive.
   * @return A MessageBatch object that can be used to iterate over the received
   *         packets.
   */
  MessageBatch<PktIterator> RecvPkts(uint32_t max_nb_pkts) {
    return RecvMessages<PktIterator>(max_nb_pkts);
  }

  /**
   * Receives a batch of packets without removing them from the queue.
   *
   * @param max_nb_pkts The maximum number of packets to receive.
   * @return A MessageBatch object that can be used to iterate over the received
   *         packets.
   */
  MessageBatch<PeekPktIterator> PeekRecvPkts(uint32_t max_nb_pkts) {
    return RecvMessages<PeekPktIterator>(max_nb_pkts);
  }

  /**
   * Frees a given number of bytes previously received on the RxPipe.
   *
   * @param nb_bytes The number of bytes to free.
   */
  void FreeBytes(uint32_t nb_bytes);

  /**
   * Frees all bytes previously received on the RxPipe.
   */
  void FreeAllBytes();

  /**
   * Send a given number of bytes previously received on the RxPipe.
   * This will also free the corresponding bytes, after transmission is done.
   * The user must be careful not to send more bytes than were received and to
   * make sure that sent bytes are not modified after calling this function.
   *
   * @param nb_bytes The number of bytes to send.
   * @return The number of bytes sent.
   */
  uint32_t SendBytes(uint32_t nb_bytes);

  const enso_pipe_id_t kId;  ///< The ID of the pipe.

 private:
  /**
   * RxPipes can only be instantiated from a `Device` object, using the
   * `AllocateRxPipe()` method.
   *
   * @param id The ID of the pipe.
   * @param notification_buf_pair The notification buffer pair to use for this
   *                              pipe.
   */
  explicit RxPipe(enso_pipe_id_t id,
                  struct NotificationBufPair* notification_buf_pair) noexcept
      : kId(id), notification_buf_pair_(notification_buf_pair) {}

  /**
   * RxPipes cannot be deallocated from outside. The `Device` object is in
   * charge of deallocating them.
   */
  virtual ~RxPipe();

  int Init(volatile struct QueueRegs* enso_pipe_regs) noexcept;

  friend class Device;

  struct RxEnsoPipeInternal internal_rx_pipe_;
  struct NotificationBufPair* notification_buf_pair_;
};

/**
 * A class that represents a TX Enso Pipe.
 *
 * Should be instantiated using a Device object.
 *
 * Example:
 *    auto device = Device::Create(core_id, nb_pipes, pcie_addr);
 *    TxPipe* tx_pipe = dev->AllocateTxPipe();
 *    uint8_t* buf = tx_pipe->AllocateBuf();
 *
 *    // This will block until the buffer is large enough. Ensure that the
 *    // applications is not TX bound to avoid this.
 *    tx_pipe->ExtendBuf(data_size);
 *
 *    // Alternatively, one may use TryExtendBuf to avoid blocking, potentially
 *    // dropping data instead of waiting.
 *
 *    // Fill the buffer with data.
 *    [...]
 *
 *    // Send the data and retrieve a new buffer.
 *    tx_pipe.SendAndFree(data_size);
 *    buf = tx_pipe.AllocateBuf();
 */
class TxPipe {
 public:
  TxPipe(const TxPipe&) = delete;
  TxPipe& operator=(const TxPipe&) = delete;
  TxPipe(TxPipe&&) = delete;
  TxPipe& operator=(TxPipe&&) = delete;

  /**
   * Allocate a buffer in the pipe.
   *
   * There can only be a single buffer allocated at a time for a given Pipe.
   * Calling this function again when a buffer is already allocated will return
   * the same address.
   *
   * The buffer capacity can be retrieved by calling `capacity()`. Note that the
   * buffer capacity can increase without notice but will never decrease. The
   * user can also explicitly request for the buffer to be extended by calling
   * `ExtendBuf()`.
   *
   * The buffer is valid until the user calls `SendAndFree()`. In which case,
   * the buffer will be freed and a new one must be allocated by calling this
   * function again.
   *
   * If SendAndFree() only partially sends the buffer, the previous buffer
   * address will still not be valid but allocating a new buffer will return a
   * a buffers that starts with the remaining data.
   *
   * @return The allocated buffer address.
   */
  uint8_t* AllocateBuf() const { return buf_ + app_begin_; }

  /**
   * Returns the allocated buffer's current available capacity.
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
   * Sends and deallocates a given number of bytes.
   *
   * After calling this function, the previous buffer address is no longer
   * valid. Accessing it will lead to undefined behavior. __The user must use
   * `AllocateBuf()` to allocate a new buffer after calling this function.__
   *
   * The pipe's capacity will also be reduced by the number of bytes sent. If
   * sending more bytes than the pipe's current capacity, the behavior is
   * undefined. The user must also make sure not to modify the sent bytes after
   * calling this function.
   *
   * @param nb_bytes The number of bytes to send. Must be a multiple of
   *                 `kQuantumSize`.
   */
  inline void SendAndFree(uint32_t nb_bytes);

  /**
   * Explicitly request a best-effort buffer extension.
   *
   * Will check for completed transmissions to try to extend the capacity of the
   * currently allocated buffer. After this, capacity will be at least as large
   * as it was before. The user can continue to use the same buffer address as
   * before.
   *
   * User may use `capacity()` to check the total number of available bytes
   * after calling this function or simply use the return value. Note that the
   * capacity will never be extended beyond kMaxCapacity.
   *
   * @return The new buffer capacity after extending.
   */
  inline uint32_t TryExtendBuf();

  /**
   * Explicitly request a buffer extension with a target capacity.
   *
   * Different from `TryExtendBuf()`, this function will block until the
   * capacity is at least as large as the target capacity. Other than that the
   * behavior is the same.
   *
   * User may use `capacity()` to check the total number of available bytes
   * after calling this function or simply use the return value. Note that the
   * capacity will never be extended beyond kMaxCapacity. Therefore, specifying
   * a target capacity larger than kMaxCapacity will freeze forever.
   *
   * @return The new buffer capacity after extending.
   */
  inline uint32_t ExtendBuf(uint32_t target_capacity) {
    uint32_t _capacity = capacity();
    assert(target_capacity <= kMaxCapacity);
    while (_capacity < target_capacity) {
      _capacity = TryExtendBuf();
    }
    return _capacity;
  }

  /**
   * Returns the number of bytes that are currently being transmitted.
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

 private:
  /**
   * TxPipes can only be instantiated from a `Device` object, using the
   * `AllocateTxPipe()` method.
   */
  explicit TxPipe(uint32_t id, Device* device) noexcept
      : kId(id), device_(device) {}

  /**
   * TxPipes cannot be deallocated from outside. The `Device` object is in
   * charge of deallocating them.
   */
  virtual ~TxPipe();

  int Init() noexcept;

  /**
   * Notifies the Pipe that a given number of bytes have been sent. Should be
   * used by the `Device` object only.
   *
   * @param nb_bytes The number of bytes that have been sent.
   */
  inline void NotifyCompletion(uint32_t nb_bytes) {
    app_end_ = (app_end_ + nb_bytes) & kBufMask;
  }

  friend class Device;

  const uint32_t kId;
  Device* device_;
  uint8_t* buf_;
  uint32_t app_begin_ = 0;  // The next byte to be sent.
  uint32_t app_end_ = 0;    // The next byte to be allocated.
  uint64_t buf_phys_addr_;

  static constexpr uint32_t kBufMask = (kMaxCapacity + kQuantumSize) - 1;
  static_assert((kBufMask & (kBufMask + 1)) == 0,
                "(kMaxCapacity + 1) must be a power of 2");

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
  // currently sends block when the notification buffer is full. If we make
  // sending non-blocking, it may be useful to let the hw_*_ and app_*_ pointers
  // diverge.
};

/**
 * A class that represents a packet within a batch. It is designed to be used as
 * an iterator. It tracks the number of missing packets such that `operator!=`
 * returns false whenever the limit is reached.
 */
class PktIterator {
 public:
  constexpr PktIterator& operator++() {
    // We need to retrieve the next packet before we expose the current one to
    // the user. This prevents potential packet modifications from interfering
    // with the iterator.

    pipe_->ConfirmBytes(next_addr_ - addr_);

    addr_ = next_addr_;
    next_addr_ = get_next_pkt(addr_);

    --missing_pkts_;

    return *this;
  }

  constexpr uint8_t* operator*() { return addr_; }

  /**
   * This is the only way to check if the iterator has reached the end of the
   * batch. It is necessary because the iterator is designed to be used in a
   * range-based for loop.
   */
  constexpr bool operator!=(const PktIterator& other) const {
    return (missing_pkts_ > 0) && (next_addr_ <= other.addr_);
  }

 private:
  /**
   * Only MessageBatch can instantiate a PktIterator object.
   *
   * @param addr The address of the first packet.
   * @param pkt_limit The maximum number of packets to receive.
   */
  constexpr PktIterator(uint8_t* addr, uint32_t pkt_limit, RxPipe* pipe)
      : addr_(addr),
        next_addr_(get_next_pkt(addr)),
        missing_pkts_(pkt_limit),
        pipe_(pipe) {}

  friend class RxPipe::MessageBatch<PktIterator>;

  uint8_t* addr_;
  uint8_t* next_addr_;
  int32_t missing_pkts_;
  RxPipe* pipe_;
};

// TODO(sadok): De-duplicate this code with PktIterator.
/**
 * A class that represents a packet within a batch. It is designed to be used as
 * an iterator. It tracks the number of missing packets such that `operator!=`
 * returns false whenever the limit is reached.
 *
 * The difference between this class and PktIterator is that this class does not
 * free the packets after they are iterated over.
 */
class PeekPktIterator {
 public:
  constexpr PeekPktIterator& operator++() {
    // We need to retrieve the next packet before we expose the current one to
    // the user. This prevents potential packet modifications from interfering
    // with the iterator.
    addr_ = next_addr_;
    next_addr_ = get_next_pkt(addr_);

    --missing_pkts_;

    return *this;
  }

  constexpr uint8_t* operator*() { return addr_; }

  /**
   * This is the only way to check if the iterator has reached the end of the
   * batch. It is necessary because the iterator is designed to be used in a
   * range-based for loop.
   */
  constexpr bool operator!=(const PeekPktIterator& other) const {
    return (missing_pkts_ > 0) && (next_addr_ <= other.addr_);
  }

 private:
  /**
   * Only MessageBatch can instantiate a PktIterator object.
   *
   * @param addr The address of the first packet.
   * @param pkt_limit The maximum number of packets to receive.
   */
  constexpr PeekPktIterator(uint8_t* addr, uint32_t pkt_limit, RxPipe* pipe)
      : addr_(addr),
        next_addr_(get_next_pkt(addr)),
        missing_pkts_(pkt_limit),
        pipe_(pipe) {}

  friend class RxPipe::MessageBatch<PeekPktIterator>;

  uint8_t* addr_;
  uint8_t* next_addr_;
  int32_t missing_pkts_;
  RxPipe* pipe_;
};

/**
 * A class that represents a device.
 *
 * Should be instantiated using the factory method `Create()`. Use separate
 * instances for each thread.
 *
 * Example:
 *    uint16_t core_id = 0;
 *    uint32_t nb_pipes = 4;
 *    std::string pcie_addr = "0000:01:00.0";
 *    auto device = Device::Create(core_id, nb_pipes, pcie_addr);
 */
class Device {
 public:
  /**
   * Factory method to create a device.
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

  virtual ~Device();

  /**
   * Allocates a pipe.
   * @return A pointer to the pipe. May be null if the pipe cannot be created.
   */
  RxPipe* AllocateRxPipe() noexcept;

  /**
   * Allocates a pipe.
   * @return A pointer to the pipe. May be null if the pipe cannot be created.
   */
  TxPipe* AllocateTxPipe() noexcept;

  RxPipe& NextPipeToRecv();

  static constexpr uint32_t kMaxPendingTxRequests = MAX_PENDING_TX_REQUESTS;

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

  int Init() noexcept;

  /**
   * Sends a certain number of bytes to the device. This is designed to be used
   * by a TxPipe object.
   *
   * @param tx_enso_pipe_id The ID of the TxPipe.
   * @param phys_addr The physical address of the buffer region to send.
   * @param nb_bytes The number of bytes to send.
   * @return The number of bytes sent.
   */
  void SendBytes(uint32_t tx_enso_pipe_id, uint64_t phys_addr,
                 uint32_t nb_bytes);

  void ProcessTxCompletions();

  friend class TxPipe;

  const std::string kPcieAddr;
  const uint32_t kNbRxPipes;

  intel_fpga_pcie_dev* fpga_dev_;
  struct NotificationBufPair notification_buf_pair_;
  int16_t core_id_;
  uint16_t bdf_;
  void* uio_mmap_bar2_addr_;

  std::vector<RxPipe*> rx_pipes_;
  std::vector<TxPipe*> tx_pipes_;

  uint32_t tx_pr_head_ = 0;
  uint32_t tx_pr_tail_ = 0;
  std::array<TxPendingRequest, kMaxPendingTxRequests + 1> tx_pending_requests_;
  static constexpr uint32_t kPendingTxRequestsBufMask = kMaxPendingTxRequests;
  static_assert((kMaxPendingTxRequests & (kMaxPendingTxRequests + 1)) == 0,
                "kMaxPendingTxRequests + 1 must be a power of 2");
};

// Needs to be implemented after Device class.
inline void TxPipe::SendAndFree(uint32_t nb_bytes) {
  uint64_t phys_addr = buf_phys_addr_ + app_begin_;
  assert(((app_end_ - app_begin_) & kBufMask) + nb_bytes <= kMaxCapacity);
  assert(nb_bytes <= kMaxCapacity);
  assert(nb_bytes / kQuantumSize * kQuantumSize == nb_bytes);

  app_begin_ = (app_begin_ + nb_bytes) & kBufMask;

  device_->SendBytes(kId, phys_addr, nb_bytes);
}

// Needs to be implemented after Device class.
inline uint32_t TxPipe::TryExtendBuf() {
  device_->ProcessTxCompletions();
  return capacity();
}

}  // namespace norman

#endif  // SOFTWARE_INCLUDE_NORMAN_PIPE_H_
