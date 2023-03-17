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

#ifndef SOFTWARE_EXAMPLES_EXAMPLE_HELPERS_H_
#define SOFTWARE_EXAMPLES_EXAMPLE_HELPERS_H_

#include <arpa/inet.h>
#include <immintrin.h>
#include <pthread.h>

#include <chrono>
#include <cstdint>
#include <iostream>
#include <thread>

const uint32_t kBaseIpAddress = ntohl(inet_addr("192.168.0.0"));
const uint32_t kDstPort = 80;
const uint32_t kProtocol = 0x11;

struct stats_t {
  uint64_t recv_bytes;
  uint64_t nb_batches;
  uint64_t nb_pkts;
} __attribute__((aligned(64)));

int set_core_id(std::thread& thread, int core_id) {
  cpu_set_t cpuset;
  CPU_ZERO(&cpuset);
  CPU_SET(core_id, &cpuset);
  return pthread_setaffinity_np(thread.native_handle(), sizeof(cpuset),
                                &cpuset);
}

void print_stats_line(uint64_t recv_bytes, uint64_t nb_batches,
                      uint64_t nb_pkts, uint64_t delta_bytes,
                      uint64_t delta_pkts, uint64_t delta_batches) {
  std::cout << std::dec << delta_bytes * 8. / 1e6 << " Mbps  "
            << delta_pkts / 1e6 << " Mpps  " << recv_bytes << " B  "
            << nb_batches << " batches  " << nb_pkts << " pkts";

  if (delta_batches > 0) {
    std::cout << "  " << delta_bytes / delta_batches << " B/batch";
    std::cout << "  " << delta_pkts / delta_batches << " pkt/batch";
  }
  std::cout << std::endl;
}

void show_stats(const std::vector<stats_t>& thread_stats,
                volatile bool* keep_running) {
  while (*keep_running) {
    std::vector<uint64_t> recv_bytes_before;
    std::vector<uint64_t> nb_batches_before;
    std::vector<uint64_t> nb_pkts_before;

    recv_bytes_before.reserve(thread_stats.size());
    nb_batches_before.reserve(thread_stats.size());
    nb_pkts_before.reserve(thread_stats.size());

    for (auto& stats : thread_stats) {
      recv_bytes_before.push_back(stats.recv_bytes);
      nb_batches_before.push_back(stats.nb_batches);
      nb_pkts_before.push_back(stats.nb_pkts);
    }

    std::this_thread::sleep_for(std::chrono::seconds(1));

    uint64_t total_recv_bytes = 0;
    uint64_t total_nb_batches = 0;
    uint64_t total_nb_pkts = 0;

    uint64_t total_delta_bytes = 0;
    uint64_t total_delta_pkts = 0;
    uint64_t total_delta_batches = 0;

    for (uint16_t i = 0; i < thread_stats.size(); ++i) {
      const stats_t& stats = thread_stats[i];

      uint64_t recv_bytes = stats.recv_bytes;
      uint64_t nb_batches = stats.nb_batches;
      uint64_t nb_pkts = stats.nb_pkts;

      total_recv_bytes += recv_bytes;
      total_nb_batches += nb_batches;
      total_nb_pkts += nb_pkts;

      uint64_t delta_bytes = recv_bytes - recv_bytes_before[i];
      uint64_t delta_pkts = nb_pkts - nb_pkts_before[i];
      uint64_t delta_batches = nb_batches - nb_batches_before[i];

      total_delta_bytes += delta_bytes;
      total_delta_pkts += delta_pkts;
      total_delta_batches += delta_batches;

      // Only print per-thread stats if there are multiple threads.
      if (thread_stats.size() > 1) {
        std::cout << "  Thread " << i << ":" << std::endl;
        std::cout << "    ";
        print_stats_line(recv_bytes, nb_batches, nb_pkts, delta_bytes,
                         delta_pkts, delta_batches);
      }
    }
    print_stats_line(total_recv_bytes, total_nb_batches, total_nb_pkts,
                     total_delta_bytes, total_delta_pkts, total_delta_batches);

    if (thread_stats.size() > 1) {
      std::cout << std::endl;
    }
  }
}

#endif  // SOFTWARE_EXAMPLES_EXAMPLE_HELPERS_H_
