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
#include <netinet/ether.h>
#include <pcap/pcap.h>

#include <cstdlib>
#include <iostream>
#include <string>

struct PcapHandlerContext {
  uint64_t nb_pkts = 0;
  uint64_t nb_bytes = 0;
};

void pcap_pkt_handler(u_char* user,
                      [[maybe_unused]] const struct pcap_pkthdr* pkt_hdr,
                      const u_char* pkt_bytes) {
  struct PcapHandlerContext* context = (struct PcapHandlerContext*)user;
  const struct ether_header* l2_hdr = (struct ether_header*)pkt_bytes;
  if (l2_hdr->ether_type != htons(ETHERTYPE_IP)) {
    std::cerr << "Non-IPv4 packets are not supported" << std::endl;
    exit(4);
  }
  context->nb_bytes += enso::get_pkt_len(pkt_bytes);
  context->nb_pkts++;
}

int main(int argc, char const* argv[]) {
  if (argc != 2) {
    std::cerr << "Usage: " << argv[0] << " PCAP_FILE" << std::endl;
    std::exit(1);
  }

  std::string pcap_file = argv[1];

  char errbuf[PCAP_ERRBUF_SIZE];

  pcap_t* pcap = pcap_open_offline(pcap_file.c_str(), errbuf);
  if (pcap == nullptr) {
    std::cerr << "Error loading pcap file (" << errbuf << ")" << std::endl;
    std::exit(2);
  }

  PcapHandlerContext context;
  if (pcap_loop(pcap, 0, pcap_pkt_handler, (u_char*)&context) < 0) {
    std::cerr << "Error while reading pcap (" << pcap_geterr(pcap) << ")"
              << std::endl;
    std::exit(3);
  }

  pcap_close(pcap);

  double mean_pkt_size = (double)context.nb_bytes / (double)context.nb_pkts;
  std::cout << mean_pkt_size << std::endl;
  return 0;
}
