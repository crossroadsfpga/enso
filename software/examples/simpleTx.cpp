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

#define TX_BUFFER_MAX_SIZE              131072
#define INTEL_FPGA_PCIE_BDF             "65:00.0"
#define DEFAULT_STATS_DELAY             1000
#define ONE_MILLION                     1e6
#define ONE_THOUSAND                    1e3
#define FPGA_PACKET_OVERHEAD            24
#define MIN_PACKET_SIZE                 64
#define PCAP_FILE_PATH                  "/home/kshitij/dev/enso/scripts/sample_pcaps/2_64_1_2.pcap"

using enso::Device;
using enso::TxPipe;

// structure for libpcap
struct PcapHandler {
    pcap_t* pcap;
    uint8_t *buf;
    uint32_t bytes_copied;
    uint32_t good_bytes;
    uint32_t nb_pkts;
};

// structure to record TX stats
struct TxStats {
    TxStats() : pkts(0), bytes(0) {}
    uint64_t pkts;
    uint64_t bytes;
};

/*
 * Variables used to control the flow of the
 * program
 * */
// used by the TX thread to keep sending packets
static int run = 1;
// used by the main thread to detect when the TX thread exits to stop collecting stats
static int done = 0;

/*
 * Interrupt handler for SIG_INT.
 * Sets the run variable to 0 so that the TX thread exists.
 *
 * */
void int_handler(int signal __attribute__((unused))) {
    run = 0;
}

/*
 * PCAP packet handler for reading PCAP files.
 *
 * */
void pcap_pkt_handler(u_char* user, const struct pcap_pkthdr* pkt_hdr,
                      const u_char* pkt_bytes) {
    (void) pkt_hdr;
    struct PcapHandler* context = (struct PcapHandler*)user;

    const struct ether_header* l2_hdr = (struct ether_header*)pkt_bytes;
    if (l2_hdr->ether_type != htons(ETHERTYPE_IP)) {
        std::cerr << "Non-IPv4 packets are not supported" << std::endl;
        exit(1);
    }

    uint32_t len = enso::get_pkt_len(pkt_bytes);
    uint32_t nb_flits = (len - 1) / MIN_PACKET_SIZE + 1;
    memcpy(context->buf + context->bytes_copied, pkt_bytes, len);
    context->bytes_copied += nb_flits * MIN_PACKET_SIZE;
    context->good_bytes += len;
    context->nb_pkts++;
}

/*
 * Reads the PCAP file and creates a packet buffer.
 *
 * @param buf: Holds the buffer that needs to be created.
 * @param total_bytes: Total number of bytes copied in buf.
 * @param total_plts: Total number of packets copied in buf.
 *
 * */
void init_buffer_with_packets(uint8_t *buf, uint64_t &total_bytes,
                              uint64_t &total_good_bytes, uint64_t &total_pkts) {
    char errbuf[PCAP_ERRBUF_SIZE];
    pcap_t* pcap = pcap_open_offline(PCAP_FILE_PATH, errbuf);
    if (pcap == NULL) {
        std::cerr << "Error loading pcap file (" << errbuf << ")" << std::endl;
        return;
    }

    struct PcapHandler context;
    context.buf = buf;
    context.pcap = pcap;
    context.bytes_copied = 0;
    context.good_bytes = 0;
    context.nb_pkts = 0;

    if (pcap_loop(pcap, 0, pcap_pkt_handler, (u_char*)&context) < 0) {
        std::cerr << "Error while reading pcap (" << pcap_geterr(pcap) << ")"
                  << std::endl;
        return;
    }

    uint32_t init_buf_length = context.bytes_copied;
    uint32_t init_good_bytes = context.good_bytes;
    uint32_t init_nb_pkts = context.nb_pkts;
    while ((context.bytes_copied + init_buf_length) <= TX_BUFFER_MAX_SIZE) {
        memcpy(buf + context.bytes_copied, buf, init_buf_length);
        context.bytes_copied += init_buf_length;
        context.good_bytes += init_good_bytes;
        context.nb_pkts += init_nb_pkts;
    }
    total_bytes = context.bytes_copied;
    total_good_bytes = context.good_bytes;
    total_pkts = context.nb_pkts;
}

/*
 * Continuously sends packets until interrupted by the user.
 *
 * @param pipe: Enso TxPipe object.
 * @param main_buf: Buffer that holds the packets copied from the PCAP file.
 * @param total_bytes_in_main_buf: Total number of bytes in main_buf.
 * @param total_pkts_in_main_buf: Total number of packets in main_buf.
 * @param stats: TxStats pointer that is shared between the sending thread and the main thread.
 *
 * */
void send_tx(TxPipe *pipe, uint8_t *main_buf, uint64_t total_bytes_in_main_buf,
             uint64_t total_good_bytes_in_main_buf, uint64_t total_pkts_in_main_buf,
             TxStats *stats) {
    (void) total_good_bytes_in_main_buf;
    while(run) {
        uint8_t* pipe_buf = pipe->AllocateBuf(TX_BUFFER_MAX_SIZE);
        if(pipe_buf == NULL) {
            std::cout << "Buffer allocation for TX pipe failed" << std::endl;
            return;
        }
        // copy the packets from the main buffer in the pipe
        memcpy(pipe_buf, main_buf, total_bytes_in_main_buf);
        // send the packets
        pipe->SendAndFree(total_bytes_in_main_buf);
        // update the stats
        stats->bytes += total_good_bytes_in_main_buf;
        stats->pkts += total_pkts_in_main_buf;
    }
    // set this so that the main thread exits
    done = 1;
}

int main() {
    // init signal handler
    signal(SIGINT, int_handler);

    // create the device and initialize the TxPipe
    std::unique_ptr<Device> dev = Device::Create(INTEL_FPGA_PCIE_BDF);
    if (!dev) {
        std::cerr << "Problem creating device" << std::endl;
        exit(2);
    }

    TxPipe *pipe = dev->AllocateTxPipe();
    if (!pipe) {
        std::cerr << "Problem creating TX pipe" << std::endl;
        exit(2);
    }

    // main buffer
    uint8_t *main_packet_buffer = (uint8_t *) malloc(TX_BUFFER_MAX_SIZE);
    if(main_packet_buffer == NULL) {
        std::cerr << "Could not allocate packet buffer" << std::endl;
        exit(1);
    }
    uint64_t total_bytes = 0;
    uint64_t total_good_bytes = 0;
    uint64_t total_pkts = 0;
    init_buffer_with_packets(main_packet_buffer, total_bytes, total_good_bytes,
                             total_pkts);

    // stats to record the metrics
    TxStats *stats = (TxStats *) malloc(sizeof(TxStats));
    if(stats == NULL) {
        std::cerr << "Could not allocate TxStats buffer" << std::endl;
        free(main_packet_buffer);
        exit(1);
    }
    stats->bytes = 0;
    stats->pkts = 0;

    // start the TX thread
    std::thread tx_thread(send_tx, pipe, main_packet_buffer, total_bytes,
                          total_good_bytes, total_pkts, stats);
    // loop until the TX thread exits
    while(!done) {
        uint64_t last_tx_pkts = stats->pkts;
        uint64_t last_tx_bytes = stats->bytes;

        std::this_thread::sleep_for(
                std::chrono::milliseconds(DEFAULT_STATS_DELAY));

        double interval_s = DEFAULT_STATS_DELAY / 1000.;
        uint64_t tx_bytes = stats->bytes;
        uint64_t tx_pkts = stats->pkts;
        uint64_t tx_pkt_diff = tx_pkts - last_tx_pkts;
        uint64_t tx_tput_mbps =
            (tx_bytes - last_tx_bytes + tx_pkt_diff * FPGA_PACKET_OVERHEAD)
            * 8. / (ONE_MILLION * interval_s);
        uint64_t tx_pkt_rate = (tx_pkt_diff / interval_s);
        uint64_t tx_pkt_rate_kpps = tx_pkt_rate / ONE_THOUSAND;

        std::cout << "TX: Throughput: " << tx_tput_mbps << " Mbps"
                  << "\tRate: " << tx_pkt_rate_kpps << " kpps" << std::endl;

    }

    tx_thread.join();

    // print final stats
    std::cout << "Total stats:" << std::endl;
    std::cout << "TX bytes: " << stats->bytes << std::endl;
    std::cout << "TX pkts: " << stats->pkts << std::endl;

    // clean up
    free(main_packet_buffer);
    free(stats);
    return 0;
}
