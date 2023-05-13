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

#include <enso/helpers.h>

#include <cstdio>
#include <iostream>
#include <thread>
#include <vector>

namespace enso {

std::unordered_map<config_tuple, int, hash_config_tuple> config_hashmap;

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

/**
 * @brief Hashes a packet with RSS to determine which pipe it should be
 * directed to.
 *
 * @param pkt_buf packet buffer.
 * @param mod number of pipes
 * @return Index of pipe
 */
int rss_hash_packet(uint8_t* pkt_buf, int mod) {
  struct ether_header* l2_hdr = (struct ether_header*)pkt_buf;
  struct iphdr* l3_hdr = (struct iphdr*)(l2_hdr + 1);
  uint32_t src_ip = l3_hdr->saddr;
  uint32_t dst_ip = l3_hdr->daddr;
  uint8_t protocol = l3_hdr->protocol;
  uint32_t src_port;
  uint32_t dst_port;
  switch (protocol) {
    case IPPROTO_TCP: {
      struct tcphdr* l4_hdr = (struct tcphdr*)(l3_hdr + 1);
      src_port = l4_hdr->source;
      dst_port = l4_hdr->dest;
      break;
    }
    case IPPROTO_UDP: {
      struct udphdr* l4_hdr = (struct udphdr*)(l3_hdr + 1);
      src_port = l4_hdr->source;
      dst_port = l4_hdr->dest;
      break;
    }
    default:
      break;
  }

  // check if this configuration has already been bound
  config_tuple tup(dst_port, src_port, dst_ip, src_ip, protocol);
  if (config_hashmap.find(tup) != config_hashmap.end()) {
    return config_hashmap[tup];
  }

  return (src_ip ^ dst_ip ^ protocol ^ src_port ^ dst_port) % mod;
}

int set_core_id(std::thread& thread, int core_id) {
  cpu_set_t cpuset;
  CPU_ZERO(&cpuset);
  CPU_SET(core_id, &cpuset);
  return pthread_setaffinity_np(thread.native_handle(), sizeof(cpuset),
                                &cpuset);
}

static void print_stats_line(uint64_t recv_bytes, uint64_t nb_batches,
                             uint64_t nb_pkts, uint64_t delta_bytes,
                             uint64_t delta_pkts, uint64_t delta_batches) {
  std::cout << std::dec << (delta_bytes + delta_pkts * 20) * 8. / 1e6
            << " Mbps  " << delta_pkts / 1e6 << " Mpps  " << recv_bytes
            << " B  " << nb_batches << " batches  " << nb_pkts << " pkts";

  if (delta_batches > 0) {
    std::cout << "  " << delta_bytes / delta_batches << " B/batch";
    std::cout << "  " << delta_pkts / delta_batches << " pkt/batch";
  }
  std::cout << std::endl;
}

void show_stats(const std::vector<stats_t>& thread_stats,
                volatile bool* keep_running) {
  while (*keep_running) {
    std::vector<uint64_t> recv_bytes_before;
    std::vector<uint64_t> nb_batches_before;
    std::vector<uint64_t> nb_pkts_before;

    std::vector<uint64_t> recv_bytes_after;
    std::vector<uint64_t> nb_batches_after;
    std::vector<uint64_t> nb_pkts_after;

    recv_bytes_before.reserve(thread_stats.size());
    nb_batches_before.reserve(thread_stats.size());
    nb_pkts_before.reserve(thread_stats.size());

    recv_bytes_after.reserve(thread_stats.size());
    nb_batches_after.reserve(thread_stats.size());
    nb_pkts_after.reserve(thread_stats.size());

    for (auto& stats : thread_stats) {
      recv_bytes_before.push_back(stats.recv_bytes);
      nb_batches_before.push_back(stats.nb_batches);
      nb_pkts_before.push_back(stats.nb_pkts);
    }

    std::this_thread::sleep_for(std::chrono::seconds(1));

    for (auto& stats : thread_stats) {
      recv_bytes_after.push_back(stats.recv_bytes);
      nb_batches_after.push_back(stats.nb_batches);
      nb_pkts_after.push_back(stats.nb_pkts);
    }

    uint64_t total_recv_bytes = 0;
    uint64_t total_nb_batches = 0;
    uint64_t total_nb_pkts = 0;

    uint64_t total_delta_bytes = 0;
    uint64_t total_delta_pkts = 0;
    uint64_t total_delta_batches = 0;

    for (uint16_t i = 0; i < thread_stats.size(); ++i) {
      uint64_t recv_bytes = recv_bytes_after[i];
      uint64_t nb_batches = nb_batches_after[i];
      uint64_t nb_pkts = nb_pkts_after[i];

      total_recv_bytes += recv_bytes;
      total_nb_batches += nb_batches;
      total_nb_pkts += nb_pkts;

      uint64_t delta_bytes = recv_bytes - recv_bytes_before[i];
      uint64_t delta_pkts = nb_pkts - nb_pkts_before[i];
      uint64_t delta_batches = nb_batches - nb_batches_before[i];

      total_delta_bytes += delta_bytes;
      total_delta_pkts += delta_pkts;
      total_delta_batches += delta_batches;

      // Only print per-thread stats if there are multiple threads.
      if (thread_stats.size() > 1) {
        std::cout << "  Thread " << i << ":" << std::endl;
        std::cout << "    ";
        print_stats_line(recv_bytes, nb_batches, nb_pkts, delta_bytes,
                         delta_pkts, delta_batches);
      }
    }
    print_stats_line(total_recv_bytes, total_nb_batches, total_nb_pkts,
                     total_delta_bytes, total_delta_pkts, total_delta_batches);

    if (thread_stats.size() > 1) {
      std::cout << std::endl;
    }
  }
}

}  // namespace enso
