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

#ifndef SOFTWARE_SRC_BACKENDS_HYBRID_DEV_BACKEND_H_
#define SOFTWARE_SRC_BACKENDS_HYBRID_DEV_BACKEND_H_

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

thread_local std::unique_ptr<QueueProducer<PipeNotification>> queue_to_backend_;
thread_local std::unique_ptr<QueueConsumer<PipeNotification>>
    queue_from_backend_;
thread_local uint64_t shinkansen_notif_buf_id_;

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
          struct PipeNotification pipe_notification;
          pipe_notification.type = NotifType::kWrite;
          pipe_notification.data[0] = offset_addr;
          pipe_notification.data[1] = value;
          while (queue_to_backend_->Push(pipe_notification) != 0) {
          }
          // remove notification queue ID from value being sent: make
          // notification buffer ID 0
          uint64_t mask = (1L << 32L) - 1L;
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
      struct PipeNotification pipe_notification;
      pipe_notification.type = NotifType::kWrite;
      pipe_notification.data[0] = offset_addr;
      pipe_notification.data[1] = value;
      while (queue_to_backend_->Push(pipe_notification) != 0) {
      }
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
      while (queue_to_backend_->Push({NotifType::kRead, offset_addr, 0}) != 0) {
      }

      std::optional<PipeNotification> notification;

      // Block until receive.
      while (!(notification = queue_from_backend_->Pop())) {
      }

      assert(notification->type == NotifType::kRead);
      assert(notification->data[0] == offset_addr);
      return notification->data[1];
    }
    return -1;
  }

  /**
   * @brief New kthreads must register themselves with the IOKernel to share
   * their waiters queue.
   *
   * @param kthread_waiters_phys_addr Physical address of kthread's waiting
   * queue.
   * @param application_id Application ID that is running the kthread.
   * @return Void
   */
  static _enso_always_inline void register_kthread(
      uint64_t kthread_waiters_phys_addr, uint32_t application_id) {
    (void)kthread_waiters_phys_addr;
    struct PipeNotification pipe_notification;
    pipe_notification.type = NotifType::kRegisterKthread;
    pipe_notification.data[0] = (uint64_t)application_id;
    while (queue_to_backend_->Push(pipe_notification) != 0) {
    }

    std::optional<PipeNotification> notification;

    // Block until receive.
    while (!(notification = queue_from_backend_->Pop())) {
    }

    assert(notification->type == NotifType::kRegisterKthread);
    return;
  }

  /**
   * @brief When uthreads want to start waiting for a new notification in their
   * notification buffer, must send message to IOKernel.
   *
   * Do not need to wait for a response, the IOKernel can take note
   * of if new notification must be sent to uthread.
   *
   * @param uthread_id
   */
  static _enso_always_inline void register_waiting(uint32_t notif_buf_id) {
    struct PipeNotification pipe_notification;
    pipe_notification.type = NotifType::kWaiting;
    pipe_notification.data[0] = (uint64_t)notif_buf_id;
    while (queue_to_backend_->Push(pipe_notification) != 0) {
    }

    return;
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
    struct PipeNotification pipe_notification;
    pipe_notification.type = NotifType::kGetNbFallbackQueues;
    while (queue_to_backend_->Push(pipe_notification) != 0) {
    }

    std::optional<PipeNotification> notification;

    // Block until receive.
    while (!(notification = queue_from_backend_->Pop())) {
    }

    assert(notification->type == NotifType::kGetNbFallbackQueues);
    return notification->data[0];
  }

  /**
   * @brief Sets the Round-Robin status.
   *
   * @param enable_rr If true, enable RR. Otherwise, disable RR.
   *
   * @return Return 0 on success. On error, -1 is returned and errno is set.
   */
  int SetRrStatus(bool enable_rr) {
    struct PipeNotification pipe_notification;
    pipe_notification.type = NotifType::kSetRrStatus;
    pipe_notification.data[0] = (uint64_t)enable_rr;
    while (queue_to_backend_->Push(pipe_notification) != 0) {
    }
    std::optional<PipeNotification> notification;

    // Block until receive.
    while (!(notification = queue_from_backend_->Pop())) {
    }

    assert(notification->type == notiftype::kSetRrStatus);
    return notification->data[0];
  }

  /**
   * @brief Gets the Round-Robin status.
   *
   * @return Return 1 if RR is enabled. Otherwise, return 0. On error, -1 is
   *         returned and errno is set.
   */
  int GetRrStatus() {
    struct PipeNotification pipe_notification;
    pipe_notification.type = NotifType::kGetRrStatus;
    while (queue_to_backend_->Push(pipe_notification) != 0) {
    }
    std::optional<PipeNotification> notification;

    // Block until receive.
    while (!(notification = queue_from_backend_->Pop())) {
    }

    assert(notification->type == notiftype::kGetRrStatus);
    return notification->data[0];
  }

  /**
   * @brief Allocates a notification buffer.
   *
   * @return Notification buffer ID. On error, -1 is returned and errno is set.
   */
  int AllocateNotifBuf(uint32_t uthread_id) {
    struct PipeNotification pipe_notification;
    pipe_notification.type = NotifType::kAllocateNotifBuf;
    pipe_notification.data[0] = (uint64_t)uthread_id;
    while (queue_to_backend_->Push(pipe_notification) != 0) {
    }

    std::optional<PipeNotification> notification;

    // Block until receive.
    while (!(notification = queue_from_backend_->Pop())) {
    }

    assert((uint32_t)notification->data[1] == uthread_id);
    assert(notification->type == notiftype::kAllocateNotifBuf);
    return notification->data[0];
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
    struct PipeNotification pipe_notification;
    pipe_notification.type = NotifType::kFreeNotifBuf;
    while (queue_to_backend_->Push(pipe_notification) != 0) {
    }

    std::optional<PipeNotification> notification;

    // Block until receive.
    while (!(notification = queue_from_backend_->Pop())) {
    }

    assert(notification->type == NotifType::kFreeNotifBuf);
    return notification->data[0];
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
   * @brief Gets the notification buffer ID that shinkansen has
   *        created with the NIC. This will be used to inform the
   *        NIC of which notification buffer to send notifications to
   *        when informing it of new pipes.
   */
  uint64_t get_shinkansen_notif_buf_id() {
    struct PipeNotification pipe_notification;
    pipe_notification.type = NotifType::kGetShinkansenNotifBufId;
    while (queue_to_backend_->Push(pipe_notification) != 0) {
    }

    std::optional<PipeNotification> notification;

    // Block until receive.
    while (!(notification = queue_from_backend_->Pop())) {
    }

    assert(notification->type == NotifType::kGetShinkansenNotifBufId);
    return notification->data[0];
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

    dev_ = intel_fpga_pcie_api::IntelFpgaPcieDev::Create(bdf_, bar_);
    if (dev_ == nullptr) {
      return -1;
    }

    shinkansen_notif_buf_id_ = get_shinkansen_notif_buf_id();

    return 0;
  }

  unsigned int bdf_;
  int bar_;
  int core_id_;
  intel_fpga_pcie_api::IntelFpgaPcieDev* dev_;
};

}  // namespace enso

#endif  // SOFTWARE_SRC_BACKENDS_HYBRID_DEV_BACKEND_H_
