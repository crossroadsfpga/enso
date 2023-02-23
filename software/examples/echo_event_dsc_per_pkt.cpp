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

#include <norman/socket.h>
#include <pthread.h>
#include <sched.h>
#include <x86intrin.h>

#include <cerrno>
#include <chrono>
#include <csignal>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>
#include <thread>

#include "app.h"

#define ZERO_COPY
#define SEND_BACK

static volatile int keep_running = 1;

void int_handler(int signal __attribute__((unused))) { keep_running = 0; }

int main(int argc, const char* argv[]) {
  int result;
  uint64_t recv_bytes = 0;
  uint64_t nb_batches = 0;

  if (argc != 5) {
    std::cerr << "Usage: " << argv[0] << " core port nb_queues nb_cycles"
              << std::endl;
    return 1;
  }

  int core_id = atoi(argv[1]);
  int port = atoi(argv[2]);
  int nb_queues = atoi(argv[3]);
  uint32_t nb_cycles = atoi(argv[4]);

  uint32_t addr_offset = core_id * nb_queues;

  signal(SIGINT, int_handler);

  std::thread socket_thread = std::thread([&recv_bytes, port, addr_offset,
                                           nb_queues, &nb_batches, &nb_cycles] {
    uint32_t tx_pr_head = 0;
    uint32_t tx_pr_tail = 0;
    tx_pending_request_t* tx_pending_requests =
        new tx_pending_request_t[MAX_PENDING_TX_REQUESTS + 1];

    std::this_thread::sleep_for(std::chrono::seconds(1));

    std::cout << "Running socket on CPU " << sched_getcpu() << std::endl;

    for (int i = 0; i < nb_queues; ++i) {
      // TODO(sadok) can we make this a valid file descriptor?
      std::cout << "creating queue " << i << std::endl;
      int socket_fd = norman::socket(AF_INET, SOCK_DGRAM, nb_queues);

      if (socket_fd == -1) {
        std::cerr << "Problem creating socket (" << errno
                  << "): " << strerror(errno) << std::endl;
        exit(2);
      }

      struct sockaddr_in addr;
      memset(&addr, 0, sizeof(addr));

      uint32_t ip_address = ntohl(inet_addr("192.168.0.0"));
      ip_address += addr_offset + i;

      addr.sin_family = AF_INET;
      addr.sin_addr.s_addr = htonl(ip_address);
      addr.sin_port = htons(port);

      if (norman::bind(socket_fd, (struct sockaddr*)&addr, sizeof(addr))) {
        std::cerr << "Problem binding socket (" << errno
                  << "): " << strerror(errno) << std::endl;
        exit(3);
      }
    }

    unsigned char* buf;

    while (keep_running) {
      int socket_fd;
      int recv_len =
          norman::recv_select(0, &socket_fd, (void**)&buf, BUF_LEN, 0);

      if (unlikely(recv_len < 0)) {
        std::cerr << "Error receiving" << std::endl;
        exit(4);
      }

      if (likely(recv_len != 0)) {
        // Modify every cache line.
        for (uint32_t i = 0; i < ((uint32_t)recv_len) / 256; i += 4) {
          ++buf[(i + 0) * 64 + 63];
          ++buf[(i + 1) * 64 + 63];
          ++buf[(i + 2) * 64 + 63];
          ++buf[(i + 3) * 64 + 63];

          // Flush cache lines to avoid contention with PCIe read.
          _mm_clflushopt(&buf[(i + 0) * 64]);
          _mm_clflushopt(&buf[(i + 1) * 64]);
          _mm_clflushopt(&buf[(i + 2) * 64]);
          _mm_clflushopt(&buf[(i + 3) * 64]);
        }
        for (uint32_t i = 0; i < (((uint32_t)recv_len) % 256) / 64; ++i) {
          ++buf[i * 64 + 63];
          _mm_clflushopt(&buf[i * 64]);
        }
        for (uint32_t i = 0; i < nb_cycles; ++i) {
          asm("nop");
        }
        ++nb_batches;
        recv_bytes += recv_len;

#ifdef SEND_BACK
        uint16_t pkt_len = 64;  // HACK(sadok): Hardcoded packet size!
        uint64_t phys_addr = norman::convert_buf_addr_to_phys(socket_fd, buf);
        for (int i = 0; i < recv_len / pkt_len; ++i) {
          norman::send(socket_fd, phys_addr, pkt_len, 0);
          phys_addr = (phys_addr + pkt_len);
          // Save transmission request so that we can free the buffer once
          // it's complete.
          tx_pending_requests[tx_pr_tail].socket_fd = socket_fd;
          tx_pending_requests[tx_pr_tail].length = pkt_len;
          tx_pr_tail = (tx_pr_tail + 1) % (MAX_PENDING_TX_REQUESTS + 1);
        }
#else
        norman::free_enso_pipe(socket_fd, recv_len);
#endif
      }

#ifdef SEND_BACK
      int nb_tx_completions = norman::get_completions(0);

      // Free data that was already sent.
      for (int i = 0; i < nb_tx_completions; ++i) {
        tx_pending_request_t tx_req = tx_pending_requests[tx_pr_head];
        norman::free_enso_pipe(tx_req.socket_fd, tx_req.length);
        tx_pr_head = (tx_pr_head + 1) % (MAX_PENDING_TX_REQUESTS + 1);
      }
#endif
    }

    // TODO(sadok): it is also common to use the close() syscall to close a
    // UDP socket.
    for (int socket_fd = 0; socket_fd < nb_queues; ++socket_fd) {
      norman::print_sock_stats(socket_fd);
      norman::shutdown(socket_fd, SHUT_RDWR);
    }

    delete[] tx_pending_requests;
  });

  cpu_set_t cpuset;
  CPU_ZERO(&cpuset);
  CPU_SET(core_id, &cpuset);
  result = pthread_setaffinity_np(socket_thread.native_handle(), sizeof(cpuset),
                                  &cpuset);
  if (result < 0) {
    std::cerr << "Error setting CPU affinity" << std::endl;
    return 6;
  }

  while (keep_running) {
    uint64_t recv_bytes_before = recv_bytes;
    std::this_thread::sleep_for(std::chrono::seconds(1));
    std::cout << std::dec << "Goodput: "
              << ((double)recv_bytes - recv_bytes_before) * 8. / 1e6
              << " Mbps  #bytes: " << recv_bytes << "  #batches: " << nb_batches
              << std::endl;
  }

  socket_thread.join();

  return 0;
}
