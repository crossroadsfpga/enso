/* use a single socket and dispatch to other cores */
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

#define BUF_LEN (1024*128)
#define CACHE_LINE_SIZE 64

static volatile int keep_running = 1;

struct rb_state {
    uint32_t head;
    uint32_t tail __attribute__((aligned(CACHE_LINE_SIZE)));
};

void int_handler(int signal __attribute__((unused)))
{
    keep_running = 0;
}

int main(int argc, const char* argv[])
{
    int result;
    uint64_t recv_bytes = 0;
    uint64_t nb_pkts = 0;

    if (argc != 3) {
        std::cerr << "Usage: " << argv[0] << " nb_cores port"
                  << std::endl;
        return 1;
    }

    unsigned nb_cores = atoi(argv[1]);
    int port = atoi(argv[2]);

    std::thread listeners[nb_cores];
    uint64_t* buffers[nb_cores];
    struct rb_state* rb_states;

    if (posix_memalign((void**) &rb_states, CACHE_LINE_SIZE,
                       nb_cores * sizeof(struct rb_state))) {
        std::cerr << "Error allocating buffers" << std::endl;
        exit(1);
    }
    for (uint32_t i = 0; i < nb_cores; ++i) {
        if (posix_memalign((void**) &buffers[i], CACHE_LINE_SIZE, BUF_LEN)) {
            std::cerr << "Error allocating buffers" << std::endl;
             exit(1);
        }
        rb_states[i].head = 0;
        rb_states[i].tail = 0;
    }
    
    std::thread socket_thread = std::thread(
        [&recv_bytes, port, &nb_pkts, rb_states, &buffers, nb_cores]
        {
            std::this_thread::sleep_for(std::chrono::seconds(1));

            std::cout << "Running socket on CPU " << sched_getcpu() 
                      << std::endl;

            // TODO(sadok) can we make this a valid file descriptor?
            int socket_fd = socket(AF_INET, SOCK_DGRAM, 1);

            if (socket_fd == -1) {
                std::cerr << "Problem creating socket (" << errno << "): "
                          << strerror(errno) << std::endl;
                exit(2);
            }

            struct sockaddr_in addr;
            memset(&addr, 0, sizeof(addr));

            addr.sin_family = AF_INET;
            addr.sin_addr.s_addr = inet_addr("192.168.0.0");
            addr.sin_port = htons(port);

            if (bind(socket_fd, (struct sockaddr*) &addr, sizeof(addr))) {
                std::cerr << "Problem binding socket (" << errno << "): "
                          << strerror(errno) <<  std::endl;
                exit(3);
            }

            #ifdef ZERO_COPY
                unsigned char* buf;
            #else
                unsigned char buf[BUF_LEN];
            #endif

            while (keep_running) {
                #ifdef ZERO_COPY
                    int recv_len = recv_zc(socket_fd, (void**) &buf, BUF_LEN,
                                           0);
                #else
                    int recv_len = recv(socket_fd, buf, BUF_LEN, 0);
                #endif
                if (unlikely(recv_len < 0)) {
                    std::cerr << "Error receiving" << std::endl;
                    exit(4);
                }
                if (recv_len > 0) {
                    ++nb_pkts;

                    // use last byte of src IP addr to determine buffer
                    // Ethernet header: 14 bytes
                    // SRC IP offset: 12 bytes
                    // Last byte of IP: 3 bytes
                    uint8_t buf_idx = ((uint8_t*) buf)[29];
                    // FIXME(sadok) must do this for every packet
                    uint32_t occup_space;
                    uint32_t my_head = rb_states[buf_idx].head;
                    do {
                        occup_space = (rb_states[buf_idx].head - 
                                    rb_states[buf_idx].tail) % BUF_LEN;
                    } while ((BUF_LEN - occup_space - 1) < (uint32_t) recv_len);
                    // must always have at least one empty spot

                    // HACK(sadok) recv_len must be aligned to 8 bytes
                    for (uint32_t i = 0; i < ((uint32_t) recv_len)/8; i++) {
                        buffers[buf_idx][my_head/8+i] = *((uint64_t*) buf + i);
                    }
                    if (occup_space > 64*128) {
                        asm volatile ("" : : : "memory"); // compiler memory barrier
                        rb_states[buf_idx].head = (my_head + recv_len) % BUF_LEN;
                    }
                    #ifdef ZERO_COPY
                        free_pkt_buf(socket_fd, recv_len);
                    #endif
                }
                recv_bytes += recv_len;
        }

        // TODO(sadok) it is also common to use the close() syscall to close a
        // UDP socket
        shutdown(socket_fd, SHUT_RDWR);

        // free buffers
        for (uint32_t i = 0; i < nb_cores; ++i) {
            free(buffers[i]);
        }
        free(rb_states);
    });

    for (uint32_t i = 0; i < nb_cores; ++i) {
        listeners[i] = std::thread(
            [](uint64_t* buffer, uint32_t* head, uint32_t* tail) {
                while (keep_running) {
                    uint32_t my_head = *head;
                    if (my_head == *tail) {
                        continue;
                    }
                    // touch data
                    buffer[my_head/64] += 1;
                    *tail = my_head;
                }
            },
            buffers[i],
            &(rb_states[i].head),
            &(rb_states[i].tail)
        );
    }

    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(0, &cpuset);
    result = pthread_setaffinity_np(socket_thread.native_handle(),
                                    sizeof(cpuset), &cpuset);
    if (result < 0) {
        std::cerr << "Error setting CPU affinity" << std::endl;
        return 6;
    }

    for (uint32_t i = 0; i < nb_cores; ++i) {
        CPU_ZERO(&cpuset);
        CPU_SET(i+1, &cpuset);
        result = pthread_setaffinity_np(listeners[i].native_handle(),
                                        sizeof(cpuset), &cpuset);
        if (result < 0) {
            std::cerr << "Error setting CPU affinity" << std::endl;
            return 6;
        }
    }

    while (keep_running) {
        uint64_t recv_bytes_before = recv_bytes;
        std::this_thread::sleep_for(std::chrono::seconds(1));
        std::cout << std::dec << "Goodput: " << 
            ((double) recv_bytes - recv_bytes_before) * 8. /1e6
            << " Mbps  #pkts: " << nb_pkts << std::endl;
    }

    socket_thread.join();

    return 0;
}
