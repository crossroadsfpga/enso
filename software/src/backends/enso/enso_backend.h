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

#ifndef SOFTWARE_SRC_BACKENDS_ENSO_DEV_BACKEND_H_
#define SOFTWARE_SRC_BACKENDS_ENSO_DEV_BACKEND_H_

#include <enso/helpers.h>

#include "enso_api.hpp"

namespace enso {

class EnsoBackend {
 public:
  static EnsoBackend* Create() noexcept {
    EnsoBackend* dev = new (std::nothrow) EnsoBackend();

    if (dev == nullptr) {
      return nullptr;
    }

    if (dev->Init()) {
      delete dev;
      return nullptr;
    }

    return dev;
  }

  ~EnsoBackend() noexcept {
    if (dev_ != nullptr) {
      delete dev_;
    }
  }

  void Test() {
    return dev_->test();
  }

  /**
   * @brief Converts an address in the application's virtual address space to an
   *        address that can be used by the device (typically the physical
   *        address).
   * @param virt_addr Address in the application's virtual address space.
   * @return Address that can be used by the device.
   */
  uint64_t ConvertVirtAddrToDevAddr(void* virt_addr) {
    return virt_to_phys(virt_addr);
  }

  /**
   * @brief Retrieves the number of fallback queues currently in use.
   * @return The number of fallback queues currently in use. On error, -1 is
   *         returned and errno is set appropriately.
   */
  int GetNbFallbackQueues() { return dev_->get_nb_fallback_queues(); }

  /**
   * @brief Sets the Round-Robin status.
   *
   * @param enable_rr If true, enable RR. Otherwise, disable RR.
   *
   * @return Return 0 on success. On error, -1 is returned and errno is set.
   */
  int SetRrStatus(bool enable_rr) { return dev_->set_rr_status(enable_rr); }

  /**
   * @brief Gets the Round-Robin status.
   *
   * @return Return 1 if RR is enabled. Otherwise, return 0. On error, -1 is
   *         returned and errno is set.
   */
  int GetRrStatus() { return dev_->get_rr_status(); }

  /**
   * @brief Allocates a notification buffer.
   *
   * @return Notification buffer ID. On error, -1 is returned and errno is set.
   */
  int AllocateNotifBuf() { return dev_->allocate_notif_buf(); }

  /**
   * @brief Frees a notification buffer.
   *
   * @param notif_buf_id Notification buffer ID.
   *
   * @return Return 0 on success. On error, -1 is returned and errno is set.
   */
  int FreeNotifBuf(int notif_buf_id) {
    return dev_->free_notif_buf(notif_buf_id);
  }

  /**
   * @brief Allocates a pipe.
   *
   * @param fallback If true, allocates a fallback pipe. Otherwise, allocates a
   *                regular pipe.
   * @return Pipe ID. On error, -1 is returned and errno is set.
   */
  int AllocatePipe(bool fallback = false) {
    return dev_->allocate_pipe(fallback);
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
   * @brief Allocates a notification buffer pair structure.
   *
   * @param notif_buf_id Notification buffer ID.
   *
   * @return Return 0 on success. On error, -1 is returned and errno is set.
   */
  int AllocNotifBufPair(int notif_buf_id) {
    return dev_->allocate_notif_buf_pair(notif_buf_id);
  }

  /**
   * @brief Transmit data to the network.
   *
   * @param phys_addr   start address of the buffer.
   * @param len         size of the data in bytes.
   * @param id          notification buffer pair id.
   *
   * @return Return 0 on success. On error, -1 is returned and errno is set.
   */
  int SendTxPipe(uint64_t phys_addr, uint32_t len, uint32_t id) {
    return dev_->send_tx_pipe(phys_addr, len, id);
  }

  /**
   * @brief Gets the number of Tx notification that have been consumed by the NIC.
   *
   * @return Return the number of unreported completions on success.
   *         On error, -1 is returned and errno is set.
   */
  int GetUnreportedCompletions() {
    return dev_->get_unreported_completions();
  }

  /**
   * @brief Transmit configuration info to the NIC.
   *
   * @param txNotification   struct TxNotification for carrying the config info.
   *
   * @return Return 0 on success. On error, -1 is returned and errno is set.
   */
  int SendConfig(struct TxNotification *txNotification) {
    return dev_->send_config(txNotification);
  }

  int AllocateEnsoRxPipe(int pipe_id, uint64_t buf_phys_addr) {
    return dev_->allocate_enso_rx_pipe(pipe_id, buf_phys_addr);
  }

  int FreeEnsoRxPipe(int pipe_id) {
    return dev_->free_enso_rx_pipe(pipe_id);
  }

  int ConsumeRxPipe(int &pipe_id, uint32_t &krx_tail) {
    return dev_->consume_rx_pipe(pipe_id, krx_tail);
  }

  int FullyAdvancePipe(int pipe_id) {
    return dev_->full_adv_pipe(pipe_id);
  }

  int GetNextBatch(int notif_id, int &pipe_id, uint32_t &krx_tail) {
    return dev_->get_next_batch(notif_id, pipe_id, krx_tail);
  }

  int AdvancePipe(int pipe_id, size_t len) {
    return dev_->advance_pipe(pipe_id, len);
  }

  int NextRxPipeToRecv() {
    return dev_->next_rx_pipe_to_recv();
  }

  int PrefetchPipe(int pipe_id) {
    return dev_->prefetch_pipe(pipe_id);
  }

 private:
  explicit EnsoBackend() noexcept {}

  EnsoBackend(const EnsoBackend& other) = delete;
  EnsoBackend& operator=(const EnsoBackend& other) = delete;
  EnsoBackend(EnsoBackend&& other) = delete;
  EnsoBackend& operator=(EnsoBackend&& other) = delete;

  int Init() noexcept {
    dev_ = enso_api::EnsoDev::Create();
    if (dev_ == nullptr) {
      return -1;
    }
    return 0;
  }

  enso_api::EnsoDev* dev_;
};

}  // namespace enso

#endif  // SOFTWARE_SRC_BACKENDS_ENSO_DEV_BACKEND_H_
