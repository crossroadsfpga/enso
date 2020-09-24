#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdio.h>

int main()
{
        int fd = open("/dev/intel_fpga_pcie_drv", O_RDONLY | O_CLOEXEC);
        printf("my fd: %d\n", fd);
        int queue1 = fsync(fd);
        printf("my queue1: %d\n", queue1);

        int waited = 0;
        char thing[10000] = {0};
        int i;

        for(i = 0; i < 5; i++) {
            int waited = read(fd, &thing, waited);
            printf("i have %d events pending!\n", waited);
            sleep(3);
        }
        return 0;
}

