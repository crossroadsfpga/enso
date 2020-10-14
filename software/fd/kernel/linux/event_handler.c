/*
 * Copyright (c) 2020, Carnegie Mellon University
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted (subject to the limitations in the disclaimer
 * below) provided that the following conditions are met:
 *
 *      * Redistributions of source code must retain the above copyright notice,
 *      this list of conditions and the following disclaimer.
 *
 *      * Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *      * Neither the name of the copyright holder nor the names of its
 *      contributors may be used to endorse or promote products derived from
 *      this software without specific prior written permission.
 *
 * NO EXPRESS OR IMPLIED LICENSES TO ANY PARTY'S PATENT RIGHTS ARE GRANTED BY
 * THIS LICENSE. THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
 * NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <linux/printk.h>
#include <linux/eventfd.h>
#include <linux/fdtable.h>
#include "event_handler.h"
#include "event_queue.h"
#include "intel_fpga_pcie_chr.h"

int handle_event(int queue_id0)
{
    int fd;
    struct file *efd_file = NULL;
    struct eventfd_ctx *efd_ctx = NULL;
    struct task_struct * task = NULL;

    spin_lock_irqsave(&event_lock, event_flags);

    fd = queue_map[queue_id0]; // (soup) change to var size
    if (fd <= 0) {
        spin_unlock_irqrestore(&event_lock, event_flags);
        return 0;
    }

    task = tasks[queue_id0];
    if (!task) {
        spin_unlock_irqrestore(&event_lock, event_flags);
        return 0;
    }

    rcu_read_lock();
    efd_file = fcheck_files(task->files, fd);
    rcu_read_unlock();

    efd_ctx = eventfd_ctx_fileget(efd_file);
    if (efd_ctx == 0) {
        spin_unlock_irqrestore(&event_lock, event_flags);
        printk(KERN_INFO "eventfd_ctx_fileget failed\n");
        return -1;
    }

    printk(KERN_INFO "eventfd_signal begin\n");
    eventfd_signal(efd_ctx, 1);
    printk(KERN_INFO "evenfd_signal end\n");

    spin_unlock_irqrestore(&event_lock, event_flags);

    return 0;
}
