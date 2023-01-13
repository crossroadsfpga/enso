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

#include "pcie.h"

#include <arpa/inet.h>
#include <fcntl.h>
#include <immintrin.h>
#include <norman/consts.h>
#include <norman/helpers.h>
#include <sched.h>
#include <string.h>
#include <termios.h>
#include <time.h>

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
#include <system_error>

#include "syscall_api/intel_fpga_pcie_api.hpp"

namespace norman {

// Adapted from ixy.
static uint64_t virt_to_phys(void* virt) {
  long pagesize = sysconf(_SC_PAGESIZE);
  int fd = open("/proc/self/pagemap", O_RDONLY);
  if (fd < 0) {
    return 0;
  }
  // pagemap is an array of pointers for each normal-sized page
  if (lseek(fd, (uintptr_t)virt / pagesize * sizeof(uintptr_t), SEEK_SET) < 0) {
    close(fd);
    return 0;
  }

  uintptr_t phy = 0;
  if (read(fd, &phy, sizeof(phy)) < 0) {
    close(fd);
    return 0;
  }
  close(fd);

  if (!phy) {
    return 0;
  }
  // bits 0-54 are the page number
  return (uint64_t)((phy & 0x7fffffffffffffULL) * pagesize +
                    ((uintptr_t)virt) % pagesize);
}

// Adapted from ixy.
static void* get_huge_page(int queue_id, size_t size) {
  int fd;
  char huge_pages_path[128];

  snprintf(huge_pages_path, sizeof(huge_pages_path), "/mnt/huge/norman:%i",
           queue_id);

  fd = open(huge_pages_path, O_CREAT | O_RDWR, S_IRWXU);
  if (fd == -1) {
    std::cerr << "(" << errno << ") Problem opening huge page file descriptor"
              << std::endl;
    return NULL;
  }

  if (ftruncate(fd, (off_t)size)) {
    std::cerr << "(" << errno
              << ") Could not truncate huge page to size: " << size
              << std::endl;
    close(fd);
    unlink(huge_pages_path);
    return NULL;
  }

  void* virt_addr = (void*)mmap(NULL, size * 2, PROT_READ | PROT_WRITE,
                                MAP_SHARED | MAP_HUGETLB, fd, 0);

  if (virt_addr == (void*)-1) {
    std::cerr << "(" << errno << ") Could not mmap huge page" << std::endl;
    close(fd);
    unlink(huge_pages_path);
    return NULL;
  }

  // Allocate same huge page at the end of the last one.
  void* ret =
      (void*)mmap((uint8_t*)virt_addr + size, size, PROT_READ | PROT_WRITE,
                  MAP_FIXED | MAP_SHARED | MAP_HUGETLB, fd, 0);

  if (ret == (void*)-1) {
    std::cerr << "(" << errno << ") Could not mmap second huge page"
              << std::endl;
    close(fd);
    unlink(huge_pages_path);
    free(virt_addr);
    return NULL;
  }

  if (mlock(virt_addr, size)) {
    std::cerr << "(" << errno << ") Could not lock huge page" << std::endl;
    munmap(virt_addr, size);
    close(fd);
    unlink(huge_pages_path);
    return NULL;
  }

  // Don't keep it around in the hugetlbfs.
  close(fd);
  unlink(huge_pages_path);

  return virt_addr;
}

int notification_buf_init(struct NotificationBufPair* notification_buf_pair,
                          volatile struct QueueRegs* notification_buf_pair_regs,
                          enso_pipe_id_t nb_queues,
                          enso_pipe_id_t enso_pipe_id_offset) {
  // Make sure the notification buffer is disabled.
  notification_buf_pair_regs->rx_mem_low = 0;
  notification_buf_pair_regs->rx_mem_high = 0;
  _norman_compiler_memory_barrier();
  while (notification_buf_pair_regs->rx_mem_low != 0 ||
         notification_buf_pair_regs->rx_mem_high != 0)
    continue;

  // Make sure head and tail start at zero.
  notification_buf_pair_regs->rx_tail = 0;
  _norman_compiler_memory_barrier();
  while (notification_buf_pair_regs->rx_tail != 0) continue;

  notification_buf_pair_regs->rx_head = 0;
  _norman_compiler_memory_barrier();
  while (notification_buf_pair_regs->rx_head != 0) continue;

  notification_buf_pair->regs = (struct QueueRegs*)notification_buf_pair_regs;
  notification_buf_pair->rx_buf = (struct RxNotification*)get_huge_page(
      notification_buf_pair->id + MAX_NB_FLOWS, ALIGNED_DSC_BUF_PAIR_SIZE);
  if (notification_buf_pair->rx_buf == NULL) {
    std::cerr << "Could not get huge page" << std::endl;
    return -1;
  }

  // Use first half of the huge page for RX and second half for TX.
  notification_buf_pair->tx_buf =
      (struct TxNotification*)((uint64_t)notification_buf_pair->rx_buf +
                               ALIGNED_DSC_BUF_PAIR_SIZE / 2);

  uint64_t phys_addr = virt_to_phys(notification_buf_pair->rx_buf);

  notification_buf_pair->rx_head_ptr =
      (uint32_t*)&notification_buf_pair_regs->rx_head;
  notification_buf_pair->tx_tail_ptr =
      (uint32_t*)&notification_buf_pair_regs->tx_tail;
  notification_buf_pair->rx_head = notification_buf_pair_regs->rx_head;

  // Preserve TX DSC tail and make head have the same value.
  notification_buf_pair->tx_tail = notification_buf_pair_regs->tx_tail;
  notification_buf_pair->tx_head = notification_buf_pair->tx_tail;

  _norman_compiler_memory_barrier();
  notification_buf_pair_regs->tx_head = notification_buf_pair->tx_head;

  // HACK(sadok): assuming that we know the number of queues beforehand
  notification_buf_pair->pending_pkt_tails = (uint32_t*)malloc(
      sizeof(*(notification_buf_pair->pending_pkt_tails)) * nb_queues);
  if (notification_buf_pair->pending_pkt_tails == NULL) {
    std::cerr << "Could not allocate memory" << std::endl;
    return -1;
  }
  memset(notification_buf_pair->pending_pkt_tails, 0, nb_queues);

  notification_buf_pair->wrap_tracker =
      (uint8_t*)malloc(NOTIFICATION_BUF_SIZE / 8);
  if (notification_buf_pair->wrap_tracker == NULL) {
    std::cerr << "Could not allocate memory" << std::endl;
    return -1;
  }
  memset(notification_buf_pair->wrap_tracker, 0, NOTIFICATION_BUF_SIZE / 8);

  notification_buf_pair->last_rx_ids =
      (enso_pipe_id_t*)malloc(NOTIFICATION_BUF_SIZE * sizeof(enso_pipe_id_t));
  if (notification_buf_pair->last_rx_ids == NULL) {
    std::cerr << "Could not allocate memory" << std::endl;
    return -1;
  }

  notification_buf_pair->pending_rx_ids = 0;
  notification_buf_pair->consumed_rx_ids = 0;
  notification_buf_pair->tx_full_cnt = 0;
  notification_buf_pair->nb_unreported_completions = 0;

  // HACK(sadok): This only works because enso pipes for the same app are
  // currently placed back to back.
  notification_buf_pair->enso_pipe_id_offset = enso_pipe_id_offset;

  // Setting the address enables the queue. Do this last.
  // Use first half of the huge page for RX and second half for TX.
  _norman_compiler_memory_barrier();
  notification_buf_pair_regs->rx_mem_low = (uint32_t)phys_addr;
  notification_buf_pair_regs->rx_mem_high = (uint32_t)(phys_addr >> 32);
  phys_addr += ALIGNED_DSC_BUF_PAIR_SIZE / 2;
  notification_buf_pair_regs->tx_mem_low = (uint32_t)phys_addr;
  notification_buf_pair_regs->tx_mem_high = (uint32_t)(phys_addr >> 32);

  return 0;
}

int enso_pipe_init(struct RxEnsoPipeInternal* enso_pipe,
                   volatile struct QueueRegs* enso_pipe_regs,
                   struct NotificationBufPair* notification_buf_pair,
                   enso_pipe_id_t enso_pipe_id) {
  enso_pipe->regs = (struct QueueRegs*)enso_pipe_regs;

  // Make sure the queue is disabled.
  enso_pipe_regs->rx_mem_low = 0;
  enso_pipe_regs->rx_mem_high = 0;
  _norman_compiler_memory_barrier();
  while (enso_pipe_regs->rx_mem_low != 0 || enso_pipe_regs->rx_mem_high != 0)
    continue;

  // Make sure head and tail start at zero.
  enso_pipe_regs->rx_tail = 0;
  _norman_compiler_memory_barrier();
  while (enso_pipe_regs->rx_tail != 0) continue;

  enso_pipe_regs->rx_head = 0;
  _norman_compiler_memory_barrier();
  while (enso_pipe_regs->rx_head != 0) continue;

  enso_pipe->buf = (uint32_t*)get_huge_page(enso_pipe_id, BUF_PAGE_SIZE);
  if (enso_pipe->buf == NULL) {
    std::cerr << "Could not get huge page" << std::endl;
    return -1;
  }
  uint64_t phys_addr = virt_to_phys(enso_pipe->buf);

  enso_pipe->buf_phys_addr = phys_addr;
  enso_pipe->phys_buf_offset = phys_addr - (uint64_t)(enso_pipe->buf);

  enso_pipe->id = enso_pipe_id - notification_buf_pair->enso_pipe_id_offset;
  enso_pipe->buf_head_ptr = (uint32_t*)&enso_pipe_regs->rx_head;
  enso_pipe->rx_head = 0;
  enso_pipe->rx_tail = 0;

  // make sure the last tail matches the current head
  notification_buf_pair->pending_pkt_tails[enso_pipe->id] = enso_pipe->rx_head;

  // Setting the address enables the queue. Do this last.
  // The least significant bits in rx_mem_low are used to keep the notification
  // buffer ID. Therefore we add `notification_buf_pair->id` to the address.
  _norman_compiler_memory_barrier();
  enso_pipe_regs->rx_mem_low = (uint32_t)phys_addr + notification_buf_pair->id;
  enso_pipe_regs->rx_mem_high = (uint32_t)(phys_addr >> 32);

  return 0;
}

int dma_init(intel_fpga_pcie_dev* dev,
             struct NotificationBufPair* notification_buf_pair,
             struct RxEnsoPipeInternal* enso_pipe, unsigned socket_id,
             unsigned nb_queues) {
  void* uio_mmap_bar2_addr;
  enso_pipe_id_t enso_pipe_id;

  printf("Running with BATCH_SIZE: %i\n", BATCH_SIZE);
  printf("Running with NOTIFICATION_BUF_SIZE: %i\n", NOTIFICATION_BUF_SIZE);
  printf("Running with ENSO_PIPE_SIZE: %i\n", ENSO_PIPE_SIZE);

  // We need this to allow the same huge page to be mapped to contiguous
  // memory regions.
  // TODO(sadok): support other buffer sizes. It may be possible to support
  // other buffer sizes by overlaying regular pages on top of the huge pages.
  // We might use those only for requests that overlap to avoid adding too
  // many entries to the TLB.
  assert(ENSO_PIPE_SIZE * 64 == BUF_PAGE_SIZE);

  // FIXME(sadok) should find a better identifier than core id.

  notification_buf_pair->id = sched_getcpu();
  if (notification_buf_pair->id < 0) {
    std::cerr << "Could not get cpu id" << std::endl;
    return -1;
  }

  enso_pipe_id = notification_buf_pair->id * nb_queues + socket_id;

  uio_mmap_bar2_addr =
      dev->uio_mmap((1 << 12) * (MAX_NB_FLOWS + MAX_NB_APPS), 2);
  if (uio_mmap_bar2_addr == MAP_FAILED) {
    std::cerr << "Could not get mmap uio memory!" << std::endl;
    return -1;
  }

  // set notification buffer only for the first socket
  // TODO(sadok): Support multiple notification buffers for the same process.
  if (notification_buf_pair->ref_cnt == 0) {
    // Register associated with the notification buffer. Notification buffer
    // registers come after the enso pipe ones, that's why we use MAX_NB_FLOWS
    // as an offset.
    volatile struct QueueRegs* notification_buf_pair_regs =
        (struct QueueRegs*)((uint8_t*)uio_mmap_bar2_addr +
                            (notification_buf_pair->id + MAX_NB_FLOWS) *
                                MEMORY_SPACE_PER_QUEUE);

    // HACK(sadok): This only works because pkt queues for the same app are
    // currently placed back to back.
    enso_pipe_id_t enso_pipe_id_offset = enso_pipe_id;

    int ret =
        notification_buf_init(notification_buf_pair, notification_buf_pair_regs,
                              nb_queues, enso_pipe_id_offset);
    if (ret != 0) {
      return ret;
    }
  }

  ++(notification_buf_pair->ref_cnt);

  // Register associated with the enso pipe.
  volatile struct QueueRegs* enso_pipe_regs =
      (struct QueueRegs*)((uint8_t*)uio_mmap_bar2_addr +
                          enso_pipe_id * MEMORY_SPACE_PER_QUEUE);

  return enso_pipe_init(enso_pipe, enso_pipe_regs, notification_buf_pair,
                        enso_pipe_id);
}

static norman_always_inline uint16_t
__get_new_tails(struct NotificationBufPair* notification_buf_pair) {
  struct RxNotification* notification_buf = notification_buf_pair->rx_buf;
  uint32_t notification_buf_head = notification_buf_pair->rx_head;
  uint16_t nb_consumed_notifications = 0;

  for (uint16_t i = 0; i < BATCH_SIZE; ++i) {
    struct RxNotification* cur_notification =
        notification_buf + notification_buf_head;

    // check if the next notification was updated by the FPGA
    if (cur_notification->signal == 0) {
      break;
    }

    cur_notification->signal = 0;
    notification_buf_head = (notification_buf_head + 1) % NOTIFICATION_BUF_SIZE;

    enso_pipe_id_t enso_pipe_id =
        cur_notification->queue_id - notification_buf_pair->enso_pipe_id_offset;
    notification_buf_pair->pending_pkt_tails[enso_pipe_id] =
        (uint32_t)cur_notification->tail;
    notification_buf_pair->last_rx_ids[nb_consumed_notifications] =
        enso_pipe_id;

    ++nb_consumed_notifications;

    // TODO(sadok) consider prefetching. Two options to consider:
    // (1) prefetch all the packets;
    // (2) pass the current queue as argument and prefetch packets for it,
    //     including potentially old packets.
  }

  if (likely(nb_consumed_notifications > 0)) {
    // update notification buffer head
    _norman_compiler_memory_barrier();
    *(notification_buf_pair->rx_head_ptr) = notification_buf_head;
    notification_buf_pair->rx_head = notification_buf_head;
  }

  return nb_consumed_notifications;
}

static norman_always_inline int __consume_queue(
    struct RxEnsoPipeInternal* enso_pipe,
    struct NotificationBufPair* notification_buf_pair, void** buf,
    bool peek = false) {
  uint32_t* enso_pipe_buf = enso_pipe->buf;
  uint32_t enso_pipe_head = enso_pipe->rx_tail;
  int queue_id = enso_pipe->id;

  *buf = &enso_pipe_buf[enso_pipe_head * 16];

  uint32_t enso_pipe_tail = notification_buf_pair->pending_pkt_tails[queue_id];

  if (enso_pipe_tail == enso_pipe_head) {
    return 0;
  }

  _mm_prefetch(buf, _MM_HINT_T0);

  uint32_t flit_aligned_size =
      ((enso_pipe_tail - enso_pipe_head) % ENSO_PIPE_SIZE) * 64;

  if (!peek) {
    enso_pipe_head = (enso_pipe_head + flit_aligned_size / 64) % ENSO_PIPE_SIZE;
    enso_pipe->rx_tail = enso_pipe_head;
  }

  return flit_aligned_size;
}

int get_next_batch_from_queue(struct RxEnsoPipeInternal* enso_pipe,
                              struct NotificationBufPair* notification_buf_pair,
                              void** buf) {
  __get_new_tails(notification_buf_pair);
  return __consume_queue(enso_pipe, notification_buf_pair, buf);
}

int peek_next_batch_from_queue(
    struct RxEnsoPipeInternal* enso_pipe,
    struct NotificationBufPair* notification_buf_pair, void** buf) {
  __get_new_tails(notification_buf_pair);
  return __consume_queue(enso_pipe, notification_buf_pair, buf, true);
}

// Return next batch among all open sockets.
int get_next_batch(struct NotificationBufPair* notification_buf_pair,
                   struct SocketInternal* socket_entries, int* enso_pipe_id,
                   void** buf) {
  // Consume up to a batch of notifications at a time. If the number of consumed
  // notifications is the same as the number of pending notifications, we are
  // done processing the last batch and can get the next one. Using batches here
  // performs **significantly** better compared to always fetching the latest
  // notification.
  if (notification_buf_pair->pending_rx_ids ==
      notification_buf_pair->consumed_rx_ids) {
    notification_buf_pair->pending_rx_ids =
        __get_new_tails(notification_buf_pair);
    notification_buf_pair->consumed_rx_ids = 0;
    if (unlikely(notification_buf_pair->pending_rx_ids == 0)) {
      return 0;
    }
  }

  enso_pipe_id_t __enso_pipe_id =
      notification_buf_pair
          ->last_rx_ids[notification_buf_pair->consumed_rx_ids++];
  *enso_pipe_id = __enso_pipe_id;

  struct SocketInternal* socket_entry = &socket_entries[__enso_pipe_id];
  struct RxEnsoPipeInternal* enso_pipe = &socket_entry->enso_pipe;

  return __consume_queue(enso_pipe, notification_buf_pair, buf);
}

void advance_ring_buffer(struct RxEnsoPipeInternal* enso_pipe, size_t len) {
  uint32_t rx_pkt_head = enso_pipe->rx_head;
  uint32_t nb_flits = ((uint64_t)len - 1) / 64 + 1;
  rx_pkt_head = (rx_pkt_head + nb_flits) % ENSO_PIPE_SIZE;

  _norman_compiler_memory_barrier();
  *(enso_pipe->buf_head_ptr) = rx_pkt_head;

  enso_pipe->rx_head = rx_pkt_head;
}

void fully_advance_ring_buffer(struct RxEnsoPipeInternal* enso_pipe) {
  _norman_compiler_memory_barrier();
  *(enso_pipe->buf_head_ptr) = enso_pipe->rx_tail;

  enso_pipe->rx_head = enso_pipe->rx_tail;
}

int send_to_queue(struct NotificationBufPair* notification_buf_pair,
                  void* phys_addr, size_t len) {
  struct TxNotification* tx_buf = notification_buf_pair->tx_buf;
  uint32_t tx_tail = notification_buf_pair->tx_tail;
  uint64_t missing_bytes = len;

  uint64_t transf_addr = (uint64_t)phys_addr;
  uint64_t hugepage_mask = ~((uint64_t)BUF_PAGE_SIZE - 1);
  uint64_t hugepage_base_addr = transf_addr & hugepage_mask;
  uint64_t hugepage_boundary = hugepage_base_addr + BUF_PAGE_SIZE;

  while (missing_bytes > 0) {
    uint32_t free_slots =
        (notification_buf_pair->tx_head - tx_tail - 1) % NOTIFICATION_BUF_SIZE;

    // Block until we can send.
    while (unlikely(free_slots == 0)) {
      ++notification_buf_pair->tx_full_cnt;
      update_tx_head(notification_buf_pair);
      free_slots = (notification_buf_pair->tx_head - tx_tail - 1) %
                   NOTIFICATION_BUF_SIZE;
    }

    struct TxNotification* tx_notification = tx_buf + tx_tail;
    uint64_t req_length = std::min(missing_bytes, (uint64_t)MAX_TRANSFER_LEN);
    uint64_t missing_bytes_in_page = hugepage_boundary - transf_addr;
    req_length = std::min(req_length, missing_bytes_in_page);

    // If the transmission needs to be split among multiple requests, we
    // need to set a bit in the wrap tracker.
    uint8_t wrap_tracker_mask = (missing_bytes > req_length) << (tx_tail & 0x7);
    notification_buf_pair->wrap_tracker[tx_tail / 8] |= wrap_tracker_mask;

    tx_notification->length = req_length;
    tx_notification->signal = 1;
    tx_notification->phys_addr = transf_addr;

    uint64_t huge_page_offset = (transf_addr + req_length) % BUF_PAGE_SIZE;
    transf_addr = hugepage_base_addr + huge_page_offset;

    _mm_clflushopt(tx_notification);

    tx_tail = (tx_tail + 1) % NOTIFICATION_BUF_SIZE;
    missing_bytes -= req_length;
  }

  notification_buf_pair->tx_tail = tx_tail;

  _norman_compiler_memory_barrier();
  *(notification_buf_pair->tx_tail_ptr) = tx_tail;

  return 0;
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
  for (uint16_t i = 0; i < BATCH_SIZE; ++i) {
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

    head = (head + 1) % NOTIFICATION_BUF_SIZE;
  }

  notification_buf_pair->tx_head = head;
}

void notification_buf_free(struct NotificationBufPair* notification_buf_pair) {
  notification_buf_pair->regs->rx_mem_low = 0;
  notification_buf_pair->regs->rx_mem_high = 0;

  notification_buf_pair->regs->tx_mem_low = 0;
  notification_buf_pair->regs->tx_mem_high = 0;
  munmap(notification_buf_pair->rx_buf, ALIGNED_DSC_BUF_PAIR_SIZE);
  free(notification_buf_pair->pending_pkt_tails);
  free(notification_buf_pair->wrap_tracker);
  free(notification_buf_pair->last_rx_ids);

  --(notification_buf_pair->ref_cnt);
}

void enso_pipe_free(struct RxEnsoPipeInternal* enso_pipe) {
  enso_pipe->regs->rx_mem_low = 0;
  enso_pipe->regs->rx_mem_high = 0;

  munmap(enso_pipe->buf, BUF_PAGE_SIZE);
}

int dma_finish(struct SocketInternal* socket_entry) {
  struct NotificationBufPair* notification_buf_pair =
      socket_entry->notification_buf_pair;

  enso_pipe_free(&socket_entry->enso_pipe);
  if (notification_buf_pair->ref_cnt == 0) {
    notification_buf_free(notification_buf_pair);
  }

  return 0;
}

uint32_t get_enso_pipe_id_from_socket(struct SocketInternal* socket_entry) {
  struct NotificationBufPair* notification_buf_pair =
      socket_entry->notification_buf_pair;
  return (uint32_t)socket_entry->enso_pipe.id +
         notification_buf_pair->enso_pipe_id_offset;
}

void print_fpga_reg(intel_fpga_pcie_dev* dev, unsigned nb_regs) {
  uint32_t temp_r;
  for (unsigned int i = 0; i < nb_regs; ++i) {
    dev->read32(2, reinterpret_cast<void*>(0 + i * 4), &temp_r);
    printf("fpga_reg[%d] = 0x%08x \n", i, temp_r);
  }
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

}  // namespace norman
