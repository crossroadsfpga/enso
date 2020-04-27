
#include <cstring>
#include <iostream>

#include "fd.h"
#include "pcie.h"
#include "api/intel_fpga_pcie_api.hpp"

// TODO(sadok) replace with hash table?
static socket_internal open_sockets[MAX_NB_SOCKETS];
static unsigned int nb_open_sockets = 0;

int socket(int domain __attribute__((unused)), int type __attribute__((unused)),
    int protocol __attribute__((unused)))
{
    intel_fpga_pcie_dev *dev;
    uint16_t bdf = 0;
    int bar = -1;
    int result;

    if (unlikely(nb_open_sockets >= MAX_NB_SOCKETS)) {
        std::cerr << "Maximum number of sockets reached" << std::endl;
        return -1;
    }

    try {
        dev = new intel_fpga_pcie_dev(bdf, bar);
    } catch (const std::exception &ex) {
        std::cerr << "Invalid BDF or BAR!" << std::endl;
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
    result = dma_init(&open_sockets[nb_open_sockets]);

    if (unlikely(result < 0)) {
        std::cerr << "Problem initializing DMA" << std::endl;
        return -1;
    }

    ++nb_open_sockets;

    return 0;
}

int bind(
    int sockfd __attribute__((unused)),
    const struct sockaddr *addr __attribute__((unused)),
    socklen_t addrlen __attribute__((unused))
)
{
    // TODO(sadok) add entry to the NIC flow table

    return 0;
}

ssize_t recv(int sockfd, void *buf, size_t len, int flags __attribute__((unused)))
{
    void* ring_buf;
    socket_internal* socket = &open_sockets[sockfd];
    
    ssize_t bytes_received = dma_run(socket, &ring_buf, len);

    if (unlikely(bytes_received <= 0)) {
        return bytes_received;
    }

    // memcpy(buf, ring_buf, bytes_received);

    advance_ring_buffer(socket);

    return bytes_received;
}

ssize_t recv_zc(int sockfd, void **buf, size_t len, int flags __attribute__((unused)))
{
    return dma_run(&open_sockets[sockfd], buf, len);
}

int shutdown(int sockfd, int how __attribute__((unused)))
{
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

    return 0;
}

void print_reg(int sockfd)
{
    print_fpga_reg(open_sockets[sockfd].dev);
}
