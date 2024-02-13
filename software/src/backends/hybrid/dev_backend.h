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
#include "intel_fpga_pcie_api.hpp"

namespace enso {

// These queues are per-kthread, not per-uthread, given that they are
// thread-local. Will automatically update when switching cores.
thread_local std::unique_ptr<QueueProducer<PipeNotification>> queue_to_backend_;
thread_local std::unique_ptr<QueueConsumer<PipeNotification>>
    queue_from_backend_;
thread_local int64_t shinkansen_notif_buf_id_ = -1;

int initialize_queues() {
  uint32_t core_id = sched_getcpu();

  std::string queue_to_app_name =
      std::string(kIpcQueueToAppName) + std::to_string(core_id) + "_";
  std::string queue_from_app_name =
      std::string(kIpcQueueFromAppName) + std::to_string(core_id) + "_";

  queue_to_backend_ =
      QueueProducer<PipeNotification>::Create(queue_from_app_name, core_id);
  if (queue_to_backend_ == nullptr) {
    std::cerr << "Could not create queue to backend" << std::endl;
    return -1;
  }

  queue_from_backend_ =
      QueueConsumer<PipeNotification>::Create(queue_to_app_name, core_id);
  if (queue_from_backend_ == nullptr) {
    std::cerr << "Could not create queue from backend" << std::endl;
    return -1;
  }

  return 0;
}

void push_to_backend(PipeNotification* notif) {
  while (queue_to_backend_->Push(*notif) != 0) {
  }
}

std::optional<PipeNotification> push_to_backend_get_response(
    PipeNotification* notif) {
  while (queue_to_backend_->Push(*notif) != 0) {
  }
  std::optional<PipeNotification> notification;

  // Block until receive.
  while (!(notification = queue_from_backend_->Pop())) {
  }
  return notification;
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

  static _enso_always_inline void mmio_write32(volatile uint32_t* addr,
                                               uint32_t value,
                                               void* uio_mmap_bar2_addr) {
    uint64_t offset_addr =
        (uint64_t)((uint8_t*)addr - (uint8_t*)uio_mmap_bar2_addr);
    enso::enso_pipe_id_t queue_id = offset_addr / enso::kMemorySpacePerQueue;
    uint32_t offset = offset_addr % enso::kMemorySpacePerQueue;

    if (queue_id < enso::kMaxNbFlows) {
      // Updates to RX pipe: write directly
      // push this to let shinkansen know about queue ID -> notification
      // queue
      switch (offset) {
        case offsetof(struct enso::QueueRegs, rx_mem_low):
          struct MmioNotification mmio_notification;
          mmio_notification.type = NotifType::kWrite;
          mmio_notification.address = offset_addr;
          mmio_notification.value = value;

          enso::PipeNotification* pipe_notification =
              (enso::PipeNotification*)&mmio_notification;

          push_to_backend(pipe_notification);
          // remove notification queue ID from value being sent: make
          // notification buffer ID 0
          uint64_t mask = (1L << 8L) - 1L;
          value = (value & ~(mask)) | shinkansen_notif_buf_id_;
          break;
      }
      _enso_compiler_memory_barrier();
      *addr = value;
      return;
    }
    queue_id -= enso::kMaxNbFlows;
    // Updates to notification buffers.
    if (queue_id < enso::kMaxNbApps) {
      // Block if full.
      struct MmioNotification mmio_notification;
      mmio_notification.type = NotifType::kWrite;
      mmio_notification.address = offset_addr;
      mmio_notification.value = value;

      enso::PipeNotification* pipe_notification =
          (enso::PipeNotification*)&mmio_notification;

      push_to_backend(pipe_notification);
    }
  }

  static _enso_always_inline uint32_t mmio_read32(volatile uint32_t* addr,
                                                  void* uio_mmap_bar2_addr) {
    uint64_t offset_addr =
        (uint64_t)((uint8_t*)addr - (uint8_t*)uio_mmap_bar2_addr);
    enso::enso_pipe_id_t queue_id = offset_addr / enso::kMemorySpacePerQueue;
    // Read from RX pipe: read directly
    if (queue_id < enso::kMaxNbFlows) {
      _enso_compiler_memory_barrier();
      return *addr;
    }
    queue_id -= enso::kMaxNbFlows;
    // Reads from notification buffers.
    if (queue_id < enso::kMaxNbApps) {
      struct MmioNotification mmio_notification;
      mmio_notification.type = NotifType::kRead;
      mmio_notification.address = offset_addr;

      enso::PipeNotification* pipe_notification =
          (enso::PipeNotification*)&mmio_notification;

      std::optional<PipeNotification> notification =
          push_to_backend_get_response(pipe_notification);

      struct MmioNotification* result =
          (struct MmioNotification*)&notification.value();

      assert(result->type == NotifType::kRead);
      assert(result->address == offset_addr);
      return result->value;
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
  int GetNbFallbackQueues() {
    struct FallbackNotification fallback_notification;
    fallback_notification.type = NotifType::kGetNbFallbackQueues;
    enso::PipeNotification* pipe_notification =
        (enso::PipeNotification*)&fallback_notification;

    std::optional<PipeNotification> notification =
        push_to_backend_get_response(pipe_notification);

    struct FallbackNotification* result =
        (struct FallbackNotification*)&notification.value();

    assert(result->type == NotifType::kGetNbFallbackQueues);
    return result->nb_fallback_queues;
  }

  /**
   * @brief Sets the Round-Robin status.
   *
   * @param round_robin If true, enable RR. Otherwise, disable RR.
   *
   * @return Return 0 on success. On error, -1 is returned and errno is set.
   */
  int SetRrStatus(bool round_robin) {
    struct RoundRobinNotification rr_notification;
    rr_notification.type = NotifType::kSetRrStatus;
    rr_notification.round_robin = (uint64_t)round_robin;

    enso::PipeNotification* pipe_notification =
        (enso::PipeNotification*)&rr_notification;

    std::optional<PipeNotification> notification =
        push_to_backend_get_response(pipe_notification);

    struct RoundRobinNotification* result =
        (struct RoundRobinNotification*)&notification.value();

    assert(result->type == NotifType::kSetRrStatus);
    return result->result;
  }

  /**
   * @brief Gets the Round-Robin status.
   *
   * @return Return 1 if RR is enabled. Otherwise, return 0. On error, -1 is
   *         returned and errno is set.
   */
  int GetRrStatus() {
    struct RoundRobinNotification rr_notification;
    rr_notification.type = NotifType::kGetRrStatus;

    enso::PipeNotification* pipe_notification =
        (enso::PipeNotification*)&rr_notification;

    std::optional<PipeNotification> notification =
        push_to_backend_get_response(pipe_notification);

    struct RoundRobinNotification* result =
        (struct RoundRobinNotification*)&notification.value();

    assert(result->type == NotifType::kGetRrStatus);
    return result->round_robin;
  }

  /**
   * @brief Allocates a notification buffer.
   *
   * @param uthread_id ID of uthread calling this function.
   *
   * @return Notification buffer ID. On error, -1 is returned and errno is set.
   */
  int AllocateNotifBuf(int32_t uthread_id) {
    if (uthread_id < 0) {
      std::cout << "ERROR: Must specify a uthread ID when creating a device in the hybrid backend." << std::uintptr_t ep_addr_aligned, data_ptr_aligned;
      exit(2);
    }
    struct NotifBufNotification nb_notification;
    nb_notification.type = NotifType::kAllocateNotifBuf;
    nb_notification.uthread_id = (uint64_t)uthread_id;

    enso::PipeNotification* pipe_notification =
        (enso::PipeNotification*)&nb_notification;

    std::optional<PipeNotification> notification =
        push_to_backend_get_response(pipe_notification);

    struct NotifBufNotification* result =
        (struct NotifBufNotification*)&notification.value();

    assert(result->type == NotifType::kAllocateNotifBuf);
    return result->notif_buf_id;
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
    struct NotifBufNotification nb_notification;
    nb_notification.type = NotifType::kFreeNotifBuf;

    enso::PipeNotification* pipe_notification =
        (enso::PipeNotification*)&nb_notification;

    std::optional<PipeNotification> notification =
        push_to_backend_get_response(pipe_notification);

    struct NotifBufNotification* result =
        (struct NotifBufNotification*)&notification.value();

    assert(result->type == NotifType::kFreeNotifBuf);
    return result->result;
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

  /**
   * @brief Sends a message to the IOKernel that the uthread is yielding.
   *
   * @param notif_buf_id The notification buffer ID of the current device.
   */
  void YieldUthread(int notif_buf_id) {
    struct YieldNotification yield_notification;
    yield_notification.type = NotifType::kUthreadWaiting;
    yield_notification.notif_buf_id = notif_buf_id;

    enso::PipeNotification* pipe_notification =
        (enso::PipeNotification*)&yield_notification;
    push_to_backend(pipe_notification);
  }

 private:
  explicit DevBackend(unsigned int bdf, int bar) noexcept
      : bdf_(bdf), bar_(bar) {}

  DevBackend(const DevBackend& other) = delete;
  DevBackend& operator=(const DevBackend& other) = delete;
  DevBackend(DevBackend&& other) = delete;
  DevBackend& operator=(DevBackend&& other) = delete;

  /**
   * @brief Gets the notification buffer ID that shinkansen has
   *        created with the NIC. This will be used to inform the
   *        NIC of which notification buffer to send notifications to
   *        when informing it of new pipes.
   */
  uint64_t get_shinkansen_notif_buf_id() {
    struct ShinkansenNotification sk_notification;
    sk_notification.type = NotifType::kGetShinkansenNotifBufId;

    enso::PipeNotification* pipe_notification =
        (enso::PipeNotification*)&sk_notification;

    std::optional<PipeNotification> notification =
        push_to_backend_get_response(pipe_notification);

    struct ShinkansenNotification* result =
        (struct ShinkansenNotification*)&notification.value();

    assert(result->type == NotifType::kGetShinkansenNotifBufId);
    return result->notif_queue_id;
  }

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

    if (shinkansen_notif_buf_id_ == -1)
      shinkansen_notif_buf_id_ = get_shinkansen_notif_buf_id();

    return 0;
  }

  unsigned int bdf_;
  int bar_;
  int core_id_;
  intel_fpga_pcie_api::IntelFpgaPcieDev* dev_;
};

}  // namespace enso

#endif  // ENSO_SOFTWARE_SRC_BACKENDS_HYBRID_DEV_BACKEND_H_
