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
#ifndef SOFTWARE_KERNEL_LINUX_ENSO_SETUP_H_
#define SOFTWARE_KERNEL_LINUX_ENSO_SETUP_H_

#include <linux/atomic.h>
#include <linux/cdev.h>
#include <linux/delay.h>
#include <linux/fs.h>
#include <linux/io.h>
#include <linux/kernel.h>
#include <linux/kthread.h>
#include <linux/mm.h>
#include <linux/module.h>
#include <linux/printk.h>
#include <linux/slab.h>
#include <linux/spinlock.h>
#include <linux/uaccess.h>
#include <linux/version.h>

#define ENSO_DRIVER_NAME "enso"
#define NOTIFICATION_BUF_SIZE 16384
#define ENSO_PIPE_SIZE 32768
#define MAX_TRANSFER_LEN 131072
#define HUGE_PAGE_SIZE (0x1ULL << 21)
#define MEM_PER_QUEUE (0x1ULL << 12)
#define BATCH_SIZE 64
#define SCHED_CORE_NUM 4

// These determine the maximum number of notification buffers and enso pipes.
// These macros also exist in hardware and **must be kept in sync**. Update the
// variables with the same name on `hardware/src/constants.sv`,
// `software/include/enso/consts.h`, and `scripts/hwtest/my_stats.tcl`.
#define MAX_NB_APPS 1024
#define MAX_NB_FLOWS 8192

/*
 * struct enso_intel_pcie
 *
 * @brief: Stores the PCIe Base Address Resgiter (BAR) information from
 *         Intel's drivers. Note: we only use BAR2's information, rest are
 *         unused.
 *
 * */
struct enso_intel_pcie {
  void *__iomem base_addr;
};

/*
 * struct enso_global_bookkeep
 *
 * @brief: Global bookkeeping information relevant to the Enso driver.
 *
 * @cdev: Used to create a character device.
 * @chr_class: Used to creating the enso device under /dev/.
 * @intel_enso: The start of the BAR region to be mapped into the kernel space.
 * @chr_major: Major number of the device.
 * @chr_minor: Minor number of the device.
 *
 * */
struct enso_global_bookkeep {
  struct cdev cdev;
  struct class *chr_class;
  struct enso_intel_pcie *intel_enso;
  int chr_major;
  int chr_minor;
  struct dev_bookkeep *dev_bk;
};

struct enso_send_tx_pipe_params {
  uint64_t phys_addr;
  uint32_t len;
  uint32_t notif_buf_id;
  uint32_t pipe_id;
} __attribute__((packed));

struct tx_queue_node {
  struct enso_send_tx_pipe_params batch;
  unsigned long ftime;
};

struct flow_metadata {
  unsigned long last_ftime;
};

struct min_heap {
  struct heap_node *harr;
  uint32_t capacity;
  uint32_t size;
};

struct heap_node {
  struct tx_queue_node *queue_node;
};

/**
 * struct dev_bookkeep - Bookkeeping structure per device.
 *
 * @chr_open_cnt:   Number of character device handles opened with
 *                  this device selected.
 * @sem:            Synchronizes accesses to this structure. Can be used in
 *                  interrupt context. Currently, only @chr_open_cnt requires
 *                  synchronization as other fields are written once.
 * @nb_fb_queues:   Number of fallback queues.
 * @enable_rr:      Enable round-robin scheduling among fallback queues.
 * @notif_q_status: Bit vector to keep track of which notification queue has
 *                  been allocated.
 * @rx_pipe_status:    Bit vector to keep track of which rx pipe has been
 * allocated.
 * @tx_pipe_status:    Bit vector to keep track of which tx pipe has been
 * allocated.
 *
 */
struct dev_bookkeep {
  atomic_t chr_open_cnt;
  struct semaphore sem;
  uint32_t nb_fb_queues;
  bool enable_rr;
  uint8_t *notif_q_status;
  uint8_t *rx_pipe_status;
  uint8_t *tx_pipe_status;

  struct task_struct *enso_sched_thread;
  unsigned long stime;
  struct flow_metadata **tx_flows;
  struct min_heap *heap;
  spinlock_t lock;
  bool sched_run;
  struct notification_buf_pair **notif_buf_pairs;
};

/**
 * struct chr_dev_bookkeep - Bookkeeping structure per character device
 *                           handle.
 *
 * @dev_bk:         Pointer to the device bookkeeping structure for the
 *                  currently selected device.
 * @nb_fb_queues:   Number of fallback queues.
 * @notif_q_status: Bit vector to keep track of which notification queue has
 *                  been allocated for this particular character device.
 * @rx_pipe_status: Bit vector to keep track of which rx pipe has been allocated
 *                  for this particular character device.
 * @tx_pipe_status: Bit vector to keep track of which tx pipe has been allocated
 *                  for this particular character device.
 * @notif_buf_pair: Notification buffer pair specific to this device handle.
 * @enso_rx_pipes: Enso RX pipes specific to this device handle.
 *
 */
struct chr_dev_bookkeep {
  struct dev_bookkeep *dev_bk;
  uint32_t nb_fb_queues;
  uint8_t *notif_q_status;
  uint8_t *rx_pipe_status;
  uint8_t *tx_pipe_status;
  struct notification_buf_pair *notif_buf_pair;
  struct rx_pipe_internal **rx_pipes;
};

struct __attribute__((__packed__)) rx_notification {
  uint64_t signal;
  uint64_t queue_id;
  uint64_t tail;
  uint64_t pad[5];
};

struct __attribute__((__packed__)) tx_notification {
  uint64_t signal;
  uint64_t phys_addr;
  uint64_t length;  // In bytes (up to 1MB).
  uint64_t pad[5];
};

struct queue_regs {
  uint32_t rx_tail;
  uint32_t rx_head;
  uint32_t rx_mem_low;
  uint32_t rx_mem_high;
  uint32_t tx_tail;
  uint32_t tx_head;
  uint32_t tx_mem_low;
  uint32_t tx_mem_high;
  uint32_t padding[8];
};

struct notification_buf_pair {
  struct rx_notification *rx_buf;
  uint32_t *next_rx_pipe_ids;  // Next pipe ids to consume from rx_buf.
  struct tx_notification *tx_buf;
  uint32_t *rx_head_ptr;
  uint32_t *tx_tail_ptr;
  uint32_t rx_head;
  uint32_t tx_head;
  uint32_t tx_tail;
  uint16_t next_rx_ids_head;
  uint16_t next_rx_ids_tail;
  uint32_t nb_unreported_completions;
  uint32_t id;

  struct queue_regs *regs;
  uint64_t tx_full_cnt;
  uint32_t ref_cnt;

  uint8_t *wrap_tracker;
  uint32_t *pending_rx_pipe_tails;

  bool allocated;
};

struct rx_pipe_internal {
  struct queue_regs *regs;
  uint32_t *buf_head_ptr;
  uint32_t rx_head;
  uint32_t rx_tail;
  uint32_t id;
  bool allocated;
};

// extern as it is used by enso_chr.c to fill out the character device info.
extern struct enso_global_bookkeep global_bk;

#endif  // SOFTWARE_KERNEL_LINUX_ENSO_SETUP_H_
