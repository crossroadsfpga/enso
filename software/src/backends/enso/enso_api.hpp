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
#ifndef SOFTWARE_SRC_BACKENDS_ENSO_ENSO_API_HPP_
#define SOFTWARE_SRC_BACKENDS_ENSO_ENSO_API_HPP_

#include <sys/types.h>

#include <cstddef>
#include <cstdint>

#ifdef _WIN32
#endif

#ifdef __linux__
#include "linux/enso_api_linux.hpp"
#endif  // __linux__

namespace enso_api {

/**
 * Enso device handle class.
 *
 * This class provides a handle to access an Enso device from
 * the user-space without worrying about kernel interface.
 *
 */
class EnsoDev {
 public:
  static EnsoDev *Create() noexcept;

  ~EnsoDev(void);

  void test();
  /**
   * Retrieve the number of fallback queues currently in use.
   * @return The number of fallback queues currently in use. On error, -1 is
   *         returned and errno is set appropriately.
   */
  int get_nb_fallback_queues();

  /**
   * Set the Round-Robin status.
   * @param enable_rr If true, enable RR. Otherwise, disable RR.
   * @return Return 0 on success. On error, -1 is returned and errno is set.
   */
  int set_rr_status(bool enable_rr);

  /**
   * Retrieve the Round-Robin status.
   * @return If the device has RR enabled, return 1. Otherwise, return 0. On
   *         error, -1 is returned and errno is set appropriately.
   */
  int get_rr_status();

  /**
   * Allocate a notification buffer.
   * @return Notification buffer ID. On error, -1 is returned and errno is set
   *         appropriately.
   */
  int allocate_notif_buf();

  /**
   * Free a notification buffer.
   * @param id Notification buffer ID.
   * @return 0 on success. On error, -1 is returned and errno is set
   *         appropriately.
   */
  int free_notif_buf(int id);

  /**
   * Allocate a pipe.
   * @param fallback If true, allocate a fallback pipe. Otherwise, allocate a
   *                 regular pipe.
   * @return Pipe ID. On error, -1 is returned and errno is set appropriately.
   */
  int allocate_rx_pipe(bool fallback = false);

  /**
   * Free a pipe.
   * @param id Pipe ID.
   * @return 0 on success. On error, -1 is returned and errno is set
   *         appropriately.
   */
  int free_pipe(int id);

  /**
   * Allocate a notification buffer pair.
   * @return 0 on success. On error, -1 is returned and errno is set
   *         appropriately.
   */
  int allocate_notif_buf_pair(int id);

  /**
   * Send a TxPipe buffer.
   * @param phys_addr starting address of the buffer.
   * @param len       size of the buffer in bytes.
   * @param buf_id    notification buffer id.
   *
   * @return 0 on success. On error, -1 is returned and errno is set
   *         appropriately.
   */
  int send_tx_pipe(uint64_t phys_addr, uint32_t len, uint32_t notif_buf_id,
                   uint32_t pipe_id);

  /**
   * Get the number of Tx notifications that were consumed by the NIC.
   * @return the number of unreported completions on success.
   *         On error, -1 is returned and errno is set appropriately.
   */
  int get_unreported_completions();

  /**
   * Send a config notification.
   * @param txNotification struct TxNotification with the configuration.
   *
   * @return 0 on success. On error, -1 is returned and errno is set
   *         appropriately.
   */
  int send_config(struct TxNotification *txNotification);
  int allocate_enso_rx_pipe(int pipe_id, uint64_t buf_phys_addr);
  int free_enso_rx_pipe(int pipe_id);
  int consume_rx_pipe(int &pipe_id, uint32_t &krx_tail);
  int full_adv_pipe(int pipe_id);
  int get_next_batch(int notif_id, int &pipe_id, uint32_t &krx_tail);
  int advance_pipe(int pipe_id, size_t len);
  int next_rx_pipe_to_recv();
  int prefetch_pipe(int pipe_id);
  int allocate_tx_pipe();
  int free_tx_pipe(int pipe_id);

 private:
  /**
   * Class should be instantiated via the Create() factory method.
   */
  EnsoDev() noexcept = default;

  int Init() noexcept;

  ssize_t m_dev_handle;
};

}  // namespace enso_api

#endif  // SOFTWARE_SRC_BACKENDS_ENSO_ENSO_API_HPP_
