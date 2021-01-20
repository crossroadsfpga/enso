
#ifndef FD_H
#define FD_H

#include <linux/types.h>

#include <arpa/inet.h>

typedef unsigned short sa_family_t;
typedef unsigned int socklen_t;

#define MAX_NB_SOCKETS 100 // TODO(sadok) support more than 100

int norman_socket(int domain, int type, int protocol);

int norman_bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);

int setsockopt(int sockfd, int level, int optname, const void *optval,
        socklen_t optlen);

ssize_t norman_recvfrom(int sockfd, void *buf, size_t len, int flags,
         struct sockaddr *src_addr, socklen_t *addrlen);

int shutdown(int sockfd, int how);

void print_reg(int sockfd);

#endif // FD_H
