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
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef SOFTWARE_INCLUDE_NORMAN_HELPERS_H_
#define SOFTWARE_INCLUDE_NORMAN_HELPERS_H_

#include <endian.h>
#include <netinet/ether.h>
#include <netinet/ip.h>
#include <norman/consts.h>
#include <norman/internals.h>

#include <cstdint>

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

/**
 * enable_timestamp() - Enable hardware timestamping.
 * @dsc_queue: Descriptor queue to send configuration through.
 *
 * All outgoing packets will receive a timestamp and all incoming packets will
 * have an RTT (in number of cycles). Use `get_pkt_rtt` to retrieve the value.
 *
 * Return: Return 0 if configuration was successful.
 */
int enable_timestamp(dsc_queue_t* dsc_queue);

/**
 * disable_timestamp() - Disable hardware timestamping.
 * @dsc_queue: Descriptor queue to send configuration through.
 *
 * Return: Return 0 if configuration was successful.
 */
int disable_timestamp(dsc_queue_t* dsc_queue);

/**
 * enable_rate_limit() - Enable hardware rate limit.
 * @dsc_queue: Descriptor queue to send configuration through.
 * @num: Rate numerator.
 * @den: Rate denominator.
 *
 * Once rate limiting is enabled, packets from all queues are sent at a rate of
 * (num/den * MAX_HARDWARE_FLIT_RATE) flits per second (a flit is 64 bytes).
 * Note that this is slightly different from how we typically define throughput
 * and you may need to take the packet sizes into account to set this properly.
 *
 * For example, suppose that you are sending 64-byte packets. Each packet
 * occupies exactly one flit. For this packet size, line rate at 100 Gbps is
 * 148.8Mpps. So if MAX_HARDWARE_FLIT_RATE is 200MHz, line rate actually
 * corresponds to a 744/1000 rate. Therefore, if you want to send at 50Gbps (50%
 * of line rate), you can use a 372/1000 (or 93/250) rate.
 *
 * The other thing to notice is that, while it might be tempting to use a large
 * denominator in order to increase the rate precision. This has the side effect
 * of increasing burstiness. The way the rate limit is implemented, we send a
 * burst of `num` consecutive flits every `den` cycles. Which means that if
 * `num` is too large, it might overflow the receiver buffer. For instance, in
 * the example above, 93/250 would be a better rate than 372/1000. And 3/8 would
 * be even better with a slight loss in precision.
 *
 * You can find the maximum packet rate for any packet size by using the
 * expression: line_rate/((pkt_size + 20)*8). So for 100Gbps and 128-byte
 * packets we have: 100e9/((128+20)*8) packets per second. Given that each
 * packet is two flits, for MAX_HARDWARE_FLIT_RATE=200e6, the maximum rate is
 * 100e9/((128+20)*8)*2/200e6, which is approximately 125/148.
 *
 * Return: Return 0 if configuration was successful.
 */
int enable_rate_limit(dsc_queue_t* dsc_queue, uint16_t num, uint16_t den);

/**
 * disable_rate_limit() - Disable hardware rate limit.
 * @dsc_queue: Descriptor queue to send configuration through.
 *
 * Return: Return 0 if configuration was successful.
 */
int disable_rate_limit(dsc_queue_t* dsc_queue);

/**
 * get_pkt_rtt() - Return RTT, in number of cycles, for a given packet.
 * @pkt: Packet to retrieve the RTT from.
 *
 * This assumes that the packet has been timestamped by hardware. To enable
 * timestamping call the `enable_timestamp` function.
 *
 * To convert from number of cycles to ns. Do `cycles * NS_PER_TIMESTAMP_CYCLE`.
 *
 * Return: Return RTT measure for the packet in nanoseconds. If timestamp is
 *         not enabled the value returned is undefined.
 */
inline uint32_t get_pkt_rtt(uint8_t* pkt) {
  uint32_t rtt = *((uint32_t*)(pkt + PACKET_RTT_OFFSET));
  return be32toh(rtt);
}

inline uint16_t be_to_le_16(uint16_t le) {
  return ((le & (uint16_t)0x00ff) << 8) | ((le & (uint16_t)0xff00) >> 8);
}

static inline uint16_t get_pkt_len(uint8_t* addr) {
  struct ether_header* l2_hdr = (struct ether_header*)addr;
  struct iphdr* l3_hdr = (struct iphdr*)(l2_hdr + 1);
  uint16_t total_len = be_to_le_16(l3_hdr->tot_len) + sizeof(*l2_hdr);

  return total_len;
}

static inline uint8_t* get_next_pkt(uint8_t* pkt) {
  uint16_t pkt_len = get_pkt_len(pkt);
  uint16_t nb_flits = (pkt_len - 1) / 64 + 1;
  return pkt + nb_flits * 64;
}

}  // namespace norman

#endif  // SOFTWARE_INCLUDE_NORMAN_HELPERS_H_
