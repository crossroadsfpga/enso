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
#include <enso/ixy_helpers.h>
#include <immintrin.h>
#include <netinet/ether.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <netinet/udp.h>
#include <pthread.h>

#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <iostream>
#include <string>
#include <thread>
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

struct alignas(kCacheLineSize) stats_t {
  uint64_t recv_bytes;
  uint64_t nb_batches;
  uint64_t nb_pkts;
};

/**
 * @brief Returns RTT, in number of cycles, for a given packet.
 *
 * This assumes that the packet has been timestamped by hardware. To enable
 * timestamping call the `Device::EnableTimeStamping` method.
 *
 * To convert from number of cycles to ns. Do `cycles * kNsPerTimestampCycle`.
 *
 * @param pkt Packet to retrieve the RTT from.
 * @param rtt_offset Offset in bytes where the RTT is stored.
 * @return Return RTT measure for the packet in number of cycles. If timestamp
 *         is not enabled on the NIC, the value returned is undefined.
 */
inline uint32_t get_pkt_rtt(
    const uint8_t* pkt, const uint8_t rtt_offset = kDefaultRttOffset) {
  uint32_t rtt = *((uint32_t*)(pkt + rtt_offset));
  return be32toh(rtt);
}

constexpr uint16_t be_to_le_16(const uint16_t le) {
  return ((le & (uint16_t)0x00ff) << 8) | ((le & (uint16_t)0xff00) >> 8);
}

_enso_always_inline uint16_t get_pkt_len(const uint8_t* addr) {
  const struct ether_header* l2_hdr = (struct ether_header*)addr;
  const struct iphdr* l3_hdr = (struct iphdr*)(l2_hdr + 1);
  const uint16_t total_len = be_to_le_16(l3_hdr->tot_len) + sizeof(*l2_hdr);

  return total_len;
}

_enso_always_inline uint8_t* get_next_pkt(uint8_t* pkt) {
  uint16_t pkt_len = get_pkt_len(pkt);
  uint16_t nb_flits = (pkt_len - 1) / 64 + 1;
  return pkt + nb_flits * 64;
}

uint16_t get_bdf_from_pcie_addr(const std::string& pcie_addr);

void print_ip(uint32_t ip);

void print_pkt_ips(uint8_t* pkt);

void print_pkt_header(uint8_t* pkt);

void print_buf(void* buf, const uint32_t nb_cache_lines);

int set_core_id(std::thread& thread, int core_id);

void show_stats(const std::vector<stats_t>& thread_stats,
                volatile bool* keep_running);

// Adapted from DPDK's rte_mov64() and rte_memcpy() functions.
_enso_always_inline void mov64(uint8_t* dst, const uint8_t* src) {
#if defined __AVX512F__
  __m512i zmm0;
  zmm0 = _mm512_loadu_si512((const void*)src);
  _mm512_storeu_si512((void*)dst, zmm0);
#elif defined __AVX2__
  __m256i ymm0, ymm1;
  ymm0 = _mm256_loadu_si256((const __m256i*)(const void*)src);
  ymm1 = _mm256_loadu_si256((const __m256i*)(const void*)(src + 32));
  _mm256_storeu_si256((__m256i*)(void*)dst, ymm0);
  _mm256_storeu_si256((__m256i*)(void*)(dst + 32), ymm1);
#elif defined __SSE2__
  __m128i xmm0, xmm1, xmm2, xmm3;
  xmm0 = _mm_loadu_si128((const __m128i*)(const void*)src);
  xmm1 = _mm_loadu_si128((const __m128i*)(const void*)(src + 16));
  xmm2 = _mm_loadu_si128((const __m128i*)(const void*)(src + 32));
  xmm3 = _mm_loadu_si128((const __m128i*)(const void*)(src + 48));
  _mm_storeu_si128((__m128i*)(void*)dst, xmm0);
  _mm_storeu_si128((__m128i*)(void*)(dst + 16), xmm1);
  _mm_storeu_si128((__m128i*)(void*)(dst + 32), xmm2);
  _mm_storeu_si128((__m128i*)(void*)(dst + 48), xmm3);
#else
  memcpy(dst, src, 64);
#endif
}

/**
 * @brief Copies data from src to dst.
 *
 * @param dst Destination address.
 * @param src Source address.
 * @param n 64-byte aligned number of bytes to copy.
 */
_enso_always_inline void memcpy_64_align(void* dst, const void* src, size_t n) {
  // Check that it is aligned to 64 bytes.
  assert(((uint64_t)dst & 0x3f) == 0);

  for (; n >= 64; n -= 64) {
    mov64((uint8_t*)dst, (const uint8_t*)src);
    dst = (uint8_t*)dst + 64;
    src = (const uint8_t*)src + 64;
  }
}

}  // namespace enso

#endif  // SOFTWARE_INCLUDE_ENSO_HELPERS_H_
