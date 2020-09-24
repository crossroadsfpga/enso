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
#include "event_handler.h"
#include "intel_fpga_pcie_chr.h"

extern spinlock_t event_lock;
extern volatile int chr_events[128];
extern volatile int queue_map[128];
extern struct task_struct * volatile blocked_events[128];
extern unsigned long event_flags;

int handle_event(int queue_id)
{
    int num_events;
    struct task_struct *thread_struct;
    int queue_id1 = -1;

    spin_lock_irqsave(&event_lock, event_flags);

    queue_id1 = queue_map[queue_id]; // (soup) change to var size
    if (queue_id1 <= 0) {
        spin_unlock_irqrestore(&event_lock, event_flags);
        return 0;
    }

    num_events = ++chr_events[queue_id1];
    thread_struct = blocked_events[queue_id1];
    if (num_events > 0 && thread_struct) {
        printk(KERN_INFO "Waking up queue %i: %i events\n",
               queue_id1, num_events);
        wake_up_process(thread_struct);
    }

    spin_unlock_irqrestore(&event_lock, event_flags);

    return 0;
}
