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

#include <fcntl.h>
#include <norman/consts.h>
#include <norman/helpers.h>
#include <norman/socket.h>
#include <pthread.h>
#include <sched.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <unistd.h>
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

// Huge page size that we are using (in bytes).
#define HUGEPAGE_SIZE (2UL << 20)

// Size of the buffer that we keep packets in.
#define BUFFER_SIZE MAX_TRANSFER_LEN

// Number of transfers required to send a buffer full of packets.
#define TRANSFERS_PER_BUFFER (((BUFFER_SIZE - 1) / MAX_TRANSFER_LEN) + 1)

// Adapted from ixy.
static void* get_huge_page(size_t size) {
  static int id = 0;
  int fd;
  char huge_pages_path[128];

  snprintf(huge_pages_path, sizeof(huge_pages_path), "/mnt/huge/pktgen:%i", id);
  ++id;

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

  void* virt_addr = (void*)mmap(NULL, size, PROT_READ | PROT_WRITE,
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

static volatile int keep_running = 1;
static volatile int setup_done = 0;

void int_handler(int signal __attribute__((unused))) { keep_running = 0; }

struct buf_tracker {
  uint8_t* tx_buf;
  uint64_t phys_addr;
  uint32_t tx_buf_offset;
  uint32_t transmissions_pending;
  int free_bytes;
};

int main(int argc, const char* argv[]) {
  int result;
  uint64_t recv_bytes = 0;
  uint64_t nb_batches = 0;
  uint64_t nb_pkts = 0;
  uint64_t dropped_pkts = 0;
  uint64_t dropped_bytes = 0;

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

  std::thread socket_thread =
      std::thread([&recv_bytes, port, addr_offset, nb_queues, &nb_batches,
                   &nb_pkts, &nb_cycles, &dropped_pkts, &dropped_bytes] {
        uint32_t tx_pr_head = 0;
        uint32_t tx_pr_tail = 0;
        tx_pending_request_t* tx_pending_requests =
            new tx_pending_request_t[MAX_PENDING_TX_REQUESTS + 1];
        (void)nb_cycles;

        std::this_thread::sleep_for(std::chrono::seconds(1));

        std::cout << "Running socket on CPU " << sched_getcpu() << std::endl;

        // uint8_t* tx_bufs[nb_queues];
        // uint32_t tx_buf_offsets[nb_queues];
        // uint32_t transmissions_pending[nb_queues];
        // uint32_t free_bytes[nb_queues];
        // uint64_t phys_addr[nb_queues];

        struct buf_tracker* buf_trackers = new buf_tracker[nb_queues];
        if (buf_trackers == NULL) {
          std::cerr << "Could not allocate buf_trackers" << std::endl;
          return;
        }

        for (int i = 0; i < nb_queues; ++i) {
          // TODO(sadok) can we make this a valid file descriptor?
          std::cout << "Creating queue " << i << std::endl;
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

          // Allocate TX buffers.
          struct buf_tracker* bt = &buf_trackers[i];
          bt->tx_buf = (uint8_t*)get_huge_page(HUGEPAGE_SIZE);
          if (bt->tx_buf == NULL) {
            std::cerr << "Problem allocating TX buffer" << std::endl;
            exit(4);
          }
          bt->tx_buf_offset = 0;
          bt->transmissions_pending = 0;
          bt->free_bytes = HUGEPAGE_SIZE;
          bt->phys_addr = virt_to_phys(bt->tx_buf);

          std::cout << "Done creating queue " << i << std::endl;
        }

#ifdef ZERO_COPY
        unsigned char* buf;
#else
        unsigned char buf[BUF_LEN];
#endif

        setup_done = 1;

        while (keep_running) {
          // HACK(sadok) this only works because socket_fd is incremental, it
          // would not work with an actual file descriptor
          for (int socket_fd = 0; socket_fd < nb_queues; ++socket_fd) {
#ifdef ZERO_COPY
            int recv_len = norman::recv_zc(socket_fd, (void**)&buf, BUF_LEN, 0);
#else
            int recv_len = norman::recv(socket_fd, buf, BUF_LEN, 0);
#endif
            if (unlikely(recv_len < 0)) {
              std::cerr << "Error receiving" << std::endl;
              exit(4);
            }

            struct buf_tracker* bt = &buf_trackers[socket_fd];

            if (likely(recv_len > 0)) {
#ifdef LATENCY_OPT
              // Prefetch next queue.
              norman::free_enso_pipe((socket_fd + 1) & (nb_queues - 1), 0);
#endif
              int processed_bytes = 0;
              uint8_t* pkt = buf;

              int transmission_len = 0;
              while (processed_bytes < recv_len) {
                uint16_t pkt_len = norman::get_pkt_len(pkt);
                uint16_t nb_flits = (pkt_len - 1) / 64 + 1;
                uint16_t pkt_aligned_len = nb_flits * 64;

                ++pkt[63];  // Increment payload.

                // for (uint32_t i = 0; i < nb_cycles; ++i) {
                //     asm("nop");
                // }

                pkt += pkt_aligned_len;
                processed_bytes += pkt_aligned_len;
                ++nb_pkts;

                // If no more space left, ignore remaining packets.
                if (likely(processed_bytes <= bt->free_bytes)) {
                  transmission_len += pkt_aligned_len;
                } else {
                  ++dropped_pkts;
                  dropped_bytes += pkt_aligned_len;
                }
              }

              ++nb_batches;
              recv_bytes += recv_len;

              constexpr uint32_t kBufFillThresh =
                  NOTIFICATION_BUF_SIZE - TRANSFERS_PER_BUFFER - 1;

              if (likely(bt->transmissions_pending < kBufFillThresh)) {
                memcpy(bt->tx_buf + bt->tx_buf_offset, buf, transmission_len);

                bt->tx_buf_offset = (bt->tx_buf_offset + transmission_len) &
                                    (HUGEPAGE_SIZE - 1);
                bt->free_bytes -= transmission_len;
                ++bt->transmissions_pending;
                // TODO(sadok): This should be transparent to the app.
                // Save transmission request so that we can free the buffer once
                // it's complete.
                tx_pending_requests[tx_pr_tail].socket_fd = socket_fd;
                tx_pending_requests[tx_pr_tail].length = transmission_len;
                tx_pr_tail = (tx_pr_tail + 1) % (MAX_PENDING_TX_REQUESTS + 1);

                norman::send(socket_fd, (void*)bt->phys_addr, transmission_len,
                             0);
              }

              // Free all packets.
              norman::free_enso_pipe(socket_fd, recv_len);
            }
          }

          uint32_t nb_tx_completions = norman::get_completions(0);

          // Free data that was already sent.
          for (uint32_t i = 0; i < nb_tx_completions; ++i) {
            tx_pending_request_t tx_req = tx_pending_requests[tx_pr_head];
            struct buf_tracker* bt = &buf_trackers[tx_req.socket_fd];
            bt->free_bytes += tx_req.length;
            bt->transmissions_pending -= 1;
            tx_pr_head = (tx_pr_head + 1) % (MAX_PENDING_TX_REQUESTS + 1);
          }
        }

        // TODO(sadok): it is also common to use the close() syscall to close a
        // UDP socket.
        for (int socket_fd = 0; socket_fd < nb_queues; ++socket_fd) {
          norman::print_sock_stats(socket_fd);
          norman::shutdown(socket_fd, SHUT_RDWR);
        }

        delete[] tx_pending_requests;
        delete[] buf_trackers;
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

  while (!setup_done) continue;

  std::cout << "Starting..." << std::endl;

  while (keep_running) {
    uint64_t recv_bytes_before = recv_bytes;
    uint64_t nb_batches_before = nb_batches;
    uint64_t nb_pkts_before = nb_pkts;

    std::this_thread::sleep_for(std::chrono::seconds(1));

    uint64_t delta_bytes = recv_bytes - recv_bytes_before;
    uint64_t delta_pkts = nb_pkts - nb_pkts_before;
    uint64_t delta_batches = nb_batches - nb_batches_before;
    std::cout << std::dec << delta_bytes * 8. / 1e6 << " Mbps  " << recv_bytes
              << " B  " << nb_batches << " batches  " << nb_pkts << " pkts  "
              << dropped_pkts << " dropped pkts  " << dropped_bytes
              << " dropped bytes";

    if (delta_batches > 0) {
      std::cout << "  " << delta_bytes / delta_batches << " B/batch";
      std::cout << "  " << delta_pkts / delta_batches << " pkt/batch";
    }
    std::cout << std::endl;
  }

  std::cout << "Waiting for threads" << std::endl;

  socket_thread.join();

  return 0;
}
