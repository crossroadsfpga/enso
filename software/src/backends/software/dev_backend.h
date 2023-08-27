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

#ifndef SOFTWARE_SRC_BACKENDS_SOFTWARE_DEV_BACKEND_H_
#define SOFTWARE_SRC_BACKENDS_SOFTWARE_DEV_BACKEND_H_

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
    return 0;  // Not a valid address. We use the offset to emulate MMIO access.
  }

  static _enso_always_inline void mmio_write32(volatile uint32_t* addr,
                                               uint32_t value) {
    // Block if full.
    struct PipeNotification notification;
    notification.type = NotifType::kWrite;
    notification.data[0] = (uint64_t)addr;
    notification.data[1] = value;
    while (queue_to_backend_->Push(notification) != 0) {
    }
  }

  static _enso_always_inline uint32_t mmio_read32(volatile uint32_t* addr) {
    struct PipeNotification notification;
    notification.type = NotifType::kRead;
    notification.data[0] = (uint64_t)addr;
    notification.data[1] = 0;
    while (queue_to_backend_->Push(notification) != 0) {
    }

    std::optional<PipeNotification> notification;

    // Block until receive.
    while (!(notification = queue_from_backend_->Pop())) {
    }

    assert(notification->type == notiftype::kRead);
    assert(notification->address == (uint64_t)addr);
    return notification->value;
  }

  /**
   * @brief Converts an address in the application's virtual address space to an
   *        address that can be used by the device.
   * @param virt_addr Address in the application's virtual address space.
   * @return Converted address or 0 if the address cannot be translated.
   */
  uint64_t ConvertVirtAddrToDevAddr(void* virt_addr) {
    uint64_t phys_addr = virt_to_phys(virt_addr);

    _enso_compiler_memory_barrier();

    struct PipeNotification notification;
    notification.type = NotifType::kTranslAddr;
    notification.data[0] = (uint64_t)phys_addr;
    notification.data[1] = 0;
    while (queue_to_backend_->Push(notification) != 0) {
    }

    std::optional<PipeNotification> notification;

    // Block until receive.
    while (!(notification = queue_from_backend_->Pop())) {
    }

    assert(notification->type == notiftype::kTranslAddr);
    assert(notification->address == (uint64_t)phys_addr);

    return notification->value;
  }

  /**
   * @brief Retrieves the number of fallback queues currently in use.
   * @return The number of fallback queues currently in use. On error, -1 is
   *         returned and errno is set appropriately.
   */
  int GetNbFallbackQueues() {
    // TODO(sadok): Implement.
    return 0;
  }

  /**
   * @brief Sets the Round-Robin status.
   *
   * @param enable_rr If true, enable RR. Otherwise, disable RR.
   *
   * @return Return 0 on success. On error, -1 is returned and errno is set.
   */
  int SetRrStatus(bool enable_rr) {
    // TODO(sadok): Implement.
    (void)enable_rr;
    return 0;
  }

  /**
   * @brief Gets the Round-Robin status.
   *
   * @return Return 1 if RR is enabled. Otherwise, return 0. On error, -1 is
   *         returned and errno is set.
   */
  int GetRrStatus() {
    // TODO(sadok): Implement.
    return 0;
  }

  /**
   * @brief Allocates a notification buffer.
   *
   * @return Notification buffer ID. On error, -1 is returned and errno is set.
   */
  int AllocateNotifBuf() {
    // TODO(sadok): Implement.
    int notif_buf_id = notif_buf_cnt_;
    ++notif_buf_cnt_;
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
    // TODO(sadok): Implement.
    --notif_buf_cnt_;
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
    struct PipeNotification notification;
    notification.type = NotifType::kAllocatePipe;
    notification.data[0] = fallback;
    while (queue_to_backend_->Push(notification) != 0) {
    }

    std::optional<PipeNotification> notification;

    // Block until receive.
    while (!(notification = queue_from_backend_->Pop())) {
    }

    assert(notification->type == notiftype::kAllocatePipe);
    return notification->value;
  }

  static int BindPipe(struct NotificationBufPair* notification_buf_pair,
                      uint16_t dst_port, uint16_t src_port, uint32_t dst_ip,
                      uint32_t src_ip, uint32_t protocol, enso_pipe_id_t id) {
    struct PipeNotification notification;
    notification.type = NotifType::kBindPipe;
    notification.data[0] = dst_port;
    notification.data[1] = src_port;
    notification.data[2] = dst_ip;
    notification.data[3] = src_ip;
    notification.data[4] = protocol;
    notification.data[5] = id;
    while (queue_to_backend_->Push(notification) != 0) {
    }

    std::optional<PipeNotification> notification;

    // Block until receive.
    while (!(notification = queue_from_backend_->Pop())) {
    }

    assert(notification->type == notiftype::kAllocatePipe);
    return notification->value;
  }

  /**
   * @brief Frees a pipe.
   *
   * @param pipe_id Pipe ID to be freed.
   *
   * @return 0 on success. On error, -1 is returned and errno is set.
   */
  int FreePipe(int pipe_id) {
    // TODO(sadok): Implement.
    --pipe_cnt_;
    return 0;
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
  int notif_buf_cnt_ = 0;
  int pipe_cnt_ = 0;
};

}  // namespace enso

#endif  // SOFTWARE_SRC_BACKENDS_SOFTWARE_DEV_BACKEND_H_
