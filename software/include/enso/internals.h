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

#include <string>

namespace enso {

#if MAX_NB_FLOWS < 65536
using enso_pipe_id_t = uint16_t;
#else
using enso_pipe_id_t = uint32_t;
#endif

struct __attribute__((__packed__)) TxNotification {
  uint64_t signal;
  uint64_t phys_addr;
  uint64_t length;  // In bytes (up to 1MB).
  uint64_t pad[5];
};

struct NotificationBufPair {
  uint32_t id;
  void* fpga_dev;
  std::string huge_page_prefix;
};

struct RxEnsoPipeInternal {
  uint32_t* buf;
  uint32_t rx_head;
  uint32_t rx_tail;
  uint32_t krx_tail;
  uint32_t last_size;
  enso_pipe_id_t id;
  std::string huge_page_prefix;
};

}  // namespace enso

#endif  // SOFTWARE_INCLUDE_ENSO_INTERNALS_H_
