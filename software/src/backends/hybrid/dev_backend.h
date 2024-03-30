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
 * @brief Device backend wrapper for software data plane running in a different
 *        process.
 *
 * @author Kaajal Gupta <kaajalg@andrew.cmu.edu>
 */

#ifndef ENSO_SOFTWARE_SRC_BACKENDS_HYBRID_DEV_BACKEND_H_
#define ENSO_SOFTWARE_SRC_BACKENDS_HYBRID_DEV_BACKEND_H_

#include <assert.h>
#include <sched.h>
#include <sys/syscall.h>
#include <unistd.h>

#include <iostream>
#include <memory>
#include <optional>
#include <string>

#include "enso/consts.h"
#include "enso/helpers.h"
#include "enso/queue.h"
#include "enso/shared.h"
#include "intel_fpga_pcie_api.hpp"

namespace enso {

#define NCPU 256

using BackendWrapper = std::function<void()>;
BackendWrapper preempt_enable_;
BackendWrapper preempt_disable_;

void initialize_backend_dev(BackendWrapper preempt_enable,
                            BackendWrapper preempt_disable) {
  preempt_enable_ = preempt_enable;
  preempt_disable_ = preempt_disable;
}

class DevBackend {
 public:
  static DevBackend* Create(unsigned int bdf, int bar) noexcept {
    std::cerr << "Using hybrid backend" << std::endl;

    DevBackend* dev = new (std::nothrow) DevBackend(bdf, bar);

    if (dev == nullptr) {
      return nullptr;
    }

    if (dev->Init()) {
      delete dev;
      return nullptr;
    }

    return dev;
  }

  ~DevBackend() noexcept {}

  void* uio_mmap([[maybe_unused]] size_t size,
                 [[maybe_unused]] unsigned int mapping) {
    // shared mmapped area between applications and NIC: able to communicate
    // with mmio
    return dev_->uio_mmap(size, mapping);
  }

  static inline uint64_t rdtsc(void) {
    uint32_t a, d;
    asm volatile("rdtsc" : "=a"(a), "=d"(d));
    return ((uint64_t)a) | (((uint64_t)d) << 32);
  }

  static _enso_always_inline void mmio_write32(volatile uint32_t* addr,
                                               uint32_t value,
                                               void* uio_mmap_bar2_addr) {
    uint64_t offset_addr =
        (uint64_t)((uint8_t*)addr - (uint8_t*)uio_mmap_bar2_addr);
    enso::enso_pipe_id_t queue_id = offset_addr / enso::kMemorySpacePerQueue;
    uint32_t offset = offset_addr % enso::kMemorySpacePerQueue;
    uint64_t mask;
    enso::PipeNotification* pipe_notification;
    struct MmioNotification mmio_notification;

    if (queue_id < enso::kMaxNbFlows) {
      // Updates to RX pipe: write directly
      switch (offset) {
        case offsetof(struct enso::QueueRegs, rx_mem_low):
          mask = enso::kMaxNbApps - 1;

          uint64_t notif_queue_id = value & mask;
          rx_queue_ids_to_notif_queue_ids_[queue_id] = notif_queue_id;

          // remove notification queue ID from value being sent: make
          // notification buffer ID 0
          value = (value & ~(mask)) | kthread_dev_->GetNotifQueueId();
          break;
      }
      _enso_compiler_memory_barrier();
      *addr = value;
      return;
    }

    queue_id -= enso::kMaxNbFlows;

    // Updates to notification buffers.
    if (queue_id < enso::kMaxNbApps) {
      switch (offset) {
        case offsetof(struct enso::QueueRegs, rx_tail):
          rx_notif_bufs_[queue_id].tail = value;
          break;

        case offsetof(struct enso::QueueRegs, rx_head):
          old_value = rx_notif_bufs_[queue_id].head;
          oldest = old_value;
          rx_notif_bufs_[queue_id].head = value;
          break;

        case offsetof(struct enso::QueueRegs, rx_mem_low): {
          uint64_t addr =
              reinterpret_cast<uint64_t>(rx_notif_bufs_[queue_id].phys_addr);
          rx_notif_bufs_[queue_id].phys_addr =
              reinterpret_cast<uint8_t*>((addr & 0xffffffff00000000) | value);
          break;
        }

        case offsetof(struct enso::QueueRegs, rx_mem_high): {
          uint64_t addr =
              reinterpret_cast<uint64_t>(rx_notif_bufs_[queue_id].phys_addr);
          rx_notif_bufs_[queue_id].phys_addr =
              reinterpret_cast<uint8_t*>((addr & 0xffffffff) | (value << 32));
          rx_notif_bufs_[queue_id].buf = reinterpret_cast<uint8_t*>(
              PhysToVirt(rx_notif_bufs_[queue_id].phys_addr));
          break;
        }

        case offsetof(struct enso::QueueRegs, tx_tail): {
          uint32_t old_tail = tx_notif_bufs_[queue_id].tail;
          tx_notif_bufs_[queue_id].tail = value;

          std::invoke(handle_tx_send, queue_id, old_tail);
          break;
        }

        case offsetof(struct enso::QueueRegs, tx_head):
          tx_notif_bufs_[queue_id].head = value;
          break;

        case offsetof(struct enso::QueueRegs, tx_mem_low): {
          uint64_t addr =
              reinterpret_cast<uint64_t>(tx_notif_bufs_[queue_id].phys_addr);
          tx_notif_bufs_[queue_id].phys_addr =
              reinterpret_cast<uint8_t*>((addr & 0xffffffff00000000) | value);
          break;
        }

        case offsetof(struct enso::QueueRegs, tx_mem_high): {
          uint64_t addr =
              reinterpret_cast<uint64_t>(tx_notif_bufs_[queue_id].phys_addr);
          tx_notif_bufs_[queue_id].phys_addr =
              reinterpret_cast<uint8_t*>((addr & 0xffffffff) | (value << 32));
          tx_notif_bufs_[queue_id].buf = reinterpret_cast<uint8_t*>(
              PhysToVirt(tx_notif_bufs_[queue_id].phys_addr));
          break;
        }

        default:
          std::cerr << "Unknown notification buffer register offset: " << offset
                    << std::endl;
          exit(1);
      }
      return;
    }
  }

  static _enso_always_inline uint32_t mmio_read32(volatile uint32_t* addr,
                                                  void* uio_mmap_bar2_addr) {
    uint64_t offset_addr =
        (uint64_t)((uint8_t*)addr - (uint8_t*)uio_mmap_bar2_addr);
    uint32_t offset = address % enso::kMemorySpacePerQueue;
    enso::enso_pipe_id_t queue_id = offset_addr / enso::kMemorySpacePerQueue;
    // Read from RX pipe: read directly
    if (queue_id < enso::kMaxNbFlows) {
      _enso_compiler_memory_barrier();
      return *addr;
    }
    queue_id -= enso::kMaxNbFlows;
    // Reads from notification buffers.
    if (queue_id < enso::kMaxNbApps) {
      uint32_t value;
      switch (offset) {
        case offsetof(struct enso::QueueRegs, rx_tail):
          value = rx_notif_bufs_[queue_id].tail;
          break;

        case offsetof(struct enso::QueueRegs, rx_head):
          value = rx_notif_bufs_[queue_id].head;
          break;

        case offsetof(struct enso::QueueRegs, rx_mem_low):
          value =
              reinterpret_cast<uint64_t>(rx_notif_bufs_[queue_id].phys_addr);
          break;

        case offsetof(struct enso::QueueRegs, rx_mem_high):
          value =
              reinterpret_cast<uint64_t>(rx_notif_bufs_[queue_id].phys_addr) >>
              32;
          break;

        case offsetof(struct enso::QueueRegs, tx_tail):
          value = tx_notif_bufs_[queue_id].tail;
          break;

        case offsetof(struct enso::QueueRegs, tx_head):
          value = tx_notif_bufs_[queue_id].head;
          break;

        case offsetof(struct enso::QueueRegs, tx_mem_low):
          value =
              reinterpret_cast<uint64_t>(tx_notif_bufs_[queue_id].phys_addr);
          break;

        case offsetof(struct enso::QueueRegs, tx_mem_high):
          value =
              reinterpret_cast<uint64_t>(tx_notif_bufs_[queue_id].phys_addr) >>
              32;
          break;

        default:
          std::cerr << "Unknown notification buffer register offset: " << offset
                    << std::endl;
          exit(1);
      }
    }
    return -1;
  }

  /**
   * @brief Converts an address in the application's virtual address space to an
   *        address that can be used by the device.
   * @param virt_addr Address in the application's virtual address space.
   * @return Converted address or 0 if the address cannot be translated.
   */
  uint64_t ConvertVirtAddrToDevAddr(void* virt_addr) {
    return virt_to_phys(virt_addr);
  }

  /**
   * @brief Retrieves the number of fallback queues currently in use.
   * @return The number of fallback queues currently in use. On error, -1 is
   *         returned and errno is set appropriately.
   */
  int GetNbFallbackQueues() { return dev_->GetNbFallbackQueues(); }

  /**
   * @brief Sets the Round-Robin status.
   *
   * @param round_robin If true, enable RR. Otherwise, disable RR.
   *
   * @return Return 0 on success. On error, -1 is returned and errno is set.
   */
  int SetRrStatus(bool round_robin) {
    if (round_robin)
      res = dev_->EnableRoundRobin();
    else
      res = dev_->DisableRoundRobin();
    return 0;
  }

  /**
   * @brief Gets the Round-Robin status.
   *
   * @return Return 1 if RR is enabled. Otherwise, return 0. On error, -1 is
   *         returned and errno is set.
   */
  int GetRrStatus() { return dev_->GetRoundRobinStatus(); }

  /**
   * @brief Allocates a notification buffer.
   *
   * @param uthread_id ID of uthread calling this function.
   *
   * @return Notification buffer ID. On error, -1 is returned and errno is set.
   */
  int AllocateNotifBuf(int32_t uthread_id) {
    if (uthread_id < 0) {
      std::cout << "ERROR: Must specify a uthread ID when creating a device in "
                   "the hybrid backend."
                << std::endl;
      exit(2);
    }
    int notif_buf_id = notif_buf_cnt_;
    notif_buf_cnt_++;

    notif_buf_ids_to_uthreads_[notif_buf_id] = uthread_id;

    return notif_buf_id;
  }

  /**
   * @brief Frees a notification buffer.
   *
   * @param notif_buf_id Notification buffer ID.
   *
   * @return Return 0 on success. On error, -1 is returned and errno is set.
   */
  int FreeNotifBuf(int notif_buf_id) {
    (void)notif_buf_id;
    return 0;
  }

  /**
   * @brief Allocates a pipe.
   *
   * @param fallback If true, allocates a fallback pipe. Otherwise, allocates a
   *                regular pipe.
   * @return Pipe ID. On error, -1 is returned and errno is set.
   */
  int AllocatePipe(bool fallback = false) {
    int pipe_id = dev_->allocate_pipe(fallback);
    return pipe_id;
  }

  /**
   * @brief Frees a pipe.
   *
   * @param pipe_id Pipe ID to be freed.
   *
   * @return 0 on success. On error, -1 is returned and errno is set.
   */
  int FreePipe(int pipe_id) { return dev_->free_pipe(pipe_id); }

 private:
  explicit DevBackend(unsigned int bdf, int bar) noexcept
      : bdf_(bdf), bar_(bar) {}

  DevBackend(const DevBackend& other) = delete;
  DevBackend& operator=(const DevBackend& other) = delete;
  DevBackend(DevBackend&& other) = delete;
  DevBackend& operator=(DevBackend&& other) = delete;

  /**
   * @brief Initializes the backend.
   *
   * @return 0 on success and a non-zero error code on failure.
   */
  int Init() noexcept {
    core_id_ = sched_getcpu();
    if (core_id_ < 0) {
      std::cerr << "Could not get CPU ID" << std::endl;
      return -1;
    }

    dev_ = intel_fpga_pcie_api::IntelFpgaPcieDev::Create(bdf_, bar_);
    if (dev_ == nullptr) {
      return -1;
    }

    return 0;
  }

  unsigned int bdf_;
  int bar_;
  int core_id_;
  intel_fpga_pcie_api::IntelFpgaPcieDev* dev_;
};

}  // namespace enso

#endif  // ENSO_SOFTWARE_SRC_BACKENDS_HYBRID_DEV_BACKEND_H_
