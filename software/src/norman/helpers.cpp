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

/**
 * @file
 * @brief Miscellaneous helper functions.
 *
 * @author Hugo Sadok <sadok@cmu.edu>
 */

#include <norman/helpers.h>

namespace norman {

uint16_t get_bdf_from_pcie_addr(const std::string& pcie_addr) {
  uint32_t domain, bus, dev, func;
  uint16_t bdf = 0;
  // Check if the address has format 00:00.0 (without domain).
  if (sscanf(pcie_addr.c_str(), "%x:%x.%x", &bus, &dev, &func) != 3) {
    // Check if the address has format 0000:00:00.0 (with domain).
    if (sscanf(pcie_addr.c_str(), "%x:%x:%x.%x", &domain, &bus, &dev, &func) !=
        4) {
      // Could not parse PCIe address.
      return 0;
    }
  }
  bdf = (bus << 8) | (dev << 3) | (func & 0x7);
  return bdf;
}

void print_buf(void* buf, const uint32_t nb_cache_lines) {
  for (uint32_t i = 0; i < nb_cache_lines * 64; i++) {
    printf("%02x ", ((uint8_t*)buf)[i]);
    if ((i + 1) % 8 == 0) {
      printf(" ");
    }
    if ((i + 1) % 16 == 0) {
      printf("\n");
    }
    if ((i + 1) % 64 == 0) {
      printf("\n");
    }
  }
}

void print_ip(uint32_t ip) {
  std::cout << ((ip >> 0) & 0xff) << "." << ((ip >> 8) & 0xff) << "."
            << ((ip >> 16) & 0xff) << "." << ((ip >> 24) & 0xff);
}

void print_pkt_ips(uint8_t* pkt) {
  struct ether_header* l2_hdr = (struct ether_header*)pkt;
  struct iphdr* l3_hdr = (struct iphdr*)(l2_hdr + 1);

  std::cout << "src: ";
  print_ip(l3_hdr->saddr);

  std::cout << "  dst: ";
  print_ip(l3_hdr->daddr);

  std::cout << std::endl;
}

void print_pkt_header(uint8_t* pkt) {
  struct ether_header* l2_hdr = (struct ether_header*)pkt;
  std::cout << "Eth - dst MAC: " << ether_ntoa((ether_addr*)l2_hdr->ether_dhost)
            << "  src MAC: " << ether_ntoa((ether_addr*)l2_hdr->ether_shost)
            << std::endl;

  struct iphdr* l3_hdr = (struct iphdr*)(l2_hdr + 1);

  uint8_t protocol = l3_hdr->protocol;
  std::cout << "IP  - protocol: " << (uint32_t)protocol
            << "  checksum: " << ntohs(l3_hdr->check);

  std::cout << "  src IP: ";
  print_ip(l3_hdr->saddr);

  std::cout << "  dst IP: ";
  print_ip(l3_hdr->daddr);
  std::cout << std::endl;

  switch (protocol) {
    case IPPROTO_TCP: {
      struct tcphdr* l4_hdr = (struct tcphdr*)(l3_hdr + 1);
      std::cout << "TCP - src port: " << ntohs(l4_hdr->source)
                << "  dst port: " << ntohs(l4_hdr->dest)
                << "  seq: " << ntohl(l4_hdr->seq) << std::endl;
      break;
    }
    case IPPROTO_UDP: {
      struct udphdr* l4_hdr = (struct udphdr*)(l3_hdr + 1);
      std::cout << "UDP - src port: " << ntohs(l4_hdr->source)
                << "  dst port: " << ntohs(l4_hdr->dest) << std::endl;
      break;
    }
    default:
      break;
  }
}

}  // namespace norman
