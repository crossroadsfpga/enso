/*
 * Copyright (c) 2022, Carnegie Mellon University
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
 */

/**
 * @file
 * @brief Miscellaneous helper functions.
 *
 * @author Hugo Sadok <sadok@cmu.edu>
 */

#ifndef SOFTWARE_INCLUDE_ENSO_HELPERS_H_
#define SOFTWARE_INCLUDE_ENSO_HELPERS_H_

#include <endian.h>
#include <enso/consts.h>
#include <enso/internals.h>
#include <netinet/ether.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <netinet/udp.h>
#include <pthread.h>

#include <cstdint>
#include <cstdio>
#include <iostream>
#include <string>
#include <thread>
#include <tuple>
#include <unordered_map>
#include <vector>

namespace enso {

#ifndef likely
#define likely(x) __builtin_expect((x), 1)
#endif

#ifndef unlikely
#define unlikely(x) __builtin_expect((x), 0)
#endif

#define _enso_compiler_memory_barrier() \
  do {                                  \
    asm volatile("" : : : "memory");    \
  } while (0)

#define _enso_always_inline __attribute__((always_inline)) inline

struct stats_t {
  uint64_t recv_bytes;
  uint64_t nb_batches;
  uint64_t nb_pkts;
} __attribute__((aligned(64)));

#ifdef MOCK
// RSS 5-tuple containing dst port, src port, dst ip, src ip, protocol
typedef std::tuple<uint16_t, uint16_t, uint32_t, uint32_t, uint32_t>
    ConfigTuple;

// A hash function used to hash the config tuple
struct HashConfigTuple {
  template <class T1, class T2, class T3, class T4, class T5>

  size_t operator()(const std::tuple<T1, T2, T3, T4, T5>& x) const {
    return std::get<0>(x) ^ std::get<1>(x) ^ std::get<2>(x) ^ std::get<3>(x) ^
           std::get<4>(x);
  }
};

// Hash map containing bindings of configurations to enso pipe IDs
extern std::unordered_map<ConfigTuple, int, HashConfigTuple> config_hashmap;

#endif

/**
 * @brief Returns RTT, in number of cycles, for a given packet.
 *
 * This assumes that the packet has been timestamped by hardware. To enable
 * timestamping call the `Device::EnableTimeStamping` method.
 *
 * To convert from number of cycles to ns. Do `cycles * kNsPerTimestampCycle`.
 *
 * @param pkt Packet to retrieve the RTT from.
 * @return Return RTT measure for the packet in number of cycles. If timestamp
 *         is not enabled on the NIC, the value returned is undefined.
 */
inline uint32_t get_pkt_rtt(const uint8_t* pkt) {
  uint32_t rtt = *((uint32_t*)(pkt + kPacketRttOffset));
  return be32toh(rtt);
}

constexpr uint16_t be_to_le_16(const uint16_t le) {
  return ((le & (uint16_t)0x00ff) << 8) | ((le & (uint16_t)0xff00) >> 8);
}

constexpr uint16_t get_pkt_len(const uint8_t* addr) {
  const struct ether_header* l2_hdr = (struct ether_header*)addr;
  const struct iphdr* l3_hdr = (struct iphdr*)(l2_hdr + 1);
  const uint16_t total_len = be_to_le_16(l3_hdr->tot_len) + sizeof(*l2_hdr);

  return total_len;
}

constexpr uint8_t* get_next_pkt(uint8_t* pkt) {
  uint16_t pkt_len = get_pkt_len(pkt);
  uint16_t nb_flits = (pkt_len - 1) / 64 + 1;
  return pkt + nb_flits * 64;
}

uint16_t get_bdf_from_pcie_addr(const std::string& pcie_addr);

void print_ip(uint32_t ip);

void print_pkt_ips(uint8_t* pkt);

void print_pkt_header(uint8_t* pkt);

void print_buf(void* buf, const uint32_t nb_cache_lines);

int rss_hash_packet(uint8_t* pkt_buf, int mod);

int set_core_id(std::thread& thread, int core_id);

void show_stats(const std::vector<stats_t>& thread_stats,
                volatile bool* keep_running);

}  // namespace enso

#endif  // SOFTWARE_INCLUDE_ENSO_HELPERS_H_
