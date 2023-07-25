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

struct SocketInternal {
  struct NotificationBufPair* notification_buf_pair;
  struct RxEnsoPipeInternal enso_pipe;
};

/**
 * @brief Initializes the notification buffer pair.
 *
 * @param bdf BDF of the PCIe device to use.
 * @param bar PCIe BAR to use (set to -1 to automatically select one).
 * @param core_id Core ID to use.
 * @param notification_buf_pair Notification buffer pair to initialize.
 * @param nb_queues Number of queues that will be used by the application.
 * @param enso_pipe_id_offset Offset to use when initializing the Enso Pipe IDs.
 *                            This is mostly a hack and should be removed in the
 *                            future.
 * @param shared_memory_prefix Prefix to use when creating the shared memory.
 */
int notification_buf_init(uint32_t bdf, int32_t bar, int16_t core_id,
                          struct NotificationBufPair* notification_buf_pair,
                          enso_pipe_id_t nb_queues,
                          enso_pipe_id_t enso_pipe_id_offset,
                          const std::string& shared_memory_prefix);

/**
 * @brief Initializes an Enso Pipe.
 *
 * @param enso_pipe Enso Pipe to initialize.
 * @param notification_buf_pair Notification buffer pair to use.
 * @param enso_pipe_id ID of the Enso Pipe to initialize.
 */
int enso_pipe_init(struct RxEnsoPipeInternal* enso_pipe,
                   struct NotificationBufPair* notification_buf_pair,
                   enso_pipe_id_t enso_pipe_id);

/**
 * @brief Initializes an enso pipe and the notification buffer if needed.
 *
 * @deprecated This function is deprecated and will be removed in the future.
 */
int dma_init(struct NotificationBufPair* notification_buf_pair,
             struct RxEnsoPipeInternal* enso_pipe, unsigned socket_id,
             unsigned nb_queues, uint32_t bdf, int32_t bar,
             const std::string& shared_memory_prefix);

/**
 * @brief Gets latest tails for the pipes associated with the given notification
 * buffer.
 *
 * @param notification_buf_pair Notification buffer to get data from.
 * @return Number of notifications received.
 */
uint16_t get_new_tails(struct NotificationBufPair* notification_buf_pair);

/**
 * @brief Gets the next batch of data from the given Enso Pipe.
 *
 * @param enso_pipe Enso Pipe to get data from.
 * @param notification_buf_pair Notification buffer to get data from.
 * @param buf Pointer to the buffer where the data will be stored, it will be
 *            updated to point to the next available data.
 * @return Number of bytes received.
 */
uint32_t get_next_batch_from_queue(
    struct RxEnsoPipeInternal* enso_pipe,
    struct NotificationBufPair* notification_buf_pair, void** buf);

/**
 * @brief Gets the next batch of data from the given Enso Pipe without consuming
 *        it. So the next call to `get_next_batch_from_queue` or to
 *       `peek_next_batch_from_queue` will return the same data.
 *
 * @param enso_pipe Enso Pipe to get data from.
 * @param notification_buf_pair Notification buffer to get data from.
 * @param buf Pointer to the buffer where the data will be stored, it will be
 *            updated to point to the next available data.
 * @return Number of bytes received.
 */
uint32_t peek_next_batch_from_queue(
    struct RxEnsoPipeInternal* enso_pipe,
    struct NotificationBufPair* notification_buf_pair, void** buf);

/**
 * @brief Get next Enso Pipe with pending data.
 *
 * @param notification_buf_pair Notification buffer to get data from.
 * @return ID for the next Enso Pipe that has data available, or -1 if no Enso
 *         Pipe has data.
 */
int32_t get_next_enso_pipe_id(
    struct NotificationBufPair* notification_buf_pair);

/**
 * @brief Get next batch of data from the next available Enso Pipe.
 *
 * @param notification_buf_pair Notification buffer to get data from.
 * @param socket_entries Array of socket entries.
 * @param enso_pipe_id ID of the Enso Pipe that the data came from.
 * @param buf Pointer to the buffer where the data will be stored.
 * @return Number of bytes received.
 */
uint32_t get_next_batch(struct NotificationBufPair* notification_buf_pair,
                        struct SocketInternal* socket_entries,
                        int* enso_pipe_id, void** buf);

/**
 * @brief Frees the next `len` bytes in the buffer associated with the
 * `socket_entry` socket. If `len` is greater than the number of allocated bytes
 * in the buffer, the behavior is undefined.
 *
 * @param enso_pipe Enso pipe to advance.
 * @param len Number of bytes to free.
 */
void advance_pipe(struct RxEnsoPipeInternal* enso_pipe, size_t len);

/**
 * @brief Frees all the received bytes in the buffer associated with the
 * `socket_entry` socket.
 *
 * @param enso_pipe Enso pipe to advance.
 */
void fully_advance_pipe(struct RxEnsoPipeInternal* enso_pipe);

/**
 * @brief Prefetches a given Enso Pipe.
 *
 * @param enso_pipe Enso pipe to prefetch.
 */
void prefetch_pipe(struct RxEnsoPipeInternal* enso_pipe);

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
 * @brief Updates the tx head and the number of TX completions.
 *
 * @param notification_buf_pair Notification buffer to be updated.
 */
void update_tx_head(struct NotificationBufPair* notification_buf_pair);

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
 * @param enso_pipe Enso Pipe to free.
 * @param enso_pipe_id Hardware ID of the Enso Pipe to free.
 */
void enso_pipe_free(struct RxEnsoPipeInternal* enso_pipe,
                    enso_pipe_id_t enso_pipe_id);

/**
 * @brief Frees the notification buffer and all pipes.
 *
 * @deprecated This function is deprecated and will be removed in the future.
 */
int dma_finish(struct SocketInternal* socket_entry);

/**
 * @brief Gets the Enso Pipe ID associated with a given socket.
 *
 * @deprecated This function is deprecated and will be removed in the future.
 */
uint32_t get_enso_pipe_id_from_socket(struct SocketInternal* socket_entry);

/**
 * @brief Prints statistics for a given socket.
 *
 * @deprecated This function is deprecated and will be removed in the future.
 */
void print_stats(struct SocketInternal* socket_entry, bool print_global);

}  // namespace enso

#endif  // SOFTWARE_SRC_PCIE_H_
