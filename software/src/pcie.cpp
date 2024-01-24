/*
 * Copyright (c) 2022, Carnegie Mellon University
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
 * @brief Functions to initialize and interface directly with the PCIe device.
 *
 * @author Hugo Sadok <sadok@cmu.edu>
 */

#include "pcie.h"

#include <arpa/inet.h>
#include <enso/config.h>
#include <enso/consts.h>
#include <enso/helpers.h>
#include <immintrin.h>
#include <sched.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#include <algorithm>
#include <cassert>
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <ctime>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>

#include <enso_backend.h>

namespace enso {

static _enso_always_inline void try_clflush([[maybe_unused]] void* addr) {
#ifdef __CLFLUSHOPT__
  _mm_clflushopt(addr);
#endif
}

int notification_buf_init(uint32_t bdf, int32_t bar,
                          struct NotificationBufPair* notification_buf_pair,
                          const std::string& huge_page_prefix) {
  (void) bdf;
  (void) bar;
  EnsoBackend* enso_dev = EnsoBackend::Create();
  if (unlikely(enso_dev == nullptr)) {
    std::cerr << "Could not create device" << std::endl;
    return -1;
  }
  notification_buf_pair->fpga_dev = enso_dev;

  int notif_pipe_id = enso_dev->AllocateNotifBuf();

  if (notif_pipe_id < 0) {
    std::cerr << "Could not allocate notification buffer" << std::endl;
    return -1;
  }

  enso_dev->AllocNotifBufPair(notif_pipe_id);
  // this is used later to allocate a huge page for the pipe
  notification_buf_pair->huge_page_prefix = huge_page_prefix;

  return 0;
}

int enso_pipe_init(struct RxEnsoPipeInternal* enso_pipe,
                   struct NotificationBufPair* notification_buf_pair,
                   bool fallback) {
  EnsoBackend* enso_dev =
      static_cast<EnsoBackend*>(notification_buf_pair->fpga_dev);

  // we keep the buffer in the userspace and pass the physical address
  // to the kernel
  int enso_pipe_id = enso_dev->AllocatePipe(fallback);
  if(enso_pipe_id < 0) {
      std::cerr << "Pipe ID allocation failed, err = "
                << std::strerror(errno) << std::endl;
      return -1;
  }
  enso_pipe->id = enso_pipe_id;

  std::string huge_page_path = notification_buf_pair->huge_page_prefix +
                               std::string(kHugePageRxPipePathPrefix) +
                               std::to_string(enso_pipe_id);

  enso_pipe->buf = (uint32_t*)get_huge_page(huge_page_path, 0, true);
  if (enso_pipe->buf == NULL) {
    std::cerr << "Could not get huge page" << std::endl;
    return -1;
  }
  uint64_t phys_addr = enso_dev->ConvertVirtAddrToDevAddr(enso_pipe->buf);
  int ret = enso_dev->AllocateEnsoRxPipe(enso_pipe_id, phys_addr);

  enso_pipe->rx_head = 0;
  enso_pipe->rx_tail = 0;
  enso_pipe->krx_tail = 0;

  if (ret < 0) {
    std::cerr << "Could not allocate pipe" << std::endl;
    return -1;
  }

  update_fallback_queues_config(notification_buf_pair);

  return enso_pipe_id;
}

static _enso_always_inline uint32_t
__consume_rx_kernel(struct RxEnsoPipeInternal* enso_pipe,
                struct NotificationBufPair* notification_buf_pair, void** buf,
                bool get_tails) {
  (void) buf;
  uint32_t* enso_pipe_buf = enso_pipe->buf;
  uint32_t enso_pipe_head = enso_pipe->rx_tail;
  *buf = &enso_pipe_buf[enso_pipe_head * 16];
  // verify if the userspace and kernel space tails match
  // if not, it means the application hasn't consumed the
  // bytes (not called ConfirmBytes)
  if(enso_pipe->rx_tail != enso_pipe->krx_tail) {
    std::cout << "Exception" << std::endl;
    return 0;
  }

  uint32_t new_rx_tail = 0;
  EnsoBackend* enso_dev =
      static_cast<EnsoBackend*>(notification_buf_pair->fpga_dev);
  uint32_t flit_aligned_size = enso_dev->ConsumeRxPipe(enso_pipe->id, new_rx_tail,
                                                       get_tails);
  if(flit_aligned_size > 0) {
    // update kernel's rx tail in pipe
    enso_pipe->krx_tail = new_rx_tail;
  }
  return flit_aligned_size;
}

uint32_t consume_rx_kernel(
    struct RxEnsoPipeInternal* enso_pipe,
    struct NotificationBufPair* notification_buf_pair, void** buf,  bool get_tails) {
  return __consume_rx_kernel(enso_pipe, notification_buf_pair, buf, get_tails);
}

uint32_t get_next_batch_kernel(struct NotificationBufPair* notification_buf_pair,
                               struct SocketInternal* socket_entries,
                               int* enso_pipe_id, void** buf) {
  EnsoBackend* enso_dev =
      static_cast<EnsoBackend*>(notification_buf_pair->fpga_dev);
  int32_t pipe_id = -1;
  uint32_t new_rx_tail = 0;
  int64_t flit_aligned_size = 0;

  flit_aligned_size = enso_dev->GetNextBatch(notification_buf_pair->id,
                                             pipe_id, new_rx_tail);

  // can there be an issue if the flit_aligned_size is 0?
  if(flit_aligned_size <= 0) {
    return 0;
  }

  *enso_pipe_id = pipe_id;

  // set the buffer
  struct SocketInternal* socket_entry = &socket_entries[pipe_id];
  struct RxEnsoPipeInternal* enso_pipe = &socket_entry->enso_pipe;

  if(enso_pipe->rx_tail != enso_pipe->krx_tail) {
    std::cout << "Exception" << std::endl;
    return 0;
  }

  uint32_t* enso_pipe_buf = enso_pipe->buf;
  *buf = &enso_pipe_buf[enso_pipe->rx_tail * 16];
  if(flit_aligned_size > 0) {
    enso_pipe->krx_tail = new_rx_tail;
  }
  return flit_aligned_size;
}

int get_next_enso_pipe_id_kernel(struct NotificationBufPair* notification_buf_pair) {
  EnsoBackend *enso_dev =
      static_cast<EnsoBackend*>(notification_buf_pair->fpga_dev);
  return enso_dev->NextRxPipeToRecv();
}

void advance_pipe_kernel(struct NotificationBufPair* notification_buf_pair,
                        struct RxEnsoPipeInternal* enso_pipe, size_t len) {
  EnsoBackend* enso_dev =
      static_cast<EnsoBackend*>(notification_buf_pair->fpga_dev);
  enso_dev->AdvancePipe(enso_pipe->id, len);
}

void fully_advance_pipe_kernel(struct RxEnsoPipeInternal* enso_pipe,
                               struct NotificationBufPair* notification_buf_pair) {
  EnsoBackend* enso_dev =
      static_cast<EnsoBackend*>(notification_buf_pair->fpga_dev);
  enso_dev->FullyAdvancePipe(enso_pipe->id);
}

void prefetch_pipe(struct RxEnsoPipeInternal* enso_pipe,
                   struct NotificationBufPair* notification_buf_pair) {
  EnsoBackend* enso_dev =
      static_cast<EnsoBackend*>(notification_buf_pair->fpga_dev);
  enso_dev->PrefetchPipe(enso_pipe->id);
}

static _enso_always_inline uint32_t
__send_to_queue(struct NotificationBufPair* notification_buf_pair,
                uint64_t phys_addr, uint32_t len) {

  EnsoBackend* enso_dev = (EnsoBackend*) notification_buf_pair->fpga_dev;
  enso_dev->SendTxPipe(phys_addr, len, notification_buf_pair->id);

  return len;
}

uint32_t send_to_queue(struct NotificationBufPair* notification_buf_pair,
                       uint64_t phys_addr, uint32_t len) {
  return __send_to_queue(notification_buf_pair, phys_addr, len);
}

uint32_t get_unreported_completions(
    struct NotificationBufPair* notification_buf_pair) {

  EnsoBackend* enso_dev = (EnsoBackend*) notification_buf_pair->fpga_dev;
  uint32_t completions = enso_dev->GetUnreportedCompletions();

  return completions;
}

int send_config(struct NotificationBufPair* notification_buf_pair,
                struct TxNotification* config_notification) {
  EnsoBackend* enso_dev =
      static_cast<EnsoBackend*>(notification_buf_pair->fpga_dev);
  int ret = enso_dev->SendConfig(config_notification);
  if(ret != 0) {
    std::cerr << "Send config failed" << std::endl;
    return ret;
  }
  return 0;
}

int get_nb_fallback_queues(struct NotificationBufPair* notification_buf_pair) {
  EnsoBackend* enso_dev =
      static_cast<EnsoBackend*>(notification_buf_pair->fpga_dev);
  return enso_dev->GetNbFallbackQueues();
}

int set_round_robin_status(struct NotificationBufPair* notification_buf_pair,
                           bool round_robin) {
  EnsoBackend* enso_dev =
      static_cast<EnsoBackend*>(notification_buf_pair->fpga_dev);
  return enso_dev->SetRrStatus(round_robin);
}

int get_round_robin_status(struct NotificationBufPair* notification_buf_pair) {
  EnsoBackend* enso_dev =
      static_cast<EnsoBackend*>(notification_buf_pair->fpga_dev);
  return enso_dev->GetRrStatus();
}

uint64_t get_dev_addr_from_virt_addr(
    struct NotificationBufPair* notification_buf_pair, void* virt_addr) {
  EnsoBackend* enso_dev =
      static_cast<EnsoBackend*>(notification_buf_pair->fpga_dev);
  uint64_t dev_addr = enso_dev->ConvertVirtAddrToDevAddr(virt_addr);
  return dev_addr;
}

void notification_buf_free(struct NotificationBufPair* notification_buf_pair) {
  EnsoBackend* enso_dev =
      static_cast<EnsoBackend*>(notification_buf_pair->fpga_dev);

  enso_dev->FreeNotifBuf(notification_buf_pair->id);

  delete enso_dev;
}

void enso_pipe_free(struct NotificationBufPair* notification_buf_pair,
                    struct RxEnsoPipeInternal* enso_pipe,
                    enso_pipe_id_t enso_pipe_id) {
  (void) enso_pipe;
  EnsoBackend* enso_dev =
      static_cast<EnsoBackend*>(notification_buf_pair->fpga_dev);

  enso_dev->FreeEnsoRxPipe(enso_pipe_id);

  if (enso_pipe->buf) {
    munmap(enso_pipe->buf, kBufPageSize);
    std::string huge_page_path = enso_pipe->huge_page_prefix +
                                 std::string(kHugePageRxPipePathPrefix) +
                                 std::to_string(enso_pipe_id);
    unlink(huge_page_path.c_str());
    enso_pipe->buf = nullptr;
  }

  enso_dev->FreePipe(enso_pipe_id);

  update_fallback_queues_config(notification_buf_pair);
}

}  // namespace enso
