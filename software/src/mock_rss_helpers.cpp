/**
 * @file mock_rss_helpers.cpp
 * @author Kaajal Gupta (kaajalg)
 * @brief Helpers for RSS hashing in the PCIE mock.
 * @version 0.1
 * @date 2023-04-16
 *
 * Structures here from https://www.tcpdump.org/pcap.html.
 *
 * @copyright Copyright (c) 2023
 *
 */

#include <arpa/inet.h>
#include <enso/consts.h>
#include <enso/helpers.h>
#include <enso/ixy_helpers.h>
#include <immintrin.h>
#include <pcap/pcap.h>
#include <sched.h>
#include <string.h>
#include <time.h>

#include <algorithm>
#include <cassert>
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <ctime>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>

#include "pcie.h"
#include "syscall_api/intel_fpga_pcie_api.hpp"

// Ethernet headers are always exactly 14 bytes
#define SIZE_ETHERNET 14

/* IP header */
struct sniff_ip {
  u_char ip_vhl;                 /* version << 4 | header length >> 2 */
  u_char ip_tos;                 /* type of service */
  u_short ip_len;                /* total length */
  u_short ip_id;                 /* identification */
  u_short ip_off;                /* fragment offset field */
#define IP_RF 0x8000             /* reserved fragment flag */
#define IP_DF 0x4000             /* don't fragment flag */
#define IP_MF 0x2000             /* more fragments flag */
#define IP_OFFMASK 0x1fff        /* mask for fragmenting bits */
  u_char ip_ttl;                 /* time to live */
  u_char ip_p;                   /* protocol */
  u_short ip_sum;                /* checksum */
  struct in_addr ip_src, ip_dst; /* source and dest address */
};

#define IP_HL(ip) (((ip)->ip_vhl) & 0x0f)
#define IP_V(ip) (((ip)->ip_vhl) >> 4)

/* TCP header */
typedef u_int tcp_seq;

struct sniff_tcp {
  u_short th_sport; /* source port */
  u_short th_dport; /* destination port */
  tcp_seq th_seq;   /* sequence number */
  tcp_seq th_ack;   /* acknowledgement number */
  u_char th_offx2;  /* data offset, rsvd */
#define TH_OFF(th) (((th)->th_offx2 & 0xf0) > 4)
  u_char th_flags;
#define TH_FIN 0x01
#define TH_SYN 0x02
#define TH_RST 0x04
#define TH_PUSH 0x08
#define TH_ACK 0x10
#define TH_URG 0x20
#define TH_ECE 0x40
#define TH_CWR 0x80
#define TH_FLAGS (TH_FIN | TH_SYN | TH_RST | TH_ACK | TH_URG | TH_ECE | TH_CWR)
  u_short th_win; /* window */
  u_short th_sum; /* checksum */
  u_short th_urp; /* urgent pointer */
};

const struct sniff_ip* ip;   /* The IP header */
const struct sniff_tcp* tcp; /* The TCP header */

/**
 * @brief Hashes a packet with the RSS 5-tuple: the source IP, source port,
 *        destination IP, destination port, and the layer 4 protocol.
 *
 * @param pkt the packet to hash.
 * @param mod value for hash value to be lesser than or equal
 *
 * @return the hash value
 */
int rss_hash_packet(packet_t* pkt, int mod) {
  ip = (struct sniff_ip*)(pkt->pkt_bytes + SIZE_ETHERNET);
  tcp = (struct sniff_tcp*)(pkt->pkt_bytes + SIZE_ETHERNET + size_ip);

  return (ip->ip_src.s_addr ^ ip->ip_dst.s_addr ^ tcp->th_sport ^
          tcp->th_dport) %
         mod;
}