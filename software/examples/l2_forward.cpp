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

#include <enso/helpers.h>
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

void run_forward(uint32_t nb_queues, enso::stats_t* stats) {
  std::this_thread::sleep_for(std::chrono::seconds(1));

  std::cout << "Running on core " << sched_getcpu() << std::endl;

  using enso::Device;
  using enso::RxPipe;
  using enso::TxPipe;

  std::unique_ptr<Device> dev = Device::Create();
  std::vector<RxPipe*> rx_pipes;

  if (!dev) {
    std::cerr << "Problem creating device" << std::endl;
    exit(2);
  }

  for (uint32_t i = 0; i < nb_queues; ++i) {
    RxPipe* rx_pipe = dev->AllocateRxPipe(true);
    if (!rx_pipe) {
      std::cerr << "Problem creating RX pipe" << std::endl;
      exit(3);
    }

    rx_pipes.push_back(rx_pipe);
  }

  TxPipe* tx_pipe = dev->AllocateTxPipe();
  if (!tx_pipe) {
    std::cerr << "Problem creating TX pipe" << std::endl;
    exit(3);
  }

  setup_done = true;

  while (keep_running) {
    RxPipe* rx_pipe = dev->NextRxPipeToRecv();

    if (unlikely(rx_pipe == nullptr)) {
      continue;
    }

    auto batch = rx_pipe->PeekPktsFromTail();

    uint8_t* tx_buf = tx_pipe->AllocateBuf(batch.available_bytes());

    for (auto pkt : batch) {
      // Align packet length to 64 bytes.
      uint16_t pkt_len = enso::get_pkt_len(pkt);
      uint16_t pkt_len_64 = ((pkt_len - 1) / 64 + 1) * 64;
      const struct ether_header* l2_hdr = (struct ether_header*)pkt;

      struct ether_addr original_src_mac =
          *((struct ether_addr*)l2_hdr->ether_shost);
      struct ether_addr original_dst_mac =
          *((struct ether_addr*)l2_hdr->ether_dhost);

      // Forward packet to TX.
      enso::memcpy_64_align(tx_buf, pkt, pkt_len_64);
      l2_hdr = (struct ether_header*)tx_buf;
      struct ether_addr* new_src_mac = (struct ether_addr*)l2_hdr->ether_shost;
      struct ether_addr* new_dst_mac = (struct ether_addr*)l2_hdr->ether_dhost;

      *new_src_mac = original_dst_mac;
      *new_dst_mac = original_src_mac;

      tx_buf += pkt_len_64;
      ++(stats->nb_pkts);
    }
    uint32_t batch_length = batch.processed_bytes();
    rx_pipe->ConfirmBytes(batch_length);

    stats->recv_bytes += batch_length;
    ++(stats->nb_batches);

    rx_pipe->Clear();

    tx_pipe->SendAndFree(batch_length);
  }
}

int main(int argc, const char* argv[]) {
  if (argc != 3) {
    std::cerr << "Usage: " << argv[0] << " NB_CORES NB_QUEUES" << std::endl
              << std::endl;
    std::cerr << "NB_CORES: Number of cores to use." << std::endl;
    std::cerr << "NB_QUEUES: Number of queues per core." << std::endl;
    return 1;
  }

  uint32_t nb_cores = atoi(argv[1]);
  uint32_t nb_queues = atoi(argv[2]);

  signal(SIGINT, int_handler);

  std::vector<std::thread> threads;
  std::vector<enso::stats_t> thread_stats(nb_cores);

  for (uint32_t core_id = 0; core_id < nb_cores; ++core_id) {
    threads.emplace_back(run_forward, nb_queues, &(thread_stats[core_id]));
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
