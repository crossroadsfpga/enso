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
 * @brief Definitions that are internal to Enso. They should not be exposed to
 * applications.
 *
 * @author Hugo Sadok <sadok@cmu.edu>
 */

// TODO(sadok): Do not expose this header.
#ifndef SOFTWARE_INCLUDE_ENSO_INTERNALS_H_
#define SOFTWARE_INCLUDE_ENSO_INTERNALS_H_

#include <stdint.h>

// Avoid exposing `intel_fpga_pcie_api.hpp` externally.
class IntelFpgaPcieDev;

namespace enso {

#if MAX_NB_FLOWS < 65536
using enso_pipe_id_t = uint16_t;
#else
using enso_pipe_id_t = uint32_t;
#endif

struct QueueRegs {
  uint32_t rx_tail;
  uint32_t rx_head;
  uint32_t rx_mem_low;
  uint32_t rx_mem_high;
  uint32_t tx_tail;
  uint32_t tx_head;
  uint32_t tx_mem_low;
  uint32_t tx_mem_high;
  uint32_t padding[8];
};

struct __attribute__((__packed__)) RxNotification {
  uint64_t signal;
  uint64_t queue_id;
  uint64_t tail;
  uint64_t pad[5];
};

struct __attribute__((__packed__)) TxNotification {
  uint64_t signal;  // whether or not notification has been consumed by hardware
  uint64_t phys_addr;
  uint64_t length;  // In bytes (up to 1MB).
  uint64_t pad[5];
};

struct NotificationBufPair {
  // First cache line:
  struct RxNotification* rx_buf;
  enso_pipe_id_t* next_rx_pipe_ids;  // Next pipe ids to consume from rx_buf.
  struct TxNotification* tx_buf;
  uint32_t* rx_head_ptr;
  uint32_t* tx_tail_ptr;
  uint32_t rx_head;
  uint32_t tx_head;
  uint32_t tx_tail;
  uint16_t last_rx_ids_head;
  uint16_t last_rx_ids_tail;
  uint32_t nb_unreported_completions;
  uint32_t id;

  // Second cache line:
  struct QueueRegs* regs;
  uint64_t tx_full_cnt;
  uint32_t ref_cnt;

  uint8_t* wrap_tracker;
  uint32_t* pending_rx_pipe_tails;

  // FIXME(sadok): This is used to decrement the enso pipe id and use it as an
  // index to the pending_rx_pipe_tails array. This only works because pipes for
  // the same app are contiguous. To fix this, we need to make the NIC aware of
  // the pipe ids used by the app.
  uint32_t enso_pipe_id_offset;

  IntelFpgaPcieDev* fpga_dev;
  void* uio_mmap_bar2_addr;  // UIO mmap address for BAR 2.
};

struct RxEnsoPipeInternal {
  uint32_t* buf;
  uint64_t buf_phys_addr;
  struct QueueRegs* regs;
  uint32_t* buf_head_ptr;
  uint32_t rx_head;
  uint32_t rx_tail;
  uint64_t phys_buf_offset;  // Use to convert between phys and virt address.
  enso_pipe_id_t id;
};

}  // namespace enso

#endif  // SOFTWARE_INCLUDE_ENSO_INTERNALS_H_
