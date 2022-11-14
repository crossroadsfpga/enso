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

#include <immintrin.h>
#include <norman/config.h>
#include <norman/consts.h>
#include <norman/helpers.h>
#include <norman/internals.h>

#include "../pcie.h"

namespace norman {

enum ConfigId {
  FLOW_TABLE_CONFIG_ID = 1,
  TIMESTAMP_CONFIG_ID = 2,
  RATE_LIMIT_CONFIG_ID = 3
};

typedef struct __attribute__((__packed__)) {
  uint64_t signal;
  uint64_t config_id;
  uint16_t dst_port;
  uint16_t src_port;
  uint32_t dst_ip;
  uint32_t src_ip;
  uint32_t protocol;
  uint32_t pkt_queue_id;
  uint8_t pad[28];
} flow_table_config_t;

typedef struct __attribute__((__packed__)) {
  uint64_t signal;
  uint64_t config_id;
  uint64_t enable;
  uint8_t pad[40];
} timestamp_config_t;

typedef struct __attribute__((__packed__)) {
  uint64_t signal;
  uint64_t config_id;
  uint16_t denominator;
  uint16_t numerator;
  uint32_t enable;
  uint8_t pad[40];
} rate_limit_config_t;

int send_config(dsc_queue_t* dsc_queue, pcie_tx_dsc_t* config_dsc) {
  pcie_tx_dsc_t* tx_buf = dsc_queue->tx_buf;
  uint32_t tx_tail = dsc_queue->tx_tail;
  uint32_t free_slots = (dsc_queue->tx_head - tx_tail - 1) % DSC_BUF_SIZE;

  // Make sure it's a config descriptor.
  if (config_dsc->signal < 2) {
    return -1;
  }

  // Block until we can send.
  while (unlikely(free_slots == 0)) {
    ++dsc_queue->tx_full_cnt;
    update_tx_head(dsc_queue);
    free_slots = (dsc_queue->tx_head - tx_tail - 1) % DSC_BUF_SIZE;
  }

  pcie_tx_dsc_t* tx_dsc = tx_buf + tx_tail;
  *tx_dsc = *config_dsc;

  _mm_clflushopt(tx_dsc);

  tx_tail = (tx_tail + 1) % DSC_BUF_SIZE;
  dsc_queue->tx_tail = tx_tail;

  _norman_compiler_memory_barrier();
  *(dsc_queue->tx_tail_ptr) = tx_tail;

  // Wait for request to be consumed.
  uint32_t nb_unreported_completions = dsc_queue->nb_unreported_completions;
  while (dsc_queue->nb_unreported_completions == nb_unreported_completions) {
    update_tx_head(dsc_queue);
  }
  dsc_queue->nb_unreported_completions = nb_unreported_completions;

  return 0;
}

int insert_flow_entry(dsc_queue_t* dsc_queue, uint16_t dst_port,
                      uint16_t src_port, uint32_t dst_ip, uint32_t src_ip,
                      uint32_t protocol, uint32_t pkt_queue_id) {
  flow_table_config_t config;

  config.signal = 2;
  config.config_id = FLOW_TABLE_CONFIG_ID;
  config.dst_port = dst_port;
  config.src_port = src_port;
  config.dst_ip = dst_ip;
  config.src_ip = src_ip;
  config.protocol = protocol;
  config.pkt_queue_id = pkt_queue_id;

  return send_config(dsc_queue, (pcie_tx_dsc_t*)&config);
}

int enable_timestamp(dsc_queue_t* dsc_queue) {
  timestamp_config_t config;

  config.signal = 2;
  config.config_id = TIMESTAMP_CONFIG_ID;
  config.enable = -1;

  return send_config(dsc_queue, (pcie_tx_dsc_t*)&config);
}

int disable_timestamp(dsc_queue_t* dsc_queue) {
  timestamp_config_t config;

  config.signal = 2;
  config.config_id = TIMESTAMP_CONFIG_ID;
  config.enable = 0;

  return send_config(dsc_queue, (pcie_tx_dsc_t*)&config);
}

int enable_rate_limit(dsc_queue_t* dsc_queue, uint16_t num, uint16_t den) {
  rate_limit_config_t config;

  config.signal = 2;
  config.config_id = RATE_LIMIT_CONFIG_ID;
  config.denominator = den;
  config.numerator = num;
  config.enable = -1;

  return send_config(dsc_queue, (pcie_tx_dsc_t*)&config);
}

int disable_rate_limit(dsc_queue_t* dsc_queue) {
  rate_limit_config_t config;

  config.signal = 2;
  config.config_id = RATE_LIMIT_CONFIG_ID;
  config.enable = 0;

  return send_config(dsc_queue, (pcie_tx_dsc_t*)&config);
}

}  // namespace norman
