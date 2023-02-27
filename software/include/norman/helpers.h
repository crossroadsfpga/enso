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

#ifndef SOFTWARE_INCLUDE_NORMAN_HELPERS_H_
#define SOFTWARE_INCLUDE_NORMAN_HELPERS_H_

#include <endian.h>
#include <netinet/ether.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <netinet/udp.h>
#include <norman/consts.h>
#include <norman/internals.h>

#include <cstdint>
#include <cstdio>
#include <iostream>
#include <string>

namespace norman {

#ifndef likely
#define likely(x) __builtin_expect((x), 1)
#endif

#ifndef unlikely
#define unlikely(x) __builtin_expect((x), 0)
#endif

#define _norman_compiler_memory_barrier() \
  do {                                    \
    asm volatile("" : : : "memory");      \
  } while (0)

#define _norman_always_inline __attribute__((always_inline)) inline

/**
 * Returns RTT, in number of cycles, for a given packet.
 *
 * This assumes that the packet has been timestamped by hardware. To enable
 * timestamping call the `enable_timestamp` function.
 *
 * To convert from number of cycles to ns. Do `cycles * NS_PER_TIMESTAMP_CYCLE`.
 *
 * @param pkt Packet to retrieve the RTT from.
 * @return Return RTT measure for the packet in nanoseconds. If timestamp is
 *         not enabled the value returned is undefined.
 */
inline uint32_t get_pkt_rtt(uint8_t* pkt) {
  uint32_t rtt = *((uint32_t*)(pkt + PACKET_RTT_OFFSET));
  return be32toh(rtt);
}

constexpr uint16_t be_to_le_16(uint16_t le) {
  return ((le & (uint16_t)0x00ff) << 8) | ((le & (uint16_t)0xff00) >> 8);
}

constexpr uint16_t get_pkt_len(uint8_t* addr) {
  struct ether_header* l2_hdr = (struct ether_header*)addr;
  struct iphdr* l3_hdr = (struct iphdr*)(l2_hdr + 1);
  uint16_t total_len = be_to_le_16(l3_hdr->tot_len) + sizeof(*l2_hdr);

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

}  // namespace norman

#endif  // SOFTWARE_INCLUDE_NORMAN_HELPERS_H_
