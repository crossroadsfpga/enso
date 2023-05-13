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
#include <mock_pcie.h>

#include <cstdio>

#include "../pcie.h"

namespace enso {

enum ConfigId {
  FLOW_TABLE_CONFIG_ID = 1,
  TIMESTAMP_CONFIG_ID = 2,
  RATE_LIMIT_CONFIG_ID = 3
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
  uint8_t pad[40];
};

struct __attribute__((__packed__)) RateLimitConfig {
  uint64_t signal;
  uint64_t config_id;
  uint16_t denominator;
  uint16_t numerator;
  uint32_t enable;
  uint8_t pad[40];
};

/**
 * Sends configuration through a notification buffer.
 *
 * NOTE: if mock enso pipe, then add config notification to global hash table
 * of queue configurations.
 *
 * @param notification_buf_pair The notification buffer pair to send the
 *                              configuration through.
 * @param config_notification The configuration notification to send. Must be
 *                            a config notification, i.e., signal >= 2.
 * @return 0 on success, -1 on failure.
 */
#ifdef MOCK

int send_config(struct NotificationBufPair* notification_buf_pair,
                struct TxNotification* config_notification) {
  // reject anything that is not binding a configuration to a pipe
  assert(config_notification->config_id == FLOW_TABLE_CONFIG_ID);

  // Make sure it's a config notification.
  if (config_notification->signal < 2) {
    return -1;
  }

  // Make sure that it's enso pipe ID is within the vector
  if (config_notification->enso_pipe_id < 0 ||
      config_notification->enso_pipe_id >= size(enso_pipes_vector)) {
    return -2;
  }

  // Adding to hash map
  config_tuple tup(config_notification->dst_port, config_notification->src_port,
                   config_notification->dst_ip, config_notification->src_ip,
                   config_notification->protocol);
  config_hashmap[tup] = config_notification->enso_pipe_id;

  return 0;
}

#else
int send_config(struct NotificationBufPair* notification_buf_pair,
                struct TxNotification* config_notification) {
  struct TxNotification* tx_buf = notification_buf_pair->tx_buf;
  uint32_t tx_tail = notification_buf_pair->tx_tail;
  uint32_t free_slots =
      (notification_buf_pair->tx_head - tx_tail - 1) % kNotificationBufSize;

  // Make sure it's a config notification.
  if (config_notification->signal < 2) {
    return -1;
  }

  // Block until we can send.
  while (unlikely(free_slots == 0)) {
    ++notification_buf_pair->tx_full_cnt;
    update_tx_head(notification_buf_pair);
    free_slots =
        (notification_buf_pair->tx_head - tx_tail - 1) % kNotificationBufSize;
  }

  struct TxNotification* tx_notification = tx_buf + tx_tail;
  *tx_notification = *config_notification;

  _mm_clflushopt(tx_notification);

  tx_tail = (tx_tail + 1) % kNotificationBufSize;
  notification_buf_pair->tx_tail = tx_tail;

  _enso_compiler_memory_barrier();
  *(notification_buf_pair->tx_tail_ptr) = tx_tail;

  // Wait for request to be consumed.
  uint32_t nb_unreported_completions =
      notification_buf_pair->nb_unreported_completions;
  while (notification_buf_pair->nb_unreported_completions ==
         nb_unreported_completions) {
    update_tx_head(notification_buf_pair);
  }
  notification_buf_pair->nb_unreported_completions = nb_unreported_completions;

  return 0;
}
#endif

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

int enable_timestamp(struct NotificationBufPair* notification_buf_pair) {
  TimestampConfig config;

  config.signal = 2;
  config.config_id = TIMESTAMP_CONFIG_ID;
  config.enable = -1;

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

}  // namespace enso
