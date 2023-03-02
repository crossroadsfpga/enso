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

#include <norman/helpers.h>
#include <norman/pipe.h>

#include <chrono>
#include <csignal>
#include <cstdint>
#include <iostream>
#include <memory>
#include <thread>

#include "example_helpers.h"

static volatile bool keep_running = true;
static volatile bool setup_done = false;

void int_handler([[maybe_unused]] int signal) { keep_running = 0; }

void run_echo(uint32_t nb_queues, uint32_t core_id,
              [[maybe_unused]] uint32_t nb_cycles, stats_t* stats) {
  std::this_thread::sleep_for(std::chrono::seconds(1));

  std::cout << "Running on core " << sched_getcpu() << std::endl;

  using norman::Device;
  using norman::RxTxPipe;

  std::unique_ptr<Device> dev = Device::Create(nb_queues, core_id);
  std::vector<RxTxPipe*> pipes;

  if (!dev) {
    std::cerr << "Problem creating device" << std::endl;
    exit(2);
  }

  for (uint32_t i = 0; i < nb_queues; ++i) {
    RxTxPipe* pipe = dev->AllocateRxTxPipe();
    if (!pipe) {
      std::cerr << "Problem creating RX/TX pipe" << std::endl;
      exit(3);
    }
    uint32_t dst_ip = kBaseIpAddress + i;
    pipe->Bind(kDstPort, 0, dst_ip, 0, kProtocol);

    pipes.push_back(pipe);
  }

  setup_done = true;

  while (keep_running) {
    for (auto& pipe : pipes) {
      auto batch = pipe->RecvPkts();

      if (unlikely(batch.kAvailableBytes == 0)) {
        continue;
      }

      for (auto pkt : batch) {
        ++pkt[63];  // Increment payload.

        for (uint32_t i = 0; i < nb_cycles; ++i) {
          asm("nop");
        }

        ++(stats->nb_pkts);
      }
      uint32_t batch_length = batch.processed_bytes();
      stats->recv_bytes += batch_length;
      ++(stats->nb_batches);

      pipe->SendAndFree(batch_length);
    }
  }
}

int main(int argc, const char* argv[]) {
  stats_t stats = {};

  if (argc != 4) {
    std::cerr << "Usage: " << argv[0] << " core nb_queues nb_cycles"
              << std::endl;
    return 1;
  }

  uint32_t core_id = atoi(argv[1]);
  uint32_t nb_queues = atoi(argv[2]);
  uint32_t nb_cycles = atoi(argv[3]);

  signal(SIGINT, int_handler);

  std::thread socket_thread =
      std::thread(run_echo, nb_queues, core_id, nb_cycles, &stats);

  if (set_core_id(socket_thread, core_id)) {
    std::cerr << "Error setting CPU affinity" << std::endl;
    return 6;
  }

  while (!setup_done) continue;  // Wait for setup to be done.

  show_stats(&stats, &keep_running);

  socket_thread.join();

  return 0;
}
