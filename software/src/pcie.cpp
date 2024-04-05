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

namespace enso {

void set_park_callback(ParkCallback park_callback) {
  park_callback_ = park_callback;
}

static _enso_always_inline void try_clflush([[maybe_unused]] void* addr) {
#ifdef __CLFLUSHOPT__
  _mm_clflushopt(addr);
#endif
}

int notification_buf_init(uint32_t bdf, int32_t bar,
                          struct NotificationBufPair* notification_buf_pair,
                          const std::string& huge_page_prefix,
                          int32_t uthread_id) {
  DevBackend* fpga_dev = DevBackend::Create(bdf, bar);
  if (unlikely(fpga_dev == nullptr)) {
    std::cerr << "Could not create device" << std::endl;
    return -1;
  }
  notification_buf_pair->fpga_dev = fpga_dev;

  int notif_pipe_id = fpga_dev->AllocateNotifBuf(uthread_id);

  if (notif_pipe_id < 0) {
    std::cerr << "Could not allocate notification buffer" << std::endl;
    return -1;
  }

  notification_buf_pair->id = notif_pipe_id;

  void* uio_mmap_bar2_addr =
      fpga_dev->uio_mmap((1 << 12) * (kMaxNbFlows + kMaxNbApps), 2);
  if (uio_mmap_bar2_addr == MAP_FAILED) {
    std::cerr << "Could not get mmap uio memory!" << std::endl;
    return -1;
  }

  notification_buf_pair->uio_mmap_bar2_addr = uio_mmap_bar2_addr;

  // Register associated with the notification buffer. Notification buffer
  // registers come after the enso pipe ones, that's why we use kMaxNbFlows
  // as an offset.
  volatile struct QueueRegs* notification_buf_pair_regs =
      (struct QueueRegs*)((uint8_t*)uio_mmap_bar2_addr +
                          (notif_pipe_id + kMaxNbFlows) * kMemorySpacePerQueue);
  // Make sure the notification buffer is disabled.
  DevBackend::mmio_write32(&notification_buf_pair_regs->rx_mem_low, 0,
                           notification_buf_pair->uio_mmap_bar2_addr);
  DevBackend::mmio_write32(&notification_buf_pair_regs->rx_mem_high, 0,
                           notification_buf_pair->uio_mmap_bar2_addr);
  while (DevBackend::mmio_read32(&notification_buf_pair_regs->rx_mem_low,
                                 notification_buf_pair->uio_mmap_bar2_addr) !=
         0)
    continue;

  while (DevBackend::mmio_read32(&notification_buf_pair_regs->rx_mem_high,
                                 notification_buf_pair->uio_mmap_bar2_addr) !=
         0)
    continue;

  DevBackend::mmio_write32(&notification_buf_pair_regs->rx_tail, 0,
                           notification_buf_pair->uio_mmap_bar2_addr);
  while (DevBackend::mmio_read32(&notification_buf_pair_regs->rx_tail,
                                 notification_buf_pair->uio_mmap_bar2_addr) !=
         0)
    continue;

  DevBackend::mmio_write32(&notification_buf_pair_regs->rx_head, 0,
                           notification_buf_pair->uio_mmap_bar2_addr);
  while (DevBackend::mmio_read32(&notification_buf_pair_regs->rx_head,
                                 notification_buf_pair->uio_mmap_bar2_addr) !=
         0)
    continue;

  std::string huge_page_path = huge_page_prefix +
                               std::string(kHugePageNotifBufPathPrefix) +
                               std::to_string(notification_buf_pair->id);

  notification_buf_pair->regs = (struct QueueRegs*)notification_buf_pair_regs;
  notification_buf_pair->rx_buf =
      (struct RxNotification*)get_huge_page(huge_page_path);
  if (notification_buf_pair->rx_buf == NULL) {
    std::cerr << "Could not get huge page" << std::endl;
    return -1;
  }

  memset(notification_buf_pair->rx_buf, 0, kNotificationBufSize * 64);

  // Use first half of the huge page for RX and second half for TX.
  notification_buf_pair->tx_buf =
      (struct TxNotification*)((uint64_t)notification_buf_pair->rx_buf +
                               kAlignedDscBufPairSize / 2);

  memset(notification_buf_pair->tx_buf, 0, kNotificationBufSize * 64);

  uint64_t phys_addr =
      fpga_dev->ConvertVirtAddrToDevAddr(notification_buf_pair->rx_buf);

  notification_buf_pair->rx_head_ptr =
      (uint32_t*)&notification_buf_pair_regs->rx_head;
  notification_buf_pair->tx_tail_ptr =
      (uint32_t*)&notification_buf_pair_regs->tx_tail;

  notification_buf_pair->rx_head =
      DevBackend::mmio_read32(notification_buf_pair->rx_head_ptr,
                              notification_buf_pair->uio_mmap_bar2_addr);

  // Preserve TX DSC tail and make head have the same value.
  notification_buf_pair->tx_tail =
      DevBackend::mmio_read32(notification_buf_pair->tx_tail_ptr,
                              notification_buf_pair->uio_mmap_bar2_addr);

  notification_buf_pair->tx_head = notification_buf_pair->tx_tail;

  DevBackend::mmio_write32(&notification_buf_pair_regs->tx_head,
                           notification_buf_pair->tx_head,
                           notification_buf_pair->uio_mmap_bar2_addr);

  notification_buf_pair->pending_rx_pipe_tails = (uint32_t*)malloc(
      sizeof(*(notification_buf_pair->pending_rx_pipe_tails)) * kMaxNbFlows);
  if (notification_buf_pair->pending_rx_pipe_tails == NULL) {
    std::cerr << "Could not allocate memory" << std::endl;
    return -1;
  }
  memset(notification_buf_pair->pending_rx_pipe_tails, 0, kMaxNbFlows);

  notification_buf_pair->wrap_tracker =
      (uint8_t*)malloc(kNotificationBufSize / 8);
  if (notification_buf_pair->wrap_tracker == NULL) {
    std::cerr << "Could not allocate memory" << std::endl;
    return -1;
  }
  memset(notification_buf_pair->wrap_tracker, 0, kNotificationBufSize / 8);

  notification_buf_pair->next_rx_pipe_notifs =
      (RxNotification**)malloc(kNotificationBufSize * sizeof(RxNotification*));
  if (notification_buf_pair->next_rx_pipe_notifs == NULL) {
    std::cerr << "Could not allocate memory" << std::endl;
    return -1;
  }

  notification_buf_pair->next_rx_ids_head = 0;
  notification_buf_pair->next_rx_ids_tail = 0;
  notification_buf_pair->tx_full_cnt = 0;

  notification_buf_pair->nb_unreported_completions = 0;
  notification_buf_pair->huge_page_prefix = huge_page_prefix;

  // Setting the address enables the queue. Do this last.
  // Use first half of the huge page for RX and second half for TX.
  DevBackend::mmio_write32(&notification_buf_pair_regs->rx_mem_low,
                           (uint32_t)phys_addr,
                           notification_buf_pair->uio_mmap_bar2_addr);
  DevBackend::mmio_write32(&notification_buf_pair_regs->rx_mem_high,
                           (uint32_t)(phys_addr >> 32),
                           notification_buf_pair->uio_mmap_bar2_addr);

  phys_addr += kAlignedDscBufPairSize / 2;

  DevBackend::mmio_write32(&notification_buf_pair_regs->tx_mem_low,
                           (uint32_t)phys_addr,
                           notification_buf_pair->uio_mmap_bar2_addr);
  DevBackend::mmio_write32(&notification_buf_pair_regs->tx_mem_high,
                           (uint32_t)(phys_addr >> 32),
                           notification_buf_pair->uio_mmap_bar2_addr);
  return 0;
}

int enso_pipe_init(struct RxEnsoPipeInternal* enso_pipe,
                   struct NotificationBufPair* notification_buf_pair,
                   bool fallback) {
  void* uio_mmap_bar2_addr = notification_buf_pair->uio_mmap_bar2_addr;
  DevBackend* fpga_dev =
      static_cast<DevBackend*>(notification_buf_pair->fpga_dev);

  int enso_pipe_id = fpga_dev->AllocatePipe(fallback);

  if (enso_pipe_id < 0) {
    std::cerr << "Could not allocate pipe" << std::endl;
    return -1;
  }

  // Register associated with the enso pipe.
  volatile struct QueueRegs* enso_pipe_regs =
      (struct QueueRegs*)((uint8_t*)uio_mmap_bar2_addr +
                          enso_pipe_id * kMemorySpacePerQueue);
  enso_pipe->regs = (struct QueueRegs*)enso_pipe_regs;
  enso_pipe->uio_mmap_bar2_addr = uio_mmap_bar2_addr;
  // Make sure the queue is disabled.
  DevBackend::mmio_write32(&enso_pipe_regs->rx_mem_low, 0,
                           notification_buf_pair->uio_mmap_bar2_addr);
  DevBackend::mmio_write32(&enso_pipe_regs->rx_mem_high, 0,
                           notification_buf_pair->uio_mmap_bar2_addr);

  uint64_t mask = (1L << 32L) - 1L;
  while ((DevBackend::mmio_read32(&enso_pipe_regs->rx_mem_low,
                                  notification_buf_pair->uio_mmap_bar2_addr) &
          (~mask)) != 0 ||
         DevBackend::mmio_read32(&enso_pipe_regs->rx_mem_high,
                                 notification_buf_pair->uio_mmap_bar2_addr) !=
             0) {
    continue;
  }

  // Make sure head and tail start at zero.
  DevBackend::mmio_write32(&enso_pipe_regs->rx_tail, 0,
                           notification_buf_pair->uio_mmap_bar2_addr);
  while (DevBackend::mmio_read32(&enso_pipe_regs->rx_tail,
                                 notification_buf_pair->uio_mmap_bar2_addr) !=
         0)
    continue;

  DevBackend::mmio_write32(&enso_pipe_regs->rx_head, 0,
                           notification_buf_pair->uio_mmap_bar2_addr);
  while (DevBackend::mmio_read32(&enso_pipe_regs->rx_head,
                                 notification_buf_pair->uio_mmap_bar2_addr) !=
         0)
    continue;

  std::string huge_page_path = notification_buf_pair->huge_page_prefix +
                               std::string(kHugePageRxPipePathPrefix) +
                               std::to_string(enso_pipe_id);

  enso_pipe->buf = (uint32_t*)get_huge_page(huge_page_path, 0, true);
  if (enso_pipe->buf == NULL) {
    std::cerr << "Could not get huge page" << std::endl;
    return -1;
  }
  uint64_t phys_addr = fpga_dev->ConvertVirtAddrToDevAddr(enso_pipe->buf);

  enso_pipe->buf_phys_addr = phys_addr;
  enso_pipe->phys_buf_offset = phys_addr - (uint64_t)(enso_pipe->buf);

  enso_pipe->id = enso_pipe_id;
  enso_pipe->buf_head_ptr = (uint32_t*)&enso_pipe_regs->rx_head;
  enso_pipe->rx_head = 0;
  enso_pipe->rx_tail = 0;
  enso_pipe->huge_page_prefix = notification_buf_pair->huge_page_prefix;

  // Make sure the last tail matches the current head.
  notification_buf_pair->pending_rx_pipe_tails[enso_pipe->id] =
      enso_pipe->rx_head;

  // Setting the address enables the queue. Do this last.
  // The least significant bits in rx_mem_low are used to keep the notification
  // buffer ID. Therefore we add `notification_buf_pair->id` to the address.
  DevBackend::mmio_write32(&enso_pipe_regs->rx_mem_low,
                           (uint32_t)phys_addr + notification_buf_pair->id,
                           notification_buf_pair->uio_mmap_bar2_addr);
  DevBackend::mmio_write32(&enso_pipe_regs->rx_mem_high,
                           (uint32_t)(phys_addr >> 32),
                           notification_buf_pair->uio_mmap_bar2_addr);
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
                                    huge_page_prefix, -1);
    if (ret != 0) {
      return ret;
    }
  }

  ++(notification_buf_pair->ref_cnt);

  return enso_pipe_init(enso_pipe, notification_buf_pair, fallback);
}

/**
 * @brief Updates bookkeeping on until where packets are
 *        available for each enso RX pipe, adds to ring buffer with
 *        next notifications to consume.
 *
 * @param notification_buf_pair
 * @return Number of consumed notifications.
 */
static _enso_always_inline uint16_t
__get_new_tails(struct NotificationBufPair* notification_buf_pair) {
  struct RxNotification* notification_buf = notification_buf_pair->rx_buf;
  uint32_t notification_buf_head = notification_buf_pair->rx_head;
  uint16_t nb_consumed_notifications = 0;

  uint16_t next_rx_ids_tail = notification_buf_pair->next_rx_ids_tail;

  for (uint16_t i = 0; i < kBatchSize; ++i) {
    struct RxNotification* cur_notification =
        notification_buf + notification_buf_head;

    // Check if the next notification was updated by the NIC.
    if (!cur_notification->signal) {
      break;
    }
    // std::cout << "Got notification for notif buf " <<
    // notification_buf_pair->id
    //           << " at notif buf head " << notification_buf_head
    //           << " until tail " << cur_notification->tail << std::endl;
    cur_notification->signal = 0;

    notification_buf_head = (notification_buf_head + 1) % kNotificationBufSize;

    // updates the 'tail', that is, until where you can read,
    // for the given enso pipe
    enso_pipe_id_t enso_pipe_id = cur_notification->queue_id;
    notification_buf_pair->pending_rx_pipe_tails[enso_pipe_id] =
        (uint32_t)cur_notification->tail;

    // orders the new updates: read pipes from next_rx_ids_head to
    // next_rx_ids_tail
    notification_buf_pair->next_rx_pipe_notifs[next_rx_ids_tail] =
        cur_notification;
    next_rx_ids_tail = (next_rx_ids_tail + 1) % kNotificationBufSize;

    ++nb_consumed_notifications;
  }

  notification_buf_pair->next_rx_ids_tail = next_rx_ids_tail;

  if (likely(nb_consumed_notifications > 0)) {
    DevBackend::mmio_write32(notification_buf_pair->rx_head_ptr,
                             notification_buf_head,
                             notification_buf_pair->uio_mmap_bar2_addr);
    notification_buf_pair->rx_head = notification_buf_head;
  }

  return nb_consumed_notifications;
}

uint16_t get_new_tails(struct NotificationBufPair* notification_buf_pair) {
  return __get_new_tails(notification_buf_pair);
}

static _enso_always_inline uint32_t
__consume_queue(struct RxEnsoPipeInternal* enso_pipe,
                struct NotificationBufPair* notification_buf_pair, void** buf,
                bool peek = false) {
  // std::cout << "consuming queue" << std::endl;
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

static _enso_always_inline struct RxNotification* __get_next_rx_notif(
    struct NotificationBufPair* notification_buf_pair) {
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
      return nullptr;
    }
  }

  struct RxNotification* notification =
      notification_buf_pair->next_rx_pipe_notifs[next_rx_ids_head];

  notification_buf_pair->next_rx_ids_head =
      (next_rx_ids_head + 1) % kNotificationBufSize;

  return notification;
}

struct RxNotification* get_next_rx_notif(
    struct NotificationBufPair* notification_buf_pair) {
  return __get_next_rx_notif(notification_buf_pair);
}

static _enso_always_inline int32_t
__get_next_enso_pipe_id(struct NotificationBufPair* notification_buf_pair) {
  struct RxNotification* notification =
      get_next_rx_notif(notification_buf_pair);
  return notification->queue_id;
}

int32_t get_next_enso_pipe_id(
    struct NotificationBufPair* notification_buf_pair) {
  return __get_next_enso_pipe_id(notification_buf_pair);
}

// Return next batch among all open sockets.
uint32_t get_next_batch(struct NotificationBufPair* notification_buf_pair,
                        struct SocketInternal* socket_entries,
                        int* enso_pipe_id, void** buf) {
  RxNotification* notif = __get_next_rx_notif(notification_buf_pair);

  if (unlikely(!notif)) {
    return 0;
  }

  int32_t __enso_pipe_id = notif->queue_id;

  *enso_pipe_id = __enso_pipe_id;

  struct SocketInternal* socket_entry = &socket_entries[__enso_pipe_id];
  struct RxEnsoPipeInternal* enso_pipe = &socket_entry->enso_pipe;

  return __consume_queue(enso_pipe, notification_buf_pair, buf);
}

void advance_pipe(struct RxEnsoPipeInternal* enso_pipe, size_t len) {
  uint32_t rx_pkt_head = enso_pipe->rx_head;
  uint32_t nb_flits = ((uint64_t)len - 1) / 64 + 1;
  rx_pkt_head = (rx_pkt_head + nb_flits) % ENSO_PIPE_SIZE;

  // std::cout << "advance pipe: " << rx_pkt_head << std::endl;
  DevBackend::mmio_write32(enso_pipe->buf_head_ptr, rx_pkt_head,
                           enso_pipe->uio_mmap_bar2_addr);
  enso_pipe->rx_head = rx_pkt_head;
}

void fully_advance_pipe(struct RxEnsoPipeInternal* enso_pipe) {
  // std::cout << "fully advance pipe: " << enso_pipe->rx_tail << std::endl;

  DevBackend::mmio_write32(enso_pipe->buf_head_ptr, enso_pipe->rx_tail,
                           enso_pipe->uio_mmap_bar2_addr);
  enso_pipe->rx_head = enso_pipe->rx_tail;
}

void prefetch_pipe(struct RxEnsoPipeInternal* enso_pipe) {
  DevBackend::mmio_write32(enso_pipe->buf_head_ptr, enso_pipe->rx_head,
                           enso_pipe->uio_mmap_bar2_addr);
}

static _enso_always_inline uint32_t
__send_to_queue(struct NotificationBufPair* notification_buf_pair,
                uint64_t phys_addr, uint32_t len, bool first) {
  struct TxNotification* tx_buf = notification_buf_pair->tx_buf;
  uint32_t tx_tail = notification_buf_pair->tx_tail;
  uint32_t missing_bytes = len;

  uint64_t transf_addr = phys_addr;
  uint64_t hugepage_mask = ~((uint64_t)kBufPageSize - 1);
  uint64_t hugepage_base_addr = transf_addr & hugepage_mask;
  uint64_t hugepage_boundary = hugepage_base_addr + kBufPageSize;

  while (missing_bytes > 0) {
    uint32_t free_slots =
        (notification_buf_pair->tx_head - tx_tail - 1) % kNotificationBufSize;

    // Block until we can send.
    while (unlikely(free_slots == 0)) {
      ++notification_buf_pair->tx_full_cnt;
      if (park_callback_ != nullptr) {
        std::invoke(park_callback_, false);
      }
      update_tx_head(notification_buf_pair);
      free_slots =
          (notification_buf_pair->tx_head - tx_tail - 1) % kNotificationBufSize;
    }

    struct TxNotification* tx_notification = tx_buf + tx_tail;
    uint32_t req_length = std::min(missing_bytes, (uint32_t)kMaxTransferLen);
    uint32_t missing_bytes_in_page = hugepage_boundary - transf_addr;
    req_length = std::min(req_length, missing_bytes_in_page);

    // If the transmission needs to be split among multiple requests, we
    // need to set a bit in the wrap tracker.
    uint8_t wrap_tracker_mask = (missing_bytes > req_length) << (tx_tail & 0x7);
    notification_buf_pair->wrap_tracker[tx_tail / 8] |= wrap_tracker_mask;

    tx_notification->length = req_length;
    tx_notification->signal = 1;
    tx_notification->phys_addr = transf_addr;

    uint64_t huge_page_offset = (transf_addr + req_length) % kBufPageSize;
    transf_addr = hugepage_base_addr + huge_page_offset;

    // if (first)
    //   std::cout << "sent phys addr " << phys_addr << " for notif buf "
    //             << notification_buf_pair->id << " at tx tail " << tx_tail
    //             << std::endl;

    tx_tail = (tx_tail + 1) % kNotificationBufSize;
    missing_bytes -= req_length;
  }

  // std::cout << "Notif buf " << notification_buf_pair->id << " tx tail is now
  // "
  //           << tx_tail << std::endl;
  notification_buf_pair->tx_tail = tx_tail;
  DevBackend::mmio_write32(notification_buf_pair->tx_tail_ptr, tx_tail,
                           notification_buf_pair->uio_mmap_bar2_addr, first);

  return len;
}

uint32_t send_to_queue(struct NotificationBufPair* notification_buf_pair,
                       uint64_t phys_addr, uint32_t len, bool first) {
  return __send_to_queue(notification_buf_pair, phys_addr, len, first);
}

uint32_t get_unreported_completions(
    struct NotificationBufPair* notification_buf_pair) {
  uint32_t completions;
  update_tx_head(notification_buf_pair);
  completions = notification_buf_pair->nb_unreported_completions;
  notification_buf_pair->nb_unreported_completions = 0;

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

    // std::cout << "Notif buf " << notification_buf_pair->id
    //           << " consumed tx notification at " << head << std::endl;

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
                struct TxNotification* config_notification,
                CompletionCallback* completion_callback) {
  struct TxNotification* tx_buf = notification_buf_pair->tx_buf;
  uint32_t tx_tail = notification_buf_pair->tx_tail;
  uint32_t free_slots =
      (notification_buf_pair->tx_head - tx_tail - 1) % kNotificationBufSize;
  // Make sure it's a config notification.
  if (config_notification->signal < 2) {
    return -1;
  }

  // Block until we can send.
  while (unlikely(free_slots == 0)) {
    ++notification_buf_pair->tx_full_cnt;
    update_tx_head(notification_buf_pair);
    free_slots =
        (notification_buf_pair->tx_head - tx_tail - 1) % kNotificationBufSize;
    if (park_callback_ != nullptr) {
      std::invoke(park_callback_, false);
    }
  }

  struct TxNotification* tx_notification = tx_buf + tx_tail;
  *tx_notification = *config_notification;

  tx_tail = (tx_tail + 1) % kNotificationBufSize;
  notification_buf_pair->tx_tail = tx_tail;
  DevBackend::mmio_write32(notification_buf_pair->tx_tail_ptr, tx_tail,
                           notification_buf_pair->uio_mmap_bar2_addr);

  // Wait for request to be consumed.
  uint32_t nb_unreported_completions =
      notification_buf_pair->nb_unreported_completions;
  while (notification_buf_pair->nb_unreported_completions ==
         nb_unreported_completions) {
    if (park_callback_ != nullptr) {
      std::invoke(park_callback_, false);
    }
    update_tx_head(notification_buf_pair);
  }

  // iterate over all nb_unreported_completions and invoke completion callback
  if (completion_callback != nullptr) {
    uint32_t unreported_config_completions =
        notification_buf_pair->nb_unreported_completions -
        nb_unreported_completions;
    for (uint32_t i = 0; i < unreported_config_completions; i++) {
      std::invoke(*completion_callback);
    }
  }
  notification_buf_pair->nb_unreported_completions = nb_unreported_completions;

  return 0;
}

int get_nb_fallback_queues(struct NotificationBufPair* notification_buf_pair) {
  DevBackend* fpga_dev =
      static_cast<DevBackend*>(notification_buf_pair->fpga_dev);
  return fpga_dev->GetNbFallbackQueues();
}

int set_round_robin_status(struct NotificationBufPair* notification_buf_pair,
                           bool round_robin) {
  DevBackend* fpga_dev =
      static_cast<DevBackend*>(notification_buf_pair->fpga_dev);
  return fpga_dev->SetRrStatus(round_robin);
}

int get_round_robin_status(struct NotificationBufPair* notification_buf_pair) {
  DevBackend* fpga_dev =
      static_cast<DevBackend*>(notification_buf_pair->fpga_dev);
  return fpga_dev->GetRrStatus();
}

uint64_t get_dev_addr_from_virt_addr(
    struct NotificationBufPair* notification_buf_pair, void* virt_addr) {
  DevBackend* fpga_dev =
      static_cast<DevBackend*>(notification_buf_pair->fpga_dev);
  uint64_t dev_addr = fpga_dev->ConvertVirtAddrToDevAddr(virt_addr);
  return dev_addr;
}

void notification_buf_free(struct NotificationBufPair* notification_buf_pair) {
  DevBackend* fpga_dev =
      static_cast<DevBackend*>(notification_buf_pair->fpga_dev);

  fpga_dev->FreeNotifBuf(notification_buf_pair->id);
  DevBackend::mmio_write32(&notification_buf_pair->regs->rx_mem_low, 0,
                           notification_buf_pair->uio_mmap_bar2_addr);
  DevBackend::mmio_write32(&notification_buf_pair->regs->rx_mem_high, 0,
                           notification_buf_pair->uio_mmap_bar2_addr);
  DevBackend::mmio_write32(&notification_buf_pair->regs->tx_mem_low, 0,
                           notification_buf_pair->uio_mmap_bar2_addr);
  DevBackend::mmio_write32(&notification_buf_pair->regs->tx_mem_high, 0,
                           notification_buf_pair->uio_mmap_bar2_addr);

  munmap(notification_buf_pair->rx_buf, kAlignedDscBufPairSize);

  std::string huge_page_path = notification_buf_pair->huge_page_prefix +
                               std::string(kHugePageNotifBufPathPrefix) +
                               std::to_string(notification_buf_pair->id);

  unlink(huge_page_path.c_str());

  free(notification_buf_pair->pending_rx_pipe_tails);
  free(notification_buf_pair->wrap_tracker);
  free(notification_buf_pair->next_rx_pipe_notifs);

  delete fpga_dev;
}

void enso_pipe_free(struct NotificationBufPair* notification_buf_pair,
                    struct RxEnsoPipeInternal* enso_pipe,
                    enso_pipe_id_t enso_pipe_id) {
  DevBackend* fpga_dev =
      static_cast<DevBackend*>(notification_buf_pair->fpga_dev);

  DevBackend::mmio_write32(&enso_pipe->regs->rx_mem_low, 0,
                           notification_buf_pair->uio_mmap_bar2_addr);
  DevBackend::mmio_write32(&enso_pipe->regs->rx_mem_high, 0,
                           notification_buf_pair->uio_mmap_bar2_addr);

  if (enso_pipe->buf) {
    munmap(enso_pipe->buf, kBufPageSize);
    std::string huge_page_path = enso_pipe->huge_page_prefix +
                                 std::string(kHugePageRxPipePathPrefix) +
                                 std::to_string(enso_pipe_id);
    unlink(huge_page_path.c_str());
    enso_pipe->buf = nullptr;
  }

  fpga_dev->FreePipe(enso_pipe_id);

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

void pcie_set_backend_core_id(uint32_t core_id) {
  set_backend_core_id_dev(core_id);
}

uint32_t get_enso_pipe_id_from_socket(struct SocketInternal* socket_entry) {
  return (uint32_t)socket_entry->enso_pipe.id;
}

void pcie_initialize_backend(BackendWrapper preempt_enable,
                             BackendWrapper preempt_disable,
                             IdCallback id_callback, TscCallback tsc_callback) {
  initialize_backend_dev(preempt_enable, preempt_disable, id_callback,
                         tsc_callback);
}

void pcie_push_to_backend(PipeNotification* notif) { push_to_backend(notif); }

std::optional<PipeNotification> pcie_push_to_backend_get_response(
    PipeNotification* notif) {
  return push_to_backend_get_response(notif);
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
