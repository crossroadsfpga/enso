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
#include <pcap/pcap.h>
#include <pthread.h>
#include <sched.h>
#include <unistd.h>  // for usleep

#include <chrono>
#include <csignal>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <memory>

#include "example_helpers.h"

static volatile bool keep_running = true;
static volatile bool setup_done = false;

void int_handler([[maybe_unused]] int signal) { keep_running = false; }

struct CaptureArgs {
  uint32_t nb_queues;
  uint32_t core_id;
  std::string pcap_file;
  std::string pcie_addr;
  enso::stats_t* stats;
  uint32_t application_id;
};

void* capture_packets(void* arg) {
  struct CaptureArgs* args = (struct CaptureArgs*)arg;
  uint32_t nb_queues = args->nb_queues;
  uint32_t core_id = args->core_id;
  std::string pcap_file = args->pcap_file;
  std::string pcie_addr = args->pcie_addr;
  enso::stats_t* stats = args->stats;
  uint32_t application_id = args->application_id;

  enso::set_self_core_id(core_id);

  usleep(1000000);

  std::cout << "Running on core " << sched_getcpu() << std::endl;

  using enso::Device;
  using enso::RxPipe;

  std::unique_ptr<Device> dev = Device::Create(application_id, NULL, pcie_addr);
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
      uint16_t pkt_len = enso::get_pkt_len(pkt);

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

  return NULL;
}

int main(int argc, const char* argv[]) {
  if (argc < 4 || argc > 5) {
    std::cerr << "Usage: " << argv[0] << " NB_QUEUES PCAP_FILE [PCIE_ADDR]"
              << std::endl
              << std::endl;
    std::cerr << "NB_QUEUES: Number of queues to use." << std::endl;
    std::cerr << "PCAP_FILE: Path to the pcap file to write to." << std::endl;
    std::cerr << "APPLICATION_ID: Count of number of applications started "
                 "before this application, starting from 0.";
    std::cerr << "PCIE_ADDR: PCIe address of the device to use." << std::endl
              << std::endl;
    return 1;
  }

  constexpr uint32_t kCoreId = 0;
  uint32_t nb_queues = atoi(argv[1]);
  std::string pcap_file = argv[2];

  if (nb_queues == 0) {
    std::cerr << "Invalid number of queues" << std::endl;
    return 2;
  }

  uint32_t application_id = atoi(argv[3]);

  std::string pcie_addr;
  if (argc == 5) {
    pcie_addr = argv[4];
  }

  signal(SIGINT, int_handler);

  std::vector<enso::stats_t> thread_stats(1);

  pthread_t thread;
  struct CaptureArgs args;
  args.nb_queues = nb_queues;
  args.core_id = kCoreId;
  args.pcap_file = pcap_file;
  args.pcie_addr = pcie_addr;
  args.stats = &(thread_stats[0]);
  args.application_id = application_id;
  pthread_create(&thread, NULL, capture_packets, static_cast<void*>(&args));

  while (!setup_done) continue;  // Wait for setup to be done.

  show_stats(thread_stats, &keep_running);

  pthread_join(thread, NULL);

  return 0;
}
