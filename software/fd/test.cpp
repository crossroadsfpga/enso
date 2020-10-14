#include <fcntl.h>
#include <stdio.h>
#include <sys/epoll.h>
#include <sys/eventfd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include "api/intel_fpga_pcie_api.hpp"

int main()
{
        int epfd = epoll_create(EPOLL_CLOEXEC);
        if (epfd < 0) {
            printf("epoll_create failed\n");
        }

        int fd0 = eventfd(0, EFD_CLOEXEC);
        if (fd0 < 0) {
            printf("eventfd failed\n");
        }

        struct epoll_event e_fd;
        e_fd.events = EPOLLIN;
        e_fd.data.fd = fd0;

        if (epoll_ctl(epfd, EPOLL_CTL_ADD, fd0, &e_fd) < 0) {
            printf("epoll_ctl failed\n");
        }

        int device_fd = open("/dev/intel_fpga_pcie_drv", O_RDWR | O_CLOEXEC);
        if (device_fd < 0) {
            printf("open failed\n");
        }
        printf("device fd: %d\n", device_fd);

        int queue1 = ioctl(device_fd, INTEL_FPGA_PCIE_IOCTL_GET_QUEUE, fd0);
        printf("my queue1: %d\n", queue1);

        int waited = 0;
        char thing[10000] = {0};
        int i;

        printf("lets start\n");
        int timeout = 500;
        int maxevents = 10;
        for(i = 0; i < 5; i++) {
            int waited = epoll_wait(epfd, &e_fd, maxevents, timeout);
            printf("hi! pending: %d\n", waited);
            sleep(3);
        }
        printf("done\n");
        // TODO: something to close the fds and cleanup
        return 0;
}

