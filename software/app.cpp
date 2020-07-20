
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
#include "fd/fd.h"
// #include <sys/socket.h>
// #include <netinet/in.h>
// #include <arpa/inet.h> 

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
    uint64_t goodput = 0;

    if (argc != 4) {
        std::cerr << "Usage: " << argv[0] << " core port nb_rules"
                  << std::endl;
        return 1;
    }

    int port = atoi(argv[2]);
    unsigned nb_rules = atoi(argv[3]);

    std::cout << "running test with " << nb_rules << " rules" << std::endl;
    
    std::thread socket_thread = std::thread([&goodput, port, nb_rules] {
        std::this_thread::sleep_for(std::chrono::seconds(1));

        std::cout << "Running socket on CPU " << sched_getcpu() << std::endl;
        // TODO(sadok) can we make this a valid file descriptor?
        int socket_fd = socket(AF_INET, SOCK_DGRAM, 0);

        if (socket_fd == -1) {
            std::cerr << "Problem creating socket (" << errno << "): " << strerror(errno) << std::endl;
            exit(2);
        }

        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));

        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = inet_addr("10.0.0.2"); // htonl(INADDR_ANY);
        addr.sin_port = htons(port);

        if (bind(socket_fd, (struct sockaddr*) &addr, nb_rules)) {
            std::cerr << "Problem binding socket (" << errno << "): " << strerror(errno) <<  std::endl;
            exit(3);
        }

        unsigned char buf[BUF_LEN];

        while (keep_running) {
            int recv_len = recv(socket_fd, buf, BUF_LEN, 0);
            if (unlikely(recv_len < 0)) {
                std::cerr << "Error receiving" << std::endl;
                exit(4);
            }
            goodput += recv_len;
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

    while (keep_running) {
        goodput = 0;
        std::this_thread::sleep_for(std::chrono::seconds(1));
        std::cout << std::dec << "Goodput: " << ((double) goodput) * 8. /1e6
                  << " Mbps" << std::endl;
    }

    socket_thread.join();

    return 0;
}
