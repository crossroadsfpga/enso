#ifndef _KERN_SOCK_INTERNAL_NORMAN_
#define _KERN_SOCK_INTERNAL_NORMAN_

#include "sock_struct.h"
#include <linux/types.h>

uint64_t num_kern_socks;
kern_sock_norman_t kern_socks[MAX_KERN_SOCKS];

DEFINE_SPINLOCK(kern_sock_lock);

int kern_create_socket(struct dev_bookkeep *pdev, int app_id);
int kern_verify_socket(struct task_struct *app, uint64_t sock_id);


#endif
