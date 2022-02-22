
#include <cerrno>
#include <chrono>
#include <csignal>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>
#include <thread>

#include <sched.h>
#include <pthread.h>

// pick one of the two below
#include "norman/socket.h"
// #include <sys/socket.h>
// #include <netinet/in.h>
// #include <arpa/inet.h> 

#define ZERO_COPY

#include "app.h"

#define BUF_LEN 100000

static volatile int keep_running = 1;

void int_handler(int signal __attribute__((unused)))
{
    keep_running = 0;
}

int main(int argc, const char* argv[])
{
    int result;
    uint64_t recv_bytes = 0;
    uint64_t nb_batches = 0;

    if (argc != 5) {
        std::cerr << "Usage: " << argv[0] << " core port nb_queues nb_cycles"
                  << std::endl;
        return 1;
    }

    int core_id = atoi(argv[1]);
    int port = atoi(argv[2]);
    int nb_queues = atoi(argv[3]);
    uint32_t nb_cycles = atoi(argv[4]);

    uint32_t addr_offset = core_id * nb_queues;

    signal(SIGINT, int_handler);

    std::thread socket_thread = std::thread([&recv_bytes, port, addr_offset, 
        nb_queues, &nb_batches, &nb_cycles]
    {
        std::this_thread::sleep_for(std::chrono::seconds(1));

        std::cout << "Running socket on CPU " << sched_getcpu() << std::endl;

        for (int i = 0; i < nb_queues; ++i) {
            // TODO(sadok) can we make this a valid file descriptor?
            std::cout << "creating queue " << i << std::endl;
            int socket_fd = socket(AF_INET, SOCK_DGRAM, nb_queues);

            if (socket_fd == -1) {
                std::cerr << "Problem creating socket (" << errno << "): "
                          << strerror(errno) << std::endl;
                exit(2);
            }

            struct sockaddr_in addr;
            memset(&addr, 0, sizeof(addr));

            uint32_t ip_address = ntohl(inet_addr("192.168.0.0"));
            ip_address += addr_offset + i;

            addr.sin_family = AF_INET;
            addr.sin_addr.s_addr = htonl(ip_address);
            addr.sin_port = htons(port);

            if (bind(socket_fd, (struct sockaddr*) &addr, sizeof(addr))) {
                std::cerr << "Problem binding socket (" << errno << "): "
                          << strerror(errno) <<  std::endl;
                exit(3);
            }
        }

        #ifdef ZERO_COPY
            unsigned char* buf;
        #else
            unsigned char buf[BUF_LEN];
        #endif

        while (keep_running) {
            // HACK(sadok) this only works because socket_fd is incremental, it
            // would not work with an actual file descriptor
            for (int socket_fd = 0; socket_fd < nb_queues; ++socket_fd) {
                #ifdef ZERO_COPY
                    int recv_len = recv_zc(socket_fd, (void**) &buf, BUF_LEN, 0);
                #else
                    int recv_len = recv(socket_fd, buf, BUF_LEN, 0);
                #endif
                if (unlikely(recv_len < 0)) {
                    std::cerr << "Error receiving" << std::endl;
                    exit(4);
                }
                // ensuring that we are modifying every cache line
                for (uint32_t i = 0; i < ((uint32_t) recv_len) / 64; ++i) {
                    ++buf[i*64 + 63];
                }
                for (uint32_t i = 0; i < nb_cycles; ++i) {
                    asm("nop");
                }
                if (recv_len > 0) {
                    ++nb_batches;
                    #ifdef ZERO_COPY
                    free_pkt_buf(socket_fd, recv_len);
                    #endif
                }
                recv_bytes += recv_len;
            }
        }

        // TODO(sadok) it is also common to use the close() syscall to close a
        // UDP socket
        for (int socket_fd = 0; socket_fd < nb_queues; ++socket_fd) {
            shutdown(socket_fd, SHUT_RDWR);
        }
    });

    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(core_id, &cpuset);
    result = pthread_setaffinity_np(socket_thread.native_handle(),
                                    sizeof(cpuset), &cpuset);
    if (result < 0) {
        std::cerr << "Error setting CPU affinity" << std::endl;
        return 6;
    }

    while (keep_running) {
        uint64_t recv_bytes_before = recv_bytes;
        std::this_thread::sleep_for(std::chrono::seconds(1));
        std::cout << std::dec << "Goodput: " << 
            ((double) recv_bytes - recv_bytes_before) * 8. /1e6
            << " Mbps  #bytes: " << recv_bytes << "  #batches: " << nb_batches
            << std::endl;
    }

    socket_thread.join();

    return 0;
}
