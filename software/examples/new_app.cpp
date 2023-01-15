/*
 * Copyright (c) 2023, Carnegie Mellon University
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

#include <norman/consts.h>
#include <norman/helpers.h>
#include <norman/pipe.h>
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
#include <memory>
#include <string>
#include <thread>

#include "app.h"

static volatile int keep_running = 1;
static volatile int setup_done = 0;

void int_handler(int signal __attribute__((unused))) { keep_running = 0; }

int main(int argc, const char* argv[]) {
  int result;
  uint64_t recv_bytes = 0;
  uint64_t nb_batches = 0;
  uint64_t nb_pkts = 0;

  if (argc != 5) {
    std::cerr << "Usage: " << argv[0] << " core port nb_queues nb_cycles"
              << std::endl;
    return 1;
  }

  int core_id = atoi(argv[1]);
  int port = atoi(argv[2]);
  int nb_queues = atoi(argv[3]);
  uint32_t nb_cycles = atoi(argv[4]);

  signal(SIGINT, int_handler);

  std::thread socket_thread =
      std::thread([&recv_bytes, port, core_id, nb_queues, &nb_batches, &nb_pkts,
                   &nb_cycles] {
        (void)recv_bytes;
        (void)port;

        std::this_thread::sleep_for(std::chrono::seconds(1));

        std::cout << "Running socket on CPU " << sched_getcpu() << std::endl;

        using norman::Device;
        using norman::RxTxPipe;

        std::unique_ptr<Device> dev = Device::Create(nb_queues, core_id);
        std::vector<RxTxPipe*> pipes;

        if (!dev) {
          std::cerr << "Problem creating device" << std::endl;
          exit(2);
        }

        for (int i = 0; i < nb_queues; ++i) {
          RxTxPipe* pipe = dev->AllocateRxTxPipe();
          if (!pipe) {
            std::cerr << "Problem creating RX pipe" << std::endl;
            exit(3);
          }
          pipes.push_back(pipe);
        }

        setup_done = 1;

        while (keep_running) {
          for (auto& pipe : pipes) {
            auto batch = pipe->RecvPkts(1024);

            if (unlikely(batch.kAvailableBytes == 0)) {
              continue;
            }

            uint32_t batch_length = 0;
            for (auto pkt : batch) {
              uint16_t pkt_len = norman::get_pkt_len(pkt);
              uint16_t nb_flits = (pkt_len - 1) / 64 + 1;
              uint16_t pkt_aligned_len = nb_flits * 64;

              recv_bytes += pkt_aligned_len;
              batch_length += pkt_aligned_len;
              ++nb_pkts;

              ++pkt[63];  // Increment payload.

              for (uint32_t i = 0; i < nb_cycles; ++i) {
                asm("nop");
              }
            }
            ++nb_batches;
            pipe->Send(batch_length);
          }
        }
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
    std::cout << std::dec << delta_bytes * 8. / 1e6 << " Mbps  "
              << delta_pkts / 1e6 << " Mpps  " << recv_bytes << " B  "
              << nb_batches << " batches  " << nb_pkts << " pkts";

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
