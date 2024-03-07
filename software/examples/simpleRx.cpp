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
#include <pcap/pcap.h>
#include <enso/pipe.h>

#include <chrono>
#include <csignal>
#include <cstdint>
#include <iostream>
#include <memory>
#include <thread>

#include "example_helpers.h"

#define INTEL_FPGA_PCIE_BDF             "65:00.0"
#define DEFAULT_STATS_DELAY             1000
#define ONE_MILLION                     1e6
#define ONE_THOUSAND                    1e3
#define FPGA_PACKET_OVERHEAD            20
#define MIN_PACKET_SIZE                 64

using enso::Device;
using enso::RxPipe;

/*
 * Variables used to control the flow of the
 * program
 * */
// used by the RX thread to keep receiving packets
static int run = 1;
// used to the main thread to detect when the RX thread exits to stop collecting stats
static bool keep_running = true;

void rcv_pkts(std::vector<RxPipe*> rxPipes, enso::stats_t* stats) {
    while(run) {
        for(int i = 0; i < 2; i++) {
          auto& rxPipe = rxPipes[i];
          auto batch = rxPipe->RecvPkts();

          if (batch.available_bytes() == 0) {
              continue;
          }

          for (auto pkt : batch) {
              (void) pkt;
              ++(stats->nb_pkts);
          }
          uint32_t batch_length = batch.processed_bytes();
          stats->recv_bytes += batch_length;
          ++(stats->nb_batches);
          rxPipe->Clear();
        }
    }
    // set this so that the main thread exits
    keep_running = false;
}

/*
 * Interrupt handler for SIG_INT.
 * Sets the run variable to 0 so that the RX thread exists.
 *
 * */
void int_handler(int signal __attribute__((unused))) {
    run = 0;
}

int main() {
    // init signal handler
    signal(SIGINT, int_handler);

    // create the device and initialize the RxPipe
    std::unique_ptr<Device> dev = Device::Create(INTEL_FPGA_PCIE_BDF);
    if (!dev) {
        std::cerr << "Problem creating device" << std::endl;
        exit(2);
    }
    std::vector<RxPipe*> rxPipes;
    for (uint32_t i = 0; i < 2; ++i) {
      RxPipe* rxPipe = dev->AllocateRxPipe();
      if (!rxPipe) {
        std::cerr << "Problem creating RX pipe" << std::endl;
        exit(3);
      }

      uint32_t dst_ip = kBaseIpAddress + i;
      rxPipe->Bind(kDstPort, 0, dst_ip, 0, kProtocol);

      rxPipes.push_back(rxPipe);
    }

    std::vector<enso::stats_t> thread_stats(1);

    // start the RX thread
    std::thread rx_thread(rcv_pkts, rxPipes, &thread_stats[0]);
    enso::set_core_id(rx_thread, 0);

    // start the stats collection in the main thread
    show_stats(thread_stats, &keep_running);

    rx_thread.join();

    dev.reset();
    return 0;
}
