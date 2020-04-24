
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
#include "fd/fd.h"
// #include <sys/socket.h>
// #include <netinet/in.h>

#include "app.h"

#define BUF_LEN 10000

#define likely(x)       __builtin_expect((x),1)
#define unlikely(x)     __builtin_expect((x),0)

static volatile int keep_running = 1;

void int_handler(int signal __attribute__((unused)))
{
    keep_running = 0;
}

int main(int argc, const char* argv[])
{
    int result;

    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " core"
                  << std::endl;
        return 1;
    }
    
    std::thread socket_thread = std::thread([] {
        std::this_thread::sleep_for(std::chrono::seconds(1));

        std::cout << "Running socket on CPU " << sched_getcpu() << std::endl;
        // TODO(sadok) can we make this a valid file descriptor?
        int socket_fd = socket(AF_INET, SOCK_DGRAM, 0);

        if (socket_fd == -1) {
            std::cerr << "Problem creating socket" << std::endl;
            exit(2);
        }

        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));

        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(INADDR_ANY);
        addr.sin_port = htons(8080);

        if (bind(socket_fd, (struct sockaddr*) &addr, sizeof(addr))) {
            std::cerr << "Problem binding socket" << std::endl;
            exit(3);
        }

        unsigned char buf[BUF_LEN];

        while (keep_running) {
            auto now = std::chrono::steady_clock::now();
            uint64_t total_bytes = 0;
            while ((std::chrono::steady_clock::now() - now) 
                    < std::chrono::seconds(1))
            {
                // this is equivalent to read()
                int recv_len = recv(socket_fd, buf, BUF_LEN, 0);
                std::this_thread::sleep_for(std::chrono::milliseconds(500));
                if (unlikely(recv_len < 0)) {
                    std::cerr << "Error receiving" << std::endl;
                    exit(4);
                }
                total_bytes += recv_len;
                // do something with the buffer? XOR?
            }
            print_reg(socket_fd);
            std::cout << "Goodput: " << total_bytes * 8 << " bps" << std::endl;
        }
        // TODO(sadok) it is also common to use the close() syscall to close a
        // UDP socket
        shutdown(socket_fd, SHUT_RDWR);
    });

    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(atoi(argv[1]), &cpuset);
    result = pthread_setaffinity_np(socket_thread.native_handle(),
                                    sizeof(cpuset), &cpuset);
    if (result < 0) {
        std::cerr << "Error setting CPU affinity" << std::endl;
        return 6;
    }

    socket_thread.join();

    return 0;
}
