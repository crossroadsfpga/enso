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

#ifndef SOFTWARE_SRC_PCIE_H_
#define SOFTWARE_SRC_PCIE_H_

#include <endian.h>
#include <netinet/ether.h>
#include <netinet/ip.h>
#include <norman/internals.h>

#include "syscall_api/intel_fpga_pcie_api.hpp"

namespace norman {

#define RULE_ID_LINE_LEN 64  // bytes
#define RULE_ID_SIZE 2       // bytes
#define NB_RULES_IN_LINE (RULE_ID_LINE_LEN / RULE_ID_SIZE)

#define MAX_PKT_SIZE 24  // in flits, if changed, must also change hardware

// 4 bytes, 1 dword
#define HEAD_OFFSET 4
#define C2F_TAIL_OFFSET 16

#define PDU_ID_OFFSET 0
#define PDU_PORTS_OFFSET 1
#define PDU_DST_IP_OFFSET 2
#define PDU_SRC_IP_OFFSET 3
#define PDU_PROTOCOL_OFFSET 4
#define PDU_SIZE_OFFSET 5
#define PDU_FLIT_OFFSET 6
#define ACTION_OFFSET 7
#define QUEUE_ID_LO_OFFSET 8
#define QUEUE_ID_HI_OFFSET 9

#define ACTION_NO_MATCH 1
#define ACTION_MATCH 2

struct RxEnsoPipe {
  uint32_t* buf;
  uint64_t buf_phys_addr;
  struct QueueRegs* regs;
  uint32_t* buf_head_ptr;
  uint32_t rx_head;
  uint32_t rx_tail;
  uint64_t phys_buf_offset;  // Use to convert between phys and virt address.
  enso_pipe_id_t id;
};

struct SocketInternal {
  struct NotificationBufPair* notification_buf_pair;
  intel_fpga_pcie_dev* dev;
  struct RxEnsoPipe enso_pipe;
};

int notification_buf_init(struct NotificationBufPair* notification_buf_pair,
                          volatile struct QueueRegs* notification_buf_pair_regs,
                          enso_pipe_id_t nb_queues,
                          enso_pipe_id_t enso_pipe_id_offset);

int enso_pipe_init(struct RxEnsoPipe* enso_pipe,
                   volatile struct QueueRegs* enso_pipe_regs,
                   struct NotificationBufPair* notification_buf_pair,
                   enso_pipe_id_t enso_pipe_id);

int dma_init(intel_fpga_pcie_dev* dev,
             struct NotificationBufPair* notification_buf_pair,
             struct RxEnsoPipe* enso_pipe, unsigned socket_id,
             unsigned nb_queues);

int get_next_batch_from_queue(struct SocketInternal* socket_entry, void** buf,
                              size_t len);

int get_next_batch(struct NotificationBufPair* notification_buf_pair,
                   struct SocketInternal* socket_entries, int* enso_pipe_id,
                   void** buf, size_t len);

/*
 * Frees the next `len` bytes in the packet buffer associated with the
 * `socket_entry` socket. If `len` is greater than the number of allocated bytes
 * in the buffer, the behavior is undefined.
 */
void advance_ring_buffer(struct SocketInternal* socket_entry, size_t len);

/**
 * Sends data through a given queue.
 *
 * This function returns as soon as a transmission requests has been enqueued to
 * the TX notification buffer. That means that it is not safe to modify or
 * deallocate the buffer pointed by `phys_addr` right after it returns. Instead,
 * the caller must use `get_unreported_completions` to figure out when the
 * transmission is complete.
 *
 * This function currently blocks if there is not enough space in the
 * notification buffer.
 *
 * @param notification_buf_pair Notification buffer to send data through.
 * @param phys_addr Physical memory address of the data to be sent.
 * @param len Length, in bytes, of the data.
 *
 * @return 0 if transfer was successful.
 */
int send_to_queue(struct NotificationBufPair* notification_buf_pair,
                  void* phys_addr, size_t len);

/**
 * Returns the number of transmission requests that were completed since the
 * last call to this function.
 *
 * Since transmissions are always completed in order, one can figure out which
 * transmissions were completed by keeping track of all the calls to
 * `send_to_queue`. There can be only up to `MAX_PENDING_TX_REQUESTS` requests
 * completed between two calls to `send_to_queue`. However, if `send` is called
 * multiple times, without calling `get_unreported_completions` the number of
 * completed requests can surpass `MAX_PENDING_TX_REQUESTS`.
 *
 * @param notification_buf_pair Notification buffer to get completions from.
 * @return number of transmission requests that were completed since the last
 *         call to this function.
 */
uint32_t get_unreported_completions(
    struct NotificationBufPair* notification_buf_pair);

/**
 * Updates the tx head and the number of TX completions.
 *
 * @param notification_buf_pair Notification buffer to be updated.
 */
void update_tx_head(struct NotificationBufPair* notification_buf_pair);

void notification_buf_free(struct NotificationBufPair* notification_buf_pair);

void enso_pipe_free(struct RxEnsoPipe* enso_pipe);

int dma_finish(struct SocketInternal* socket_entry);

uint32_t get_enso_pipe_id_from_socket(struct SocketInternal* socket_entry);

void print_fpga_reg(intel_fpga_pcie_dev* dev, unsigned nb_regs);

void print_ip(uint32_t ip);

void print_pkt_ips(uint8_t* pkt);

void print_pkt_header(uint8_t* pkt);

void print_buf(void* buf, const uint32_t nb_cache_lines);

void print_stats(struct SocketInternal* socket_entry, bool print_global);

}  // namespace norman

#endif  // SOFTWARE_SRC_PCIE_H_
