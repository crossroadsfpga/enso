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
#include <immintrin.h>
#include <norman/consts.h>
#include <norman/helpers.h>
#include <norman/ixy_helpers.h>
#include <sched.h>
#include <string.h>
#include <time.h>
#include <pcap/pcap.h>

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

#include "syscall_api/intel_fpga_pcie_api.hpp"
#include "pipe.h"

namespace norman {

int notification_buf_init(struct NotificationBufPair* notification_buf_pair,
                          volatile struct QueueRegs* notification_buf_pair_regs,
                          enso_pipe_id_t nb_queues,
                          enso_pipe_id_t enso_pipe_id_offset) {
  return 0;
}

int enso_pipe_init(struct RxEnsoPipeInternal* enso_pipe,
                   volatile struct QueueRegs* enso_pipe_regs,
                   struct NotificationBufPair* notification_buf_pair,
                   enso_pipe_id_t enso_pipe_id) {
  return 0;
}

int dma_init(intel_fpga_pcie_dev* dev,
             struct NotificationBufPair* notification_buf_pair,
             struct RxEnsoPipeInternal* enso_pipe, unsigned socket_id,
             unsigned nb_queues) {
  return 0;
}

static norman_always_inline uint16_t
__get_new_tails(struct NotificationBufPair* notification_buf_pair) {
  struct RxNotification* notification_buf = notification_buf_pair->rx_buf;
  uint32_t notification_buf_head = notification_buf_pair->rx_head;
  uint16_t nb_consumed_notifications = 0;
    return 0;
}

static norman_always_inline uint32_t
__consume_queue(struct RxEnsoPipeInternal* enso_pipe,
                struct NotificationBufPair* notification_buf_pair, void** buf,
                bool peek = false) {
  return 0;
}

uint32_t get_next_batch_from_queue(
    struct RxEnsoPipeInternal* enso_pipe,
    struct NotificationBufPair* notification_buf_pair, void** buf) {
  __get_new_tails(notification_buf_pair);
    return 0;
}

uint32_t peek_next_batch_from_queue(
    struct RxEnsoPipeInternal* enso_pipe,
    struct NotificationBufPair* notification_buf_pair, void** buf) {
  __get_new_tails(notification_buf_pair);
    return 0;
}

// Return next batch among all open sockets.
uint32_t get_next_batch(struct NotificationBufPair* notification_buf_pair,
                        struct SocketInternal* socket_entries,
                        int* enso_pipe_id, void** buf) {

}

void advance_ring_buffer(struct RxEnsoPipeInternal* enso_pipe, size_t len) {

}

void fully_advance_ring_buffer(struct RxEnsoPipeInternal* enso_pipe) {
  _norman_compiler_memory_barrier();
  
}

uint64_t phys_to_virt(void* phys) {
  long page_size = sysconf(_SC_PAGESIZE);

  uintptr_t offset = (uintptr_t)phys % page_size;

  // Bits 0-54 are the page number.
  return (uint64_t)((buf_virt_addr_ & 0x7fffffffffffffULL) * page_size +
                    ((uintptr_t)virt) % page_size);
}

static norman_always_inline uint32_t
__send_to_queue(struct NotificationBufPair* notification_buf_pair,
                uint64_t phys_addr, uint32_t len) {
  // should just 
}

uint32_t send_to_queue(struct NotificationBufPair* notification_buf_pair,
                       uint64_t phys_addr, uint32_t len) {
    uint64_t virt_addr = phys_to_virt(phys_addr);
    std::string pcap_file(len, '*');
    for (int i = 0; i < len; i++) {
        pcap_file[i] = phys_addr[i];
    }

    // saving data from phys_addr to file
    pcap_t* pd = pcap_open_dead(DLT_EN10MB, 65535);
    pcap_dumper_t* pdumper = pcap_dump_open(pd, pcap_file.c_str());
    return 0;
}

uint32_t get_unreported_completions(
    return 0;
}

void update_tx_head(struct NotificationBufPair* notification_buf_pair) {
}

void notification_buf_free(struct NotificationBufPair* notification_buf_pair) {

}

void enso_pipe_free(struct RxEnsoPipeInternal* enso_pipe) {

}

int dma_finish(struct SocketInternal* socket_entry) {
  
}

uint32_t get_enso_pipe_id_from_socket(struct SocketInternal* socket_entry) {
  
}

void print_fpga_reg(intel_fpga_pcie_dev* dev, unsigned nb_regs) {
  
}

void print_stats(struct SocketInternal* socket_entry, bool print_global) {
  
}

}  // namespace norman
