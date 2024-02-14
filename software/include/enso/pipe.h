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

#ifndef SOFTWARE_INCLUDE_ENSO_PIPE_H_
#define SOFTWARE_INCLUDE_ENSO_PIPE_H_

#include <enso/consts.h>
#include <enso/helpers.h>
#include <enso/internals.h>

#include <array>
#include <cassert>
#include <functional>
#include <iostream>
#include <memory>
#include <string>
#include <vector>

namespace enso {

class RxPipe;
class TxPipe;
class RxTxPipe;

class PktIterator;
class PeekPktIterator;

/**
 * @brief A class that represents a device.
 *
 * Should be instantiated using the factory method `Create()`. Use separate
 * instances for each thread.
 *
 * Example:
 * @code
 *    std::string pcie_addr = "0000:01:00.0";
 *    auto device = Device::Create(pcie_addr);
 * @endcode
 */
class Device {
 public:
  /**
   * @brief Factory method to create a device.
   *
   * @param pcie_addr The PCIe address of the device. If empty, uses the first
   *                  device found.
   * @param huge_page_prefix The prefix to use for huge pages file. If empty,
   *                         uses the default prefix.
   * @return A unique pointer to the device. May be null if the device cannot be
   *         created.
   */
  static std::unique_ptr<Device> Create(
      const std::string& pcie_addr = "",
      const std::string& huge_page_prefix = "") noexcept;

  Device(const Device&) = delete;
  Device& operator=(const Device&) = delete;
  Device(Device&&) = delete;
  Device& operator=(Device&&) = delete;

  ~Device();

  /**
   * @brief Allocates an RX pipe.
   *
   * @param fallback Whether this pipe is a fallback pipe. Fallback pipes can
   *                 receive data from any flow but are also guaranteed to
   *                 receive data from all flows that they `Bind()` to.
   *
   * @note The hardware can only use a number of fallback pipes that is a power
   *       of two. If the number of fallback pipes is not a power of two, only
   *       the first power of two pipes allocated will be used.
   *
   * @warning Fallback pipes should be used by only one application at a time.
   *          If multiple applications use fallback pipes at once, the behavior
   *          is undefined.
   *
   * @return A pointer to the pipe. May be null if the pipe cannot be created.
   */
  RxPipe* AllocateRxPipe(bool fallback = false) noexcept;

  /**
   * @brief Allocates a TX pipe.
   *
   * @param buf Buffer address to use for the pipe. It must be a pinned
   *            hugepage. If not specified, the buffer is allocated
   *            internally.
   * @return A pointer to the pipe. May be null if the pipe cannot be
   *         created.
   */
  TxPipe* AllocateTxPipe(uint8_t* buf = nullptr) noexcept;

  /**
   * @brief Retrieves the number of fallback queues for this device.
   */
  int GetNbFallbackQueues() noexcept;

  /**
   * @brief Allocates an RX/TX pipe.
   *
   * @param fallback Whether this pipe is a fallback pipe. Fallback pipes can
   *                 receive data from any flow but are also guaranteed to
   *                 receive data from all flows that they `Bind()` to.
   *
   * @note The hardware can only use a number of fallback pipes that is a power
   *       of two. If the number of fallback pipes is not a power of two, only
   *       the first power of two pipes allocated will be used.
   *
   * @warning Fallback pipes should be used by only one application at a time.
   *          If multiple applications use fallback pipes at once, the behavior
   *          is undefined.
   *
   * @return A pointer to the pipe. May be null if the pipe cannot be created.
   */
  RxTxPipe* AllocateRxTxPipe(bool fallback = false) noexcept;

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
   * @brief Processes completions for all pipes associated with this device.
   */
  void ProcessCompletions();

  /**
   * @brief Enables hardware time stamping.
   *
   * All outgoing packets will receive a timestamp and all incoming packets will
   * have an RTT (in number of cycles). Use `get_pkt_rtt` to retrieve the value.
   *
   * @note This setting applies to all pipes that share the same hardware
   *       device.
   * @see DisableTimeStamping
   * @see get_pkt_rtt
   */
  int EnableTimeStamping();

  /**
   * @brief Disables hardware time stamping.
   *
   * @note This setting applies to all pipes that share the same hardware
   *       device.
   * @see EnableTimeStamping
   */
  int DisableTimeStamping();

  /**
   * @brief Enables hardware rate limiting.
   *
   * Once rate limiting is enabled, packets from all queues are sent at a rate
   * of `num / den * kMaxHardwareFlitRate` flits per second (a flit is 64
   * bytes). Note that this is slightly different from how we typically define
   * throughput and you will need to take the packet sizes into account to set
   * this properly.
   *
   * For example, suppose that you are sending 64-byte packets. Each packet
   * occupies exactly one flit. For this packet size, line rate at 100Gbps is
   * 148.8Mpps. So if `kMaxHardwareFlitRate` is 200MHz, line rate actually
   * corresponds to a 744/1000 rate. Therefore, if you want to send at 50Gbps
   * (50% of line rate), you can use a 372/1000 (or 93/250) rate.
   *
   * The other thing to notice is that, while it might be tempting to use a
   * large denominator in order to increase the rate precision. This has the
   * side effect of increasing burstiness. The way the rate limit is
   * implemented, we send a burst of `num` consecutive flits every `den` cycles.
   * Which means that if `num` is too large, it might overflow the receiver
   * buffer. For instance, in the example above, 93/250 would be a better rate
   * than 372/1000. And 3/8 would be even better with a slight loss in
   * precision.
   *
   * You can find the maximum packet rate for any packet size by using the
   * expression: `line_rate / ((pkt_size + 20) * 8)`. So for 100Gbps and
   * 128-byte packets we have: `100e9 / ((128 + 20) * 8)` packets per second.
   * Given that each packet is two flits, for `kMaxHardwareFlitRate = 200e6`,
   * the maximum rate is `100e9 / ((128 + 20) * 8) * 2 / 200e6`, which is
   * approximately 125/148. Therefore, if you want to send packets at 20Gbps
   * (20% of line rate), you should use a 25/148 rate.
   *
   * @note This setting applies to all pipes that share the same hardware
   *       device.
   *
   * @see DisableRateLimiting
   *
   * @param num Rate numerator.
   * @param den Rate denominator.
   * @return 0 if configuration was successful.
   */
  int EnableRateLimiting(uint16_t num, uint16_t den);

  /**
   * @brief Disables hardware rate limiting.
   *
   * @note This setting applies to all pipes that share the same hardware
   *       device.
   *
   * @see EnableRateLimiting
   *
   * @return 0 if configuration was successful.
   */
  int DisableRateLimiting();

  /**
   * @brief Enables round robing of packets among the fallback pipes.
   *
   * @note This setting applies to all pipes that share the same hardware
   *       device.
   *
   * @see DisableRoundRobin
   *
   * @return 0 if configuration was successful.
   */
  int EnableRoundRobin();

  /**
   * @brief Disables round robing of packets among the fallback pipes. Will use
   *        a hash of the five-tuple to direct flows not binded to any pipe.
   *
   * @note This setting applies to all pipes that share the same hardware
   *       device.
   *
   * @see EnableRoundRobin
   *
   * @return 0 if configuration was successful.
   */
  int DisableRoundRobin();

  /**
   * @brief Gets the round robin status for the device.
   *
   * @return 0 if round robin is disabled, 1 if round robin is enabled, -1 on
   *         failure.
   */
  int GetRoundRobinStatus() noexcept;

  /**
   * @brief Sends the given config notification to the device.
   *
   * @param config_notification The config notification.
   * @return 0 on success, -1 on failure.
   */
  int ApplyConfig(struct TxNotification* config_notification);

 private:
  struct TxPendingRequest {
    uint32_t pipe_id;
    uint32_t nb_bytes;
  };

  /**
   * Use `Create` factory method to instantiate objects externally.
   */
  Device(const std::string& pcie_addr, std::string huge_page_prefix) noexcept
      : kPcieAddr(pcie_addr) {
#ifndef NDEBUG
    std::cerr << "Warning: assertions are enabled. Performance may be affected."
              << std::endl;
#endif  // NDEBUG
    if (huge_page_prefix == "") {
      huge_page_prefix = std::string(kHugePageDefaultPrefix);
    }
    huge_page_prefix_ = huge_page_prefix;
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

  struct NotificationBufPair notification_buf_pair_;
  int16_t core_id_;
  uint16_t bdf_;
  std::string huge_page_prefix_;

  std::vector<RxPipe*> rx_pipes_;
  std::vector<TxPipe*> tx_pipes_;
  std::vector<RxTxPipe*> rx_tx_pipes_;

  std::array<RxPipe*, kMaxNbFlows> rx_pipes_map_ = {};
  std::array<RxTxPipe*, kMaxNbFlows> rx_tx_pipes_map_ = {};

  int32_t next_pipe_id_ = -1;

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
   *          `enso::PktIterator` for an example of a raw packet iterator.
   */
  template <typename T>
  class MessageBatch {
   public:
    /**
     * @brief Instantiates an empty message batch.
     */
    constexpr MessageBatch() : MessageBatch(nullptr, 0, 0, nullptr) {}

    MessageBatch(const MessageBatch&) = default;
    MessageBatch(MessageBatch&&) = default;

    MessageBatch& operator=(const MessageBatch&) = default;
    MessageBatch& operator=(MessageBatch&&) = default;

    constexpr T begin() { return T(buf_, message_limit_, this); }
    constexpr T begin() const { return T(buf_, message_limit_, this); }

    constexpr T end() {
      return T(buf_ + available_bytes_, message_limit_, this);
    }
    constexpr T end() const {
      return T(buf_ + available_bytes_, message_limit_, this);
    }

    /**
     * @brief Number of bytes processed by the iterator.
     */
    uint32_t processed_bytes() const { return processed_bytes_; }

    /**
     * @brief Notifies the batch that a given number of bytes have been
     *        processed.
     *
     * @param nb_bytes The number of bytes processed.
     */
    inline void NotifyProcessedBytes(uint32_t nb_bytes) {
      processed_bytes_ += nb_bytes;
    }

    /**
     * @brief Returns number of bytes available in the batch.
     *
     * @note It may include more messages than `message_limit()`, in which case,
     * iterating over the batch will result in fewer bytes than
     * `available_bytes()`. After iterating over the batch, the total number of
     * bytes iterated over can be obtained by calling `processed_bytes()`.
     *
     * @return The number of bytes available in the batch.
     */
    uint32_t available_bytes() const { return available_bytes_; }

    /**
     * @brief Returns maximum number of messages in the batch.
     *
     * @return The maximum number of messages in the batch.
     */
    int32_t message_limit() const { return message_limit_; }

    /**
     * @brief Returns a pointer to the start of the batch.
     *
     * @return A pointer to the start of the batch.
     */
    uint8_t* buf() const { return buf_; }

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
        : available_bytes_(available_bytes),
          message_limit_(message_limit),
          buf_(buf),
          pipe_(pipe) {}

    friend class RxPipe;
    friend T;

    uint32_t available_bytes_;
    int32_t message_limit_;
    uint8_t* buf_;
    uint32_t processed_bytes_ = 0;
    RxPipe* pipe_;
  };

  RxPipe(const RxPipe&) = delete;
  RxPipe& operator=(const RxPipe&) = delete;
  RxPipe(RxPipe&&) = delete;
  RxPipe& operator=(RxPipe&&) = delete;

  /**
   * @brief Binds the pipe to a given flow entry. Can be called multiple times
   *        to bind to multiple flows.
   *
   * @warning Currently the hardware ignores the source IP and source port for
   *          UDP packets. You **must** set them to 0 when binding to UDP.
   *
   * @note Binding semantics depend on the functionality implemented on the NIC.
   *       More flexible steering may require different kinds of bindings.
   *
   * While binding semantics will vary for different NIC implementations, here
   * we describe how the NIC implementation that accompanies Enso behaves.
   *
   * Every call to `Bind()` will result in a new flow entry being created on the
   * NIC using all the fields specified in the function arguments (5-tuple). For
   * every incoming packet, the NIC will try to find a matching flow entry. If
   * it does, it will steer the packet to the corresponding RX pipe. If it
   * does not, it will steer the packet to one of the fallback pipes, or dropped
   * if there are no fallback pipes.
   *
   * The fields that are used to find a matching entry depend on the incoming
   * packet:
   * - If the packet protocol is TCP (`6`):
   *   - If the SYN flag is set, the NIC will match it to a flow entry based on
   *     dst IP, dst port, and protocol, all the other fields will be set to 0
   *     when looking for a matching flow entry.
   *   - For TCP packets without a SYN flag set, the NIC will use all the
   *     fields, i.e., dst IP, dst port, src IP, src port, and protocol.
   * - If the packet protocol is UDP (`17`), the NIC will use only dst IP, dst
   *   port, and protocol when looking for a matching flow entry. All the other
   *   fields will be set to 0.
   * - For all the other protocols, the NIC will use only the destination IP
   *   when looking for a matching flow entry. All the other fields will be set
   *   to 0.
   *
   * Therefore, if you want to listen for new TCP connections, you should bind
   * to the destination IP and port and set all the other fields to 0. If you
   * want to receive packets from an open TCP connection, you should bind to
   * all the fields, i.e., dst IP, dst port, src IP, src port, and protocol. If
   * you want to receive UDP packets, you should bind to the destination IP
   * and port and set all the other fields to 0.
   *
   * @param dst_port Destination port (little-endian).
   * @param src_port Source port (little-endian).
   * @param dst_ip Destination IP (little-endian).
   * @param src_ip Source IP (little-endian).
   * @param protocol Protocol (little-endian).
   *
   * @return 0 on success, a different value otherwise.
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
  uint32_t PeekFromTail(uint8_t** buf, uint32_t max_nb_bytes);

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
    rx_tail = (rx_tail + nb_bytes / 64) % kEnsoPipeSize;
    internal_rx_pipe_.rx_tail = rx_tail;
  }

  /**
   * @brief Returns the number of bytes allocated in the pipe, i.e., the number
   *        of bytes owned by the application.
   *
   * @return The number of bytes allocated in the pipe.
   */
  constexpr uint32_t capacity() const {
    uint32_t rx_head = internal_rx_pipe_.rx_head;
    uint32_t rx_tail = internal_rx_pipe_.rx_tail;
    return ((rx_head - rx_tail) % kEnsoPipeSize) * 64;
  }

  /**
   * @brief Receives a batch of generic messages.
   *
   * @param T An iterator for the particular message type. Refer to
   *          `enso::PktIterator` for an example of a raw packet
   *          iterator.
   * @param max_nb_messages The maximum number of messages to receive. If set to
   *                        -1, all messages in the pipe will be received.
   *
   * @return A MessageBatch object that can be used to iterate over the received
   *         messages.
   */
  template <typename T>
  constexpr MessageBatch<T> RecvMessages(int32_t max_nb_messages = -1) {
    uint8_t* buf = nullptr;
    uint32_t recv = Peek(&buf, ~0);
    return MessageBatch<T>((uint8_t*)buf, recv, max_nb_messages, this);
  }

  template <typename T>
  constexpr MessageBatch<T> RecvMessagesFromTail(int32_t max_nb_messages = -1) {
    uint8_t* buf = nullptr;
    uint32_t recv = PeekFromTail(&buf, ~0);
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

  inline MessageBatch<PeekPktIterator> PeekPktsFromTail(int32_t max_nb_pkts = -1) {
    return RecvMessagesFromTail<PeekPktIterator>(max_nb_pkts);
  }

  /**
   * @brief Prefetches the next batch of bytes to be received on the RxPipe.
   *
   * @warning *Explicit* prefetching from the application cannot be used in
   *          conjunction with the `NextRxPipeToRecv` and `NextRxTxPipeToRecv`
   *          functions. These functions only support *implicit* prefetching,
   *          which can be enabled by compiling the library with
   *          `-Dlatency_opt=true` (the default).
   */
  void Prefetch();

  /**
   * @brief Frees a given number of bytes previously received on the RxPipe.
   *
   * @see Clear()
   *
   * @param nb_bytes The number of bytes to free.
   */
  void Free(uint32_t nb_bytes);

  /**
   * @brief Frees all bytes previously received on the RxPipe.
   *
   * @see Free()
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
  inline enso_pipe_id_t id() const { return id_; }

  /**
   * @brief Returns the context associated with the pipe.
   *
   * Applications can use context to associate arbitrary pointers with a given
   * pipe that can later be retrieved in a different point. For instance, when
   * using Device::NextRxPipeToRecv(), the application may use the context to
   * retrieve application data associated with the returned pipe.
   *
   * @see RxPipe::set_context()
   *
   * @return The context associated with the pipe.
   */
  inline void* context() const { return context_; }

  /**
   * @brief Sets the context associated with the pipe.
   *
   * @see RxPipe::context()
   */
  inline void set_context(void* new_context) { context_ = new_context; }

  /**
   * The size of a "buffer quantum" in bytes. This is the minimum unit that can
   * be sent at a time. Every transfer should be a multiple of this size.
   */
  static constexpr uint32_t kQuantumSize = 64;

  /**
   * Maximum capacity achievable by the pipe. There should always be at least
   * one buffer quantum available.
   */
  static constexpr uint32_t kMaxCapacity = kEnsoPipeSize * 64 - kQuantumSize;

 private:
  /**
   * RxPipes can only be instantiated from a `Device` object, using the
   * `AllocateRxPipe()` method.
   *
   * @param device The `Device` object that instantiated this pipe.
   */
  explicit RxPipe(Device* device) noexcept
      : notification_buf_pair_(&(device->notification_buf_pair_)) {}

  /**
   * @note RxPipes cannot be deallocated from outside. The `Device` object is in
   * charge of deallocating them.
   */
  ~RxPipe();

  /**
   * @brief Initializes the RX pipe.
   *
   * @param fallback Whether this pipe is a fallback pipe.
   *
   * @return 0 on success and a non-zero error code on failure.
   */
  int Init(bool fallback) noexcept;

  void SetAsNextPipe() noexcept { next_pipe_ = true; }

  friend class Device;

  bool next_pipe_ = false;  ///< Whether this pipe is the next pipe to be
                            ///< processed by the device. This is used in
                            ///< conjunction with NextRxPipeToRecv().
  enso_pipe_id_t id_;       ///< The ID of the pipe.
  void* context_;
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
 *    enso::Device* device = enso::Device::Create(pcie_addr);
 *    enso::TxPipe* tx_pipe = device->AllocateTxPipe();
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
   * @brief Allocates a buffer in the pipe.
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
   *                        avoid blocking (the default).
   *
   * @return The allocated buffer address.
   */
  uint8_t* AllocateBuf(uint32_t target_capacity = 0) {
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
   *       calling this function.
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
   * @brief Returns the pipe's internal buffer.
   *
   * @return A pointer to the start of the pipe's internal buffer.
   */
  inline uint8_t* buf() const { return buf_; }

  /**
   * @brief Returns the pipe's ID.
   *
   * @return The pipe's ID.
   */
  inline enso_pipe_id_t id() const { return kId; }

  /**
   * @brief Returns the context associated with the pipe.
   *
   * Applications can use context to associate arbitrary pointers with a given
   * pipe that can later be retrieved in a different point.
   *
   * @see TxPipe::set_context()
   *
   * @return The context associated with the pipe.
   */
  inline void* context() const { return context_; }

  /**
   * @brief Sets the context associated with the pipe.
   *
   * @see TxPipe::context()
   */
  inline void set_context(void* new_context) { context_ = new_context; }

  /**
   * The size of a "buffer quantum" in bytes. This is the minimum unit that can
   * be sent at a time. Every transfer should be a multiple of this size.
   */
  static constexpr uint32_t kQuantumSize = 64;

  /**
   * Maximum capacity achievable by the pipe. There should always be at least
   * one buffer quantum available.
   */
  static constexpr uint32_t kMaxCapacity = kEnsoPipeSize * 64 - kQuantumSize;

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
   * @note TxPipes cannot be deallocated from outside. The `Device` object is in
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

  inline std::string GetHugePageFilePath() const {
    return device_->huge_page_prefix_ + std::string(kHugePagePathPrefix) +
           std::to_string(kId);
  }

  friend class Device;

  const enso_pipe_id_t kId;  ///< The ID of the pipe.
  void* context_;
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
 *    enso::RxTxPipe* rx_tx_pipe = device->AllocateRxTxPipe();
 *    rx_tx_pipe->Bind(...);
 *
 *    auto batch = rx_tx_pipe->RecvPkts();
 *    for (auto pkt : batch) {
 *      // Do something with the packet.
 *    }
 *    rx_tx_pipe->SendAndFree(batch_length);
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
   * @copydoc RxPipe::PeekPktsFromTail
   */
  inline RxPipe::MessageBatch<PeekPktIterator> PeekPktsFromTail(
      int32_t max_nb_pkts = -1) {
    device_->ProcessCompletions();
    return rx_pipe_->PeekPktsFromTail(max_nb_pkts);
  }

  /**
   * @brief Prefetches the next batch of bytes to be received on the RxTxPipe.
   *
   * @warning *Explicit* prefetching from the application cannot be used in
   *          conjunction with the `NextRxPipeToRecv` and `NextRxTxPipeToRecv`
   *          functions. These functions only support *implicit* prefetching,
   *          which can be enabled by compiling the library with
   *          `-Dlatency_opt=true` (the default).
   */
  inline void Prefetch() { rx_pipe_->Prefetch(); }

  /**
   * @brief Sends and deallocates a given number of bytes.
   *
   * You can only send bytes that have been received and confirmed. Such as
   * using `Recv` or a combination of `Peek` and `ConfirmBytes`, as well as the
   * equivalent methods for raw packets and messages.
   *
   * @param nb_bytes The number of bytes to send.
   */
  inline void SendAndFree(uint32_t nb_bytes) {
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
   * @brief Returns the pipe's internal buffer.
   *
   * @return A pointer to the start of the pipe's internal buffer.
   */
  inline uint8_t* buf() const { return rx_pipe_->buf(); }

  /**
   * @brief Return the pipe's RX ID.
   *
   * @return The pipe's RX ID.
   */
  inline enso_pipe_id_t rx_id() const { return rx_pipe_->id(); }

  /**
   * @brief Return the pipe's TX ID.
   *
   * @return The pipe's TX ID.
   */
  inline enso_pipe_id_t tx_id() const { return tx_pipe_->id(); }

  /**
   * @brief Returns the context associated with the pipe.
   *
   * Applications can use context to associate arbitrary pointers with a given
   * pipe that can later be retrieved in a different point. For instance, when
   * using Device::NextRxTxPipeToRecv(), the application may use the context to
   * retrieve application data associated with the returned pipe.
   *
   * @see RxTxPipe::set_context()
   *
   * @return The context associated with the pipe.
   */
  inline void* context() const { return rx_pipe_->context(); }

  /**
   * @brief Sets the context associated with the pipe.
   *
   * @see RxTxPipe::context()
   */
  inline void set_context(void* new_context) {
    rx_pipe_->set_context(new_context);
  }

  /**
   * @copydoc RxPipe::kQuantumSize
   */
  static constexpr uint32_t kQuantumSize = RxPipe::kQuantumSize;

  /**
   * @copydoc RxPipe::kMaxCapacity
   */
  static constexpr uint32_t kMaxCapacity = RxPipe::kMaxCapacity;

  static_assert(RxPipe::kQuantumSize == TxPipe::kQuantumSize,
                "Quantum size mismatch");
  static_assert(RxPipe::kMaxCapacity == TxPipe::kMaxCapacity,
                "Max capacity mismatch");

 private:
  /**
   * Threshold for processing completions. If the RX pipe's capacity is greater
   * than this threshold, we process completions.
   */
  static constexpr uint32_t kCompletionsThreshold = kEnsoPipeSize * 64 / 2;

  /**
   * RxTxPipes can only be instantiated from a Device object, using the
   * `AllocateRxTxPipe()` method.
   *
   * @param id The ID of the pipe.
   * @param device The `Device` object that instantiated this pipe.
   */
  explicit RxTxPipe(Device* device) noexcept : device_(device) {}

  /**
   * @note RxTxPipes cannot be deallocated from outside. The `Device` object is
   * in charge of deallocating them.
   */
  ~RxTxPipe() = default;

  /**
   * @brief Initializes the RX/TX pipe.
   *
   * @param fallback Whether this pipe is a fallback pipe.
   *
   * @return 0 on success and a non-zero error code on failure.
   */
  int Init(bool fallback) noexcept;

  friend class Device;

  Device* device_;
  RxPipe* rx_pipe_;
  TxPipe* tx_pipe_;
  uint32_t last_tx_pipe_capacity_;
};

/**
 * @brief Base class to represent a message within a batch.
 *
 * It is designed to be used as an iterator. It tracks the number of missing
 * messages such that `operator!=` returns false whenever the limit is reached.
 */
template <typename T>
class MessageIteratorBase {
 public:
  constexpr uint8_t* operator*() { return addr_; }

  /*
   * This is a bit ugly but, as far as I know, there is no way to check for the
   * end of a range-based for loop without overloading the != operator.
   *
   * The issue is that it does not work as expected for actual inequality check.
   */
  constexpr bool operator!=(const MessageIteratorBase& other) const {
    return (missing_messages_ != 0) && (next_addr_ <= other.addr_);
  }

  constexpr T& operator++() {
    T* child = static_cast<T*>(this);

    uint32_t nb_bytes = next_addr_ - addr_;

    child->OnAdvanceMessage(nb_bytes);

    addr_ = next_addr_;
    next_addr_ = child->GetNextMessage(addr_);

    --missing_messages_;
    batch_->NotifyProcessedBytes(nb_bytes);

    return *child;
  }

 protected:
  inline MessageIteratorBase()
      : addr_(nullptr),
        missing_messages_(0),
        batch_(nullptr),
        next_addr_(nullptr) {}

  MessageIteratorBase(const MessageIteratorBase&) = default;
  MessageIteratorBase& operator=(const MessageIteratorBase&) = default;
  MessageIteratorBase(MessageIteratorBase&&) = default;
  MessageIteratorBase& operator=(MessageIteratorBase&&) = default;

  /**
   * @param addr The address of the first message.
   * @param message_limit The maximum number of messages to receive.
   * @param batch The batch associated with this iterator.
   */
  inline MessageIteratorBase(uint8_t* addr, int32_t message_limit,
                             RxPipe::MessageBatch<T>* batch)
      : addr_(addr),
        missing_messages_(message_limit),
        batch_(batch),
        next_addr_(static_cast<T*>(this)->GetNextMessage(addr)) {}

  uint8_t* addr_;
  int32_t missing_messages_;
  RxPipe::MessageBatch<T>* batch_;
  uint8_t* next_addr_;
};

/**
 * @brief Packet iterator.
 * @see RxPipe::RecvPkts
 * @see RxTxPipe::RecvPkts
 * @see PeekPktIterator
 */
class PktIterator : public MessageIteratorBase<PktIterator> {
 public:
  inline PktIterator() : MessageIteratorBase() {}

  /**
   * @copydoc MessageIteratorBase::MessageIteratorBase
   */
  inline PktIterator(uint8_t* addr, int32_t message_limit,
                     RxPipe::MessageBatch<PktIterator>* batch)
      : MessageIteratorBase(addr, message_limit, batch) {}

  PktIterator(const PktIterator&) = default;
  PktIterator& operator=(const PktIterator&) = default;
  PktIterator(PktIterator&&) = default;
  PktIterator& operator=(PktIterator&&) = default;

  /**
   * @brief Computes the next message address based on the current message.
   *
   * @param current_message The current message.
   *
   * @return The next message.
   */
  _enso_always_inline uint8_t* GetNextMessage(uint8_t* current_message) {
    return get_next_pkt(current_message);
  }

  /**
   * @brief Called when the iterator is done processing a message.
   *
   * @param nb_bytes The number of bytes processed.
   */
  constexpr void OnAdvanceMessage(uint32_t nb_bytes) {
    batch_->pipe_->ConfirmBytes(nb_bytes);
  }
};

/**
 * @brief Packet iterator that does not consume the packets from the pipe.
 * @see RxPipe::PeekPkts
 * @see RxTxPipe::PeekPkts
 * @see PktIterator
 */
class PeekPktIterator : public MessageIteratorBase<PeekPktIterator> {
 public:
  /**
   * @copydoc MessageIteratorBase::MessageIteratorBase
   */
  inline PeekPktIterator(uint8_t* addr, int32_t message_limit,
                         RxPipe::MessageBatch<PeekPktIterator>* batch)
      : MessageIteratorBase(addr, message_limit, batch) {}

  /**
   * @copydoc PktIterator::GetNextMessage
   */
  _enso_always_inline uint8_t* GetNextMessage(uint8_t* current_message) {
    return get_next_pkt(current_message);
  }

  /**
   * @copydoc PktIterator::OnAdvanceMessage
   */
  constexpr void OnAdvanceMessage([[maybe_unused]] uint32_t nb_bytes) {}
};

}  // namespace enso

#endif  // SOFTWARE_INCLUDE_ENSO_PIPE_H_
