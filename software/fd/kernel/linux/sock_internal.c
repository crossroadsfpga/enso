#include "sock_internal.h"
#include "sock_struct.h"
#include "intel_fpga_pcie_setup.h"
#include "sock_errors.h"
#include <linux/types.h>

uint64_t num_kern_socks = 0;
kern_sock_norman_t kern_socks[MAX_KERN_SOCKS];
DEFINE_SPINLOCK(kern_sock_lock);

int kern_create_socket(struct dev_bookkeep *dev, int app_id) {
    int kern_socks_event_flags = 0;
    pcie_block_t *uio_mmap_bar2_addr;
    kern_sock_norman_t *sock;

    if (num_kern_socks >= MAX_KERN_SOCKS) {
	printk(KERN_INFO "too many socks.");
        return -too_many_socks_err;
    }

    // alloc socket struct
    spin_lock_irqsave(&kern_sock_lock, kern_socks_event_flags);
    sock = kern_socks + num_kern_socks;


    // app info
    sock->app_id = app_id; // TODO
    sock->app_thr = current;

    // dsc buf
    printk(KERN_INFO "dsc buf stuff");
    uio_mmap_bar2_addr = dev->bar[2].base_addr;
    sock->uio_data_bar2 = (pcie_block_t *) (
        (uint8_t *)uio_mmap_bar2_addr + app_id * MEMORY_SPACE_PER_APP
        );
    sock->dsc_buf_head = DESC_HEAD_INVALID;

    printk(KERN_INFO "finishing up");
    // finish up
    sock->active = 1;
    sock->sock_id = num_kern_socks;
    num_kern_socks++;
    spin_unlock_irqrestore(&kern_sock_lock, kern_socks_event_flags);

    return sock->sock_id;
}

// socket-app safety check
int kern_verify_socket(struct task_struct *app, uint64_t sock_id) {
    kern_sock_norman_t *s = NULL;
    int ret = 0;
    return ret;
    // TODO retrieve socket
    if (s->sock_id != sock_id) {
        printk(KERN_INFO "sock_id mismatch\n");
        ret = 1;
    }
    if (s->app_thr != app) {
        printk(KERN_INFO "app_thr mismatch\n");
        ret = 1;
    }
    return ret;
}
