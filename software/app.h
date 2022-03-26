
#ifndef APP_H
#define APP_H

#define likely(x)       __builtin_expect((x),1)
#define unlikely(x)     __builtin_expect((x),0)
typedef struct {
    int socket_fd;
    size_t length;
} tx_pending_request_t;

#define BUF_LEN 10000000
// #define BUF_LEN 100000

#endif // APP_H
