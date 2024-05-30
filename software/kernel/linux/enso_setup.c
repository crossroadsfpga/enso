/*
 * Copyright (c) 2024, Carnegie Mellon University
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

#include "enso_setup.h"

#include "enso_chr.h"
#include "enso_heap.h"
#include "enso_ioctl.h"

struct enso_global_bookkeep global_bk __read_mostly;

// function defined in Intel's FPGA to get the BAR information
extern struct enso_intel_pcie *get_intel_fpga_pcie_addr(void);

/******************************************************************************
 * Kernel Registration
 *****************************************************************************/
/*
 * enso_init(void): Registers the Enso driver.
 *
 * @returns: 0 if successful.
 *
 * */
static __init int enso_init(void) {
  int ret;
  struct dev_bookkeep *dev_bk;

  global_bk.intel_enso = NULL;
  global_bk.intel_enso = get_intel_fpga_pcie_addr();
  if (global_bk.intel_enso == NULL) {
    printk("Failed to receive BAR info\n");
    return -1;
  }

  // initialize a character device
  ret = enso_chr_init();
  if (ret != 0) {
    printk("Failed to initialize character device\n");
    return ret;
  }

  // Allocate dev bookkeeper and set fields
  dev_bk = kzalloc(sizeof(struct dev_bookkeep), GFP_KERNEL);
  if (dev_bk == NULL) {
    printk("couldn't create device bookkeeper");
    return -ENOMEM;
  }
  sema_init(&dev_bk->sem, 1);
  atomic_set(&dev_bk->chr_open_cnt, 0);
  dev_bk->nb_fb_queues = 0;
  dev_bk->enable_rr = false;
  dev_bk->notif_q_status = kzalloc(MAX_NB_APPS / 8, GFP_KERNEL);
  if (dev_bk->notif_q_status == NULL) {
    printk("couldn't create notification queue status\n");
    goto failed_notif_q_status_alloc;
  }

  dev_bk->rx_pipe_status = kzalloc(MAX_NB_FLOWS / 8, GFP_KERNEL);
  if (dev_bk->rx_pipe_status == NULL) {
    printk("couldn't create pipe status for device\n");
    goto failed_rx_pipe_status_alloc;
  }

  dev_bk->tx_pipe_status = kzalloc(MAX_NB_FLOWS / 8, GFP_KERNEL);
  if (dev_bk->tx_pipe_status == NULL) {
    printk("couldn't create pipe status for device\n");
    goto failed_tx_pipe_status_alloc;
  }

  dev_bk->tx_flows =
      kzalloc(MAX_NB_FLOWS * sizeof(struct flow_metadata *), GFP_KERNEL);
  if (dev_bk->tx_flows == NULL) {
    printk("couldn't create tx_flows for device\n");
    goto failed_tx_flows_alloc;
  }

  dev_bk->notif_buf_pairs =
      kzalloc(MAX_NB_APPS * sizeof(struct notification_buf_pair *), GFP_KERNEL);
  if (dev_bk->notif_buf_pairs == NULL) {
    printk("couldn't create notif_buf_pairs\n");
    goto failed_notif_buf_pair_alloc;
  }

  dev_bk->heap = kzalloc(sizeof(struct min_heap), GFP_KERNEL);
  if (dev_bk->heap == NULL) {
    printk("couldn't create the heap\n");
    goto failed_heap_alloc;
  }
  init_heap(dev_bk->heap);

  spin_lock_init(&dev_bk->lock);
  dev_bk->enso_sched_thread = kthread_create(enso_sched, dev_bk, "enso_sched");
  kthread_bind(dev_bk->enso_sched_thread, 4);
  wake_up_process(dev_bk->enso_sched_thread);
  dev_bk->sched_run = true;

  global_bk.dev_bk = dev_bk;

  return 0;

failed_heap_alloc:
  kfree(dev_bk->notif_buf_pairs);
failed_notif_buf_pair_alloc:
  kfree(dev_bk->tx_flows);
failed_tx_flows_alloc:
  kfree(dev_bk->tx_pipe_status);
failed_tx_pipe_status_alloc:
  kfree(dev_bk->rx_pipe_status);
failed_rx_pipe_status_alloc:
  kfree(dev_bk->notif_q_status);
failed_notif_q_status_alloc:
  kfree(dev_bk);
  return -ENOMEM;
}

module_init(enso_init);

/*
 * enso_exit(void): Unregisters the Enso driver.
 *
 * */
static void enso_exit(void) {
  // scheduler clean up
  int index;
  struct flow_metadata *tx_flow;

  if (global_bk.dev_bk->sched_run) {
    kthread_stop(global_bk.dev_bk->enso_sched_thread);
  }

  // tx_flows
  for (index = 0; index < MAX_NB_FLOWS; index++) {
    tx_flow = global_bk.dev_bk->tx_flows[index];
    if (tx_flow) {
      kfree(tx_flow);
      tx_flow = NULL;
    }
  }
  kfree(global_bk.dev_bk->tx_flows);

  // free heap
  free_heap(global_bk.dev_bk->heap);
  kfree(global_bk.dev_bk->heap);

  // all other clean up
  enso_chr_exit();
  global_bk.intel_enso = NULL;
  kfree(global_bk.dev_bk->tx_pipe_status);
  kfree(global_bk.dev_bk->rx_pipe_status);
  kfree(global_bk.dev_bk->notif_q_status);
  kfree(global_bk.dev_bk->notif_buf_pairs);
  kfree(global_bk.dev_bk);
}
module_exit(enso_exit);

MODULE_LICENSE("GPL");
