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
 * @brief Socket-like API.
 * @deprecated Use the API defined in `pipe.h` instead.
 *
 * @author Hugo Sadok <sadok@cmu.edu>
 */

#ifndef SOFTWARE_INCLUDE_ENSO_SOCKET_H_
#define SOFTWARE_INCLUDE_ENSO_SOCKET_H_

#include <arpa/inet.h>
#include <enso/consts.h>
#include <linux/types.h>

namespace enso {

typedef unsigned short sa_family_t;
typedef unsigned int socklen_t;

#define MAX_NB_CORES 128
#define MAX_NB_SOCKETS MAX_NB_FLOWS

void set_bdf(uint16_t bdf_);

int socket(int domain, int type, int protocol, bool fallback) noexcept;

int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen) noexcept;

uint64_t get_socket_phys_addr(int sockfd);

void *get_socket_virt_addr(int sockfd);

uint64_t convert_buf_addr_to_phys(int sockfd, void *addr);

int shutdown(int sockfd, int how) noexcept;

/*
 * Receives packets using a POSIX-like interface. Here *buf is the address to a
 * buffer allocated by the user. The function will copy the received data to
 * this buffer.
 */
ssize_t recv(int sockfd, void *buf, size_t len, int flags);

ssize_t recv_zc(int sockfd, void **buf, size_t len, int flags);

ssize_t recv_select(int ref_sockfd, int *sockfd, void **buf, size_t len,
                    int flags);

/*
 * Send the bytes pointed by address `phys_addr` through the `sockfd` socket.
 * There are two important differences to a traditional POSIX `send`:
 * - Memory must be pinned (phys_addr needs to be a physical address);
 * - It is not safe to change the buffer content until the transmission is done.
 *
 * This function blocks until it can send but returns before the transmission is
 * over. To figure out when the transmission is over, use the `get_completions`
 * function.
 */
ssize_t send(int sockfd, uint64_t phys_addr, size_t len, int flags);

/*
 * Return the number of transmission requests that were completed since the last
 * call to this function. Since transmissions are always completed in order, one
 * can figure out which transmissions were completed by keeping track of all the
 * calls to `send`. There can be only up to `kMaxPendingTxRequests` requests
 * completed between two calls to `send`. However, if `send` is called multiple
 * times, without calling `get_completions` the number of completed requests can
 * surpass `kMaxPendingTxRequests`.
 */
uint32_t get_completions(int ref_sockfd);

/*
 * Enable hardware timestamping for the device. This applies to all sockets.
 */
int enable_device_timestamp(int ref_sockfd, uint8_t offset = kDefaultRttOffset);

/*
 * Disable hardware timestamping for the device. This applies to all sockets.
 */
int disable_device_timestamp(int ref_sockfd);

/*
 * Enable hardware rate limit for the device. This applies to all sockets.
 */
int enable_device_rate_limit(int ref_sockfd, uint16_t num, uint16_t den);

/*
 * Disable hardware rate limit for the device. This applies to all sockets.
 */
int disable_device_rate_limit(int ref_sockfd);

/*
 * Enable round robin for the device. This applies to all sockets.
 */
int enable_device_round_robin(int ref_sockfd);

/*
 * Disable round robin for the device. This applies to all sockets.
 */
int disable_device_round_robin(int ref_sockfd);

/*
 * Free packet buffer. Use this to free received packets.
 */
void free_enso_pipe(int sockfd, size_t len);

void print_sock_stats(int sockfd);

}  // namespace enso

#endif  // SOFTWARE_INCLUDE_ENSO_SOCKET_H_
