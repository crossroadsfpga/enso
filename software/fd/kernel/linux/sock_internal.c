#include "sock_internal.h"

int kern_create_socket(void) {
    // alloc socket struct
    spin_lock_irqsave(&kern_sock_lock, kern_socks_event_flags);
    kern_sock_norman_t *sock = kern_socks + num_kern_socks;

    // alloc packet desc buf
    sock->dsc_buf = dsc_bufs + num_dsc_bufs;
    num_dsc_bufs++;

    // alloc packet buf
    sock->pkt_buf = pkt_bufs + num_pkt_bufs;
    num_pkt_bufs++;

    // app info
    sock->app_id = 0; // TODO where does this come from??
    sock->app_thr = current;
    sock->uio_data_bar2 = NULL; // TODO where does this come from??
    // TODO figure out how reading packets from kernel works

    // finish up
    sock->active = 1;
    sock->sock_id = num_kern_socks;
    num_kern_socks++;
    spin_unlock_irqrestore(&kern_sock_log, kern_socks_event_flags);

    return sock->sock_id;
}

// socket-app safety check
int kern_verify_socket(struct tast_struct *app, uint64_t sock_id) {
    int ret = 0;
    return ret;
    // TODO retrieve socket
    kern_sock_norman_t *s = NULL;
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
