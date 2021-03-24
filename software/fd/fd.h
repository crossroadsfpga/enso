
#ifndef FD_H
#define FD_H

#include <linux/types.h>

#include <arpa/inet.h>

typedef unsigned short sa_family_t;
typedef unsigned int socklen_t;

#define MAX_NB_SOCKETS 16384

int socket(int domain, int type, int protocol);

int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen,
         unsigned nb_queues);

ssize_t recv(int sockfd, void *buf, size_t len, int flags);

ssize_t recv_zc(int sockfd, void **buf, size_t len, int flags);

ssize_t recv_select(int* sockfd, void **buf, size_t len, int flags);

void free_pkt_buf(int sockfd);

// ssize_t recvfrom(int sockfd, void *buf, size_t len, int flags,
//         struct sockaddr *src_addr, socklen_t *addrlen);

int shutdown(int sockfd, int how);

#endif // FD_H
