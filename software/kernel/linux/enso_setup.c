#include "enso_setup.h"
#include "enso_chr.h"
#include "enso_ioctl.h"

struct enso_global_bookkeep global_bk __read_mostly;

// function defined in Intel's FPGA to get the BAR information
extern struct enso_intel_pcie* get_intel_fpga_pcie_addr(void);

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
  if(global_bk.intel_enso == NULL) {
    printk("Failed to receive BAR info\n");
    return -1;
  }

  // initialize a character device
  ret = enso_chr_init();
  if(ret != 0) {
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
  dev_bk->chr_open_cnt = 0;
  dev_bk->nb_fb_queues = 0;
  dev_bk->enable_rr = false;
  dev_bk->notif_q_status = kzalloc(MAX_NB_APPS / 8, GFP_KERNEL);
  if (dev_bk->notif_q_status == NULL) {
    printk("couldn't create notification queue status\n");
    kfree(dev_bk);
    return -ENOMEM;
  }

  dev_bk->pipe_status = kzalloc(MAX_NB_FLOWS / 8, GFP_KERNEL);
  if (dev_bk->pipe_status == NULL) {
    printk("couldn't create pipe status for device\n");
    kfree(dev_bk->notif_q_status);
    kfree(dev_bk);
    return -ENOMEM;
  }

  dev_bk->tx_pipe_status = kzalloc(MAX_NB_FLOWS / 8, GFP_KERNEL);
  if (dev_bk->tx_pipe_status == NULL) {
    printk("couldn't create pipe status for device\n");
    kfree(dev_bk->pipe_status);
    kfree(dev_bk->notif_q_status);
    kfree(dev_bk);
    return -ENOMEM;
  }

  dev_bk->queue_heads = kzalloc(MAX_NB_FLOWS * sizeof(struct tx_queue_head*), GFP_KERNEL);
  if (dev_bk->queue_heads == NULL) {
    printk("couldn't create queue head for device\n");
    kfree(dev_bk->tx_pipe_status);
    kfree(dev_bk->pipe_status);
    kfree(dev_bk->notif_q_status);
    kfree(dev_bk);
    return -ENOMEM;
  }

  dev_bk->sqh = kzalloc(sizeof(struct sched_queue_head), GFP_KERNEL);
  if (dev_bk->sqh == NULL) {
    printk("couldn't create sched head for device\n");
    kfree(dev_bk->queue_heads);
    kfree(dev_bk->tx_pipe_status);
    kfree(dev_bk->pipe_status);
    kfree(dev_bk->notif_q_status);
    kfree(dev_bk);
    return -ENOMEM;
  }

  dev_bk->notif_buf_pairs = kzalloc(MAX_NB_APPS * sizeof(struct notification_buf_pair *), GFP_KERNEL);
  if (dev_bk->notif_buf_pairs == NULL) {
    printk("couldn't create notif_buf_pairs\n");
    kfree(dev_bk->sqh);
    kfree(dev_bk->queue_heads);
    kfree(dev_bk->tx_pipe_status);
    kfree(dev_bk->pipe_status);
    kfree(dev_bk->notif_q_status);
    kfree(dev_bk);
    return -ENOMEM;
  }

  spin_lock_init(&dev_bk->lock);
  dev_bk->enso_sched_thread = kthread_create(enso_sched, dev_bk, "enso_sched");
  kthread_bind(dev_bk->enso_sched_thread, 4);
  wake_up_process(dev_bk->enso_sched_thread);
  dev_bk->sched_run = true;

  global_bk.dev_bk = dev_bk;

  return 0;
}

void free_tx_queue(struct tx_queue_head *queue_head) {
  struct tx_queue_node *node;
  struct tx_queue_node *to_free;
  node = queue_head->front;
  while(node != NULL) {
    to_free = node;
    if(to_free) {
      kfree(to_free);
      to_free = NULL;
    }
    node = node->next;
  }
  kfree(queue_head);
}

module_init(enso_init);

/*
 * enso_exit(void): Unregisters the Enso driver.
 *
 * */
static void enso_exit(void) {
  // scheduler clean up
  int index;
  struct tx_queue_head *queue_head;
  struct sched_queue_head *sqh;
  struct sched_queue_node *node;
  struct sched_queue_node *to_free;

  if(global_bk.dev_bk->sched_run) {
    kthread_stop(global_bk.dev_bk->enso_sched_thread);
  }

  // tx_queue_heads
  for(index = 0; index < MAX_NB_FLOWS; index++) {
    queue_head = global_bk.dev_bk->queue_heads[index];
    if(queue_head) {
      free_tx_queue(queue_head);
    }
  }

  // scheduler queue
  sqh = global_bk.dev_bk->sqh;
  node = sqh->front;
  while(node != NULL) {
    to_free = node;
    node = node->next;
    if(to_free) {
      kfree(to_free);
      to_free = NULL;
    }
  }
  kfree(sqh);

  // other clean up
  enso_chr_exit();
  global_bk.intel_enso = NULL;
  kfree(global_bk.dev_bk->pipe_status);
  kfree(global_bk.dev_bk->notif_q_status);
  kfree(global_bk.dev_bk->notif_buf_pairs);
  kfree(global_bk.dev_bk);
}
module_exit(enso_exit);

MODULE_LICENSE("GPL");
