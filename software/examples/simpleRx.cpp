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
#define FPGA_PACKET_OVERHEAD            24
#define MIN_PACKET_SIZE                 64

using enso::Device;
using enso::RxPipe;

// structure to record RX stats
struct RxStats {
    RxStats() : pkts(0), bytes(0), batches(0) {}
    uint64_t pkts;
    uint64_t bytes;
    uint64_t batches;
};

/*
 * Variables used to control the flow of the
 * program
 * */
// used by the RX thread to keep receiving packets
static int run = 1;
// used to the main thread to detect when the RX thread exits to stop collecting stats
static int done = 0;

void rcv_pkts(RxPipe *rxPipe, RxStats *stats) {

    while(run) {
        auto batch = rxPipe->RecvPkts();

        if (batch.available_bytes() == 0) {
            continue;
        }

        for (auto pkt : batch) {
            (void) pkt;
            ++(stats->pkts);
        }
        uint32_t batch_length = batch.processed_bytes();
        stats->bytes += batch_length;
        ++(stats->batches);
        rxPipe->Clear();
        // if(stats->pkts == 2048) {
        //     run = 0;
        // }
    }
    // set this so that the main thread exits
    done = 1;
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

    RxPipe *pipe = dev->AllocateRxPipe();
    if (!pipe) {
        std::cerr << "Problem creating RX pipe" << std::endl;
        exit(2);
    }
    std::cout << "Binding to port" << std::endl;
    uint32_t dst_ip = kBaseIpAddress + 1;
    pipe->Bind(kDstPort, 0, dst_ip, 0, kProtocol);

    // stats to record the metrics
    RxStats *stats = (RxStats *) malloc(sizeof(RxStats));
    if(stats == NULL) {
        std::cerr << "Could not allocate RxStats buffer" << std::endl;
        exit(1);
    }
    stats->bytes = 0;
    stats->pkts = 0;
    stats->batches = 0;

    // start the RX thread
    std::thread rx_thread(rcv_pkts, pipe, stats);
    while(!done) {
        uint64_t last_rx_pkts = stats->pkts;
        uint64_t last_rx_bytes = stats->bytes;

        std::this_thread::sleep_for(
                std::chrono::milliseconds(DEFAULT_STATS_DELAY));

        uint64_t rx_bytes = stats->bytes;
        uint64_t rx_pkts = stats->pkts;

        double interval_s = DEFAULT_STATS_DELAY / 1000.;
        uint64_t rx_pkt_diff = rx_pkts - last_rx_pkts;
        uint64_t rx_goodput_mbps =
            (rx_bytes - last_rx_bytes) * 8. / (ONE_MILLION * interval_s);
        uint64_t rx_pkt_rate = (rx_pkt_diff / interval_s);
        uint64_t rx_pkt_rate_kpps = rx_pkt_rate / ONE_THOUSAND;
        uint64_t rx_tput_mbps = rx_goodput_mbps + FPGA_PACKET_OVERHEAD * 8 * rx_pkt_rate / ONE_MILLION;

        std::cout << std::dec << "RX: Throughput: " << rx_tput_mbps << " Mbps"
                  << "  Rate: " << rx_pkt_rate_kpps << " kpps" << std::endl

                  << "          #bytes: " << rx_bytes << "  #packets: " << rx_pkts
                  << std::endl;
    }

    rx_thread.join();

    // print final stats
    std::cout << "Total stats:" << std::endl;
    std::cout << "RX bytes: " << stats->bytes << std::endl;
    std::cout << "RX pkts: " << stats->pkts << std::endl;
    std::cout << "RX batches: " << stats->batches << std::endl;

    dev.reset();
    // clean up
    free(stats);
    return 0;
}
