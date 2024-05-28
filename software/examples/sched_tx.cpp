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

#define TX_BUFFER_MAX_SIZE 131072
#define INTEL_FPGA_PCIE_BDF "65:00.0"
#define MIN_PACKET_SIZE 64

using enso::Device;
using enso::TxPipe;

/**
 * @brief Structure to store an Enso TxPipe object and attributes related
 * to it.
 */
struct EnsoTxPipe {
  explicit EnsoTxPipe(TxPipe* pipe)
      : tx_pipe(pipe), nb_aligned_bytes(0), nb_raw_bytes(0), nb_pkts(0) {}
  // Enso TxPipe
  TxPipe* tx_pipe;
  // Number of cache aligned bytes in the pipe
  uint32_t nb_aligned_bytes;
  // Number of raw bytes in the pipe
  uint32_t nb_raw_bytes;
  // Number of packets in the pipe
  uint32_t nb_pkts;
};

// structure for libpcap
struct PcapHandler {
  PcapHandler(std::unique_ptr<Device>& dev_, pcap_t* pcap_)
      : dev(dev_), pcap(pcap_) {}
  // Pointer to Enso device
  std::unique_ptr<Device>& dev;
  // Pipes to store the packets from the PCAP file
  std::vector<struct EnsoTxPipe> txPipes;
  // libpcap object associated with the opened PCAP file
  pcap_t* pcap;
};

static volatile bool keep_running = true;

/*
 * Interrupt handler for SIG_INT.
 * Sets the run variable to 0 so that the TX thread exists.
 *
 * */
void int_handler(int signal __attribute__((unused))) { keep_running = false; }

void fill_pipe_with_packets(uint8_t* pipe_buf, uint32_t& a_bytes,
                            uint32_t& r_bytes, uint32_t& pkts) {
  uint32_t init_buf_length = a_bytes;
  uint32_t init_good_bytes = r_bytes;
  uint32_t init_nb_pkts = pkts;
  while ((a_bytes + init_buf_length) <= TX_BUFFER_MAX_SIZE) {
    memcpy(pipe_buf + a_bytes, pipe_buf, init_buf_length);
    a_bytes += init_buf_length;
    r_bytes += init_good_bytes;
    pkts += init_nb_pkts;
  }
}

/*
 * PCAP packet handler for reading PCAP files.
 *
 * */
void pcap_pkt_handler(u_char* user, const struct pcap_pkthdr* pkt_hdr,
                      const u_char* pkt_bytes) {
  (void)pkt_hdr;
  struct PcapHandler* context = (struct PcapHandler*)user;

  const struct ether_header* l2_hdr = (struct ether_header*)pkt_bytes;
  if (l2_hdr->ether_type != htons(ETHERTYPE_IP)) {
    std::cerr << "Non-IPv4 packets are not supported" << std::endl;
    exit(1);
  }

  uint32_t len = enso::get_pkt_len(pkt_bytes);
  uint32_t nb_flits = (len - 1) / MIN_PACKET_SIZE + 1;
  TxPipe* pipe = context->dev->AllocateTxPipe();
  if (!pipe) {
    std::cerr << "Problem creating TX pipe" << std::endl;
    exit(2);
  }
  uint8_t* pipe_buf = pipe->AllocateBuf(TX_BUFFER_MAX_SIZE);
  struct EnsoTxPipe etp(pipe);
  memcpy(pipe_buf, pkt_bytes, len);
  etp.nb_aligned_bytes = nb_flits * MIN_PACKET_SIZE;
  etp.nb_raw_bytes = len;
  etp.nb_pkts = 1;
  fill_pipe_with_packets(pipe_buf, etp.nb_aligned_bytes, etp.nb_raw_bytes,
                         etp.nb_pkts);
  context->txPipes.push_back(etp);
}

/*
 * Continuously sends packets until interrupted by the user.
 *
 * @param pipe: Enso TxPipe object.
 * @param main_buf: Buffer that holds the packets copied from the PCAP file.
 * @param total_bytes_in_main_buf: Total number of bytes in main_buf.
 * @param total_pkts_in_main_buf: Total number of packets in main_buf.
 * @param stats: TxStats pointer that is shared between the sending thread and
 * the main thread.
 *
 * */
void run_tx(enso::tx_stats_t* stats, uint32_t core_id, uint32_t nb_queues,
            std::vector<struct EnsoTxPipe>& pipes) {
  std::this_thread::sleep_for(std::chrono::seconds(1));
  std::cout << "Running on core " << sched_getcpu() << std::endl;
  int startPipeInd = core_id * nb_queues;
  int endPipeInd = startPipeInd + nb_queues;
  while (keep_running) {
    for (int i = startPipeInd; i < endPipeInd; i++) {
      // send the packets
      pipes[i].tx_pipe->Send(pipes[i].nb_aligned_bytes);
      // update the stats
      stats->nb_bytes += pipes[i].nb_raw_bytes;
      stats->nb_pkts += pipes[i].nb_pkts;
    }
  }
}

int main(int argc, const char* argv[]) {
  if (argc != 4) {
    std::cerr << "Usage: " << argv[0] << " NB_CORES NB_QUEUES" << std::endl;
    std::cerr << "NB_CORES: Number of cores to use." << std::endl;
    std::cerr << "NB_QUEUES: Number of Tx flows per core." << std::endl;
    std::cerr << "PCAP_PATH: Path to the PCAP file." << std::endl;
    return 1;
  }

  uint32_t nb_cores = atoi(argv[1]);
  uint32_t nb_flows = atoi(argv[2]);
  std::string pcap_file = argv[3];

  // init signal handler
  signal(SIGINT, int_handler);

  std::unique_ptr<Device> dev = Device::Create(INTEL_FPGA_PCIE_BDF);
  if (!dev) {
    std::cerr << "Problem creating device" << std::endl;
    exit(2);
  }

  char errbuf[PCAP_ERRBUF_SIZE];
  pcap_t* pcap = pcap_open_offline(pcap_file.c_str(), errbuf);
  if (pcap == NULL) {
    std::cerr << "Error loading pcap file (" << errbuf << ")" << std::endl;
    return 2;
  }

  struct PcapHandler context(dev, pcap);
  std::vector<struct EnsoTxPipe>& tx_pipes = context.txPipes;

  if (pcap_loop(context.pcap, 0, pcap_pkt_handler, (u_char*)&context) < 0) {
    std::cerr << "Error while reading pcap (" << pcap_geterr(context.pcap)
              << ")" << std::endl;
    return -2;
  }

  if (tx_pipes.size() != (nb_cores * nb_flows)) {
    std::cerr << "PCAP file does not have the same number of flows"
              << std::endl;
    std::cerr << nb_flows * nb_cores << " expected. " << tx_pipes.size()
              << " found." << std::endl;
    return -2;
  }

  // stats to record the metrics
  std::vector<std::thread> threads;
  std::vector<enso::tx_stats_t> thread_stats(nb_cores);

  for (uint32_t core_id = 0; core_id < nb_cores; ++core_id) {
    threads.emplace_back(run_tx, &(thread_stats[core_id]), core_id, nb_flows,
                         std::ref(tx_pipes));
    if (enso::set_core_id(threads.back(), core_id)) {
      std::cerr << "Error setting CPU affinity" << std::endl;
      return 6;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(100));
  }

  show_tx_stats(thread_stats, &keep_running);

  for (auto& thread : threads) {
    thread.join();
  }

  return 0;
}
