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

#include <arpa/inet.h>
#include <getopt.h>
#include <netinet/ether.h>
#include <netinet/ip.h>
#include <netinet/udp.h>
#include <pcap/pcap.h>
#include <sys/time.h>

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <random>
#include <string>
#include <vector>

constexpr uint32_t kMaxPktSize = 1518;
constexpr char kDstMac[] = "aa:aa:aa:aa:aa:aa";
constexpr char kSrcMac[] = "bb:bb:bb:bb:bb:bb";

static constexpr uint32_t ip(uint8_t a, uint8_t b, uint8_t c, uint8_t d) {
  return (((uint32_t)a) << 24) | (((uint32_t)b) << 16) | (((uint32_t)c) << 8) |
         ((uint32_t)d);
}

enum {
  CMD_OPT_HELP_NUM = 256,
  CMD_OPT_OUTPUT_PCAP_NUM,
  CMD_OPT_REQUEST_RATE_NUM
};

static const char short_options[] = "";

static const struct option long_options[] = {
    {"output-pcap", required_argument, nullptr, CMD_OPT_OUTPUT_PCAP_NUM},
    {"request-rate", required_argument, nullptr, CMD_OPT_REQUEST_RATE_NUM},
};

int main(int argc, char** argv) {
  int opt;
  int long_index;

  const int pkt_size = std::stoi(argv[1]);
  const int nb_src = std::stoi(argv[2]);
  const int nb_dst = std::stoi(argv[3]);
  const int dst_start = std::stoi(argv[4]);

  std::vector<int> request_rates;
  std::string output_pcap;

  while ((opt = getopt_long(argc, argv, short_options, long_options,
                            &long_index)) != EOF) {
    switch (opt) {
      case CMD_OPT_HELP_NUM:
        return 1;
      case CMD_OPT_OUTPUT_PCAP_NUM:
        output_pcap = optarg;
        break;
      case CMD_OPT_REQUEST_RATE_NUM:
        request_rates.push_back(atoi(optarg));
        break;
    }
  }

  // Skip if pcap with same name already exists.
  {
    std::ifstream f(output_pcap);
    if (f.good()) {
      std::cout << "Pcap with the same name already exists. Skipping."
                << std::endl;
      return 0;
    }
  }

  struct ether_addr dst_mac = *ether_aton(kDstMac);
  struct ether_addr src_mac = *ether_aton(kSrcMac);
  pcap_t* pd;
  pcap_dumper_t* pdumper;

  pd = pcap_open_dead(DLT_EN10MB, 65535);
  pdumper = pcap_dump_open(pd, output_pcap.c_str());
  struct timeval ts;
  ts.tv_sec = 0;
  ts.tv_usec = 0;
  uint8_t pkt[kMaxPktSize];
  memset(pkt, 0, kMaxPktSize);

  struct ether_header* l2_hdr = (struct ether_header*)&pkt;
  struct iphdr* l3_hdr = (struct iphdr*)(l2_hdr + 1);
  struct udphdr* l4_hdr = (struct udphdr*)(l3_hdr + 1);

  *((struct ether_addr*)&l2_hdr->ether_dhost) = dst_mac;
  *((struct ether_addr*)&l2_hdr->ether_shost) = src_mac;

  l2_hdr->ether_type = htons(ETHERTYPE_IP);
  l3_hdr->ihl = 5;
  l3_hdr->version = 4;
  l3_hdr->tos = 0;
  l3_hdr->id = 0;
  l3_hdr->frag_off = 0;
  l3_hdr->ttl = 255;
  l3_hdr->protocol = IPPROTO_UDP;

  struct pcap_pkthdr pkt_hdr;
  pkt_hdr.ts = ts;

  uint32_t src_ip = ip(192, 168, 0, 0);
  uint32_t dst_ip = ip(192, 168, 0, dst_start);

  uint32_t mss =
      pkt_size - sizeof(*l2_hdr) - sizeof(*l3_hdr) - sizeof(*l4_hdr) - 4;

  // Seed the random generator.
  std::mt19937 g(dst_start);

  for (uint32_t i = 0; i < request_rates.size(); i++) {
    /* Create a packet transmit schedule based on a Poisson arrival rate. */
    uint32_t rate = request_rates[i];
    std::vector<double> poisson_schedule(rate);
    std::exponential_distribution<double> rd(1.0 / (1000000.0 / rate));
    std::generate(poisson_schedule.begin(), poisson_schedule.end(),
                  std::bind(rd, g));

    int packets_per_dst = rate / nb_dst;

    /* Create an order for packets for each destination to arrive in*/
    std::vector<int> packet_order;
    for (int i = 0; i < nb_dst; ++i) {
      for (int j = 0; j < packets_per_dst; ++j) {
        packet_order.push_back(i);
      }
    }
    std::shuffle(packet_order.begin(), packet_order.end(), g);

    double nb_pkts = 0;

    while (nb_pkts < rate) {
      int i = packet_order[nb_pkts];
      l3_hdr->daddr = htonl(dst_ip + (uint32_t)i);
      uint32_t src_offset = i / (nb_dst / nb_src);
      l3_hdr->saddr = htonl(src_ip + src_offset);

      l3_hdr->tot_len = htons(mss + sizeof(*l3_hdr) + sizeof(*l4_hdr));

      pkt_hdr.len = sizeof(*l2_hdr) + sizeof(*l3_hdr) + sizeof(*l4_hdr) + mss;
      pkt_hdr.caplen = pkt_hdr.len;
      ts.tv_usec = poisson_schedule[nb_pkts] * 100;
      pkt_hdr.ts = ts;

      l4_hdr->dest = htons(80);
      l4_hdr->source = htons(8080);
      l4_hdr->len = htons(sizeof(*l4_hdr) + mss);

      pcap_dump((u_char*)pdumper, &pkt_hdr, pkt);

      ++nb_pkts;
    }
  }

  pcap_close(pd);
  pcap_dump_close(pdumper);

  return 0;
}
