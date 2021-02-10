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

#include "intel_fpga_pcie_setup.h"
#include "event_queue.h"
#include "event_handler.h"
#include "sock_struct.h"
#include "sock_internal.h"

// HACK(sadok) number of queues should not be fixed
#define NB_QUEUES 2

int event_queue_loop(event_kthread_data_t* data) {
    int sock_id = 0;
    while (!kthread_should_stop()) {
        // FIXME(sadok) this is a very generous sleep that we should remove when
        // doing something useful here
        // we can also pass a condition here instead of 0
        wait_event_timeout(data->queue, 0, HZ);

        for (sock_id = 0; sock_id < MAX_KERN_SOCKS; sock_id++) {
            kern_sock_norman_t *socket_entry = kern_socks + sock_id;
            pcie_pkt_desc_t *dsc_buf = socket_entry->dsc_buf;
            uint32_t dsc_buf_head = socket_entry->dsc_buf_head;
            if (dsc_buf_head == DESC_HEAD_INVALID) {
                continue;
            }

            pcie_pkt_desc_t *cur_desc = dsc_buf + dsc_buf_head;

            if (socket_entry->active == false) {
                continue;
            }

            // TODO (soup) read cur_desc somehow
            /*
            if (cur_desc->signal == 1) {
                handle_event(queue_id);
            }
            */
        }
    }
    return 0;
}

int launch_event_kthread(void)
{
    init_waitqueue_head(&global_bk.event_kthread_data.queue);

    global_bk.event_kthread_data.task = kthread_create_on_node(
        (int (*)(void *)) event_queue_loop,
        &global_bk.event_kthread_data,
        NUMA_NO_NODE, // TODO(sadok) we can bind the kthread to a cpu
        "event_queue_loop"
    );

    if (global_bk.event_kthread_data.task <= 0) {
        return -1;
    }

    wake_up_process(global_bk.event_kthread_data.task);

    return 0;
}

void stop_event_kthread(void)
{
    kthread_stop(global_bk.event_kthread_data.task);
}
