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
#include <pcap/pcap.h>

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

void int_handler([[maybe_unused]] int signal) { keep_running = 0; }

void capture_packets(uint32_t nb_queues, uint32_t core_id,
                     const std::string& pcap_file, stats_t* stats) {
  std::this_thread::sleep_for(std::chrono::seconds(1));

  std::cout << "Running on core " << sched_getcpu() << std::endl;

  using norman::Device;
  using norman::RxPipe;
  using norman::TxPipe;

  std::unique_ptr<Device> dev = Device::Create(nb_queues, core_id);
  std::vector<RxPipe*> rx_pipes;

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
  }

  pcap_t* pd;
  pcap_dumper_t* pdumper;

  pd = pcap_open_dead(DLT_EN10MB, 65535);
  pdumper = pcap_dump_open(pd, pcap_file.c_str());
  struct timeval ts;
  ts.tv_sec = 0;
  ts.tv_usec = 0;

  setup_done = true;

  while (keep_running) {
    RxPipe* pipe = dev->NextRxPipeToRecv();

    if (unlikely(pipe == nullptr)) {
      continue;
    }

    auto batch = pipe->RecvPkts();

    for (auto pkt : batch) {
      uint16_t pkt_len = norman::get_pkt_len(pkt);

      // Save packet to pcap
      struct pcap_pkthdr pkt_hdr;
      pkt_hdr.ts = ts;

      pkt_hdr.len = pkt_len;
      pkt_hdr.caplen = pkt_len;
      ++(ts.tv_usec);
      pcap_dump((u_char*)pdumper, &pkt_hdr, pkt);

      ++(stats->nb_pkts);
    }
    uint32_t batch_length = batch.processed_bytes();
    stats->recv_bytes += batch_length;
    ++(stats->nb_batches);

    pipe->Clear();
  }

  pcap_dump_close(pdumper);
  pcap_close(pd);
}

int main(int argc, const char* argv[]) {
  stats_t stats = {};

  if (argc != 4) {
    std::cerr << "Usage: " << argv[0] << " core nb_queues pcap_file"
              << std::endl;
    return 1;
  }

  uint32_t core_id = atoi(argv[1]);
  uint32_t nb_queues = atoi(argv[2]);
  std::string pcap_file = argv[3];

  signal(SIGINT, int_handler);

  std::thread socket_thread =
      std::thread(capture_packets, nb_queues, core_id, pcap_file, &stats);

  if (set_core_id(socket_thread, core_id)) {
    std::cerr << "Error setting CPU affinity" << std::endl;
    return 6;
  }

  while (!setup_done) continue;  // Wait for setup to be done.

  show_stats(&stats, &keep_running);

  socket_thread.join();

  return 0;
}
