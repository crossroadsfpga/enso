#include "enso_setup.h"
#include "enso_chr.h"

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
    printk("couldn't create notification queue status");
    kfree(dev_bk);
    return -ENOMEM;
  }

  dev_bk->pipe_status = kzalloc(MAX_NB_FLOWS / 8, GFP_KERNEL);
  if (dev_bk->pipe_status == NULL) {
    printk("couldn't create pipe status for device ");
    kfree(dev_bk);
    kfree(dev_bk->notif_q_status);
    return -ENOMEM;
  }
  global_bk.dev_bk = dev_bk;
  return 0;

}
module_init(enso_init);

/*
 * enso_init(void): Unregisters the Enso driver.
 *
 * */
static void enso_exit(void) {
  // unregister the character device
  enso_chr_exit();
  global_bk.intel_enso = NULL;
}
module_exit(enso_exit);

MODULE_LICENSE("GPL");
