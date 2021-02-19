
#ifndef FD_H
#define FD_H

#include <linux/types.h>

#include <arpa/inet.h>

typedef unsigned short sa_family_t;
typedef unsigned int socklen_t;

#define MAX_NB_SOCKETS 16384

extern int norman_socket(int domain, int type, int protocol);

extern int norman_bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen,
         unsigned nb_queues);

extern ssize_t norman_recv(int sockfd, void *buf, size_t len, int flags);

extern ssize_t norman_recv_zc(int sockfd, void **buf, size_t len, int flags);

extern void norman_free_pkt_buf(int sockfd);

// ssize_t recvfrom(int sockfd, void *buf, size_t len, int flags,
//         struct sockaddr *src_addr, socklen_t *addrlen);

extern int norman_shutdown(int sockfd, int how);

extern void print_reg(int sockfd);

#endif // FD_H
