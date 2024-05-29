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
 * @brief Implementation of Enso Pipe API. @see pipe.h
 *
 * @author Hugo Sadok <sadok@cmu.edu>
 */

#include <enso/config.h>
#include <enso/helpers.h>
#include <enso/pipe.h>
#include <sched.h>
#include <sys/mman.h>
#include <unistd.h>

#include <algorithm>
#include <cassert>
#include <cstdio>
#include <iostream>
#include <memory>
#include <string>

#include "../pcie.h"

namespace enso {

UpdateCallback pipe_update_callback_ = nullptr;

void set_backend_core_id(uint32_t core_id) {
  pcie_set_backend_core_id(core_id);
}

void initialize_backend(BackendWrapper preempt_enable,
                        BackendWrapper preempt_disable, IdCallback id_callback,
                        TscCallback tsc_callback,
                        UpdateCallback update_callback, TxCallback tx_callback,
                        uint32_t application_id) {
  pipe_update_callback_ = update_callback;
  return pcie_initialize_backend(preempt_enable, preempt_disable, id_callback,
                                 tsc_callback, update_callback, tx_callback,
                                 application_id);
}

void push_to_backend_queues(PipeNotification* notif) {
  return pcie_push_to_backend(notif);
}

std::optional<PipeNotification> push_to_backend_queues_get_response(
    PipeNotification* notif) {
  return pcie_push_to_backend_get_response(notif);
}

uint32_t external_peek_next_batch_from_queue(
    struct RxEnsoPipeInternal* enso_pipe,
    struct NotificationBufPair* notification_buf_pair, void** buf) {
  return peek_next_batch_from_queue(enso_pipe, notification_buf_pair, buf);
}

int RxPipe::Bind(uint16_t dst_port, uint16_t src_port, uint32_t dst_ip,
                 uint32_t src_ip, uint32_t protocol) {
  return insert_flow_entry(notification_buf_pair_, dst_port, src_port, dst_ip,
                           src_ip, protocol, id_);
}

uint32_t RxPipe::Recv(uint8_t** buf, uint32_t max_nb_bytes) {
  uint32_t ret = Peek(buf, max_nb_bytes);
  ConfirmBytes(ret);
  return ret;
}

inline void RxPipe::SetPktSentTime(uint32_t tail, uint64_t sent_time) {
  uint32_t* enso_pipe_buf = internal_rx_pipe_.buf;
  uint8_t* pkt = (uint8_t*)&enso_pipe_buf[tail * 16];
  set_pkt_sent_time(pkt, sent_time);
}

inline uint32_t RxPipe::Peek(uint8_t** buf, uint32_t max_nb_bytes) {
  if (!next_pipe_) {
    get_new_tails(notification_buf_pair_);
  }
  uint32_t ret = peek_next_batch_from_queue(
      &internal_rx_pipe_, notification_buf_pair_, (void**)buf);
  return std::min(ret, max_nb_bytes);
}

void RxPipe::Free(uint32_t nb_bytes) {
  advance_pipe(&internal_rx_pipe_, nb_bytes);
}

void RxPipe::Prefetch() { prefetch_pipe(&internal_rx_pipe_); }

void RxPipe::Clear() { fully_advance_pipe(&internal_rx_pipe_); }

RxPipe::~RxPipe() {
  enso_pipe_free(notification_buf_pair_, &internal_rx_pipe_, id_);
}

int RxPipe::Init(bool fallback) noexcept {
  int ret =
      enso_pipe_init(&internal_rx_pipe_, notification_buf_pair_, fallback);
  if (ret < 0) {
    return ret;
  }

  id_ = ret;

  return 0;
}

TxPipe::~TxPipe() {
  if (internal_buf_) {
    munmap(buf_, kMaxCapacity);
    std::string path = GetHugePageFilePath();
    unlink(path.c_str());
  }
}

int TxPipe::Init() noexcept {
  if (internal_buf_) {
    std::string path = GetHugePageFilePath();
    buf_ = (uint8_t*)get_huge_page(path, 0, true);
    if (unlikely(!buf_)) {
      return -1;
    }
  }

  struct NotificationBufPair* notif_buf = &(device_->notification_buf_pair_);

  buf_phys_addr_ = get_dev_addr_from_virt_addr(notif_buf, buf_);
  return 0;
}

void RxTxPipe::SetPktSentTime(uint32_t tail, uint64_t sent_time) {
  rx_pipe_->SetPktSentTime(tail, sent_time);
}

int RxTxPipe::Init(bool fallback) noexcept {
  rx_pipe_ = device_->AllocateRxPipe(fallback);
  if (rx_pipe_ == nullptr) {
    return -1;
  }

  tx_pipe_ = device_->AllocateTxPipe(rx_pipe_->buf());
  if (tx_pipe_ == nullptr) {
    return -1;
  }

  last_tx_pipe_capacity_ = tx_pipe_->capacity();

  return 0;
}

std::unique_ptr<Device> Device::Create(const std::string& pcie_addr,
                                       const std::string& huge_page_prefix,
                                       int32_t uthread_id,
                                       CompletionCallback completion_callback,
                                       ParkCallback park_callback) noexcept {
  std::unique_ptr<Device> dev(
      new (std::nothrow) Device(uthread_id, completion_callback, park_callback,
                                pcie_addr, huge_page_prefix));
  if (unlikely(!dev)) {
    return std::unique_ptr<Device>{};
  }

  set_park_callback(park_callback);

  if (dev->Init(uthread_id)) {
    return std::unique_ptr<Device>{};
  }

  return dev;
}

Device::~Device() {
  for (auto& pipe : rx_tx_pipes_) {
    rx_tx_pipes_map_[pipe->rx_id()] = nullptr;
    delete pipe;
  }

  for (auto& pipe : rx_pipes_) {
    rx_pipes_map_[pipe->id()] = nullptr;
    delete pipe;
  }

  for (auto& pipe : tx_pipes_) {
    delete pipe;
  }

  notification_buf_free(&notification_buf_pair_);
}

RxPipe* Device::AllocateRxPipe(bool fallback) noexcept {
  RxPipe* pipe(new (std::nothrow) RxPipe(this));

  if (unlikely(!pipe)) {
    return nullptr;
  }

  if (pipe->Init(fallback)) {
    delete pipe;
    return nullptr;
  }

  rx_pipes_.push_back(pipe);
  rx_pipes_map_[pipe->id()] = pipe;

  return pipe;
}

int Device::GetNbFallbackQueues() noexcept {
  return get_nb_fallback_queues(&notification_buf_pair_);
}

TxPipe* Device::AllocateTxPipe(uint8_t* buf) noexcept {
  TxPipe* pipe(new (std::nothrow) TxPipe(tx_pipes_.size(), this, buf));

  if (unlikely(!pipe)) {
    return nullptr;
  }

  if (pipe->Init()) {
    delete pipe;
    return nullptr;
  }

  tx_pipes_.push_back(pipe);

  return pipe;
}

RxTxPipe* Device::AllocateRxTxPipe(bool fallback) noexcept {
  RxTxPipe* pipe(new (std::nothrow) RxTxPipe(this));

  if (unlikely(!pipe)) {
    return nullptr;
  }

  if (pipe->Init(fallback)) {
    delete pipe;
    return nullptr;
  }

  rx_tx_pipes_.push_back(pipe);
  rx_tx_pipes_map_[pipe->rx_id()] = pipe;

  return pipe;
}

struct RxNotification* Device::NextRxNotif() {
  // This function can only be used when there are **no** RxTx pipes.
  assert(rx_tx_pipes_.size() == 0);

  struct RxNotification* notif;
  notif = get_next_rx_notif(&notification_buf_pair_);
  return notif;
}

// TODO(sadok): DRY this code.
RxPipe* Device::NextRxPipeToRecv() {
  // This function can only be used when there are **no** RxTx pipes.
  assert(rx_tx_pipes_.size() == 0);

  struct RxNotification* notification = NextRxNotif();
  if (!notification) {
    return nullptr;
  }
  int32_t id = notification->queue_id;

  RxPipe* rx_pipe = rx_pipes_map_[id];
  if (!rx_pipe) return NULL;
  rx_pipe->SetAsNextPipe();

  return rx_pipe;
}

RxTxPipe* Device::NextRxTxPipeToRecv() {
  ProcessCompletions();
  // This function can only be used when there are only RxTx pipes.
  assert(rx_pipes_.size() == rx_tx_pipes_.size());
  struct RxNotification* notif;
  int32_t id;

  notif = get_next_rx_notif(
      &notification_buf_pair_, [this](enso_pipe_id_t enso_pipe_id,
                                      uint64_t sent_time, uint32_t prev_tail) {
        RxTxPipe* rx_tx_pipe = rx_tx_pipes_map_[enso_pipe_id];
        rx_tx_pipe->SetPktSentTime(prev_tail, sent_time);
      });

  if (!notif) return nullptr;

  id = notif->queue_id;
  RxTxPipe* rx_tx_pipe = rx_tx_pipes_map_[id];

  uint64_t now = rdtsc();
  uint64_t time_to_uthread = now - notif->pad[0];
  uint64_t overall_time = now - notif->pad[1];
  if (pipe_update_callback_)
    std::invoke(pipe_update_callback_, time_to_uthread, overall_time);

  rx_tx_pipe->rx_pipe_->SetAsNextPipe();
  return rx_tx_pipe;
}

int Device::GetNotifQueueId() noexcept { return notification_buf_pair_.id; }

struct RxNotification* Device::GetRxNotifQueueBuf() noexcept {
  return notification_buf_pair_.rx_buf;
}

struct TxNotification* Device::GetTxNotifQueueBuf() noexcept {
  return notification_buf_pair_.tx_buf;
}

uint32_t Device::GetRxHead() noexcept { return notification_buf_pair_.rx_head; }

uint32_t Device::GetTxHead() noexcept { return notification_buf_pair_.tx_head; }

int Device::Init(int32_t uthread_id) noexcept {
  if (core_id_ < 0) {
    core_id_ = sched_getcpu();
    if (core_id_ < 0) {
      // Error getting CPU ID.
      return 1;
    }
  }

  bdf_ = 0;
  if (kPcieAddr != "") {
    bdf_ = get_bdf_from_pcie_addr(kPcieAddr);

    if (unlikely(bdf_ == 0)) {
      // Invalid PCIe address.
      return 2;
    }
  }

  int bar = -1;

  std::cerr << "Running with NOTIFICATION_BUF_SIZE: " << kNotificationBufSize
            << std::endl;
  std::cerr << "Running with ENSO_PIPE_SIZE: " << kEnsoPipeSize << std::endl;

  // initialize entire notification buf information for uthreads to access
  int ret = notification_buf_init(bdf_, bar, &notification_buf_pair_,
                                  huge_page_prefix_, uthread_id);
  if (ret != 0) {
    // Could not initialize notification buffer.
    return 3;
  }

  return 0;
}

int Device::ApplyConfig(struct TxNotification* notification) {
  tx_pending_requests_[tx_pr_tail_].pipe_id = -1;
  tx_pending_requests_[tx_pr_tail_].nb_bytes = 0;
  tx_pr_tail_ = (tx_pr_tail_ + 1) & kPendingTxRequestsBufMask;
  return send_config(&notification_buf_pair_, notification,
                     &completion_callback_);
}

void Device::Send(int tx_enso_pipe_id, uint64_t phys_addr, uint32_t nb_bytes,
                  bool first, uint64_t sent_time) {
  // TODO(sadok): We might be able to improve performance by avoiding the wrap
  // tracker currently used inside send_to_queue.
  send_to_queue(&notification_buf_pair_, phys_addr, nb_bytes, first, sent_time);

  uint32_t nb_pending_requests =
      (tx_pr_tail_ - tx_pr_head_) & kPendingTxRequestsBufMask;

  // This will block until there is enough space to keep at least two requests.
  // We need space for two requests because the request may be split into two
  // if the bytes wrap around the end of the buffer.
  while (unlikely(nb_pending_requests >= (kMaxPendingTxRequests - 2))) {
    if (park_callback_ != nullptr) std::invoke(park_callback_, false);
    ProcessCompletions();
    nb_pending_requests =
        (tx_pr_tail_ - tx_pr_head_) & kPendingTxRequestsBufMask;
  }

  tx_pending_requests_[tx_pr_tail_].phys_addr = phys_addr;
  tx_pending_requests_[tx_pr_tail_].pipe_id = tx_enso_pipe_id;
  tx_pending_requests_[tx_pr_tail_].nb_bytes = nb_bytes;
  tx_pr_tail_ = (tx_pr_tail_ + 1) & kPendingTxRequestsBufMask;
}

/**
 * @brief Processes the completed transmissions of packets by checking
 * the TX notification buffer.
 *
 */
void Device::ProcessCompletions() {
  uint32_t tx_completions = get_unreported_completions(&notification_buf_pair_);
  for (uint32_t i = 0; i < tx_completions; ++i) {
    TxPendingRequest tx_req = tx_pending_requests_[tx_pr_head_];
    tx_pr_head_ = (tx_pr_head_ + 1) & kPendingTxRequestsBufMask;

    if (tx_req.pipe_id < 0) {
      // on receiving this, shinkansen should update the notification->signal
      // for applications
      std::invoke(completion_callback_);
    } else {
      // std::cout << "Processing completion of " << tx_req.nb_bytes
      //           << " bytes with phys addr " << tx_req.phys_addr << std::endl;
      TxPipe* pipe = tx_pipes_[tx_req.pipe_id];
      // increments app_end_ for the tx pipe by nb_bytes
      pipe->NotifyCompletion(tx_req.nb_bytes);
    }
  }

  // RxTx pipes need to be explicitly notified so that they can free space for
  // more incoming packets.
  for (RxTxPipe* pipe : rx_tx_pipes_) {
    pipe->ProcessCompletions();
  }
}

int Device::EnableTimeStamping() {
  return enable_timestamp(&notification_buf_pair_);
}

int Device::DisableTimeStamping() {
  return disable_timestamp(&notification_buf_pair_);
}

int Device::EnableRateLimiting(uint16_t num, uint16_t den) {
  return enable_rate_limit(&notification_buf_pair_, num, den);
}

int Device::DisableRateLimiting() {
  return disable_rate_limit(&notification_buf_pair_);
}

int Device::EnablePerPacketRateLimiting() {
  return enable_per_packet_rate_limit(&notification_buf_pair_);
}

int Device::DisablePerPacketRateLimiting() {
  return disable_per_packet_rate_limit(&notification_buf_pair_);
}

int Device::EnableRoundRobin() {
  return enable_round_robin(&notification_buf_pair_);
}

int Device::GetRoundRobinStatus() noexcept {
  return get_round_robin_status(&notification_buf_pair_);
}

int Device::DisableRoundRobin() {
  return disable_round_robin(&notification_buf_pair_);
}

}  // namespace enso
