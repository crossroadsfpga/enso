
#ifndef FD_H
#define FD_H

#include <linux/types.h>

#include <arpa/inet.h>

#include "pcie.h"

typedef unsigned short sa_family_t;
typedef unsigned int socklen_t;

#define MAX_NB_SOCKETS 16384
#define MAX_PENDING_TX_REQUESTS (DSC_BUF_SIZE-1)

int socket(int domain, int type, int protocol) noexcept;

int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen,
         unsigned nb_queues);

uint64_t get_socket_phys_addr(int sockfd);

void* get_socket_virt_addr(int sockfd);

uint64_t convert_buf_addr_to_phys(int sockfd, void* addr);

ssize_t recv(int sockfd, void *buf, size_t len, int flags);

ssize_t recv_zc(int sockfd, void **buf, size_t len, int flags);

ssize_t recv_select(int* sockfd, void **buf, size_t len, int flags);

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
ssize_t send(int sockfd, void *phys_addr, size_t len, int flags);

/*
 * Return the number of transmission requests that were completed since the last
 * call to this function. Since transmissions are always completed in order, one
 * can figure out which transmissions were completed by keeping track of all the
 * calls to `send`. There can be only up to `MAX_PENDING_TX_REQUESTS` requests
 * completed between two calls to `send`. However, if `send` is called multiple
 * times, without calling `get_completions` the number of completed requests can
 * surpass `MAX_PENDING_TX_REQUESTS`.
 */
int get_completions();

void free_pkt_buf(int sockfd, size_t len);

// ssize_t recvfrom(int sockfd, void *buf, size_t len, int flags,
//         struct sockaddr *src_addr, socklen_t *addrlen);

int shutdown(int sockfd, int how) noexcept;

void print_sock_stats(int sockfd);

#endif // FD_H
