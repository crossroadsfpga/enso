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

/**
 * @file
 * @brief Functions to configure the data plane.
 *
 * @author Hugo Sadok <sadok@cmu.edu>
 */

#include <enso/config.h>
#include <enso/consts.h>
#include <enso/helpers.h>
#include <enso/internals.h>
#include <immintrin.h>

#include <cstdio>

#include "../pcie.h"

namespace enso {

enum ConfigId {
  FLOW_TABLE_CONFIG_ID = 1,
  TIMESTAMP_CONFIG_ID = 2,
  RATE_LIMIT_CONFIG_ID = 3,
  FALLBACK_QUEUES_CONFIG_ID = 4
};

struct __attribute__((__packed__)) FlowTableConfig {
  uint64_t signal;
  uint64_t config_id;
  uint16_t dst_port;
  uint16_t src_port;
  uint32_t dst_ip;
  uint32_t src_ip;
  uint32_t protocol;
  uint32_t enso_pipe_id;
  uint8_t pad[28];
};

struct __attribute__((__packed__)) TimestampConfig {
  uint64_t signal;
  uint64_t config_id;
  uint64_t enable;
  uint64_t offset;
  uint8_t pad[32];
};

struct __attribute__((__packed__)) RateLimitConfig {
  uint64_t signal;
  uint64_t config_id;
  uint16_t denominator;
  uint16_t numerator;
  uint32_t enable;
  uint8_t pad[40];
};

struct __attribute__((__packed__)) FallbackQueueConfig {
  uint64_t signal;
  uint64_t config_id;
  uint32_t nb_fallback_queues;
  uint32_t fallback_queue_mask;
  uint64_t enable_rr;
  uint8_t pad[32];
};

int insert_flow_entry(struct NotificationBufPair* notification_buf_pair,
                      uint16_t dst_port, uint16_t src_port, uint32_t dst_ip,
                      uint32_t src_ip, uint32_t protocol,
                      uint32_t enso_pipe_id) {
  struct FlowTableConfig config;

  config.signal = 2;
  config.config_id = FLOW_TABLE_CONFIG_ID;
  config.dst_port = dst_port;
  config.src_port = src_port;
  config.dst_ip = dst_ip;
  config.src_ip = src_ip;
  config.protocol = protocol;
  config.enso_pipe_id = enso_pipe_id;

  std::cout << "Inserting flow entry: dst_port=" << dst_port
            << ", src_port=" << src_port << ", dst_ip=";
  print_ip(htonl(dst_ip));
  std::cout << ", src_ip=";
  print_ip(htonl(src_ip));
  std::cout << ", protocol=" << protocol << ", enso_pipe_id=" << enso_pipe_id
            << ")" << std::endl;

  return send_config(notification_buf_pair, (struct TxNotification*)&config);
}

int enable_timestamp(struct NotificationBufPair* notification_buf_pair,
                     uint8_t offset) {
  if (offset > 60) {
    return -1;
  }

  TimestampConfig config;

  config.signal = 2;
  config.config_id = TIMESTAMP_CONFIG_ID;
  config.enable = -1;
  config.offset = offset;

  return send_config(notification_buf_pair, (struct TxNotification*)&config);
}

int disable_timestamp(struct NotificationBufPair* notification_buf_pair) {
  TimestampConfig config;

  config.signal = 2;
  config.config_id = TIMESTAMP_CONFIG_ID;
  config.enable = 0;

  return send_config(notification_buf_pair, (struct TxNotification*)&config);
}

int enable_rate_limit(struct NotificationBufPair* notification_buf_pair,
                      uint16_t num, uint16_t den) {
  struct RateLimitConfig config;

  config.signal = 2;
  config.config_id = RATE_LIMIT_CONFIG_ID;
  config.denominator = den;
  config.numerator = num;
  config.enable = -1;

  return send_config(notification_buf_pair, (struct TxNotification*)&config);
}

int disable_rate_limit(struct NotificationBufPair* notification_buf_pair) {
  struct RateLimitConfig config;

  config.signal = 2;
  config.config_id = RATE_LIMIT_CONFIG_ID;
  config.enable = 0;

  return send_config(notification_buf_pair, (struct TxNotification*)&config);
}

static int configure_fallback_queues(
    struct NotificationBufPair* notification_buf_pair,
    uint32_t nb_fallback_queues, bool enable_rr) {
  struct FallbackQueueConfig config;

  config.signal = 2;
  config.config_id = FALLBACK_QUEUES_CONFIG_ID;
  config.nb_fallback_queues = nb_fallback_queues;
  config.enable_rr = enable_rr ? -1 : 0;

  // Round down to the nearest power of 2.
  uint32_t cnt = 0;
  while (nb_fallback_queues) {
    nb_fallback_queues >>= 1;
    ++cnt;
  }
  config.fallback_queue_mask = cnt ? (1 << (cnt - 1)) - 1 : 0;

  return send_config(notification_buf_pair, (struct TxNotification*)&config);
}

static int set_round_robin(struct NotificationBufPair* notification_buf_pair,
                           bool enable_rr) {
  int nb_fallback_queues = get_nb_fallback_queues(notification_buf_pair);
  if (nb_fallback_queues < 0) {
    return nb_fallback_queues;
  }

  if (set_round_robin_status(notification_buf_pair, enable_rr)) {
    return -1;
  }

  return configure_fallback_queues(notification_buf_pair, nb_fallback_queues,
                                   enable_rr);
}

int enable_round_robin(struct NotificationBufPair* notification_buf_pair) {
  return set_round_robin(notification_buf_pair, true);
}

int disable_round_robin(struct NotificationBufPair* notification_buf_pair) {
  return set_round_robin(notification_buf_pair, false);
}

int update_fallback_queues_config(
    struct NotificationBufPair* notification_buf_pair) {
  int enable_rr = get_round_robin_status(notification_buf_pair);

  if (enable_rr < 0) {
    return enable_rr;
  }

  int nb_fallback_queues = get_nb_fallback_queues(notification_buf_pair);
  if (nb_fallback_queues < 0) {
    return nb_fallback_queues;
  }

  return configure_fallback_queues(notification_buf_pair, nb_fallback_queues,
                                   (bool)enable_rr);
}

}  // namespace enso
