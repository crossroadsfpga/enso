/*
 * Copyright (c) 2024, Carnegie Mellon University
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
#include <pcap/pcap.h>

#include <chrono>
#include <csignal>
#include <cstdint>
#include <iostream>
#include <memory>
#include <thread>

#include "example_helpers.h"

#define INTEL_FPGA_PCIE_BDF "65:00.0"
#define DEFAULT_STATS_DELAY 1000
#define ONE_MILLION 1e6
#define ONE_THOUSAND 1e3
#define FPGA_PACKET_OVERHEAD 20
#define MIN_PACKET_SIZE 64
#define DEFAULT_NB_QUEUES 4

using enso::Device;
using enso::RxPipe;

static volatile bool keep_running = true;

void rcv_pkts(enso::stats_t* stats, std::vector<uint64_t>& pkts_per_flow) {
  // create the device and initialize the RxPipe
  std::unique_ptr<Device> dev = Device::Create(INTEL_FPGA_PCIE_BDF);
  if (!dev) {
    std::cerr << "Problem creating device" << std::endl;
    exit(2);
  }

  // Enable round robin to ensure Rx does not drop packets
  // TODO(kshitij): Remove this once support is added in HW
  // for one Tx pipe per flow
  dev->EnableRoundRobin();

  std::vector<RxPipe*> rxPipes;
  for (uint32_t i = 0; i < DEFAULT_NB_QUEUES; ++i) {
    RxPipe* rxPipe = dev->AllocateRxPipe(true);
    if (!rxPipe) {
      std::cerr << "Problem creating RX pipe" << std::endl;
      exit(3);
    }
    rxPipes.push_back(rxPipe);
  }

  while (keep_running) {
    uint64_t nb_pkts = 0;

    RxPipe* rx_pipe = dev->NextRxPipeToRecv();
    if (unlikely(rx_pipe == nullptr)) {
      continue;
    }

    auto batch = rx_pipe->PeekPktsFromTail();
    for (auto pkt : batch) {
      (void)pkt;
      uint16_t pkt_dst = enso::get_pkt_dst_lsb(pkt);
      pkts_per_flow[pkt_dst]++;
      nb_pkts++;
    }
    uint32_t batch_length = batch.processed_bytes();
    rx_pipe->ConfirmBytes(batch_length);

    stats->recv_bytes += batch_length;
    stats->nb_batches++;
    stats->nb_pkts += nb_pkts;

    rx_pipe->Clear();
  }
}

/*
 * Interrupt handler for SIG_INT.
 * Sets the run variable to 0 so that the RX thread exists.
 *
 * */
void int_handler(int signal __attribute__((unused))) { keep_running = false; }

int main(int argc, const char* argv[]) {
  if (argc != 2) {
    std::cerr << "Usage: " << argv[0] << " NB_EXPECTED_FLOWS" << std::endl;
    std::cerr << "NB_EXPECTED_FLOWS: Number of expected flows." << std::endl;
    return 1;
  }
  // init signal handler
  signal(SIGINT, int_handler);

  std::vector<enso::stats_t> thread_stats(1);
  std::vector<uint64_t> pkts_per_flow(4096);
  uint32_t num_expected_flows = atoi(argv[1]);

  // start the RX thread
  std::thread rx_thread(rcv_pkts, &thread_stats[0], std::ref(pkts_per_flow));
  enso::set_core_id(rx_thread, 0);

  // start the stats collection in the main thread
  enso::show_rx_flow_stats(pkts_per_flow, &thread_stats[0], num_expected_flows,
                           &keep_running);

  rx_thread.join();

  uint64_t total_pkts = 0;
  for (uint32_t i = 0; i < num_expected_flows; i++) {
    std::cout << "Flow " << i << ": " << pkts_per_flow[i] << std::endl;
    total_pkts += pkts_per_flow[i];
  }
  std::cout << "Total packets received: " << total_pkts << std::endl;
  return 0;
}
