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

#include <arpa/inet.h>
#include <enso/consts.h>
#include <enso/helpers.h>
#include <enso/ixy_helpers.h>
#include <immintrin.h>
#include <pcap/pcap.h>
#include <sched.h>
#include <string.h>
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

#include "pcie.h"
#include "syscall_api/intel_fpga_pcie_api.hpp"

namespace enso {

#define MAX_NUM_PACKETS 512
#define MOCK_BATCH_SIZE 16

typedef struct packet {
  u_char* pkt_bytes;
  uint32_t pkt_len;
} packet_t;

struct PcapHandlerContext {
  packet_t** buf;
  int buf_position;
  uint32_t hugepage_offset;
  pcap_t* pcap;
};

struct timeval ts;
pcap_t* pd;
pcap_dumper_t* pdumper_out;
packet_t* in_buf[MAX_NUM_PACKETS];
uint32_t pipe_packets_head;
uint32_t pipe_packets_tail;

int notification_buf_init(uint32_t bdf, int32_t bar, int16_t core_id,
                          struct NotificationBufPair* notification_buf_pair,
                          enso_pipe_id_t nb_queues,
                          enso_pipe_id_t enso_pipe_id_offset) {
  (void)bdf;
  (void)bar;
  (void)core_id;
  (void)notification_buf_pair;
  (void)nb_queues;
  (void)enso_pipe_id_offset;
  return 0;
}

/**
 * @brief Handler for managing receiving packets in the mock. Adds read
 *        pakcets to in_buf up to MAX_NUM_PACKETS.
 *
 * @param user Not used here.
 * @param pkt_hdr Header for packet, includes information on the length.
 * @param pkt_bytes Actual packet bytes to store.
 */
void pcap_pkt_handler(u_char* user, const struct pcap_pkthdr* pkt_hdr,
                      const u_char* pkt_bytes) {
  std::cout << "Pipe tail " << pipe_packets_tail << std::endl;
  struct PcapHandlerContext* context = (struct PcapHandlerContext*)user;
  uint32_t len = pkt_hdr->len;

  packet_t* pkt = new packet_t;
  pkt->pkt_bytes = new u_char[len];
  memcpy(pkt->pkt_bytes, pkt_bytes, len);
  pkt->pkt_len = len;
  context->buf[pipe_packets_tail] = pkt;

  pipe_packets_tail += 1;
  // if we hit the max num packets to read, break from loop
  if (pipe_packets_tail == MAX_NUM_PACKETS) pcap_breakloop(context->pcap);
}

/**
 * @brief Reads from the in.pcap file up to MAX_NUM_PACKETS and stores in
 * in_buf.
 *
 * @return 0 on success, negative on failure.
 */
int read_in_file() {
  // reading from in file and storing in a buffer
  char errbuf[PCAP_ERRBUF_SIZE];
  pcap_t* pcap = pcap_open_offline("in.pcap", errbuf);
  if (pcap == NULL) {
    std::cerr << "Error loading pcap file (" << errbuf << ")" << std::endl;
    return -1;
  }
  struct PcapHandlerContext context;
  context.pcap = pcap;
  context.buf = in_buf;
  // read up to 256 packets
  int err;
  if ((err = pcap_loop(pcap, 0, pcap_pkt_handler, (u_char*)&context)) < 0) {
    std::cerr << "Error while reading pcap (" << pcap_geterr(pcap) << ")"
              << std::endl;
    std::cerr << "Error: " << err << std::endl;
    return -2;
  }
  return 0;
}

/**
 * @brief Initializes mock enso pipe: reads from the in_file and initializes
 * global variables.
 *
 * @param enso_pipe
 * @param notification_buf_pair
 * @param enso_pipe_id
 * @return 0 on success, negative on failure.
 */
int enso_pipe_init(struct RxEnsoPipeInternal* enso_pipe,
                   struct NotificationBufPair* notification_buf_pair,
                   enso_pipe_id_t enso_pipe_id) {
  (void)enso_pipe;
  (void)notification_buf_pair;
  (void)enso_pipe_id;

  ts.tv_sec = 0;
  ts.tv_usec = 0;

  pipe_packets_head = 0;
  pipe_packets_tail = 0;

  // opening files to dump packets to
  pd = pcap_open_dead(DLT_EN10MB, 65535);
  pdumper_out = pcap_dump_open(pd, "out.pcap");

  // read from in_file: this is what will be read when reading from the enso
  // pipes.
  if (read_in_file() < 0) return -1;

  return 0;
}

static _enso_always_inline uint32_t
__consume_queue(struct RxEnsoPipeInternal* enso_pipe,
                struct NotificationBufPair* notification_buf_pair, void** buf,
                bool peek = false) {
  (void)(enso_pipe);
  (void)notification_buf_pair;
  (void)peek;

  std::cout << "Consuming from queue" << std::endl;

  *buf = new u_char[0];

  if (pipe_packets_head == pipe_packets_tail) {
    std::cout << "Nothing in queue" << std::endl;
    return 0;
  }

  uint32_t index = 0;
  size_t num_bytes_read = 0;

  uint32_t max_index =
      std::min(pipe_packets_tail, pipe_packets_head + MOCK_BATCH_SIZE);
  // use receive-side scaling or round robin

  // getting total number of bytes to read
  while (index < max_index) {
    packet_t* pkt = in_buf[index];
    uint32_t pkt_len = pkt->pkt_len;
    // packets must be cache-aligned: so get aligned length
    uint16_t nb_flits = (pkt_len - 1) / 64 + 1;
    uint16_t pkt_aligned_len = nb_flits * 64;

    num_bytes_read += pkt_aligned_len;

    index += 1;
  }

  // malloc a buffer the c++ way
  u_char* my_buf = new u_char[num_bytes_read];
  num_bytes_read = 0;
  // reading bytes
  while (pipe_packets_head < max_index) {
    packet_t* pkt = in_buf[pipe_packets_head];
    memcpy(my_buf + num_bytes_read, pkt->pkt_bytes, pkt->pkt_len);
    uint32_t pkt_len = pkt->pkt_len;
    // packets must be cache-aligned: so get aligned length
    uint16_t nb_flits = (pkt_len - 1) / 64 + 1;
    uint16_t pkt_aligned_len = nb_flits * 64;

    num_bytes_read += pkt_aligned_len;

    pipe_packets_head += 1;
  }

  // give the buffer to the caller
  *buf = my_buf;

  return num_bytes_read;
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
  // can sleep until then OR loop using c++ function
  // https://en.cppreference.com/w/cpp/thread/sleep_for

  std::cout << "Sending to queue" << std::endl;

  (void)notification_buf_pair;

  u_char* addr_buf = new u_char[len];
  memcpy(addr_buf, (uint8_t*)phys_addr, len);

  uint32_t processed_bytes = 0;
  uint8_t* pkt = addr_buf;

  while (processed_bytes < len) {
    // read header of each packet to get packet length
    uint16_t pkt_len = enso::get_pkt_len(pkt);
    // packets must be cache-aligned: so get aligned length
    uint16_t nb_flits = (pkt_len - 1) / 64 + 1;
    uint16_t pkt_aligned_len = nb_flits * 64;

    // Save packet to file using pcap
    struct pcap_pkthdr pkt_hdr;
    pkt_hdr.ts = ts;
    pkt_hdr.len = pkt_len;
    pkt_hdr.caplen = pkt_len;
    ++(ts.tv_usec);
    pcap_dump((u_char*)pdumper_out, &pkt_hdr, pkt);

    // moving packet forward by aligned length
    pkt += pkt_aligned_len;
    processed_bytes += pkt_aligned_len;
  }
  pipe_packets_tail += processed_bytes;

  return 0;
}

int dma_init(struct NotificationBufPair* notification_buf_pair,
             struct RxEnsoPipeInternal* enso_pipe, unsigned socket_id,
             unsigned nb_queues, uint32_t bdf, int32_t bar) {
  (void)notification_buf_pair;
  (void)enso_pipe;
  (void)socket_id;
  (void)nb_queues;
  (void)bdf;
  (void)bar;
  return 0;
}

static _enso_always_inline uint16_t
__get_new_tails(struct NotificationBufPair* notification_buf_pair) {
  (void)notification_buf_pair;
  return 0;
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

// Return next batch among all open sockets.
uint32_t get_next_batch(struct NotificationBufPair* notification_buf_pair,
                        struct SocketInternal* socket_entries,
                        int* enso_pipe_id, void** buf) {
  (void)socket_entries;
  (void)notification_buf_pair;
  (void)enso_pipe_id;
  (void)buf;
  return 0;
}

void advance_ring_buffer(struct RxEnsoPipeInternal* enso_pipe, size_t len) {
  (void)enso_pipe;
  (void)len;
}

void fully_advance_ring_buffer(struct RxEnsoPipeInternal* enso_pipe) {
  _enso_compiler_memory_barrier();
  (void)enso_pipe;
}

static _enso_always_inline uint32_t
__send_to_queue(struct NotificationBufPair* notification_buf_pair,
                uint64_t phys_addr, uint32_t len) {
  (void)phys_addr;
  (void)notification_buf_pair;
  (void)len;
  return 0;
}

uint32_t get_unreported_completions(
    [[maybe_unused]] struct NotificationBufPair* notification_buf_pair) {
  return 0;
}

void update_tx_head(struct NotificationBufPair* notification_buf_pair) {
  (void)notification_buf_pair;
}

void notification_buf_free(struct NotificationBufPair* notification_buf_pair) {
  (void)notification_buf_pair;
}

void enso_pipe_free(struct RxEnsoPipeInternal* enso_pipe) {
  (void)enso_pipe;
  pcap_dump_close(pdumper_out);
  pcap_close(pd);
}

int dma_finish(struct SocketInternal* socket_entry) {
  (void)socket_entry;
  return 0;
}

uint32_t get_enso_pipe_id_from_socket(struct SocketInternal* socket_entry) {
  (void)socket_entry;
  return 0;
}

void print_fpga_reg(IntelFpgaPcieDev* dev, unsigned nb_regs) {
  (void)dev;
  (void)nb_regs;
}

void print_stats(struct SocketInternal* socket_entry, bool print_global) {
  (void)socket_entry;
  (void)print_global;
}

static _enso_always_inline int32_t
__get_next_enso_pipe_id(struct NotificationBufPair* notification_buf_pair) {
  // Consume up to a batch of notifications at a time. If the number of consumed
  // notifications is the same as the number of pending notifications, we are
  // done processing the last batch and can get the next one. Using batches here
  // performs **significantly** better compared to always fetching the latest
  // notification.
  (void)notification_buf_pair;
  if (pipe_packets_head == pipe_packets_tail) return -1;
  return 0;
}

int32_t get_next_enso_pipe_id(
    struct NotificationBufPair* notification_buf_pair) {
  return __get_next_enso_pipe_id(notification_buf_pair);
}

void advance_pipe(struct RxEnsoPipeInternal* enso_pipe, size_t len) {
  (void)enso_pipe;
  (void)len;
}

void fully_advance_pipe(struct RxEnsoPipeInternal* enso_pipe) {
  (void)enso_pipe;
}

}  // namespace enso
