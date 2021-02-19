
#include <cstring>
#include <iostream>
#include <assert.h>

#include "fd.h"
#include "pcie.h"
#include "api/intel_fpga_pcie_api.hpp"

// TODO(sadok) replace with hash table?
static socket_internal open_sockets[MAX_NB_SOCKETS];
static unsigned int nb_open_sockets = 0;
static int init = 0;

int norman_socket(int domain __attribute__((unused)), int type __attribute__((unused)),
    int nb_queues) // HACK(sadok) using protocol as nb_queues
{
    intel_fpga_pcie_dev *dev;
    uint16_t bdf = 0;
    int bar = -1;
    int result;
    int sock_id = -1;;

    // TODO (soup) check init atomically
    if (unlikely(!init)) {
        for (int queue_id = 0; queue_id < MAX_NB_SOCKETS; queue_id++) {
            open_sockets[queue_id].active = false;
        }
        init = 1;
    }

    if (unlikely(nb_open_sockets >= MAX_NB_SOCKETS)) {
        std::cerr << "Maximum number of sockets reached" << std::endl;
        return -1;
    }

    try {
        dev = new intel_fpga_pcie_dev(bdf, bar);
    } catch (const std::exception &ex) {
        std::cerr << "Error initializing: " << ex.what() << std::endl;
        return -1;
    }
    std::cout << std::hex << std::showbase;
    std::cout << "Opened a handle to BAR " << dev->get_bar();
    std::cout << " of a device with BDF " << dev->get_dev() << std::endl;

    result = dev->use_cmd(true);
    if (unlikely(result == 0)) {
        std::cerr << "Could not switch to CMD use mode!" << std::endl;
        return -1;
    }

    open_sockets[nb_open_sockets].dev = dev;
    ssize_t fd = open("/dev/intel_fpga_pcie_drv", O_RDWR | O_CLOEXEC);
    open_sockets[nb_open_sockets].fd = fd;
    sock_id = ioctl(fd, INTEL_FPGA_PCIE_IOCTL_CREATE_SOCK, nb_open_sockets);
    assert(sock_id == (int) nb_open_sockets);

    result = dma_init(&open_sockets[nb_open_sockets], nb_open_sockets, nb_queues);

    if (unlikely(result < 0)) {
        std::cerr << "Problem initializing DMA" << std::endl;
        return -1;
    }

    // TODO: make inc atomic
    nb_open_sockets++;
    return sock_id;
}

int norman_bind(
    int sockfd,
    const struct sockaddr *addr __attribute__((unused)),
    socklen_t addrlen, // HACK(sadok) specifying number of rules
    unsigned nb_queues // HACK(sadok) should not have this last argument in the
                       //             bind call
)
{
    socket_internal* socket = &open_sockets[sockfd];

    // FIXME(sadok) we currently only bind sockets on app 0
    if (socket->app_id != 0) {
        std::cerr << "not sending control message" << std::endl;
        return 0;
    }

    #ifdef CONTROL_MSG
    unsigned nb_rules = addrlen;
    if (send_control_message(socket, nb_rules, nb_queues)) {
        std::cerr << "Could not send control message" << std::endl;
        return -1;
    }
    #else
    (void) addrlen;// avoid unused parameter warning
    (void) nb_queues;
    #endif

    return 0;
}

ssize_t norman_recv(int sockfd, void *buf, size_t len, int flags __attribute__((unused)))
{
    void* ring_buf;
    socket_internal* socket = &open_sockets[sockfd];

    ssize_t bytes_received = dma_run(socket, &ring_buf, len);

    if (unlikely(bytes_received <= 0)) {
        return bytes_received;
    }

    memcpy(buf, ring_buf, bytes_received);

    advance_ring_buffer(socket);

    return bytes_received;
}

ssize_t norman_recv_zc(int sockfd, void **buf, size_t len, int flags __attribute__((unused)))
{
    return dma_run(&open_sockets[sockfd], buf, len);
}

void norman_free_pkt_buf(int sockfd)
{
    advance_ring_buffer(&open_sockets[sockfd]);
}

int norman_shutdown(int sockfd, int how __attribute__((unused)))
{
    int result;
    intel_fpga_pcie_dev *dev = open_sockets[sockfd].dev;

    result = dma_finish(&open_sockets[sockfd]);
    result = dev->use_cmd(false);

    close(open_sockets[sockfd].fd);

    if (unlikely(result == 0)) {
        std::cerr << "Could not switch to CMD use mode!\n";
        return -1;
    }

    // TODO(sadok) remove entry from the NIC flow table

    delete dev;

    return 0;
}

void print_reg(int sockfd)
{
    print_fpga_reg(open_sockets[sockfd].dev);
}
