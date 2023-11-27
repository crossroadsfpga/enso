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

#include <enso/pipe.h>

#include <chrono>
#include <csignal>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <memory>
#include <thread>

#include "example_helpers.h"

static volatile bool keep_running = true;
static volatile bool setup_done = false;

void int_handler([[maybe_unused]] int signal) { keep_running = false; }

void run_experiment(uint32_t nb_queues, uint32_t nb_cycles,
                    enso::stats_t* stats, uint32_t dst_ip_1, uint32_t dst_ip_2,
                    uint32_t core_id, int ms_interval) {
  (void)core_id;
  std::this_thread::sleep_for(std::chrono::seconds(1));

  std::cout << "Running on core " << sched_getcpu() << std::endl;

  using enso::Device;
  using enso::RxPipe;
  using enso::TxPipe;
  using namespace std::chrono;

  Device* dev = Device::Create();
  std::vector<RxPipe*> rx_pipes;
  std::vector<TxPipe*> tx_pipes;

  if (!dev) {
    std::cerr << "Problem creating device" << std::endl;
    exit(2);
  }

  for (uint32_t i = 0; i < nb_queues; ++i) {
    RxPipe* rx_pipe = dev->AllocateRxPipe();
    if (!rx_pipe) {
      std::cerr << "Problem creating RX pipe" << std::endl;
      exit(3);
    }

    rx_pipes.push_back(rx_pipe);

    TxPipe* tx_pipe = dev->AllocateTxPipe();
    if (!tx_pipe) {
      std::cerr << "Problem creating TX pipe" << std::endl;
      exit(3);
    }
    tx_pipes.push_back(tx_pipe);
  }

  setup_done = true;
  milliseconds time =
      duration_cast<milliseconds>(system_clock::now().time_since_epoch());
  while (keep_running) {
    milliseconds now =
        duration_cast<milliseconds>(system_clock::now().time_since_epoch());
    bool change = false;
    if (now - time >= ms_interval) {
      change = true;
    }
    for (uint32_t i = 0; i < nb_queues; ++i) {
      auto& rx_pipe = rx_pipes[i];
      // bind pipes to the same socket
      if (change) {
        if (i % 2 == 0)
          rx_pipe->Bind(kDstPort, 0, dst_ip_1, 0, kProtocol);
        else
          rx_pipe->Bind(kDstPort, 0, dst_ip_2, 0, kProtocol);
      }

      auto batch = rx_pipe->RecvPkts();

      if (unlikely(batch.available_bytes() == 0)) {
        continue;
      }
      // std::cout << "packets!" << std::endl;

      for (auto pkt : batch) {
        ++pkt[63];  // Increment payload.

        for (uint32_t i = 0; i < nb_cycles; ++i) {
          asm("nop");
        }

        ++(stats->nb_pkts);
      }
      // std::cout << "finished loop" << std::endl;
      uint32_t batch_length = batch.processed_bytes();
      stats->recv_bytes += batch_length;
      ++(stats->nb_batches);
      // std::cout << "stats done" << std::endl;

      auto& tx_pipe = tx_pipes[i];
      uint8_t* tx_buf = tx_pipe->AllocateBuf(batch_length);
      // std::cout << "allocated buf" << std::endl;

      memcpy(tx_buf, batch.buf(), batch_length);

      rx_pipe->Clear();

      // std::cout << "cleared rx pipe" << std::endl;

      // tx_pipe->SendAndFree(batch_length);

      // std::cout << "sent and freed" << std::endl;
    }
    time = now;
  }
}

int main(int argc, const char* argv[]) {
  if (argc != 5) {
    std::cerr << "Usage: " << argv[0]
              << " NB_CORES NB_QUEUES NB_CYCLES INTERVAL" << std::endl
              << std::endl;
    std::cerr << "NB_CORES: Number of cores to use." << std::endl;
    std::cerr << "NB_QUEUES: Number of queues per core." << std::endl;
    std::cerr << "NB_CYCLES: Number of cycles to busy loop when processing each"
                 " packet."
              << std::endl;
    std::cerr
        << "INTERVAL: Number of milliseconds between configuration change."
        << std::endl;
    return 1;
  }

  uint32_t nb_cores = atoi(argv[1]);
  uint32_t nb_queues = atoi(argv[2]);
  uint32_t nb_cycles = atoi(argv[3]);
  uint32_t ms_interval = atoi(argv[4]);

  signal(SIGINT, int_handler);

  std::vector<std::thread> threads;
  std::vector<enso::stats_t> thread_stats(nb_cores);

  uint32_t dst_ip_1 = kBaseIpAddress;
  uint32_t dst_ip_2 = kBaseIpAddress + 1;

  for (uint32_t core_id = 0; core_id < nb_cores; ++core_id) {
    threads.emplace_back(run_experiment, nb_queues, nb_cycles,
                         &(thread_stats[core_id]), dst_ip_1, dst_ip_2, core_id,
                         ms_interval);
    if (enso::set_core_id(threads.back(), core_id)) {
      std::cerr << "Error setting CPU affinity" << std::endl;
      return 6;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(100));
  }

  while (!setup_done) continue;  // Wait for setup to be done.

  show_stats(thread_stats, &keep_running);

  for (auto& thread : threads) {
    thread.join();
  }

  return 0;
}
