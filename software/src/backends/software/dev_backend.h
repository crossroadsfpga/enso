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
 * @author Hugo Sadok <sadok@cmu.edu>
 */

#ifndef ENSO_SOFTWARE_SRC_BACKENDS_SOFTWARE_DEV_BACKEND_H_
#define ENSO_SOFTWARE_SRC_BACKENDS_SOFTWARE_DEV_BACKEND_H_

#include <assert.h>
#include <sched.h>
#include <unistd.h>

#include <iostream>
#include <memory>
#include <optional>
#include <string>

#include "enso/consts.h"
#include "enso/helpers.h"
#include "enso/queue.h"

namespace enso {

thread_local std::unique_ptr<QueueProducer<PipeNotification>> queue_to_backend_;
thread_local std::unique_ptr<QueueConsumer<PipeNotification>>
    queue_from_backend_;

using BackendWrapper = std::function<void()>;
int initialize_queues(uint32_t core_id, BackendWrapper preempt_enable,
                      BackendWrapper preempt_disable) {
  return 0;
}

void initialize_backend_dev(BackendWrapper preempt_enable,
                            BackendWrapper preempt_disable) {
  (void)preempt_enable;
  (void)preempt_disable;
}

void set_backend_core_id_dev(uint32_t core_id) { (void)core_id; }

void push_to_backend(enso::PipeNotification* notif) { (void)notif; }

void update_backend_queues() {}

void access_backend_queues() {}

std::optional<PipeNotification> push_to_backend_get_response(
    enso::PipeNotification* notif) {
  (void)notif;
  std::optional<PipeNotification> res;
  return res;
}

class DevBackend {
 public:
  static DevBackend* Create(unsigned int bdf, int bar) noexcept {
    std::cerr << "Using software backend" << std::endl;

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
    return 0;  // Not a valid address. We use the offset to emulate MMIO
               // access.
  }

  static _enso_always_inline void mmio_write32(volatile uint32_t* addr,
                                               uint32_t value,
                                               void* uio_mmap_bar2_addr) {
    (void)uio_mmap_bar2_addr;
    // Block if full.
    struct MmioNotification mmio_notification;
    mmio_notification.type = NotifType::kWrite;
    mmio_notification.address = (uint64_t)addr;
    mmio_notification.value = value;

    enso::PipeNotification* pipe_notification =
        (enso::PipeNotification*)&mmio_notification;

    while (queue_to_backend_->Push(*pipe_notification) != 0) {
    }
  }

  static _enso_always_inline uint32_t mmio_read32(volatile uint32_t* addr) {
    struct MmioNotification mmio_notification;
    mmio_notification.type = NotifType::kRead;
    mmio_notification.address = (uint64_t)addr;
    mmio_notification.value = 0;

    enso::PipeNotification* pipe_notification =
        (enso::PipeNotification*)&mmio_notification;

    while (queue_to_backend_->Push(*pipe_notification) != 0) {
    }

    std::optional<PipeNotification> notification;

    // Block until receive.
    while (
        !(notification = (struct MmioNotification)queue_from_backend_->Pop())) {
    }

    struct MmioNotification* result =
        (struct MmioNotification*)&notification.value();

    assert(result->type == NotifType::kRead);
    assert(result->address == (uint64_t)addr);
    return result->value;
  }

  /**
   * @brief Converts an address in the application's virtual address space to
   * an address that can be used by the device.
   * @param virt_addr Address in the application's virtual address space.
   * @return Converted address or 0 if the address cannot be translated.
   */
  uint64_t ConvertVirtAddrToDevAddr(void* virt_addr) {
    uint64_t phys_addr = virt_to_phys(virt_addr);

    _enso_compiler_memory_barrier();

    struct MmioNotification mmio_notification;
    mmio_notification.type = NotifType::kTranslAddr;
    mmio_notification.address = (uint64_t)phys_addr;
    mmio_notification.value = 0;

    enso::PipeNotification* pipe_notification =
        (enso::PipeNotification*)&mmio_notification;
    while (queue_to_backend_->Push(*pipe_notification) != 0) {
    }

    std::optional<PipeNotification> notification;

    // Block until receive.
    while (
        !(notification = (struct MmioNotification)queue_from_backend_->Pop())) {
    }

    struct MmioNotification* result =
        (struct MmioNotification*)&notification.value();

    assert(result->type == NotifType::kTranslAddr);
    assert(result->address == (uint64_t)phys_addr);
    return result->value;
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
    while (queue_to_backend_->Push(*pipe_notification) != 0) {
    }

    std::optional<PipeNotification> notification;

    // Block until receive.
    while (!(notification = queue_from_backend_->Pop())) {
    }

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
    while (queue_to_backend_->Push(*pipe_notification) != 0) {
    }

    std::optional<PipeNotification> notification;

    // Block until receive.
    while (!(notification = queue_from_backend_->Pop())) {
    }

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

    while (queue_to_backend_->Push(*pipe_notification) != 0) {
    }

    std::optional<PipeNotification> notification;

    // Block until receive.
    while (!(notification = queue_from_backend_->Pop())) {
    }

    struct RoundRobinNotification* result =
        (struct RoundRobinNotification*)&notification.value();

    assert(result->type == NotifType::kGetRrStatus);
    return result->round_robin;
  }

  /**
   * @brief Allocates a notification buffer.
   *
   * @param uthread_id ID of currently running uthread.
   *
   * @return Notification buffer ID. On error, -1 is returned and errno is
   * set.
   */
  int AllocateNotifBuf(int32_t uthread_id) {
    struct NotifBufNotification nb_notification;
    nb_notification.type = NotifType::kAllocateNotifBuf;
    nb_notification.uthread_id = (uint64_t)uthread_id;

    enso::PipeNotification* pipe_notification =
        (enso::PipeNotification*)&nb_notification;
    while (queue_to_backend_->Push(*pipe_notification) != 0) {
    }

    std::optional<PipeNotification> queue_value;

    // Block until receive.
    while (!(queue_value = queue_from_backend_->Pop())) {
    }

    struct PipeNotification notification = queue_value.value();

    struct NotifBufNotification* result =
        (struct NotifBufNotification*)&notification;

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
    while (queue_to_backend_->Push(*pipe_notification) != 0) {
    }

    std::optional<PipeNotification> notification;

    // Block until receive.
    while (!(notification = queue_from_backend_->Pop())) {
    }

    struct NotifBufNotification* result =
        (struct NotifBufNotification*)&notification.value();

    assert(result->type == NotifType::kFreeNotifBuf);
    return result->result;
  }

  /**
   * @brief Allocates a pipe.
   *
   * @param fallback If true, allocates a fallback pipe. Otherwise, allocates
   * a regular pipe.
   * @return Pipe ID. On error, -1 is returned and errno is set.
   */
  int AllocatePipe(bool fallback = false) {
    struct AllocatePipeNotification alloc_notification;
    alloc_notification.type = NotifType::kAllocatePipe;
    alloc_notification.fallback = fallback;

    enso::PipeNotification* pipe_notification =
        (enso::PipeNotification*)&alloc_notification;
    while (queue_to_backend_->Push(*pipe_notification) != 0) {
    }

    std::optional<PipeNotification> notification;

    // Block until receive.
    while (!(notification = queue_from_backend_->Pop())) {
    }

    struct AllocatePipeNotification* result =
        (struct AllocatePipeNotification*)&notification.value();
    assert(result->type == NotifType::kAllocatePipe);
    return result->pipe_id;
  }

  /**
   * @brief Frees a pipe.
   *
   * @param pipe_id Pipe ID to be freed.
   *
   * @return 0 on success. On error, -1 is returned and errno is set.
   */
  int FreePipe(int pipe_id) {
    struct FreePipeNotification free_notification;
    free_notification.type = NotifType::kFreePipe;
    free_notification.pipe_id = pipe_id;

    enso::PipeNotification* pipe_notification =
        (enso::PipeNotification*)&free_notification;
    while (queue_to_backend_->Push(*pipe_notification) != 0) {
    }

    std::optional<PipeNotification> notification;

    // Block until receive.
    while (!(notification = queue_from_backend_->Pop())) {
    }

    struct FreePipeNotification* result =
        (struct FreePipeNotification*)&notification.value();

    assert(result->type == NotifType::kFreePipe);
    return result->result;
  }

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

    std::string queue_to_app_name =
        std::string(enso::kIpcQueueToAppName) + std::to_string(core_id_) + "_";
    std::string queue_from_app_name = std::string(enso::kIpcQueueFromAppName) +
                                      std::to_string(core_id_) + "_";

    queue_to_backend_ =
        QueueProducer<PipeNotification>::Create(queue_from_app_name);
    if (queue_to_backend_ == nullptr) {
      std::cerr << "Could not create queue to backend" << std::endl;
      return -1;
    }

    queue_from_backend_ =
        QueueConsumer<PipeNotification>::Create(queue_to_app_name);
    if (queue_from_backend_ == nullptr) {
      std::cerr << "Could not create queue from backend" << std::endl;
      return -1;
    }

    return 0;
  }

  unsigned int bdf_;
  int bar_;
  int core_id_;
};
}  // namespace enso

#endif  // ENSO_SOFTWARE_SRC_BACKENDS_SOFTWARE_DEV_BACKEND_H_
