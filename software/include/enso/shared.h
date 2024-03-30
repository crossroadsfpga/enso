/*
 * Copyright (c) 2023, Carnegie Mellon University
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
 * @brief Shared definitions for the Enso project.
 *
 * @author Kaajal Gupta <kaajalg@andrew.cmu.edu>
 */

#ifndef ENSO_SOFTWARE_INCLUDE_ENSO_SHARED_H_
#define ENSO_SOFTWARE_INCLUDE_ENSO_SHARED_H_

#include <enso/consts.h>
#include <enso/pipe.h>
#include <enso/queue.h>
#include <immintrin.h>

#include <array>
#include <cstdint>
#include <fastscheduler/defs.hpp>
#include <fastscheduler/sched.hpp>
#include <filesystem>
#include <functional>
#include <memory>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace enso {

/**
 * @brief Holds information on transmission notifications.
 */
struct TxNotificationInfo {
  enso::TxNotification *notification;
  uint32_t notif_buf_id;
  uint32_t tail;
};

struct RingBuf {
  uint8_t *buf = nullptr;
  uint32_t tail = 0;
  uint32_t head = 0;
};

#define NCPU 256

// Application RX Pipe IDs mapped to their notification queue IDs
std::array<int, enso::kMaxNbFlows> rx_queue_ids_to_notif_queue_ids_ = {0};

std::array<uint32_t, enso::kMaxNbFlows> notif_buf_ids_to_uthreads_ = {0};

std::array<struct RingBuf, enso::kMaxNbApps> rx_notif_bufs_ = {0};
std::array<struct RingBuf, enso::kMaxNbApps> tx_notif_bufs_ = {0};

std::unordered_map<uint64_t, uint64_t> map_phys_to_virt_;
std::unordered_map<std::string, uint8_t *> mapped_huge_pages_;

int notif_buf_cnt_ = 0;

/* Kthreads' local device */
thread_local Device *kthread_dev_ = {0};

void set_kthread_device(Device *dev) { kthread_dev_ = dev; }

}  // namespace enso

#endif  // ENSO_SOFTWARE_INCLUDE_ENSO_SHARED_H_
