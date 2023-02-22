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
 *
 * Constants used throughout the codebase. Some of these constants need to be
 * kept in sync with the hardware.
 *
 * Authors:
 *   Hugo Sadok <sadok@cmu.edu>
 */

#ifndef SOFTWARE_INCLUDE_NORMAN_CONSTS_H_
#define SOFTWARE_INCLUDE_NORMAN_CONSTS_H_

namespace norman {

// These determine the maximum number of notification buffers and enso pipes,
// these macros also exist in hardware and **must be kept in sync**. Update the
// variables with the same name on `hardware/src/constants.sv` and
// `hardware_test/hwtest/my_stats.tcl`.
#define MAX_NB_APPS 1024
#define MAX_NB_FLOWS 8192

// TODO(sadok): Use constexpr instead of macros.

#define MAX_TRANSFER_LEN 131072

#ifndef BATCH_SIZE
// Maximum number of packets to process in call to get_next_batch_from_queue
#define BATCH_SIZE 64
#endif

#ifndef NOTIFICATION_BUF_SIZE
// This should be the max buffer supported by the hardware, we may override this
// value when compiling. It is defined in number of flits (64 bytes).
#define NOTIFICATION_BUF_SIZE 16384
#endif

#ifndef ENSO_PIPE_SIZE
// This should be the max buffer supported by the hardware, we may override this
// value when compiling. It is defined in number of flits (64 bytes).
#define ENSO_PIPE_SIZE 32768
#endif

#define MAX_PENDING_TX_REQUESTS (NOTIFICATION_BUF_SIZE - 1)

#define BUF_PAGE_SIZE (1UL << 21)  // using 2MB huge pages (size in bytes)

// Sizes aligned to the huge page size, but if both buffers fit in a single
// page, we may put them in the same page
#define ALIGNED_DSC_BUF_PAIR_SIZE \
  ((((NOTIFICATION_BUF_SIZE * 64 * 2 - 1) / BUF_PAGE_SIZE + 1) * BUF_PAGE_SIZE))

// Assumes that the FPGA `clk_datamover` runs at 200MHz. If we change the clock,
// we must also change this value.
#define NS_PER_TIMESTAMP_CYCLE 5

// Offset of the RTT when timestamp is enabled (in bytes).
#define PACKET_RTT_OFFSET 18

// The maximum number of flits (64 byte chunks) that the hardware can send per
// second. This is simply the frequency of the `rate_limiter` module -- which is
// currently 200MHz.
#define MAX_HARDWARE_FLIT_RATE (200e6)

#define MEMORY_SPACE_PER_QUEUE (1 << 12)

}  // namespace norman

#endif  // SOFTWARE_INCLUDE_NORMAN_CONSTS_H_
