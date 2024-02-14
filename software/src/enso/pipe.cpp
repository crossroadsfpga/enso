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
#include <dev_backend.h>

namespace enso {

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

inline uint32_t RxPipe::Peek(uint8_t** buf, uint32_t max_nb_bytes) {
  uint32_t* enso_pipe_buf = internal_rx_pipe_.buf;
  uint32_t enso_pipe_head = internal_rx_pipe_.rx_tail;
  *buf = (uint8_t *)&enso_pipe_buf[enso_pipe_head * 16];
  uint32_t flit_aligned_size;
  uint32_t new_rx_tail = 0;
  int32_t pipe_id = internal_rx_pipe_.id;

  flit_aligned_size = consume_rx_kernel(notification_buf_pair_,
                                        new_rx_tail, pipe_id);
  if(flit_aligned_size > 0) {
    internal_rx_pipe_.krx_tail = new_rx_tail;
  }
  return std::min(flit_aligned_size, max_nb_bytes);
}

uint32_t RxPipe::PeekFromTail(uint8_t** buf, uint32_t max_nb_bytes) {
  if(internal_rx_pipe_.rx_tail == internal_rx_pipe_.krx_tail) {
    return 0;
  }
  uint32_t* enso_pipe_buf = internal_rx_pipe_.buf;
  uint32_t enso_pipe_head = internal_rx_pipe_.rx_tail;
  *buf = (uint8_t *)&enso_pipe_buf[enso_pipe_head * 16];
  return std::min(internal_rx_pipe_.last_size, max_nb_bytes);
}

void RxPipe::Free(uint32_t nb_bytes) {
  advance_pipe_kernel(notification_buf_pair_, &internal_rx_pipe_, nb_bytes);
}

void RxPipe::Prefetch() {
  prefetch_pipe(&internal_rx_pipe_, notification_buf_pair_);
}

void RxPipe::Clear() {
  fully_advance_pipe_kernel(&internal_rx_pipe_, notification_buf_pair_);
}

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

std::unique_ptr<Device> Device::Create(
    const std::string& pcie_addr,
    const std::string& huge_page_prefix) noexcept {
  std::unique_ptr<Device> dev(new (std::nothrow)
                                  Device(pcie_addr, huge_page_prefix));
  if (unlikely(!dev)) {
    return std::unique_ptr<Device>{};
  }

  if (dev->Init()) {
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

// TODO(sadok): DRY this code.
RxPipe* Device::NextRxPipeToRecv() {
  // This function can only be used when there are **no** RxTx pipes.
  assert(rx_tx_pipes_.size() == 0);

  int32_t id = -1;

  uint32_t size;
  uint32_t new_rx_tail;
  size = consume_rx_kernel(&notification_buf_pair_, new_rx_tail, id);

  if (size == 0) {
    return nullptr;
  }

  RxPipe* rx_pipe = rx_pipes_map_[id];
  rx_pipe->internal_rx_pipe_.krx_tail = new_rx_tail;
  rx_pipe->internal_rx_pipe_.last_size = size;
  return rx_pipe;
}

RxTxPipe* Device::NextRxTxPipeToRecv() {
  ProcessCompletions();
  // This function can only be used when there are only RxTx pipes.
  assert(rx_pipes_.size() == rx_tx_pipes_.size());
  int32_t id = -1;

  uint32_t size;
  uint32_t new_rx_tail;
  size = consume_rx_kernel(&notification_buf_pair_, new_rx_tail, id);

  if (size == 0) {
    return nullptr;
  }

  RxTxPipe* rx_tx_pipe = rx_tx_pipes_map_[id];
  rx_tx_pipe->rx_pipe_->internal_rx_pipe_.krx_tail = new_rx_tail;
  rx_tx_pipe->rx_pipe_->internal_rx_pipe_.last_size = size;
  return rx_tx_pipe;
}

int Device::Init() noexcept {
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

  int ret = notification_buf_init(bdf_, bar, &notification_buf_pair_,
                                  huge_page_prefix_);
  if (ret != 0) {
    // Could not initialize notification buffer.
    return 3;
  }

  return 0;
}

int Device::ApplyConfig(struct TxNotification* config_notification) {
  return send_config(&notification_buf_pair_, config_notification);
}

void Device::Send(uint32_t tx_enso_pipe_id, uint64_t phys_addr,
                  uint32_t nb_bytes) {
  // TODO(sadok): We might be able to improve performance by avoiding the wrap
  // tracker currently used inside send_to_queue.
  send_to_queue(&notification_buf_pair_, phys_addr, nb_bytes);

  uint32_t nb_pending_requests =
      (tx_pr_tail_ - tx_pr_head_) & kPendingTxRequestsBufMask;

  // This will block until there is enough space to keep at least two requests.
  // We need space for two requests because the request may be split into two
  // if the bytes wrap around the end of the buffer.
  while (unlikely(nb_pending_requests >= (kMaxPendingTxRequests - 2))) {
    ProcessCompletions();
    nb_pending_requests =
        (tx_pr_tail_ - tx_pr_head_) & kPendingTxRequestsBufMask;
  }

  tx_pending_requests_[tx_pr_tail_].pipe_id = tx_enso_pipe_id;
  tx_pending_requests_[tx_pr_tail_].nb_bytes = nb_bytes;
  tx_pr_tail_ = (tx_pr_tail_ + 1) & kPendingTxRequestsBufMask;
}

void Device::ProcessCompletions() {
  uint32_t tx_completions = get_unreported_completions(&notification_buf_pair_);
  for (uint32_t i = 0; i < tx_completions; ++i) {
    TxPendingRequest tx_req = tx_pending_requests_[tx_pr_head_];
    tx_pr_head_ = (tx_pr_head_ + 1) & kPendingTxRequestsBufMask;

    TxPipe* pipe = tx_pipes_[tx_req.pipe_id];
    pipe->NotifyCompletion(tx_req.nb_bytes);
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
