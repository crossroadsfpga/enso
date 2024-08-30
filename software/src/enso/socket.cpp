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
 * @brief Socket-like API.
 * @deprecated Use the API defined in `pipe.h` instead.
 *
 * @author Hugo Sadok <sadok@cmu.edu>
 */

#include "enso/socket.h"

#include <enso/config.h>
#include <enso/helpers.h>

#include <cstring>
#include <iostream>

#include "../pcie.h"

namespace enso {

static struct NotificationBufPair notification_buf_pair[MAX_NB_CORES];

// TODO(sadok) replace with hash table?
static struct SocketInternal open_sockets[MAX_NB_SOCKETS];
static unsigned int nb_open_sockets = 0;
static uint16_t bdf = 0;

// HACK(sadok): We need a better way to specify the BDF.
void set_bdf(uint16_t bdf_) { bdf = bdf_; }

int socket([[maybe_unused]] int domain, [[maybe_unused]] int type,
           [[maybe_unused]] int protocol, bool fallback) noexcept {
  if (unlikely(nb_open_sockets >= MAX_NB_SOCKETS)) {
    std::cerr << "Maximum number of sockets reached" << std::endl;
    return -1;
  }

  struct SocketInternal socket_entry;

  struct NotificationBufPair* nb_pair = &notification_buf_pair[sched_getcpu()];
  socket_entry.notification_buf_pair = nb_pair;

  struct RxEnsoPipeInternal* enso_pipe = &socket_entry.enso_pipe;

  int bar = -1;
  int socket_id = dma_init(nb_pair, enso_pipe, bdf, bar,
                           std::string(kHugePageDefaultPrefix), fallback);
  if (unlikely(socket_id < 0)) {
    std::cerr << "Problem initializing DMA" << std::endl;
    return -1;
  }

  open_sockets[socket_id] = socket_entry;

  // FIXME(sadok): Use __sync_fetch_and_add to update atomically.
  ++nb_open_sockets;

  return socket_id;
}

int bind(int sockfd, const struct sockaddr* addr, socklen_t addrlen) noexcept {
  (void)addrlen;  // Avoid unused warnings.
  struct SocketInternal* socket = &open_sockets[sockfd];
  sockaddr_in* addr_in = (sockaddr_in*)addr;

  uint32_t enso_pipe_id = get_enso_pipe_id_from_socket(socket);

  // TODO(sadok): insert flow entry from kernel.
  insert_flow_entry(socket->notification_buf_pair, ntohs(addr_in->sin_port), 0,
                    ntohl(addr_in->sin_addr.s_addr), 0,
                    0x11,  // TODO(sadok): support protocols other than UDP.
                    enso_pipe_id);

  return 0;
}

/*
 * Return physical address of the buffer associated with the socket.
 */
uint64_t get_socket_phys_addr(int sockfd) {
  return open_sockets[sockfd].enso_pipe.buf_phys_addr;
}

/*
 * Return virtual address of the buffer associated with the socket.
 */
void* get_socket_virt_addr(int sockfd) {
  return (void*)open_sockets[sockfd].enso_pipe.buf;
}

/*
 * Convert a socket buffer virtual address to physical address.
 */
uint64_t convert_buf_addr_to_phys(int sockfd, void* addr) {
  return (uint64_t)addr + open_sockets[sockfd].enso_pipe.phys_buf_offset;
}

ssize_t recv(int sockfd, void* buf, size_t len, int flags) {
  (void)len;
  (void)flags;

  void* ring_buf;
  struct SocketInternal* socket = &open_sockets[sockfd];
  struct RxEnsoPipeInternal* enso_pipe = &socket->enso_pipe;
  struct NotificationBufPair* notification_buf_pair =
      socket->notification_buf_pair;

  get_new_tails(notification_buf_pair);

  ssize_t bytes_received =
      get_next_batch_from_queue(enso_pipe, notification_buf_pair, &ring_buf);

  if (unlikely(bytes_received <= 0)) {
    return bytes_received;
  }

  memcpy(buf, ring_buf, bytes_received);

  advance_pipe(enso_pipe, bytes_received);

  return bytes_received;
}

ssize_t recv_zc(int sockfd, void** buf, size_t len, int flags) {
  (void)len;
  (void)flags;

  struct SocketInternal* socket = &open_sockets[sockfd];
  struct RxEnsoPipeInternal* enso_pipe = &socket->enso_pipe;
  struct NotificationBufPair* notification_buf_pair =
      socket->notification_buf_pair;

  get_new_tails(notification_buf_pair);

  return get_next_batch_from_queue(enso_pipe, notification_buf_pair, buf);
}

ssize_t recv_select(int ref_sockfd, int* sockfd, void** buf, size_t len,
                    int flags) {
  (void)len;
  (void)flags;

  struct NotificationBufPair* notification_buf_pair =
      open_sockets[ref_sockfd].notification_buf_pair;
  return get_next_batch(notification_buf_pair, open_sockets, sockfd, buf);
}

ssize_t send(int sockfd, uint64_t phys_addr, size_t len, int flags) {
  (void)flags;
  return send_to_queue(open_sockets[sockfd].notification_buf_pair, phys_addr,
                       len);
}

uint32_t get_completions(int ref_sockfd) {
  struct NotificationBufPair* notification_buf_pair =
      open_sockets[ref_sockfd].notification_buf_pair;
  return get_unreported_completions(notification_buf_pair);
}

void free_enso_pipe(int sockfd, size_t len) {
  advance_pipe(&(open_sockets[sockfd].enso_pipe), len);
}

int enable_device_timestamp(int ref_sockfd, uint8_t offset) {
  if (nb_open_sockets == 0) {
    return -2;
  }
  return enable_timestamp(open_sockets[ref_sockfd].notification_buf_pair,
                          offset);
}

int disable_device_timestamp(int ref_sockfd) {
  if (nb_open_sockets == 0) {
    return -2;
  }
  return disable_timestamp(open_sockets[ref_sockfd].notification_buf_pair);
}

int enable_device_rate_limit(int ref_sockfd, uint16_t num, uint16_t den) {
  if (nb_open_sockets == 0) {
    return -2;
  }
  return enable_rate_limit(open_sockets[ref_sockfd].notification_buf_pair, num,
                           den);
}

int disable_device_rate_limit(int ref_sockfd) {
  if (nb_open_sockets == 0) {
    return -2;
  }
  return disable_rate_limit(open_sockets[ref_sockfd].notification_buf_pair);
}

int enable_device_round_robin(int ref_sockfd) {
  if (nb_open_sockets == 0) {
    return -2;
  }
  return enable_round_robin(open_sockets[ref_sockfd].notification_buf_pair);
}

int disable_device_round_robin(int ref_sockfd) {
  if (nb_open_sockets == 0) {
    return -2;
  }
  return disable_round_robin(open_sockets[ref_sockfd].notification_buf_pair);
}

int shutdown(int sockfd, int how __attribute__((unused))) noexcept {
  dma_finish(&open_sockets[sockfd]);

  // TODO(sadok): Remove entry from the NIC flow table.

  --nb_open_sockets;

  return 0;
}

void print_sock_stats(int sockfd) {
  struct SocketInternal* socket = &open_sockets[sockfd];
  print_stats(socket, socket->enso_pipe.id == 0);
}

}  // namespace enso
