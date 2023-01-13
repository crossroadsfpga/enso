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

#include <norman/helpers.h>
#include <norman/pipe.h>
#include <sched.h>

#include <cstdio>
#include <iostream>
#include <memory>
#include <string>

#include "../pcie.h"
#include "../syscall_api/intel_fpga_pcie_api.hpp"

namespace norman {

int external_peek_next_batch_from_queue(
    struct RxEnsoPipeInternal* enso_pipe,
    struct NotificationBufPair* notification_buf_pair, void** buf) {
  return peek_next_batch_from_queue(enso_pipe, notification_buf_pair, buf);
}

void RxPipe::FreeBytes(uint32_t nb_bytes) {
  advance_ring_buffer(&internal_rx_pipe_, nb_bytes);
}

void RxPipe::FreeAllBytes() { fully_advance_ring_buffer(&internal_rx_pipe_); }

RxPipe::~RxPipe() { enso_pipe_free(&internal_rx_pipe_); }

int RxPipe::Init(volatile struct QueueRegs* enso_pipe_regs) noexcept {
  return enso_pipe_init(&internal_rx_pipe_, enso_pipe_regs,
                        notification_buf_pair_, kId);
}

std::unique_ptr<Device> Device::Create(const uint32_t nb_pipes, int16_t core_id,
                                       const std::string& pcie_addr) noexcept {
  std::unique_ptr<Device> dev(new (std::nothrow)
                                  Device(nb_pipes, core_id, pcie_addr));
  if (unlikely(!dev)) {
    return std::unique_ptr<Device>{};
  }

  if (dev->Init()) {
    return std::unique_ptr<Device>{};
  }

  return dev;
}

Device::~Device() {
  for (auto& pipe : pipes_) {
    delete pipe;
  }

  notification_buf_free(&notification_buf_pair_);

  delete fpga_dev_;
}

RxPipe* Device::AllocateRxPipe() noexcept {
  if (pipes_.size() >= kNbPipes) {
    // No more pipes available.
    return nullptr;
  }

  enso_pipe_id_t enso_pipe_id =
      notification_buf_pair_.id * kNbPipes + pipes_.size();

  RxPipe* pipe(new (std::nothrow)
                   RxPipe(enso_pipe_id, &notification_buf_pair_));

  if (unlikely(!pipe)) {
    return nullptr;
  }

  volatile struct QueueRegs* enso_pipe_regs =
      (struct QueueRegs*)((uint8_t*)uio_mmap_bar2_addr_ +
                          enso_pipe_id * MEMORY_SPACE_PER_QUEUE);

  if (pipe->Init(enso_pipe_regs)) {
    delete pipe;
    return nullptr;
  }

  pipes_.push_back(pipe);

  return pipe;
}

int Device::Init() noexcept {
  if (core_id_ < 0) {
    core_id_ = sched_getcpu();
    if (core_id_ < 0) {
      // Error getting CPU ID.
      return 1;
    }
  }

  uint16_t bdf = 0;
  if (kPcieAddr != "") {
    bdf_ = get_bdf_from_pcie_addr(kPcieAddr);

    if (unlikely(bdf_ == 0)) {
      // Invalid PCIe address.
      return 2;
    }
  }

  try {
    int bar = -1;
    fpga_dev_ = new intel_fpga_pcie_dev(bdf, bar);
  } catch (const std::exception& ex) {
    // Failed to open device or allocate object.
    return 3;
  }

  int result = fpga_dev_->use_cmd(true);
  if (unlikely(result == 0)) {
    // Could not switch to CMD use mode.
    return 4;
  }

  std::cerr << "Running with BATCH_SIZE: " << BATCH_SIZE << std::endl;
  std::cerr << "Running with NOTIFICATION_BUF_SIZE: " << NOTIFICATION_BUF_SIZE
            << std::endl;
  std::cerr << "Running with ENSO_PIPE_SIZE: " << ENSO_PIPE_SIZE << std::endl;

  // We need this to allow the same huge page to be mapped to contiguous
  // memory regions.
  // TODO(sadok): support other buffer sizes. It may be possible to support
  // other buffer sizes by overlaying regular pages on top of the huge pages.
  // We might use those only for requests that overlap to avoid adding too
  // many entries to the TLB.
  if (ENSO_PIPE_SIZE * 64 != BUF_PAGE_SIZE) {
    // Unsupported buffer size.
    return 5;
  }

  // FIXME(sadok) should find a better identifier than core id.
  uint32_t id = core_id_;
  notification_buf_pair_.id = id;

  uio_mmap_bar2_addr_ =
      fpga_dev_->uio_mmap((1 << 12) * (MAX_NB_FLOWS + MAX_NB_APPS), 2);
  if (uio_mmap_bar2_addr_ == MAP_FAILED) {
    // Could not get mmap uio memory.
    return 7;
  }

  // Register associated with the notification buffer. Notification buffer
  // registers come after the enso pipe ones, that's why we use MAX_NB_FLOWS
  // as an offset.
  volatile struct QueueRegs* notification_buf_pair_regs =
      (struct QueueRegs*)((uint8_t*)uio_mmap_bar2_addr_ +
                          (id + MAX_NB_FLOWS) * MEMORY_SPACE_PER_QUEUE);

  // HACK(sadok): This only works because pkt queues for the same app are
  // currently placed back to back.
  enso_pipe_id_t enso_pipe_id_offset = id * kNbPipes;

  int ret =
      notification_buf_init(&notification_buf_pair_, notification_buf_pair_regs,
                            kNbPipes, enso_pipe_id_offset);
  if (ret != 0) {
    // Could not initialize notification buffer.
    return 8;
  }

  return 0;
}

}  // namespace norman
