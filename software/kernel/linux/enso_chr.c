#include "enso_chr.h"

#include "enso_ioctl.h"

/******************************************************************************
 * Static function prototypes
 *****************************************************************************/
static int enso_chr_open(struct inode *inode, struct file *filp);
static int enso_chr_release(struct inode *inode, struct file *filp);
static void free_notif_buf_pair(struct chr_dev_bookkeep *chr_dev_bk);
static void free_rx_pipes(struct chr_dev_bookkeep *chr_dev_bk);

/******************************************************************************
 * File operation functions
 *****************************************************************************/
const struct file_operations enso_fops = {
  .owner = THIS_MODULE,
  .open = enso_chr_open,
  .release = enso_chr_release,
  .unlocked_ioctl = enso_unlocked_ioctl
};

/**
 * enso_chr_open() - Responds to the system call open(2).
 *
 * @inode: Unused.
 * @filp:  Pointer to file struct.
 *
 * @return: 0 if successful, negative error code otherwise.
 *
 */
static int enso_chr_open(struct inode *inode, struct file *filp) {
  struct chr_dev_bookkeep *chr_dev_bk;
  struct dev_bookkeep *dev_bk = global_bk.dev_bk;

  if(dev_bk == NULL) {
    printk("dev_bk uninitialized\n");
    return -ENXIO;
  }

  // Create a bookkeeping structure for this particular open file.
  chr_dev_bk = kzalloc(sizeof(struct chr_dev_bookkeep), GFP_KERNEL);
  if (chr_dev_bk == NULL) {
    printk("couldn't create character device bookkeeper.");
    return -ENOMEM;
  }
  chr_dev_bk->dev_bk = dev_bk;
  filp->private_data = chr_dev_bk;

  chr_dev_bk->nb_fb_queues = 0;

  chr_dev_bk->notif_buf_pair = kzalloc(sizeof(struct notification_buf_pair),
                                       GFP_KERNEL);
  if(chr_dev_bk->notif_buf_pair == NULL) {
    printk("couldn't create notification buffer pair\n");
    goto failed_notif_buf_pair_alloc;
  }
  chr_dev_bk->notif_buf_pair->allocated = false;

  chr_dev_bk->rx_pipes = kzalloc(MAX_NB_FLOWS *
                                 sizeof(struct rx_pipe_internal *),
                                 GFP_KERNEL);
  if(chr_dev_bk->rx_pipes == NULL) {
    printk("couldn't create rx_pipes");
    goto failed_rx_pipe_alloc;
  }

  chr_dev_bk->notif_q_status = kzalloc(MAX_NB_APPS / 8, GFP_KERNEL);
  if (chr_dev_bk->notif_q_status == NULL) {
    printk("couldn't create notification queue status\n");
    goto failed_notif_status_alloc;
  }

  chr_dev_bk->pipe_status = kzalloc(MAX_NB_FLOWS / 8, GFP_KERNEL);
  if (chr_dev_bk->pipe_status == NULL) {
    printk("couldn't create pipe status for device\n");
    goto failed_pipe_status_alloc;
  }

  // Increase device open count.
  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.\n");
    return -ERESTARTSYS;
  }
  ++dev_bk->chr_open_cnt;
  up(&dev_bk->sem);
  return 0;

failed_pipe_status_alloc:
  kfree(chr_dev_bk->notif_q_status);
failed_notif_status_alloc:
  kfree(chr_dev_bk->rx_pipes);
failed_rx_pipe_alloc:
  kfree(chr_dev_bk->notif_buf_pair);
failed_notif_buf_pair_alloc:
  kfree(chr_dev_bk);
  return -ENOMEM;
}

/**
 * enso_chr_release() - Responds to the system call close(2). Clean up character
 *                      device file structure.
 * @inode: Unused.
 * @filp:  Pointer to file struct.
 *
 * @return: 0 if successful, negative error code otherwise.
 *
 */
static int enso_chr_release(struct inode *inode, struct file *filp) {
  int i;
  struct chr_dev_bookkeep *chr_dev_bk;
  struct dev_bookkeep *dev_bk;

  chr_dev_bk = filp->private_data;
  dev_bk = chr_dev_bk->dev_bk;

  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.");
    return -ERESTARTSYS;
  }

  // Release notification buffers and pipes.
  for (i = 0; i < MAX_NB_APPS / 8; ++i) {
    dev_bk->notif_q_status[i] &= ~(chr_dev_bk->notif_q_status[i]);
  }
  for (i = 0; i < MAX_NB_FLOWS / 8; ++i) {
    dev_bk->pipe_status[i] &= ~(chr_dev_bk->pipe_status[i]);
  }

  dev_bk->nb_fb_queues -= chr_dev_bk->nb_fb_queues;

  --dev_bk->chr_open_cnt;
  up(&dev_bk->sem);

  free_notif_buf_pair(chr_dev_bk);
  free_rx_pipes(chr_dev_bk);
  kfree(chr_dev_bk->notif_q_status);
  kfree(chr_dev_bk->pipe_status);
  kfree(chr_dev_bk);

  return 0;
}

/******************************************************************************
 * Initialization functions
 *****************************************************************************/
/**
 * enso_chr_init() - Populates sysfs entry with a new device class
 *                   and creates a character device.
 *
 * @return: 0 if successful, negative error code otherwise.
 */
int __init enso_chr_init(void) {
  dev_t dev_id;
  struct device *dev;
  int ret;

  // allocate chrdev region for this device
  // we allocate minor numbers starting from 0
  // we need only one device
  ret = alloc_chrdev_region(&dev_id, 0, 1, ENSO_DRIVER_NAME);
  if(ret) {
    printk("Failed to register char dev\n");
    return -1;
  }
  // dev_id contains a unique identifier allocated by the kernel
  // get the major and minor device numbers from it
  global_bk.chr_major = MAJOR(dev_id);
  global_bk.chr_minor = MINOR(dev_id);

  // initilize and add the character device to the kernel
  cdev_init(&global_bk.cdev, &enso_fops);
  global_bk.cdev.owner = THIS_MODULE;
  global_bk.cdev.ops = &enso_fops;

  // link the major/minor numbers to the char dev
  ret = cdev_add(&global_bk.cdev, dev_id, 1);
  if(ret) {
    printk("Failed to add char device\n");
    goto failed_cdev_add;
  }

  // add an entry under /dev/ for the enso device
  // same as running mknod
  global_bk.chr_class = class_create(THIS_MODULE, ENSO_DRIVER_NAME);
  if (IS_ERR(global_bk.chr_class)) {
    printk("Failed to create device class\n");
    goto failed_chr_class;
  }
  dev = device_create(global_bk.chr_class, NULL, dev_id, NULL,
                      ENSO_DRIVER_NAME);
  if (IS_ERR(dev)) {
    printk("Failed to create device under /dev/.");
    goto failed_dev_create;
  }
  return 0;

failed_dev_create:
  class_destroy(global_bk.chr_class);
failed_chr_class:
  global_bk.chr_class = NULL;
  cdev_del(&global_bk.cdev);
failed_cdev_add:
  global_bk.chr_major = 0;
  global_bk.chr_minor = 0;
  unregister_chrdev_region(dev_id, 1);
  return -1;
}

/**
 * enso_chr_exit() - Undo everything done by enso_chr_init().
 *
 * @return: Nothing
 */
void enso_chr_exit(void) {
  unregister_chrdev_region(MKDEV(global_bk.chr_major, global_bk.chr_minor), 1);
  cdev_del(&global_bk.cdev);
  device_destroy(global_bk.chr_class,
                 MKDEV(global_bk.chr_major, global_bk.chr_minor));
  global_bk.chr_major = 0;
  global_bk.chr_minor = 0;
  class_destroy(global_bk.chr_class);
  global_bk.chr_class = NULL;
}

/******************************************************************************
 * Helper functions
 *****************************************************************************/
/**
 * free_notif_buf_pair() - Frees a notif_buf_pair structure.
 *                         Used by chr_release().
 *
 * @chr_dev_bk: Structure containing information about the current
 *              character file handle.
 *
 */
static void free_notif_buf_pair(struct chr_dev_bookkeep *chr_dev_bk) {
  size_t rx_tx_buf_size = 512 * PAGE_SIZE;
  struct rx_notification *rx_notif = NULL;
  struct notification_buf_pair *notif_buf_pair = NULL;
  unsigned int page_ind = 0;

  if(chr_dev_bk == NULL) {
    return;
  }
  notif_buf_pair = chr_dev_bk->notif_buf_pair;
  if(notif_buf_pair == NULL) {
    printk("enso_drv: How is this possible\n");
    return;
  }
  if(!notif_buf_pair->allocated) {
    printk("enso_drv: Notif buf pair not allocated\n");
    kfree(notif_buf_pair);
    chr_dev_bk->notif_buf_pair = NULL;
    return;
  }
  printk("enso_drv: Cleaning up notif buf pair ID = %d\n", notif_buf_pair->id);
  if(notif_buf_pair->rx_buf != NULL) {
    rx_notif = notif_buf_pair->rx_buf;
    for(;page_ind < rx_tx_buf_size;
         page_ind += PAGE_SIZE) {
      ClearPageReserved(virt_to_page(((unsigned long)rx_notif) + page_ind));
    }
    kfree(rx_notif);
  }
  if(notif_buf_pair->pending_rx_pipe_tails != NULL) {
    kfree(notif_buf_pair->pending_rx_pipe_tails);
  }
  if(notif_buf_pair->wrap_tracker != NULL) {
    kfree(notif_buf_pair->wrap_tracker);
  }
  kfree(notif_buf_pair);
  chr_dev_bk->notif_buf_pair = NULL;
  return;
}

void free_rx_pipes(struct chr_dev_bookkeep *chr_dev_bk) {
  unsigned int ind = 0;
  struct rx_pipe_internal **pipes;
  if(chr_dev_bk == NULL) {
    return;
  }

  pipes = chr_dev_bk->rx_pipes;
  if(pipes == NULL) {
    return;
  }
  for(; ind < MAX_NB_FLOWS; ind++) {
    if(pipes[ind])
    {
      free_rx_pipe(pipes[ind]);
      kfree(pipes[ind]);
      pipes[ind] = NULL;
    }
  }
  kfree(chr_dev_bk->rx_pipes);
  chr_dev_bk->rx_pipes = NULL;
  return;
}
