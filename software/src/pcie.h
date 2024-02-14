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
 * @brief Functions to initialize and interface directly with the PCIe device.
 *
 * @author Hugo Sadok <sadok@cmu.edu>
 */

#ifndef SOFTWARE_SRC_PCIE_H_
#define SOFTWARE_SRC_PCIE_H_

#include <endian.h>
#include <enso/helpers.h>
#include <enso/internals.h>
#include <netinet/ether.h>
#include <netinet/ip.h>

#include <string>

namespace enso {

/**
 * @brief Initializes the notification buffer pair.
 *
 * @param bdf BDF of the PCIe device to use.
 * @param bar PCIe BAR to use (set to -1 to automatically select one).
 * @param notification_buf_pair Notification buffer pair to initialize.
 * @param huge_page_prefix File prefix to use when allocating the huge pages.
 *
 * @return 0 on success, -1 on failure.
 */
int notification_buf_init(uint32_t bdf, int32_t bar,
                          struct NotificationBufPair* notification_buf_pair,
                          const std::string& huge_page_prefix);

/**
 * @brief Initializes an Enso Pipe.
 *
 * @param enso_pipe Enso Pipe to initialize.
 * @param notification_buf_pair Notification buffer pair to use.
 * @param fallback Whether the queues is a fallback queue or not.
 *
 * @return Pipe ID on success, -1 on failure.
 */
int enso_pipe_init(struct RxEnsoPipeInternal* enso_pipe,
                   struct NotificationBufPair* notification_buf_pair,
                   bool fallback);

uint32_t consume_rx_kernel(struct NotificationBufPair* notification_buf_pair,
                                  uint32_t &new_rx_tail, int32_t &pipe_id);

void advance_pipe_kernel(struct NotificationBufPair* notification_buf_pair,
                        struct RxEnsoPipeInternal* enso_pipe, size_t len);

void fully_advance_pipe_kernel(struct RxEnsoPipeInternal* enso_pipe,
                               struct NotificationBufPair* notification_buf_pair);

/**
 * @brief Prefetches a given Enso Pipe.
 *
 * @param enso_pipe Enso pipe to prefetch.
 */
void prefetch_pipe(struct RxEnsoPipeInternal* enso_pipe,
                   struct NotificationBufPair* notification_buf_pair);

/**
 * @brief Sends data through a given queue.
 *
 * This function returns as soon as a transmission requests has been enqueued to
 * the TX notification buffer. That means that it is not safe to modify or
 * deallocate the buffer pointed by `phys_addr` right after it returns. Instead,
 * the caller must use `get_unreported_completions` to figure out when the
 * transmission is complete.
 *
 * This function currently blocks if there is not enough space in the
 * notification buffer.
 *
 * @param notification_buf_pair Notification buffer to send data through.
 * @param phys_addr Physical memory address of the data to be sent.
 * @param len Length, in bytes, of the data.
 *
 * @return number of bytes sent.
 */
uint32_t send_to_queue(struct NotificationBufPair* notification_buf_pair,
                       uint64_t phys_addr, uint32_t len);

/**
 * @brief Returns the number of transmission requests that were completed since
 * the last call to this function.
 *
 * Since transmissions are always completed in order, one can figure out which
 * transmissions were completed by keeping track of all the calls to
 * `send_to_queue`. There can be only up to `kMaxPendingTxRequests` requests
 * completed between two calls to `send_to_queue`. However, if `send` is called
 * multiple times, without calling `get_unreported_completions` the number of
 * completed requests can surpass `kMaxPendingTxRequests`.
 *
 * @param notification_buf_pair Notification buffer to get completions from.
 * @return number of transmission requests that were completed since the last
 *         call to this function.
 */
uint32_t get_unreported_completions(
    struct NotificationBufPair* notification_buf_pair);

/**
 * @brief Sends configuration to the NIC.
 *
 * @param notification_buf_pair The notification buffer pair to send the
 *                              configuration through.
 * @param config_notification The configuration notification to send. Must be
 *                            a config notification, i.e., signal >= 2.
 *
 * @return 0 on success, -1 on failure.
 */
int send_config(struct NotificationBufPair* notification_buf_pair,
                struct TxNotification* config_notification);

/**
 * @brief Get number of fallback queues currently in use.
 *
 * @param notification_buf_pair Notification buffer pair to use.
 *
 * @return Number of fallback queues currently in use or -1 on failure.
 */
int get_nb_fallback_queues(struct NotificationBufPair* notification_buf_pair);

/**
 * @brief Sets the round robin status for the device.
 *
 * @param notification_buf_pair Notification buffer pair to use.
 * @param round_robin Whether to enable or disable round robin.
 *
 * @return 0 on success, -1 on failure.
 */
int set_round_robin_status(struct NotificationBufPair* notification_buf_pair,
                           bool round_robin);

/**
 * @brief Gets the round robin status for the device.
 *
 * @param notification_buf_pair Notification buffer pair to use.
 *
 * @return 0 if round robin is disabled, 1 if round robin is enabled, -1 on
 *         failure.
 */
int get_round_robin_status(struct NotificationBufPair* notification_buf_pair);

/**
 * @brief Converts an address in the application's virtual address space to an
 *        address that can be used by the device (typically a physical address).
 *
 * @param notification_buf_pair Notification buffer pair to use.
 * @param virt_addr Virtual address to convert.
 * @return Converted address or 0 if the address cannot be translated.
 */
uint64_t get_dev_addr_from_virt_addr(
    struct NotificationBufPair* notification_buf_pair, void* virt_addr);

/**
 * @brief Frees the notification buffer pair.
 *
 * @param notification_buf_pair Notification buffer pair to free.
 */
void notification_buf_free(struct NotificationBufPair* notification_buf_pair);

/**
 * @brief Frees the Enso Pipe.
 *
 * @param notification_buf_pair Notification buffer pair to use.
 * @param enso_pipe Enso Pipe to free.
 * @param enso_pipe_id Hardware ID of the Enso Pipe to free.
 */
void enso_pipe_free(struct NotificationBufPair* notification_buf_pair,
                    struct RxEnsoPipeInternal* enso_pipe,
                    enso_pipe_id_t enso_pipe_id);

}  // namespace enso

#endif  // SOFTWARE_SRC_PCIE_H_
