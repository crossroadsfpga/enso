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

// Automatically points to the device backend configured at compile time.
#include <dev_backend.h>

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
  (void) huge_page_prefix;
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
  notification_buf_pair->huge_page_prefix = huge_page_prefix;

  return 0;
}

int enso_pipe_init(struct RxEnsoPipeInternal* enso_pipe,
                   struct NotificationBufPair* notification_buf_pair,
                   bool fallback) {
  // void* uio_mmap_bar2_addr = notification_buf_pair->uio_mmap_bar2_addr;
  (void) enso_pipe;
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

  enso_pipe->buf_phys_addr = phys_addr;
  enso_pipe->phys_buf_offset = phys_addr - (uint64_t)(enso_pipe->buf);

  int ret = enso_dev->AllocateEnsoRxPipe(enso_pipe_id, phys_addr);

  if (ret < 0) {
    std::cerr << "Could not allocate pipe" << std::endl;
    return -1;
  }
  // std::cout << "Got pipe id = " << enso_pipe_id << std::endl;

  update_fallback_queues_config(notification_buf_pair);

  return enso_pipe_id;
}

int dma_init(struct NotificationBufPair* notification_buf_pair,
             struct RxEnsoPipeInternal* enso_pipe, uint32_t bdf, int32_t bar,
             const std::string& huge_page_prefix, bool fallback) {
  printf("Running with NOTIFICATION_BUF_SIZE: %i\n", kNotificationBufSize);
  printf("Running with ENSO_PIPE_SIZE: %i\n", kEnsoPipeSize);

  int16_t core_id = sched_getcpu();
  if (core_id < 0) {
    std::cerr << "Could not get CPU id" << std::endl;
    return -1;
  }

  // Set notification buffer only for the first socket.
  if (notification_buf_pair->ref_cnt == 0) {
    int ret = notification_buf_init(bdf, bar, notification_buf_pair,
                                    huge_page_prefix);
    if (ret != 0) {
      return ret;
    }
  }

  ++(notification_buf_pair->ref_cnt);

  return enso_pipe_init(enso_pipe, notification_buf_pair, fallback);
}

static _enso_always_inline uint16_t
__get_new_tails(struct NotificationBufPair* notification_buf_pair) {
  (void) notification_buf_pair;
  return 0;
  /*struct RxNotification* notification_buf = notification_buf_pair->rx_buf;
  uint32_t notification_buf_head = notification_buf_pair->rx_head;
  uint16_t nb_consumed_notifications = 0;

  uint16_t next_rx_ids_tail = notification_buf_pair->next_rx_ids_tail;

  for (uint16_t i = 0; i < kBatchSize; ++i) {
    struct RxNotification* cur_notification =
        notification_buf + notification_buf_head;

    // Check if the next notification was updated by the NIC.
    if (cur_notification->signal == 0) {
      break;
    }

    cur_notification->signal = 0;
    notification_buf_head = (notification_buf_head + 1) % kNotificationBufSize;

    enso_pipe_id_t enso_pipe_id = cur_notification->queue_id;
    notification_buf_pair->pending_rx_pipe_tails[enso_pipe_id] =
        (uint32_t)cur_notification->tail;

    notification_buf_pair->next_rx_pipe_ids[next_rx_ids_tail] = enso_pipe_id;
    next_rx_ids_tail = (next_rx_ids_tail + 1) % kNotificationBufSize;

    ++nb_consumed_notifications;
  }

  notification_buf_pair->next_rx_ids_tail = next_rx_ids_tail;

  if (likely(nb_consumed_notifications > 0)) {
    // Update notification buffer head.
    DevBackend::mmio_write32(notification_buf_pair->rx_head_ptr,
                             notification_buf_head);
    notification_buf_pair->rx_head = notification_buf_head;
  }

  return nb_consumed_notifications;*/
}

uint16_t get_new_tails(struct NotificationBufPair* notification_buf_pair) {
  return __get_new_tails(notification_buf_pair);
}

static _enso_always_inline uint32_t
__consume_rx_kernel(struct RxEnsoPipeInternal* enso_pipe,
                struct NotificationBufPair* notification_buf_pair, void** buf,
                bool peek = false) {
  (void) buf;
  uint32_t pipe_head = 0;
  EnsoBackend* enso_dev =
      static_cast<EnsoBackend*>(notification_buf_pair->fpga_dev);
  uint32_t flit_aligned_size = enso_dev->ConsumeRxPipe(enso_pipe->id, peek, pipe_head);
  if(flit_aligned_size > 0)
  {
    uint32_t* enso_pipe_buf = enso_pipe->buf;
    *buf = &enso_pipe_buf[pipe_head * 16];
  }
  return flit_aligned_size;
}

static _enso_always_inline uint32_t
__consume_queue(struct RxEnsoPipeInternal* enso_pipe,
                struct NotificationBufPair* notification_buf_pair, void** buf,
                bool peek = false) {
  uint32_t* enso_pipe_buf = enso_pipe->buf;
  uint32_t enso_pipe_head = enso_pipe->rx_tail;
  int queue_id = enso_pipe->id;

  *buf = &enso_pipe_buf[enso_pipe_head * 16];

  uint32_t enso_pipe_tail =
      notification_buf_pair->pending_rx_pipe_tails[queue_id];

  if (enso_pipe_tail == enso_pipe_head) {
    return 0;
  }

  uint32_t flit_aligned_size =
      ((enso_pipe_tail - enso_pipe_head) % ENSO_PIPE_SIZE) * 64;

  if (!peek) {
    enso_pipe_head = (enso_pipe_head + flit_aligned_size / 64) % ENSO_PIPE_SIZE;
    enso_pipe->rx_tail = enso_pipe_head;
  }

  return flit_aligned_size;
}

uint32_t consume_rx_kernel(
    struct RxEnsoPipeInternal* enso_pipe,
    struct NotificationBufPair* notification_buf_pair, void** buf) {
  return __consume_rx_kernel(enso_pipe, notification_buf_pair, buf);
}

uint32_t get_next_batch_from_queue(
    struct RxEnsoPipeInternal* enso_pipe,
    struct NotificationBufPair* notification_buf_pair, void** buf) {
  return __consume_queue(enso_pipe, notification_buf_pair, buf);
}

uint32_t peek_next_batch_from_queue(
    struct RxEnsoPipeInternal* enso_pipe,
    struct NotificationBufPair* notification_buf_pair, void** buf) {
  return __consume_queue(enso_pipe, notification_buf_pair, buf, true);
}

static _enso_always_inline int32_t
__get_next_enso_pipe_id(struct NotificationBufPair* notification_buf_pair) {
  // Consume up to a batch of notifications at a time. If the number of consumed
  // notifications is the same as the number of pending notifications, we are
  // done processing the last batch and can get the next one. Using batches here
  // performs **significantly** better compared to always fetching the latest
  // notification.
  uint16_t next_rx_ids_head = notification_buf_pair->next_rx_ids_head;
  uint16_t next_rx_ids_tail = notification_buf_pair->next_rx_ids_tail;

  if (next_rx_ids_head == next_rx_ids_tail) {
    uint16_t nb_consumed_notifications = __get_new_tails(notification_buf_pair);
    if (unlikely(nb_consumed_notifications == 0)) {
      return -1;
    }
  }

  enso_pipe_id_t enso_pipe_id =
      notification_buf_pair->next_rx_pipe_ids[next_rx_ids_head];

  notification_buf_pair->next_rx_ids_head =
      (next_rx_ids_head + 1) % kNotificationBufSize;

  return enso_pipe_id;
}

int32_t get_next_enso_pipe_id(
    struct NotificationBufPair* notification_buf_pair) {
  return __get_next_enso_pipe_id(notification_buf_pair);
}

// Return next batch among all open sockets.
uint32_t get_next_batch(struct NotificationBufPair* notification_buf_pair,
                        struct SocketInternal* socket_entries,
                        int* enso_pipe_id, void** buf) {
  int32_t __enso_pipe_id = __get_next_enso_pipe_id(notification_buf_pair);

  if (unlikely(__enso_pipe_id == -1)) {
    return 0;
  }

  *enso_pipe_id = __enso_pipe_id;

  struct SocketInternal* socket_entry = &socket_entries[__enso_pipe_id];
  struct RxEnsoPipeInternal* enso_pipe = &socket_entry->enso_pipe;

  return __consume_queue(enso_pipe, notification_buf_pair, buf);
}

uint32_t get_next_batch_kernel(struct NotificationBufPair* notification_buf_pair,
                               struct SocketInternal* socket_entries,
                               int* enso_pipe_id, void** buf) {
  EnsoBackend* enso_dev =
      static_cast<EnsoBackend*>(notification_buf_pair->fpga_dev);
  int32_t pipe_id = -1;
  bool peek = false;
  uint32_t pipe_head = 0;
  int64_t flit_aligned_size = 0;

  flit_aligned_size = enso_dev->GetNextBatch(notification_buf_pair->id,
                                             peek, pipe_id, pipe_head);

  // can there be an issue if the flit_aligned_size is 0?
  if(flit_aligned_size <= 0) {
    return 0;
  }

  *enso_pipe_id = pipe_id;

  // set the buffer
  struct SocketInternal* socket_entry = &socket_entries[pipe_id];
  struct RxEnsoPipeInternal* enso_pipe = &socket_entry->enso_pipe;
  uint32_t* enso_pipe_buf = enso_pipe->buf;
  *buf = &enso_pipe_buf[pipe_head * 16];
  return flit_aligned_size;
}

void advance_pipe(struct RxEnsoPipeInternal* enso_pipe, size_t len) {
  uint32_t rx_pkt_head = enso_pipe->rx_head;
  uint32_t nb_flits = ((uint64_t)len - 1) / 64 + 1;
  rx_pkt_head = (rx_pkt_head + nb_flits) % ENSO_PIPE_SIZE;

  DevBackend::mmio_write32(enso_pipe->buf_head_ptr, rx_pkt_head);
  enso_pipe->rx_head = rx_pkt_head;
}

void advance_pipe_kernel(struct NotificationBufPair* notification_buf_pair,
                        struct RxEnsoPipeInternal* enso_pipe, size_t len) {
  EnsoBackend* enso_dev =
      static_cast<EnsoBackend*>(notification_buf_pair->fpga_dev);
  enso_dev->AdvancePipe(enso_pipe->id, len);
}

void fully_advance_pipe(struct RxEnsoPipeInternal* enso_pipe) {
  DevBackend::mmio_write32(enso_pipe->buf_head_ptr, enso_pipe->rx_tail);
  enso_pipe->rx_head = enso_pipe->rx_tail;
}

void fully_advance_pipe_kernel(struct RxEnsoPipeInternal* enso_pipe,
                               struct NotificationBufPair* notification_buf_pair) {
  EnsoBackend* enso_dev =
      static_cast<EnsoBackend*>(notification_buf_pair->fpga_dev);
  enso_dev->FullyAdvancePipe(enso_pipe->id);
}

void prefetch_pipe(struct RxEnsoPipeInternal* enso_pipe) {
  DevBackend::mmio_write32(enso_pipe->buf_head_ptr, enso_pipe->rx_head);
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

void update_tx_head(struct NotificationBufPair* notification_buf_pair) {
  struct TxNotification* tx_buf = notification_buf_pair->tx_buf;
  uint32_t head = notification_buf_pair->tx_head;
  uint32_t tail = notification_buf_pair->tx_tail;

  if (head == tail) {
    return;
  }

  // Advance pointer for pkt queues that were already sent.
  for (uint16_t i = 0; i < kBatchSize; ++i) {
    if (head == tail) {
      break;
    }
    struct TxNotification* tx_notification = tx_buf + head;

    // Notification has not yet been consumed by hardware.
    if (tx_notification->signal != 0) {
      break;
    }

    // Requests that wrap around need two notifications but should only signal
    // a single completion notification. Therefore, we only increment
    // `nb_unreported_completions` in the second notification.
    // TODO(sadok): If we implement the logic to have two notifications in the
    // same cache line, we can get rid of `wrap_tracker` and instead check
    // for two notifications.
    uint8_t wrap_tracker_mask = 1 << (head & 0x7);
    uint8_t no_wrap =
        !(notification_buf_pair->wrap_tracker[head / 8] & wrap_tracker_mask);
    notification_buf_pair->nb_unreported_completions += no_wrap;
    notification_buf_pair->wrap_tracker[head / 8] &= ~wrap_tracker_mask;

    head = (head + 1) % kNotificationBufSize;
  }

  notification_buf_pair->tx_head = head;
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

int dma_finish(struct SocketInternal* socket_entry) {
  struct NotificationBufPair* notification_buf_pair =
      socket_entry->notification_buf_pair;

  struct RxEnsoPipeInternal* enso_pipe = &socket_entry->enso_pipe;

  enso_pipe_id_t enso_pipe_id = enso_pipe->id;

  if (notification_buf_pair->ref_cnt == 0) {
    return -1;
  }

  enso_pipe_free(notification_buf_pair, enso_pipe, enso_pipe_id);

  if (notification_buf_pair->ref_cnt == 1) {
    notification_buf_free(notification_buf_pair);
  }

  --(notification_buf_pair->ref_cnt);

  return 0;
}

uint32_t get_enso_pipe_id_from_socket(struct SocketInternal* socket_entry) {
  return (uint32_t)socket_entry->enso_pipe.id;
}

void print_stats(struct SocketInternal* socket_entry, bool print_global) {
  struct NotificationBufPair* notification_buf_pair =
      socket_entry->notification_buf_pair;

  if (print_global) {
    printf("TX notification buffer full counter: %lu\n\n",
           notification_buf_pair->tx_full_cnt);
    printf("Dsc RX head: %d\n", notification_buf_pair->rx_head);
    printf("Dsc TX tail: %d\n", notification_buf_pair->tx_tail);
    printf("Dsc TX head: %d\n\n", notification_buf_pair->tx_head);
  }

  printf("Pkt RX tail: %d\n", socket_entry->enso_pipe.rx_tail);
  printf("Pkt RX head: %d\n", socket_entry->enso_pipe.rx_head);
}

}  // namespace enso
