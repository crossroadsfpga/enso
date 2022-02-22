
#include <cstring>
#include <iostream>

#include "socket.h"
#include "pcie.h"
#include "api/intel_fpga_pcie_api.hpp"


static dsc_queue_t dsc_queue [MAX_NB_CORES];

// TODO(sadok) replace with hash table?
static socket_internal open_sockets[MAX_NB_SOCKETS];
static unsigned int nb_open_sockets = 0;

int socket(int domain __attribute__((unused)), int type __attribute__((unused)),
           int nb_queues) noexcept // HACK(sadok) using protocol as nb_queues
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
        std::cerr << "Error initializing: " << ex.what() << std::endl;
        return -1;
    }

    result = dev->use_cmd(true);
    if (unlikely(result == 0)) {
        std::cerr << "Could not switch to CMD use mode!" << std::endl;
        return -1;
    }

    // FIXME(sadok) use __sync_fetch_and_add to update atomically
    unsigned int socket_id = nb_open_sockets++;

    open_sockets[socket_id].dev = dev;
    open_sockets[socket_id].dsc_queue = &dsc_queue[sched_getcpu()];

    result = dma_init(&open_sockets[socket_id], socket_id, nb_queues);

    if (unlikely(result < 0)) {
        std::cerr << "Problem initializing DMA" << std::endl;
        return -1;
    }

    return socket_id;
}

int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen) noexcept
{
    (void) addrlen;  // Avoid unused warnings.
    socket_internal* socket = &open_sockets[sockfd];
    sockaddr_in* addr_in = (sockaddr_in*) addr;

    uint32_t pkt_queue_id = get_pkt_queue_id_from_socket(socket);

    // TODO(sadok): insert flow entry from kernel.
    insert_flow_entry(
        socket->dsc_queue,
        ntohs(addr_in->sin_port),
        0,
        ntohl(addr_in->sin_addr.s_addr),
        0,
        0x11, // TODO(sadok): support protocols other than UDP.
        pkt_queue_id
    );

    return 0;
}

/*
 * Return physical address of the buffer associated with the socket.
 */
uint64_t get_socket_phys_addr(int sockfd)
{
    return open_sockets[sockfd].pkt_queue.buf_phys_addr;
}

/*
 * Return virtual address of the buffer associated with the socket.
 */
void* get_socket_virt_addr(int sockfd)
{
    return (void*) open_sockets[sockfd].pkt_queue.buf;
}

/*
 * Convert a socket buffer virtual address to physical address.
 */
uint64_t convert_buf_addr_to_phys(int sockfd, void* addr)
{
    return (uint64_t) addr + open_sockets[sockfd].pkt_queue.phys_buf_offset;
}

ssize_t recv(int sockfd, void *buf, size_t len,
             int flags __attribute__((unused)))
{
    void* ring_buf;
    socket_internal* socket = &open_sockets[sockfd];
    
    ssize_t bytes_received = get_next_batch_from_queue(socket, &ring_buf, len);

    if (unlikely(bytes_received <= 0)) {
        return bytes_received;
    }

    memcpy(buf, ring_buf, bytes_received);

    advance_ring_buffer(socket, bytes_received);

    return bytes_received;
}

ssize_t recv_zc(int sockfd, void **buf, size_t len,
                int flags __attribute__((unused)))
{
    return get_next_batch_from_queue(&open_sockets[sockfd], buf, len);
}

ssize_t recv_select(int ref_sockfd, int* sockfd, void **buf, size_t len,
                    int flags __attribute__((unused)))
{
    dsc_queue_t* dsc_queue = open_sockets[ref_sockfd].dsc_queue;
    return get_next_batch(dsc_queue, open_sockets, sockfd, buf, len);
}

ssize_t send(int sockfd, void *phys_addr, size_t len,
             int flags __attribute__((unused)))
{
    return send_to_queue(open_sockets[sockfd].dsc_queue, phys_addr, len);
}

uint32_t get_completions(int ref_sockfd)
{
    dsc_queue_t* dsc_queue = open_sockets[ref_sockfd].dsc_queue;
    return get_unreported_completions(dsc_queue);
}

void free_pkt_buf(int sockfd, size_t len)
{
    advance_ring_buffer(&open_sockets[sockfd], len);
}

int enable_device_timestamp()
{
    if (nb_open_sockets == 0) {
        return -2;
    }
    return enable_timestamp(open_sockets[0].dsc_queue);
}

int disable_device_timestamp()
{
    if (nb_open_sockets == 0) {
        return -2;
    }
    return disable_timestamp(open_sockets[0].dsc_queue);
}

int enable_device_rate_limit(uint16_t num, uint16_t den)
{
    if (nb_open_sockets == 0) {
        return -2;
    }
    return enable_rate_limit(open_sockets[0].dsc_queue, num, den);
}

int disable_device_rate_limit()
{
    if (nb_open_sockets == 0) {
        return -2;
    }
    return disable_rate_limit(open_sockets[0].dsc_queue);
}

int shutdown(int sockfd, int how __attribute__((unused))) noexcept
{
    int result;
    intel_fpga_pcie_dev *dev = open_sockets[sockfd].dev;
    
    result = dma_finish(&open_sockets[sockfd]);
    result = dev->use_cmd(false);

    if (unlikely(result == 0)) {
        std::cerr << "Could not switch to CMD use mode!\n";
        return -1;
    }

    --nb_open_sockets;

    // TODO(sadok) remove entry from the NIC flow table

    delete dev;

    return 0;
}

void print_sock_stats(int sockfd) {
    socket_internal* socket = &open_sockets[sockfd];
    print_stats(socket, socket->queue_id == 0);
}
