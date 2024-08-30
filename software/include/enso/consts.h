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
 * @brief Constants used throughout the codebase. Some of these constants need
 * to be kept in sync with the hardware.
 *
 * @author Hugo Sadok <sadok@cmu.edu>
 */

#ifndef SOFTWARE_INCLUDE_ENSO_CONSTS_H_
#define SOFTWARE_INCLUDE_ENSO_CONSTS_H_

#include <cstdint>
#include <string>

namespace enso {

// These determine the maximum number of notification buffers and enso pipes,
// these macros also exist in hardware and **must be kept in sync**. Update the
// variables with the same name on `hardware/src/constants.sv`,
// `software/kernel/linux/intel_fpga_pcie_setup.h`, and
// `scripts/hwtest/my_stats.tcl`.
#define MAX_NB_APPS 1024
#define MAX_NB_FLOWS 8192

constexpr uint32_t kMaxNbApps = MAX_NB_APPS;
constexpr uint32_t kMaxNbFlows = MAX_NB_FLOWS;

constexpr uint32_t kMaxTransferLen = 131072;

// Maximum number of tails to process at once.
constexpr uint32_t kBatchSize = 64;

#ifndef NOTIFICATION_BUF_SIZE
// This should be the max buffer supported by the hardware, we may override this
// value when compiling. It is defined in number of flits (64 bytes).
#define NOTIFICATION_BUF_SIZE 16384
#endif
constexpr uint32_t kNotificationBufSize = NOTIFICATION_BUF_SIZE;

#ifndef ENSO_PIPE_SIZE
// This should be the max buffer supported by the hardware, we may override this
// value when compiling. It is defined in number of flits (64 bytes).
#define ENSO_PIPE_SIZE 32768
#endif
constexpr uint32_t kEnsoPipeSize = ENSO_PIPE_SIZE;

constexpr uint32_t kMaxPendingTxRequests = kNotificationBufSize - 1;

// Using 2MB huge pages (size in bytes).
constexpr uint32_t kBufPageSize = 1UL << 21;

// Huge page paths.
static constexpr std::string_view kHugePageDefaultPrefix = "/mnt/huge/enso";
static constexpr std::string_view kHugePageRxPipePathPrefix = "_rx_pipe:";
static constexpr std::string_view kHugePagePathPrefix = "_tx_pipe:";
static constexpr std::string_view kHugePageNotifBufPathPrefix = "_notif_buf:";
static constexpr std::string_view kHugePageQueuePathPrefix = "_queue:";

// We need this to allow the same huge page to be mapped to adjacent memory
// regions.
// TODO(sadok): support other buffer sizes. It may be possible to support
// other buffer sizes by overlaying regular pages on top of the huge pages.
// We might use those only for requests that overlap to avoid adding too
// many entries to the TLB.
static_assert(ENSO_PIPE_SIZE * 64 == kBufPageSize, "Unsupported buffer size");

/**
 * Sizes aligned to the huge page size, but if both buffers fit in a single
 * page, we may put them in the same page.
 */
constexpr uint32_t kAlignedDscBufPairSize =
    ((kNotificationBufSize * 64 * 2 - 1) / kBufPageSize + 1) * kBufPageSize;

/**
 * @brief The clock period of the timestamp module in nanoseconds.
 *
 * This assumes that the FPGA `clk_datamover` runs at 200MHz. If we change this
 * clock, we must also change this value.
 */
constexpr uint32_t kNsPerTimestampCycle = 5;

/**
 * @brief Default timestamp offset of the RTT when timestamp is enabled (in
 *        bytes). Uses bytes 4--7 of IPv4 header.
 */
constexpr uint8_t kDefaultRttOffset = 18;

/**
 * @brief Maximum number of flits (64 byte chunks) that the hardware can send
 *        per second.
 *
 * This is simply the clock frequency of the `rate_limiter` module.
 */
constexpr uint32_t kMaxHardwareFlitRate = 200e6;

constexpr uint32_t kMemorySpacePerQueue = 1 << 12;

constexpr uint32_t kCacheLineSize = 64;  // bytes.

// Software backend definitions.

// IPC queue names for software backend.
static constexpr std::string_view kIpcQueueToAppName = "enso_ipc_queue_to_app";
static constexpr std::string_view kIpcQueueFromAppName =
    "enso_ipc_queue_from_app";

enum class NotifType : uint8_t {
  kWrite = 0,
  kRead = 1,
  kTranslAddr = 2,  // Used to translate physical address to virtual address in
                    // the software backend address space.
  kAllocatePipe = 3,
  kAllocateNotifBuf = 4,
  kGetNbFallbackQueues = 5,
  kSetRrStatus = 6,
  kGetRrStatus = 7,
  kFreeNotifBuf = 8,
  kFreePipe = 9
};

struct MmioNotification {
  NotifType type;
  uint64_t address;
  uint64_t value;
};

struct FallbackNotification {
  NotifType type;
  uint64_t nb_fallback_queues;
  uint64_t result;
};

struct RoundRobinNotification {
  NotifType type;
  uint64_t round_robin;
  uint64_t result;
};

struct NotifBufNotification {
  NotifType type;
  uint64_t notif_buf_id;
  uint64_t result;
};

struct AllocatePipeNotification {
  NotifType type;
  uint64_t fallback;
  uint64_t pipe_id;
};

struct FreePipeNotification {
  NotifType type;
  uint64_t pipe_id;
  uint64_t result;
};

struct PipeNotification {
  NotifType type;
  uint64_t data[2];
};

}  // namespace enso

#endif  // SOFTWARE_INCLUDE_ENSO_CONSTS_H_
