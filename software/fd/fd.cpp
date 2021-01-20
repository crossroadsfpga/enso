#include <assert.h>
#include <cstring>
#include <sys/epoll.h>
#include <sys/eventfd.h>
#include <iostream>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "fd.h"
#include "pcie.h"
#include "api/intel_fpga_pcie_api.hpp"

// #define GLOB

// TODO(sadok) replace with hash table?
static socket_internal open_sockets[MAX_NB_SOCKETS];
static unsigned int nb_open_sockets = 0;

#ifdef GLOB
static int glob_epfd = -1;
// TODO add locks for multi-threaded applications
static uint32_t epoll_results = 0; // mask for whether event availability
#endif

// TODO do i need multiple?
static int device_fd = -1;
static int buf_fd = -1;

char *p = NULL;
char buff[64];

int norman_socket(int domain __attribute__((unused)), int type __attribute__((unused)),
    int nb_queues) // HACK(sadok) using protocol as nb_queues
{
    struct epoll_event e_event;
    int epfd = -1;
    int queue = -1;
    int ret = 0;

    if (unlikely(nb_open_sockets >= MAX_NB_SOCKETS)) {
        std::cerr << "Maximum number of sockets reached" << std::endl;
        return -1;
    }

    if (device_fd < 0) {
        device_fd = open("/dev/intel_fpga_pcie_drv", O_RDWR | O_CLOEXEC);
        if (device_fd < 0) {
            std::cerr << "Failed to open device fd" << std::endl;
            return -1;
        }
    }
    open_sockets[nb_open_sockets].device_fd = device_fd;

    if (buf_fd < 0) {
        buf_fd = open("/dev/mchar", O_RDWR|O_NDELAY);
        if (buf_fd < 0) {
            return -1;
        }
    }

    p = (char *)mmap(0, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, buf_fd, 0);
    munmap(p, 4096);
    close(buf_fd);

#ifdef GLOB
    if (glob_epfd < 0) {
        epfd = epoll_create(EPOLL_CLOEXEC);
        if (epfd < 0) {
            std::cerr << "Failed to create glob epfd" << std::endl;
            return -1;
        }
    }
#else
    epfd = epoll_create(EPOLL_CLOEXEC);
    if (epfd < 0) {
        std::cerr << "Failed to create sock epfd" << std::endl;
        return -1;
    }
#endif
    open_sockets[nb_open_sockets].epfd = epfd;

    int efd = eventfd(0, EFD_CLOEXEC);
    if (efd < 0) {
        std::cerr << "Failed to create event fd" << std::endl;
        return -1;
    }
    open_sockets[nb_open_sockets].efd = efd;

    e_event.events = EPOLLIN;
    e_event.data.fd = efd; // is this right? TODO (this cld be better)

    if (epoll_ctl(epfd, EPOLL_CTL_ADD, efd, &e_event) < 0) {
        std::cerr << "epoll_ctl failed" << std::endl;
        return -1;
    }

    queue = ioctl(device_fd, INTEL_FPGA_PCIE_IOCTL_GET_QUEUE, efd);
    if (queue < 0) {
        std::cerr << "ioctl get queue failed" << std::endl;
        return -1;
    }

    // set up DMA bufferasdf

    return nb_open_sockets++;
}

// associate with port
int norman_bind(
    int sockfd,
    const struct sockaddr *addr __attribute__((unused)),
    socklen_t addrlen // HACK(sadok) specifying number of rules
)
{
    socket_internal* socket = &open_sockets[sockfd];

    return 0;
}

int setsockopt(int sockfd, int level, int optname, const void *optval,
               socklen_t optlen)
{
    // TODO (soup)
    return 0;
}

ssize_t norman_recvfrom(int sockfd, void *buffer, size_t length, int flags,
        struct sockaddr *address, socklen_t *address_len)
{
    int epfd = open_sockets[sockfd].epfd;
    int efd = open_sockets[sockfd].efd;
    int maxevents = 10;
    struct epoll_event events[maxevents];
    int timeout = 10; // ms
    int ret = 0;
    int buff_fd = -1;

#ifndef GLOB
    int epoll_results = 0;
#endif

    // not allowing peeks/oob/waitall yet
    assert(flags == 0);

    // emulating old socket behavior (change epfd to per-socket for best)
    while ((epoll_results & (1 << efd)) == 0) {
        int fds = epoll_wait(epfd, events, maxevents, timeout);
        for (int i = 0; i < fds; i++) {
            epoll_results |= (1 << events[i].data.fd);
        }
    }

    epoll_results &= ~(1 << efd); // race! TODO (instead of fd, use #pck?)


    // TODO now read from dma buffer and put something into buffer
    buff_fd = open("/dev/mchar", O_RDWR | O_NDELAY);
    ret = read(buff_fd, buff, 1);
    if (ret < 0) {
        printf("read error!\n");
        ret = errno;
        return ret;
    }
    while (buff[0] == 1) {
        printf("1");
        buff[0] = 0;
        ret = read(buff_fd, buff, 1);
        if (ret < 0) {
            printf("read error!\n");
            ret = errno;
            return ret;
        }
        ret = write(buff_fd, "\0", strlen("\0"));
        if (ret < 0) {
            printf("write error!\n");
            ret = errno;
            return ret;
        }
    }
    printf("%d\n", buff[0]);
    close(buff_fd); // TODO do i need to keep open/closing this? (soup)
    return 0;
}

int shutdown(int sockfd, int how __attribute__((unused)))
{
    /*
    int result;
    intel_fpga_pcie_dev *dev = open_sockets[sockfd].dev;

    result = dma_finish(&open_sockets[sockfd]);

    result = dev->use_cmd(false);

    if (unlikely(result == 0)) {
        std::cerr << "Could not switch to CMD use mode!\n";
        return -1;
    }

    // TODO(sadok) remove entry from the NIC flow table

    delete dev;
    */

    return 0;
}
