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

#ifndef SOFTWARE_INCLUDE_NORMAN_DEV_H_
#define SOFTWARE_INCLUDE_NORMAN_DEV_H_

#include <norman/helpers.h>
#include <norman/internals.h>

#include <functional>
#include <memory>
#include <string>
#include <vector>

// Avoid exposing `intel_fpga_pcie_api.hpp` externally.
class intel_fpga_pcie_dev;

namespace norman {

class PktIterator;
class PeekPktIterator;

int external_peek_next_batch_from_queue(
    struct RxEnsoPipeInternal* enso_pipe,
    struct NotificationBufPair* notification_buf_pair, void** buf);

/**
 * A class that represents an RX Enso Pipe.
 *
 * Should be instantiated using a Device object.
 *
 * Example:
 *    auto device = Device::Create(core_id, nb_pipes, pcie_addr);
 *    RxTxPipe* pipe = device->AllocateRxTxPipe();
 *    pipe->Bind();
 *
 *    auto batch = pipe->RecvPkts(64);
 *    for (auto pkt : batch) {
 *      // Do something with the packet.
 *    }
 *    pipe->FreeAllBytes();
 */
class RxTxPipe {
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

   private:
    /**
     * Can only be constructed by RxTxPipe.
     *
     * @param buf A pointer to the start of the batch.
     * @param available_bytes The number of bytes available in the batch.
     * @param message_limit The maximum number of messages in the batch.
     * @param ConfirmBytesFunction A function that will be called to confirm
     *                             the bytes associated with each packet.
     */
    constexpr MessageBatch(uint8_t* buf, uint32_t available_bytes,
                           uint32_t message_limit, RxTxPipe* pipe)
        : kAvailableBytes(available_bytes),
          kMessageLimit(message_limit),
          kBuf(buf),
          pipe_(pipe) {}

    friend class RxTxPipe;

    uint8_t* const kBuf;
    RxTxPipe* pipe_;
  };

  RxTxPipe(const RxTxPipe&) = delete;
  RxTxPipe& operator=(const RxTxPipe&) = delete;
  RxTxPipe(RxTxPipe&&) = delete;
  RxTxPipe& operator=(RxTxPipe&&) = delete;

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
  int32_t RecvBytes(uint8_t** buf, uint32_t max_nb_bytes);

  /**
   * Receives a batch of bytes without removing them from the queue.
   *
   * @param buf A pointer that will be set to the start of the received bytes.
   * @param max_nb_bytes The maximum number of bytes to receive.
   *
   * @return The number of bytes received or a negative error code.
   */
  int32_t PeekRecvBytes(uint8_t** buf, uint32_t max_nb_bytes) const;

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
    uint32_t enso_pipe_head = rx_pipe_.rx_tail;
    enso_pipe_head = (enso_pipe_head + nb_bytes / 64) % ENSO_PIPE_SIZE;
    rx_pipe_.rx_tail = enso_pipe_head;
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
    int recv = external_peek_next_batch_from_queue(
        &rx_pipe_, notification_buf_pair_, &buf);
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
   * Frees a given number of bytes previously received on the RxTxPipe.
   *
   * @param nb_bytes The number of bytes to free.
   */
  void FreeBytes(uint32_t nb_bytes);

  /**
   * Frees all bytes previously received on the RxTxPipe.
   */
  void FreeAllBytes();

  /**
   * Send a given number of bytes previously received on the RxTxPipe.
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
   * `AllocateRxTxPipe()` method.
   *
   * @param id The ID of the pipe.
   * @param notification_buf_pair The notification buffer pair to use for this
   *                             pipe.
   */
  RxTxPipe(enso_pipe_id_t id,
           struct NotificationBufPair* notification_buf_pair) noexcept
      : kId(id), notification_buf_pair_(notification_buf_pair) {}

  /**
   * Pipes cannot be deallocated from outside. The `Device` object is in charge
   * of deallocating them.
   */
  virtual ~RxTxPipe();

  int Init(volatile struct QueueRegs* enso_pipe_regs) noexcept;

  friend class Device;

  struct RxEnsoPipeInternal rx_pipe_;
  struct NotificationBufPair* notification_buf_pair_;
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
  constexpr PktIterator(uint8_t* addr, uint32_t pkt_limit, RxTxPipe* pipe)
      : addr_(addr),
        next_addr_(get_next_pkt(addr)),
        missing_pkts_(pkt_limit),
        pipe_(pipe) {}

  friend class RxTxPipe::MessageBatch<PktIterator>;

  uint8_t* addr_;
  uint8_t* next_addr_;
  int32_t missing_pkts_;
  RxTxPipe* pipe_;
};

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
  constexpr PeekPktIterator(uint8_t* addr, uint32_t pkt_limit, RxTxPipe* pipe)
      : addr_(addr),
        next_addr_(get_next_pkt(addr)),
        missing_pkts_(pkt_limit),
        pipe_(pipe) {}

  friend class RxTxPipe::MessageBatch<PeekPktIterator>;

  uint8_t* addr_;
  uint8_t* next_addr_;
  int32_t missing_pkts_;
  RxTxPipe* pipe_;
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
   * @param nb_pipes The number of queues to create. TODO(sadok): This should
   *                  not be needed.
   * @param core_id The core ID of the thread that will access the device. If
   *                -1, uses the current core.
   * @param pcie_addr The PCIe address of the device. If empty, uses the first
   *                  device found.
   * @return A unique pointer to the device. May be null if the device cannot be
   *         created.
   */
  static std::unique_ptr<Device> Create(
      uint32_t nb_pipes, int16_t core_id = -1,
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
  RxTxPipe* AllocateRxTxPipe() noexcept;

 private:
  /**
   * Use `Create` factory method to instantiate objects externally.
   */
  Device(uint32_t nb_pipes, int16_t core_id,
         const std::string& pcie_addr) noexcept
      : kPcieAddr(pcie_addr), kNbPipes(nb_pipes), core_id_(core_id) {
    pipes_.reserve(kNbPipes);
  }

  int Init() noexcept;

  RxTxPipe& NextPipeToRecv();

  const std::string kPcieAddr;
  const uint32_t kNbPipes;
  intel_fpga_pcie_dev* fpga_dev_;
  struct NotificationBufPair notification_buf_pair_;
  int16_t core_id_;
  uint16_t bdf_;
  void* uio_mmap_bar2_addr_;
  std::vector<RxTxPipe*> pipes_;
};

}  // namespace norman

#endif  // SOFTWARE_INCLUDE_NORMAN_DEV_H_
