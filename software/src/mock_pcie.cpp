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

#define MAX_NUM_PACKETS 256;
#define BATCH_SIZE 16;

typedef struct packet {
    const uchar *pkt_bytes;
    uint32_t pkt_len;
} packet_t;

struct PcapHandlerContext {
  void **buf;
  int buf_position;
  uint32_t hugepage_offset;
  pcap_t* pcap;
};

struct timeval ts;
ts.tv_sec = 0;
ts.tv_usec = 0;
pcap_t* pd;
pcap_dumper_t* pdumper_out;
packet_t in_buf[MAX_NUM_PACKETS];
uint32_t pipe_packets_head;
uint32_t pipe_packets_tail;

int notification_buf_init(struct NotificationBufPair* notification_buf_pair,
                          volatile struct QueueRegs* notification_buf_pair_regs,
                          enso_pipe_id_t nb_queues,
                          enso_pipe_id_t enso_pipe_id_offset) {
  return 0;
}

// called each time a packet is processed
void pcap_pkt_handler(u_char* user, const struct pcap_pkthdr* pkt_hdr,
                      const u_char* pkt_bytes) {
    struct PcapHandlerContext* context = (struct PcapHandlerContext*)user;
    uint32_t len = pkt_hdr->len;

    packet_t pkt;
    pkt.pkt_bytes = pkt_bytes;
    pkt.pkt_len = len;
    context->buf[pipe_packets_tail] = pkt;

    pipe_packets_tail += 1;
}

int read_in_file() {
    // reading from in file and storing in a buffer
    char errbuf[PCAP_ERRBUF_SIZE];
    pcap_t* pcap = pcap_open_offline("in.pcap", errbuf);
    if (pcap == NULL) {
        std::cerr << "Error loading pcap file (" << errbuf << ")" << std::endl;
        return 2;
    }
    struct PcapHandlerContext context;
    context.hugepage_offset = HUGEPAGE_SIZE;
    context.pcap = pcap;
    context.buf = in_buf;
    // read infinitely until packets are all consumed
    if (pcap_loop(pcap, 0, pcap_pkt_handler, (u_char*)&context) < 0) {
        std::cerr << "Error while reading pcap (" << pcap_geterr(pcap) << ")"
                << std::endl;
        return 3;
    }
    return 0;
}

int enso_pipe_init(struct RxEnsoPipeInternal* enso_pipe,
                   volatile struct QueueRegs* enso_pipe_regs,
                   struct NotificationBufPair* notification_buf_pair,
                   enso_pipe_id_t enso_pipe_id) {
    pipe_packets_head = 0;
    pipe_packets_tail = 0;

    // opening files to dump packets to
    pd = pcap_open_dead(DLT_EN10MB, 65535);
    pdumper = pcap_dump_open(pd, "out.pcap");

    if (read_in_file() < 0)  
        return -1;

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
    if (pipe_packets_head==pipe_packets_tail)
        return 0;
    
    int index = 0;
    int num_bytes_read = 0;
    while (pipe_packets_head < std::min(pipe_packets_tail, pipe_packets_head + BATCH_SIZE))
        packet_t pkt = in_buf[pipe_packets_head];
        memcpy(*buf[index], pkt.pkt_bytes);
        num_bytes_read += pkt.pkt_len;
        index += 1;
        pipe_packets_head += 1;
    }

    return num_bytes_read;
}

uint32_t get_next_batch_from_queue(
    struct RxEnsoPipeInternal* enso_pipe,
    struct NotificationBufPair* notification_buf_pair, void** buf) {
    return 0;
}

uint32_t peek_next_batch_from_queue(
    struct RxEnsoPipeInternal* enso_pipe,
    struct NotificationBufPair* notification_buf_pair, void** buf) {
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

}

uint32_t send_to_queue(struct NotificationBufPair* notification_buf_pair,
                       uint64_t phys_addr, uint32_t len) {
    // phys_addr is the virtual address in the mock
    // add number of times you want to send this set of packets using macros
    // writing to file is like writing to network
    // the file is the network, like an ethernet pipe
    // set transmission bandwidth as a parameter, never allow
    // more data in a certain period of time than the given bandwidth
    // calculate number of packets per interval 
    // can sleep until then OR loop using c++ function https://en.cppreference.com/w/cpp/thread/sleep_for

    // to test, follow the README.md
    unsigned char buf[len];
    memcpy(phys_addr, buf, len);
    
    int processed_bytes = 0;
    uint8_t *pkt = buf;
    
    while (processed_bytes < len) {
        // read header of each packet to get packet length
        uint16_t pkt_len = norman::get_pkt_len(pkt);
        // packets must be cache-aligned: so get aligned length
        uint16_t nb_flits = (pkt_len - 1) / 64 + 1;
        uint16_t pkt_aligned_len = nb_flits * 64;

        // Save packet to file using pcap
        struct pcap_pkthdr pkt_hdr;
        pkt_hdr.ts = ts;
        pkt_hdr.len = pkt_len;
        pkt_hdr.caplen = pkt_len;
        ++(ts.tv_usec);
        pcap_dump((u_char*)pdumper, &pkt_hdr, pkt);

        // moving packet forward by aligned length
        pkt += pkt_aligned_len;
        processed_bytes += pkt_aligned_len;
    }
    pipe_tail += processed_bytes;

    return 0;
}

uint32_t get_unreported_completions(){
    return 0;
}

void update_tx_head(struct NotificationBufPair* notification_buf_pair) {
}

void notification_buf_free(struct NotificationBufPair* notification_buf_pair) {

}

void enso_pipe_free(struct RxEnsoPipeInternal* enso_pipe) {
    pcap_dump_close(pdumper);
    pcap_close(pd);
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
