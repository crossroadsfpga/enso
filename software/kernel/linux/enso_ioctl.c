#include "enso_ioctl.h"

/******************************************************************************
 * Static function prototypes
 *****************************************************************************/
static int test(void);
static long get_nb_fallback_queues(struct dev_bookkeep *dev_bk,
                                   unsigned int __user *user_addr);
static long set_rr_status(struct dev_bookkeep *dev_bk, bool status);
static long get_rr_status(struct dev_bookkeep *dev_bk, bool __user *user_addr);
static long alloc_notif_buffer(struct chr_dev_bookkeep *dev_bk,
                               unsigned int __user *user_addr);
static long free_notif_buffer(struct chr_dev_bookkeep *chr_dev_bk,
                              unsigned long uarg);
static long alloc_pipe(struct chr_dev_bookkeep *chr_dev_bk,
                       unsigned int __user *user_addr);
static long free_pipe(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg);

static long alloc_notif_buf_pair(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg);
static long send_tx_pipe(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg);
static long get_unreported_completions(struct chr_dev_bookkeep *chr_dev_bk, unsigned int __user *user_addr);

static long send_config(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg);
static long alloc_rx_pipe(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg);
static long free_rx_pipe_id(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg);
static long consume_rx_pipe(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg);
static long fully_advance_pipe(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg);
static long get_next_batch(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg);
static long advance_pipe(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg);
static long next_rx_pipe_to_recv(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg);
static long prefetch_pipe(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg);

/* Helpers */
static void free_rx_tx_buf(struct chr_dev_bookkeep *chr_dev_bk);
static void update_tx_head(struct notification_buf_pair* notif_buf_pair);
static int32_t get_next_pipe_id(struct notification_buf_pair *notif_buf_pair);
static uint32_t consume_queue(struct notification_buf_pair *notif_buf_pair,
                              struct rx_pipe_internal *pipe,
                              uint32_t *new_rx_tail);
static uint16_t get_new_tails(struct notification_buf_pair *notif_buf_pair);
static int32_t get_next_rx_pipe(struct notification_buf_pair *notif_buf_pair,
                                struct rx_pipe_internal **rx_enso_pipes);

/******************************************************************************
 * Device and I/O control function
 *****************************************************************************/
/**
 * enso_unlocked_ioctl() - Responds to the system call ioctl(2).
 * @filp: Pointer to file struct.
 * @cmd:  The command value corresponding to some desired action.
 * @uarg: Optional argument passed to the system call. This could actually
 *        be data or it could be a pointer to some structure which has been
 *        casted.
 *
 * @return: 0 on success, negative error code on failure.
 */
long enso_unlocked_ioctl(struct file *filp, unsigned int cmd,
                         unsigned long uarg) {
  long retval = 0;
  struct chr_dev_bookkeep *chr_dev_bk;
  struct dev_bookkeep *dev_bk;

  if (unlikely(_IOC_TYPE(cmd) != ENSO_IOCTL_MAGIC)) {
    printk(
        "ioctl called with wrong magic "
        "number: %d",
        _IOC_TYPE(cmd));
    return -ENOTTY;
  }

  if (unlikely(_IOC_NR(cmd) > ENSO_IOCTL_MAXNR)) {
    printk(
        "ioctl called with wrong "
        "command number: %d",
        _IOC_NR(cmd));
    return -ENOTTY;
  }

// Linux 5.0 changed access_ok.
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 0, 0)
  retval = !access_ok((void __user *)uarg, _IOC_SIZE(cmd));
#else
  /*
   * The direction is a bitmask, and VERIFY_WRITE catches R/W transfers.
   * `Type' is user-oriented, while access_ok is kernel-oriented, so the
   * concept of "read" and "write" is reversed.
   */
  if (_IOC_DIR(cmd) & _IOC_READ) {
    // Note: VERIFY_WRITE is a superset of VERIFY_READ
    retval = !access_ok(VERIFY_WRITE, (void __user *)uarg, _IOC_SIZE(cmd));
  } else if (_IOC_DIR(cmd) & _IOC_WRITE) {
    retval = !access_ok(VERIFY_READ, (void __user *)uarg, _IOC_SIZE(cmd));
  }
#endif

  if (unlikely(retval)) {
    printk("ioctl access violation.");
    return -EFAULT;
  }

  // Retrieve bookkeeping information.
  chr_dev_bk = filp->private_data;
  dev_bk = chr_dev_bk->dev_bk;

  // Determine access type.
  switch (cmd) {
    case ENSO_IOCTL_TEST:
      retval = test();
      break;
    case ENSO_IOCTL_GET_NB_FALLBACK_QUEUES:
      retval = get_nb_fallback_queues(dev_bk, (unsigned int __user *)uarg);
      break;
    case ENSO_IOCTL_SET_RR_STATUS:
      retval = set_rr_status(dev_bk, (bool)uarg);
      break;
    case ENSO_IOCTL_GET_RR_STATUS:
      retval = get_rr_status(dev_bk, (bool __user *)uarg);
      break;
    case ENSO_IOCTL_ALLOC_NOTIF_BUFFER:
      retval = alloc_notif_buffer(chr_dev_bk, (unsigned int __user *)uarg);
      break;
    case ENSO_IOCTL_FREE_NOTIF_BUFFER:
      retval = free_notif_buffer(chr_dev_bk, uarg);
      break;
    case ENSO_IOCTL_ALLOC_PIPE:
      retval = alloc_pipe(chr_dev_bk, (unsigned int __user *)uarg);
      break;
    case ENSO_IOCTL_FREE_PIPE:
      retval = free_pipe(chr_dev_bk, uarg);
      break;
    case ENSO_IOCTL_ALLOC_NOTIF_BUF_PAIR:
      retval = alloc_notif_buf_pair(chr_dev_bk, uarg);
      break;
    case ENSO_IOCTL_SEND_TX_PIPE:
      retval = send_tx_pipe(chr_dev_bk, uarg);
      break;
    case ENSO_IOCTL_GET_UNREPORTED_COMPLETIONS:
      retval = get_unreported_completions(chr_dev_bk, (unsigned int __user *) uarg);
      break;
    case ENSO_IOCTL_SEND_CONFIG:
      retval = send_config(chr_dev_bk, uarg);
      break;
    case ENSO_IOCTL_ALLOC_RX_ENSO_PIPE:
      retval = alloc_rx_pipe(chr_dev_bk, uarg);
      break;
    case ENSO_IOCTL_FREE_RX_ENSO_PIPE:
      retval = free_rx_pipe_id(chr_dev_bk, uarg);
      break;
    case ENSO_IOCTL_CONSUME_RX:
      retval = consume_rx_pipe(chr_dev_bk, uarg);
      break;
    case ENSO_IOCTL_FULL_ADV_PIPE:
      retval = fully_advance_pipe(chr_dev_bk, uarg);
      break;
    case ENSO_IOCTL_GET_NEXT_BATCH:
      retval = get_next_batch(chr_dev_bk, uarg);
      break;
    case ENSO_IOCTL_ADVANCE_PIPE:
      retval = advance_pipe(chr_dev_bk, uarg);
      break;
    case ENSO_IOCTL_NEXT_RX_PIPE_RCV:
      retval = next_rx_pipe_to_recv(chr_dev_bk, uarg);
      break;
    case ENSO_IOCTL_PREFETCH_PIPE:
      retval = prefetch_pipe(chr_dev_bk, uarg);
      break;
    default:
      retval = -ENOTTY;
  }

  return retval;
}

static int test(void) {
  printk("Hello World\n");
  return 0;
}

/**
 * get_nb_fallback_queues() - Copies the number of fallback queues to userspace.
 *
 * @dev_bk:     Pointer to the device bookkeeping structure.
 * @user_addr:  Address to an unsigned int in user-space to save the result.
 *
 * Return: 0 if successful, negative error code otherwise.
 */
static long get_nb_fallback_queues(struct dev_bookkeep *dev_bk,
                                   unsigned int __user *user_addr) {
  unsigned int nb_fb_queues = dev_bk->nb_fb_queues;
  if (copy_to_user(user_addr, &nb_fb_queues, sizeof(nb_fb_queues))) {
    printk("couldn't copy nb_fb_queues information to user.");
    return -EFAULT;
  }
  return 0;
}

/**
 * set_rr_status() - Enables or disables round-robin across fallback queues.
 *
 * @dev_bk:  Pointer to the device bookkeeping structure.
 * @status:  The status to set: true to enable RR, false to disable.
 *
 * Return: 0 if successful, negative error code otherwise.
 */
static long set_rr_status(struct dev_bookkeep *dev_bk, bool rr_status) {
  // FIXME(sadok): Right now all this does is to set a variable in the kernel
  // module so that processes can coordinate the current RR status. User space
  // is still responsible for sending the configuration to the NIC.
  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.");
    return -ERESTARTSYS;
  }

  dev_bk->enable_rr = rr_status;

  up(&dev_bk->sem);

  return 0;
}

/**
 * get_rr_status() - Copies the current RR status to userspace.
 *
 * @dev_bk:     Pointer to the device bookkeeping structure.
 * @user_addr:  Address to a boolean in user-space to save the result.
 *
 * Return: 0 if successful, negative error code otherwise.
 */
static long get_rr_status(struct dev_bookkeep *dev_bk, bool __user *user_addr) {
  bool rr_status = dev_bk->enable_rr;
  if (copy_to_user(user_addr, &rr_status, sizeof(rr_status))) {
    printk("couldn't copy rr_status information to user.");
    return -EFAULT;
  }
  return 0;
}

/**
 * alloc_notif_buffer() - Allocates a notification buffer for the current
 *                        device.
 *
 * @chr_dev_bk: Structure containing information about the current
 *              character file handle.
 * @user_addr:  Address to an unsigned int in user-space to save the buffer ID.
 *
 * Return: 0 if successful, negative error code otherwise.
 */
static long alloc_notif_buffer(struct chr_dev_bookkeep *chr_dev_bk,
                               unsigned int __user *user_addr) {
  int i = 0;
  int32_t buf_id = -1;
  struct dev_bookkeep *dev_bk;
  dev_bk = chr_dev_bk->dev_bk;

  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.");
    return -ERESTARTSYS;
  }

  // Find first available notification buffer. If none are available, return
  // an error.
  for (i = 0; i < MAX_NB_APPS / 8; ++i) {
    int32_t set_buf_id = 0;
    uint8_t set = dev_bk->notif_q_status[i];
    while (set & 0x1) {
      ++set_buf_id;
      set >>= 1;
    }
    if (set_buf_id < 8) {
      // Set status bit for both the device bitvector and the character device
      // bitvector.
      dev_bk->notif_q_status[i] |= (1 << set_buf_id);
      chr_dev_bk->notif_q_status[i] |= (1 << set_buf_id);

      buf_id = i * 8 + set_buf_id;
      break;
    }
  }

  up(&dev_bk->sem);

  if (buf_id < 0) {
    printk("couldn't allocate notification buffer.");
    return -ENOMEM;
  }

  if (copy_to_user(user_addr, &buf_id, sizeof(buf_id))) {
    printk("couldn't copy buf_id information to user.");
    return -EFAULT;
  }

  return 0;
}

/**
 * free_notif_buffer() - Frees a notification buffer for the current
 *                       device.
 *
 * @chr_dev_bk: Structure containing information about the current
 *              character file handle.
 * @uarg:       The buffer ID to free.
 *
 * Return: 0 if successful, negative error code otherwise.
 *
 */
static long free_notif_buffer(struct chr_dev_bookkeep *chr_dev_bk,
                              unsigned long uarg) {
  int32_t i, j;
  int32_t buf_id = (int32_t)uarg;
  struct dev_bookkeep *dev_bk;

  dev_bk = chr_dev_bk->dev_bk;

  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.");
    return -ERESTARTSYS;
  }

  // Check that the buffer ID is valid.
  if (buf_id < 0 || buf_id >= MAX_NB_APPS) {
    printk("invalid buffer ID.");
    return -EINVAL;
  }

  // Clear status bit for both the device bitvector and the character device
  // bitvector.
  i = buf_id / 8;
  j = buf_id % 8;
  dev_bk->notif_q_status[i] &= ~(1 << j);
  chr_dev_bk->notif_q_status[i] &= ~(1 << j);

  up(&dev_bk->sem);

  return 0;
}

/**
 * alloc_pipe() - Allocates a pipe for the current device.
 *
 * @chr_dev_bk: Structure containing information about the current
 *              character file handle.
 * @user_addr:  Address to an unsigned int in user-space. It is used as input to
 *              determine if the pipe is a fallback pipe (1 to fallback pipe, 0
 *              if not) and as output to save the pipe ID.
 *
 * Return: 0 if successful, negative error code otherwise.
 *
 */
static long alloc_pipe(struct chr_dev_bookkeep *chr_dev_bk,
                       unsigned int __user *user_addr) {
  int32_t i, j;
  bool is_fallback;
  int32_t pipe_id = -1;
  struct dev_bookkeep *dev_bk;
  dev_bk = chr_dev_bk->dev_bk;

  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.");
    return -ERESTARTSYS;
  }

  if (copy_from_user(&is_fallback, user_addr, 1)) {
    printk("couldn't copy is_fallback information from user.");
    return -EFAULT;
  }

  if (is_fallback) {  // Fallback pipes are allocated at the front.
    for (i = 0; i < MAX_NB_FLOWS / 8; ++i) {
      int32_t set_pipe_id = 0;
      uint8_t set = dev_bk->pipe_status[i];
      while (set & 0x1) {
        ++set_pipe_id;
        set >>= 1;
      }
      if (set_pipe_id < 8) {
        pipe_id = i * 8 + set_pipe_id;
        break;
      }
    }

    if (pipe_id >= 0) {
      // Make sure all fallback pipes are contiguously allocated.
      if (pipe_id != dev_bk->nb_fb_queues) {
        printk("fallback pipes are not contiguous.");
        up(&dev_bk->sem);
        return -EINVAL;
      }

      ++(dev_bk->nb_fb_queues);
      ++(chr_dev_bk->nb_fb_queues);
    }

  } else {  // Non-fallback pipes are allocated at the back.
    for (i = MAX_NB_FLOWS / 8 - 1; i >= 0; --i) {
      int32_t set_pipe_id = 7;
      uint8_t set = dev_bk->pipe_status[i];
      while (set & 0x80) {
        --set_pipe_id;
        set <<= 1;
      }
      if (set_pipe_id >= 0) {
        pipe_id = i * 8 + set_pipe_id;
        break;
      }
    }
  }

  up(&dev_bk->sem);

  if (pipe_id < 0) {
    printk("couldn't allocate pipe.");
    return -ENOMEM;
  }

  // Set status bit for both the device bitvector and the character device
  // bitvector.
  i = pipe_id / 8;
  j = pipe_id % 8;
  dev_bk->pipe_status[i] |= (1 << j);
  chr_dev_bk->pipe_status[i] |= (1 << j);

  if (copy_to_user(user_addr, &pipe_id, sizeof(pipe_id))) {
    printk("couldn't copy buf_id information to user.");
    return -EFAULT;
  }

  return 0;
}

/**
 * free_pipe() - Frees a pipe for the current device.
 *
 * @chr_dev_bk: Structure containing information about the current
 *              character file handle.
 * @uarg:       The pipe ID to free.
 *
 * Return: 0 if successful, negative error code otherwise.
 *
 */
static long free_pipe(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg) {
  int32_t i, j;
  int32_t pipe_id = (int32_t)uarg;
  struct dev_bookkeep *dev_bk;

  dev_bk = chr_dev_bk->dev_bk;

  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.");
    return -ERESTARTSYS;
  }

  // Check that the pipe ID is valid.
  if (pipe_id < 0 || pipe_id >= MAX_NB_FLOWS) {
    printk("invalid pipe ID.");
    return -EINVAL;
  }

  // Check that the pipe ID is allocated.
  i = pipe_id / 8;
  j = pipe_id % 8;
  if (!(chr_dev_bk->pipe_status[i] & (1 << j))) {
    printk("pipe ID is not allocated for this file handle.");
    return -EINVAL;
  }

  // Clear status bit for both the device bitvector and the character device
  // bitvector.
  dev_bk->pipe_status[i] &= ~(1 << j);
  chr_dev_bk->pipe_status[i] &= ~(1 << j);

  // Fallback pipes are allocated at the front.
  if (pipe_id < dev_bk->nb_fb_queues) {
    --(dev_bk->nb_fb_queues);
    --(chr_dev_bk->nb_fb_queues);
  }

  up(&dev_bk->sem);

  return 0;
}

/**
 * alloc_notif_buf_pair() - Allocates a notification buffer
 *
 * @chr_dev_bk: Structure containing information about the current
 *              character file handle.
 * @uarg:       The notification buffer ID.
 *
 * Return: 0 if successful, negative error code otherwise.
 *
 */
static long alloc_notif_buf_pair(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg) {
  int32_t buf_id = (int32_t)uarg;
  struct dev_bookkeep *dev_bk;
  struct notification_buf_pair *notif_buf_pair;
  uint8_t *bar2_addr;
  struct queue_regs *nbp_q_regs;
  uint32_t page_ind = 0;
  size_t rx_tx_buf_size = 512 * PAGE_SIZE;
  uint64_t rx_buf_phys_addr;

  notif_buf_pair = chr_dev_bk->notif_buf_pair;
  dev_bk = chr_dev_bk->dev_bk;

  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.");
    return -ERESTARTSYS;
  }

  notif_buf_pair->id = buf_id;

  printk("Creating notif buf pair %d\n", buf_id);

  // Check that the buffer ID is valid.
  if (buf_id < 0 || buf_id >= MAX_NB_APPS) {
    printk("invalid buffer ID.");
    return -EINVAL;
  }

  // check if notification buf pair already allocated
  if(notif_buf_pair->allocated) {
    printk("Notification buf pair already allocated.\n");
    return -EINVAL;
  }

  // 2. Map BAR into queue regs
  bar2_addr = (uint8_t *) global_bk.intel_enso->base_addr;
  nbp_q_regs = (struct queue_regs *)(bar2_addr
                                   + (notif_buf_pair->id + MAX_NB_FLOWS)
                                   * MEM_PER_QUEUE);
  // TODO:Create wrappers on top of these ioread/write functions
  // initialize the queue registers
  smp_wmb();
  iowrite32(0, &nbp_q_regs->rx_mem_low);
  smp_wmb();
  iowrite32(0, &nbp_q_regs->rx_mem_high);

  smp_rmb();
  while(ioread32(&nbp_q_regs->rx_mem_low) != 0)
      continue;
  smp_rmb();
  while(ioread32(&nbp_q_regs->rx_mem_high) != 0)
      continue;

  smp_wmb();
  iowrite32(0, &nbp_q_regs->rx_tail);
  smp_rmb();
  while(ioread32(&nbp_q_regs->rx_tail) != 0)
      continue;

  smp_wmb();
  iowrite32(0, &nbp_q_regs->rx_head);
  smp_rmb();
  while(ioread32(&nbp_q_regs->rx_head) != 0)
      continue;

  notif_buf_pair->regs = nbp_q_regs;

  // 3. Allocate TX and RX notification buffers
  // TODO: Think if we can move these buffers in the userspace
  notif_buf_pair->rx_buf = (struct rx_notification *)kmalloc(rx_tx_buf_size, GFP_DMA);
  if(notif_buf_pair->rx_buf == NULL) {
    printk("RX_TX allocation failed");
    return -ENOMEM;
  }
  // reserve these pages, so that they are not swapped out
  for(;page_ind <  rx_tx_buf_size;
        page_ind += PAGE_SIZE) {
    SetPageReserved(virt_to_page(((unsigned long)notif_buf_pair->rx_buf) + page_ind));
  }
  rx_buf_phys_addr = virt_to_phys(notif_buf_pair->rx_buf);

  // we divide the DMA memory into two halves
  // first half for the rx notification buffers
  // second half for the tx notification buffers
  memset(notif_buf_pair->rx_buf, 0, NOTIFICATION_BUF_SIZE * 64);

  notif_buf_pair->tx_buf = (struct tx_notification *)(
                                    (uint64_t) notif_buf_pair->rx_buf + (rx_tx_buf_size/2));
  memset(notif_buf_pair->tx_buf, 0, NOTIFICATION_BUF_SIZE * 64);

  // 4. Initialize notification buf pair finally
  notif_buf_pair->rx_head_ptr = (uint32_t *)&nbp_q_regs->rx_head;
  smp_rmb();
  notif_buf_pair->rx_head = ioread32(notif_buf_pair->rx_head_ptr);

  notif_buf_pair->tx_tail_ptr = (uint32_t *)&nbp_q_regs->tx_tail;
  smp_rmb();
  notif_buf_pair->tx_tail = ioread32(notif_buf_pair->tx_tail_ptr);
  notif_buf_pair->tx_head = notif_buf_pair->tx_tail;
  smp_wmb();
  iowrite32(notif_buf_pair->tx_head, &nbp_q_regs->tx_head);

  notif_buf_pair->pending_rx_pipe_tails = (uint32_t *)kmalloc(
                    sizeof(*(notif_buf_pair->pending_rx_pipe_tails)) * 8192, GFP_KERNEL);
  if(notif_buf_pair->pending_rx_pipe_tails == NULL) {
    printk("Pending RX pipe tails allocation failed");
    free_rx_tx_buf(chr_dev_bk);
    return -ENOMEM;
  }
  memset(notif_buf_pair->pending_rx_pipe_tails, 0, 8192);

  notif_buf_pair->wrap_tracker = (uint8_t *)kmalloc(NOTIFICATION_BUF_SIZE / 8, GFP_KERNEL);
  if(notif_buf_pair->wrap_tracker == NULL) {
    kfree(notif_buf_pair->pending_rx_pipe_tails);
    free_rx_tx_buf(chr_dev_bk);
    return -ENOMEM;
  }
  memset(notif_buf_pair->wrap_tracker, 0, NOTIFICATION_BUF_SIZE / 8);

  notif_buf_pair->next_rx_pipe_ids = (uint32_t *) kmalloc(sizeof(uint32_t) * NOTIFICATION_BUF_SIZE, GFP_KERNEL);
  if(notif_buf_pair->next_rx_pipe_ids == NULL) {
    printk("Pending RX pipe tails allocation failed");
    kfree(notif_buf_pair->wrap_tracker);
    kfree(notif_buf_pair->pending_rx_pipe_tails);
    free_rx_tx_buf(chr_dev_bk);
    return -ENOMEM;
  }

  notif_buf_pair->next_rx_ids_head = 0;
  notif_buf_pair->next_rx_ids_tail = 0;
  notif_buf_pair->tx_full_cnt = 0;
  notif_buf_pair->nb_unreported_completions = 0;

  printk("Rx buf address: %llx\n", rx_buf_phys_addr);
  smp_wmb();
  iowrite32((uint32_t)rx_buf_phys_addr, &nbp_q_regs->rx_mem_low);
  smp_wmb();
  iowrite32((uint32_t)(rx_buf_phys_addr >> 32), &nbp_q_regs->rx_mem_high);

  rx_buf_phys_addr += rx_tx_buf_size / 2;

  printk("Tx buf address: %llx\n", rx_buf_phys_addr);
  smp_wmb();
  iowrite32((uint32_t)rx_buf_phys_addr, &nbp_q_regs->tx_mem_low);
  smp_wmb();
  iowrite32((uint32_t)(rx_buf_phys_addr >> 32), &nbp_q_regs->tx_mem_high);

  notif_buf_pair->allocated = true;

  up(&dev_bk->sem);

  return 0;
}

/**
 * send_tx_pipe() - Send a TxPipe to the NIC.
 *
 * @chr_dev_bk: Structure containing information about the current
 *              character file handle.
 * @uarg:       struct enso_send_tx_pipe_params sent from the userspace.
 *
 * Return: 0 if successful, negative error code otherwise.
 *
 */
static long send_tx_pipe(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg) {
  struct enso_send_tx_pipe_params stpp;
  struct notification_buf_pair *notif_buf_pair = chr_dev_bk->notif_buf_pair;
  struct tx_notification* tx_buf;
  struct tx_notification* new_tx_notification;
  struct dev_bookkeep *dev_bk;
  uint32_t tx_tail;
  uint32_t missing_bytes;
  uint32_t missing_bytes_in_page;
  uint8_t wrap_tracker_mask;

  uint64_t transf_addr;
  uint64_t hugepage_mask;
  uint64_t hugepage_base_addr;
  uint64_t hugepage_boundary;
  uint64_t huge_page_offset;
  uint32_t free_slots;
  uint32_t req_length;

  uint32_t buf_page_size = HUGE_PAGE_SIZE;

  // printk(KERN_CRIT "Send TX Pipe\n");
  if (copy_from_user(&stpp, (void __user *)uarg, sizeof(stpp))) {
    printk("couldn't copy arg from user.");
    return -EFAULT;
  }

  if(notif_buf_pair == NULL) {
    printk("Notification buffer is invalid");
    return -EFAULT;
  }
  dev_bk = chr_dev_bk->dev_bk;

  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.");
    return -ERESTARTSYS;
  }

  tx_buf = notif_buf_pair->tx_buf;
  tx_tail = notif_buf_pair->tx_tail;
  missing_bytes = stpp.len;

  transf_addr = stpp.phys_addr;
  hugepage_mask = ~((uint64_t)buf_page_size - 1);
  hugepage_base_addr = transf_addr & hugepage_mask;
  hugepage_boundary = hugepage_base_addr + buf_page_size;

  //printk("Send request received from: %llx, %x, %x\n", stpp.phys_addr, stpp.len, stpp.id);

  while (missing_bytes > 0) {
    free_slots = (notif_buf_pair->tx_head - tx_tail - 1) % NOTIFICATION_BUF_SIZE;

    // Block until we can send.
    while (unlikely(free_slots == 0)) {
      ++notif_buf_pair->tx_full_cnt;
      update_tx_head(notif_buf_pair);
      free_slots =
          (notif_buf_pair->tx_head - tx_tail - 1) % NOTIFICATION_BUF_SIZE;
    }

    new_tx_notification = tx_buf + tx_tail;
    req_length = (missing_bytes < MAX_TRANSFER_LEN) ? missing_bytes : MAX_TRANSFER_LEN;
    missing_bytes_in_page = hugepage_boundary - transf_addr;
    req_length = (req_length < missing_bytes_in_page) ? req_length : missing_bytes_in_page;

    // If the transmission needs to be split among multiple requests, we
    // need to set a bit in the wrap tracker.
    wrap_tracker_mask = (missing_bytes > req_length) << (tx_tail & 0x7);
    notif_buf_pair->wrap_tracker[tx_tail / 8] |= wrap_tracker_mask;

    new_tx_notification->length = req_length;
    new_tx_notification->signal = 1;
    new_tx_notification->phys_addr = transf_addr;

    huge_page_offset = (transf_addr + req_length) % (HUGE_PAGE_SIZE);
    transf_addr = hugepage_base_addr + huge_page_offset;

    tx_tail = (tx_tail + 1) % NOTIFICATION_BUF_SIZE;
    missing_bytes -= req_length;
  }

  notif_buf_pair->tx_tail = tx_tail;
  smp_wmb();
  iowrite32(tx_tail, notif_buf_pair->tx_tail_ptr);

  // req_length = 0;
  // while(req_length < 27500) {
  //   asm("nop");
  //   req_length++;
  // }

  up(&dev_bk->sem);

  return 0;
}

/**
 * get_unreported_completions() - Returns a count of the number of unreported
 *                                TX notifications that have been marked completed
 *                                by the NIC but the application has not freed their buffer.
 *
 * @chr_dev_bk: Structure containing information about the current
 *              character file handle.
 * @user_addr:  Copy the unreported count to this variable in userspace.
 *
 */
static long get_unreported_completions(struct chr_dev_bookkeep *chr_dev_bk, unsigned int __user *user_addr) {
  struct dev_bookkeep *dev_bk;
  uint32_t completions;
  struct notification_buf_pair *notif_buf_pair;

  notif_buf_pair = chr_dev_bk->notif_buf_pair;
  dev_bk = chr_dev_bk->dev_bk;
  // printk(KERN_CRIT "get_unreported_completions\n");
  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.");
    return -ERESTARTSYS;
  }
  if(notif_buf_pair == NULL) {
    printk("Notification buf pair is NULL");
    return -EINVAL;
  }

  // first we update the tx head
  update_tx_head(notif_buf_pair);
  completions = notif_buf_pair->nb_unreported_completions;
  if (copy_to_user(user_addr, &completions, sizeof(completions))) {
    printk("couldn't copy information to user.");
    return -EFAULT;
  }
  notif_buf_pair->nb_unreported_completions = 0; // reset
  up(&dev_bk->sem);
  return 0;
}

/**
 * send_config() - Send a configuration message to the NIC.
 *
 * @chr_dev_bk: Structure containing information about the current
 *              character file handle.
 * @uarg:       struct tx_notification sent from the userspace.
 *
 * Return: 0 if successful, negative error code otherwise.
 */
static long send_config(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg) {
  struct notification_buf_pair *notif_buf_pair = chr_dev_bk->notif_buf_pair;
  struct tx_notification* tx_buf = notif_buf_pair->tx_buf;
  uint32_t tx_tail = notif_buf_pair->tx_tail;
  uint32_t free_slots =
      (notif_buf_pair->tx_head - tx_tail - 1) % NOTIFICATION_BUF_SIZE;
  struct tx_notification *tx_notification;
  struct tx_notification config_notification;
  struct dev_bookkeep *dev_bk;
  uint32_t nb_unreported_completions;

  if (copy_from_user(&config_notification, (void __user *)uarg, sizeof(config_notification))) {
    printk("couldn't copy arg from user.");
    return -EFAULT;
  }

  dev_bk = chr_dev_bk->dev_bk;
  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.");
    return -ERESTARTSYS;
  }

  // Make sure it's a config notification.
  if (config_notification.signal < 2) {
    return -EFAULT;
  }

  // Block until we can send.
  while (unlikely(free_slots == 0)) {
    ++notif_buf_pair->tx_full_cnt;
    update_tx_head(notif_buf_pair);
    free_slots =
        (notif_buf_pair->tx_head - tx_tail - 1) % NOTIFICATION_BUF_SIZE;
  }

  tx_notification = tx_buf + tx_tail;
  *tx_notification = config_notification;

  tx_tail = (tx_tail + 1) % NOTIFICATION_BUF_SIZE;
  notif_buf_pair->tx_tail = tx_tail;

  smp_wmb();
  iowrite32(tx_tail, notif_buf_pair->tx_tail_ptr);

  // Wait for request to be consumed.
  nb_unreported_completions = notif_buf_pair->nb_unreported_completions;
  while (notif_buf_pair->nb_unreported_completions ==
         nb_unreported_completions) {
    update_tx_head(notif_buf_pair);
  }
  notif_buf_pair->nb_unreported_completions = nb_unreported_completions;

  up(&dev_bk->sem);

  return 0;
}

static long alloc_rx_pipe(struct chr_dev_bookkeep *chr_dev_bk,
                               unsigned long uarg) {
  struct enso_pipe_init_params params;
  struct dev_bookkeep *dev_bk;
  struct rx_pipe_internal **rx_pipes;
  struct rx_pipe_internal *new_enso_rx_pipe;
  uint8_t *bar2_addr;
  struct queue_regs *rep_q_regs;
  int32_t pipe_id;
  uint64_t rx_buf_phys_addr;

  dev_bk = chr_dev_bk->dev_bk;

  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.");
    return -ERESTARTSYS;
  }

  if (copy_from_user(&params, (void __user *)uarg, sizeof(params))) {
    printk("couldn't copy arg from user.");
    return -EFAULT;
  }

  pipe_id = params.id;
  printk("Allocating enso RX pipe with ID = %d\n", pipe_id);
  rx_pipes = chr_dev_bk->rx_pipes;
  if(rx_pipes == NULL) {
    printk("Enso pipes not allocated\n");
    return -EINVAL;
  }
  // check if pipe already allocated
  if(rx_pipes[pipe_id]) {
    if(rx_pipes[pipe_id]->allocated) {
      printk("Rx enso pipe already allocated.\n");
      return -EINVAL;
    }
  }
  new_enso_rx_pipe = kzalloc(sizeof(struct rx_pipe_internal), GFP_KERNEL);
  if(new_enso_rx_pipe == NULL) {
    printk("Memory failure\n");
    return -ENOMEM;
  }
  new_enso_rx_pipe->id = pipe_id;

  // 2. Map BAR into queue regs
  bar2_addr = (uint8_t *) global_bk.intel_enso->base_addr;
  rep_q_regs = (struct queue_regs *)(bar2_addr
                                   + (pipe_id
                                   * MEM_PER_QUEUE));
  new_enso_rx_pipe->regs = (struct queue_regs *) rep_q_regs;

  // initialize the queue
  smp_wmb();
  iowrite32(0, &rep_q_regs->rx_mem_low);
  smp_wmb();
  iowrite32(0, &rep_q_regs->rx_mem_high);

  smp_rmb();
  while(ioread32(&rep_q_regs->rx_mem_low) != 0)
      continue;
  smp_rmb();
  while(ioread32(&rep_q_regs->rx_mem_high) != 0)
      continue;

  smp_wmb();
  iowrite32(0, &rep_q_regs->rx_tail);
  smp_rmb();
  while(ioread32(&rep_q_regs->rx_tail) != 0)
      continue;

  smp_wmb();
  iowrite32(0, &rep_q_regs->rx_head);
  smp_rmb();
  while(ioread32(&rep_q_regs->rx_head) != 0)
      continue;

  new_enso_rx_pipe->buf_head_ptr = (uint32_t*)&rep_q_regs->rx_head;
  new_enso_rx_pipe->rx_head = 0;
  new_enso_rx_pipe->rx_tail = 0;

  chr_dev_bk->notif_buf_pair->pending_rx_pipe_tails[pipe_id] = new_enso_rx_pipe->rx_head;
  rx_buf_phys_addr = params.phys_addr;

  smp_wmb();
  iowrite32((uint32_t)rx_buf_phys_addr + chr_dev_bk->notif_buf_pair->id,
            &rep_q_regs->rx_mem_low);
  smp_wmb();
  iowrite32((uint32_t)(rx_buf_phys_addr >> 32), &rep_q_regs->rx_mem_high);

  new_enso_rx_pipe->allocated = true;
  rx_pipes[pipe_id] = new_enso_rx_pipe;

  up(&dev_bk->sem);

  return 0;
}

static long free_rx_pipe_id(struct chr_dev_bookkeep *chr_dev_bk,
                         unsigned long uarg) {
  struct dev_bookkeep *dev_bk;
  struct rx_pipe_internal **rx_pipes;
  int32_t pipe_id = (int32_t)uarg;

  rx_pipes = chr_dev_bk->rx_pipes;
  if(rx_pipes[pipe_id] == NULL) {
    printk("Pipe id %d does not exist\n", pipe_id);
    return -EFAULT;
  }
  dev_bk = chr_dev_bk->dev_bk;

  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.");
    return -ERESTARTSYS;
  }

  free_rx_pipe(rx_pipes[pipe_id]);

  up(&dev_bk->sem);

  return 0;
}

static long consume_rx_pipe(struct chr_dev_bookkeep *chr_dev_bk,
                            unsigned long uarg) {
  struct dev_bookkeep *dev_bk;
  struct notification_buf_pair *notif_buf_pair;
  struct rx_pipe_internal **rx_pipes;
  struct rx_pipe_internal *pipe;
  struct enso_consume_rx_params params;
  uint32_t flit_aligned_size = 0;
  int32_t pipe_id;

  dev_bk = chr_dev_bk->dev_bk;
  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.");
    return -ERESTARTSYS;
  }

  if (copy_from_user(&params, (struct enso_consume_rx_params __user *)uarg,
                    sizeof(struct enso_consume_rx_params))) {
    printk("couldn't copy arg from user.");
    up(&dev_bk->sem);
    return -EFAULT;
  }

  notif_buf_pair = chr_dev_bk->notif_buf_pair;
  rx_pipes = chr_dev_bk->rx_pipes;

  // in case the userspace sets the pipe_id properly, we need to fetch the
  // new tails for that specific pipe_id. otherwise, if pipe_id is -1,
  // we check which pipe_id is now available and send it back to the userspace
  if(params.id != -1) {
    get_new_tails(notif_buf_pair);
    pipe_id = params.id;
  } else {
    pipe_id = get_next_rx_pipe(notif_buf_pair, rx_pipes);
    if(pipe_id == -1) {
        // no new pipes are available to be fetched from
        // return back to userspace
        up(&dev_bk->sem);
        return 0;
    }
    params.id = pipe_id;
  }

  pipe = rx_pipes[pipe_id];
  if(pipe == NULL) {
    printk("No pipe with ID = %d\n", pipe_id);
    up(&dev_bk->sem);
    return -EFAULT;
  }

  // now get the new rx pipe tail
  flit_aligned_size = consume_queue(notif_buf_pair, pipe, &params.new_rx_tail);

  if (copy_to_user((struct enso_consume_rx_params __user *)uarg, &params,
                  sizeof(struct enso_consume_rx_params))) {
    printk("couldn't copy head to user.");
    up(&dev_bk->sem);
    return -EFAULT;
  }

  up(&dev_bk->sem);

  return flit_aligned_size;
}

static long fully_advance_pipe(struct chr_dev_bookkeep *chr_dev_bk,
                               unsigned long uarg) {
  struct dev_bookkeep *dev_bk;
  struct rx_pipe_internal **rx_enso_pipes;
  struct rx_pipe_internal *pipe;
  uint32_t enso_pipe_id;

  dev_bk = chr_dev_bk->dev_bk;
  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.");
    return -ERESTARTSYS;
  }

  if (copy_from_user(&enso_pipe_id, (void __user *)uarg, sizeof(enso_pipe_id))) {
    printk("couldn't copy arg from user.");
    return -EFAULT;
  }

  rx_enso_pipes = chr_dev_bk->rx_pipes;
  pipe = rx_enso_pipes[enso_pipe_id];
  if(pipe == NULL) {
      printk("Pipe ID %d is NULL\n", enso_pipe_id);
      return -EFAULT;
  }
  smp_wmb();
  iowrite32(pipe->rx_tail, pipe->buf_head_ptr);
  pipe->rx_head = pipe->rx_tail;

  up(&dev_bk->sem);
  return 0;
}

static long advance_pipe(struct chr_dev_bookkeep *chr_dev_bk,
                         unsigned long uarg) {
  struct dev_bookkeep *dev_bk;
  struct rx_pipe_internal **rx_enso_pipes;
  struct rx_pipe_internal *pipe;
  uint32_t enso_pipe_id;
  size_t len;
  struct enso_advance_pipe_params param;
  uint32_t rx_pkt_head;
  uint32_t nb_flits;

  dev_bk = chr_dev_bk->dev_bk;
  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.");
    return -ERESTARTSYS;
  }

  if (copy_from_user(&param, (struct enso_advance_pipe_params __user *)uarg,
                     sizeof(struct enso_advance_pipe_params))) {
    printk("couldn't copy arg from user.");
    return -EFAULT;
  }

  enso_pipe_id = param.id;
  len = param.len;
  rx_enso_pipes = chr_dev_bk->rx_pipes;
  pipe = rx_enso_pipes[enso_pipe_id];
  if(pipe == NULL) {
      printk("Pipe ID %d is NULL\n", enso_pipe_id);
      return -EFAULT;
  }

  rx_pkt_head = pipe->rx_head;
  nb_flits = ((uint64_t)len - 1) / 64 + 1;
  rx_pkt_head = (rx_pkt_head + nb_flits) % ENSO_PIPE_SIZE;

  smp_wmb();
  iowrite32(rx_pkt_head, pipe->buf_head_ptr);
  pipe->rx_head = rx_pkt_head;

  up(&dev_bk->sem);
  return 0;
}

static long get_next_batch(struct chr_dev_bookkeep *chr_dev_bk,
                           unsigned long uarg) {
  struct dev_bookkeep *dev_bk;
  struct notification_buf_pair *notif_buf_pair;
  struct rx_pipe_internal **rx_pipes;
  struct rx_pipe_internal *pipe;
  struct enso_get_next_batch_params params;
  uint32_t flit_aligned_size = 0;
  int32_t enso_pipe_id;

  dev_bk = chr_dev_bk->dev_bk;
  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.");
    return -ERESTARTSYS;
  }

  if (copy_from_user(&params, (struct enso_get_next_batch_params __user *)uarg,
                    sizeof(struct enso_get_next_batch_params))) {
    printk("couldn't copy arg from user.");
    return -EFAULT;
  }

  notif_buf_pair = chr_dev_bk->notif_buf_pair;

  enso_pipe_id = get_next_pipe_id(notif_buf_pair);
  params.pipe_id = enso_pipe_id;
  if(enso_pipe_id == -1) {
    up(&dev_bk->sem);
    return -EFAULT;
  }
  rx_pipes = chr_dev_bk->rx_pipes;
  pipe = rx_pipes[enso_pipe_id];
  if(pipe == NULL) {
    printk("No pipe with ID = %d\n", enso_pipe_id);
    up(&dev_bk->sem);
    return -EFAULT;
  }

  flit_aligned_size = consume_queue(notif_buf_pair, pipe, &params.new_rx_tail);

  if (copy_to_user((struct enso_get_next_batch_params __user *)uarg, &params,
                  sizeof(struct enso_get_next_batch_params))) {
    printk("couldn't copy head to user.");
    up(&dev_bk->sem);
    return -EFAULT;
  }

  up(&dev_bk->sem);

  return flit_aligned_size;
}

static long next_rx_pipe_to_recv(struct chr_dev_bookkeep *chr_dev_bk,
                                 unsigned long uarg) {
  struct dev_bookkeep *dev_bk;
  struct rx_pipe_internal **rx_enso_pipes;
  struct rx_pipe_internal *pipe;
  struct notification_buf_pair *notif_buf_pair;
  int32_t pipe_id;
  uint32_t enso_pipe_head;
  uint32_t enso_pipe_tail;

  (void) uarg;
  dev_bk = chr_dev_bk->dev_bk;
  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.");
    return -ERESTARTSYS;
  }

  notif_buf_pair = chr_dev_bk->notif_buf_pair;
  rx_enso_pipes = chr_dev_bk->rx_pipes;

  pipe_id = get_next_pipe_id(notif_buf_pair);
  while(pipe_id >= 0) {
    pipe = rx_enso_pipes[pipe_id];
    if(pipe == NULL) {
      printk("Pipe ID = %d is NULL\n", pipe_id);
      return -1;
    }
    enso_pipe_head = pipe->rx_tail;
    enso_pipe_tail = notif_buf_pair->pending_rx_pipe_tails[pipe_id];
    if(enso_pipe_head != enso_pipe_tail) {
      smp_wmb();
      iowrite32(pipe->rx_head, pipe->buf_head_ptr);
      break;
    }
    pipe_id = get_next_pipe_id(notif_buf_pair);
  }

  up(&dev_bk->sem);
  return pipe_id;
}

static long prefetch_pipe(struct chr_dev_bookkeep *chr_dev_bk,
                          unsigned long uarg) {
  struct dev_bookkeep *dev_bk;
  struct rx_pipe_internal **rx_enso_pipes;
  struct rx_pipe_internal *pipe;
  struct notification_buf_pair *notif_buf_pair;
  int32_t pipe_id;

  dev_bk = chr_dev_bk->dev_bk;
  if (unlikely(down_interruptible(&dev_bk->sem))) {
    printk("interrupted while attempting to obtain device semaphore.");
    return -ERESTARTSYS;
  }

  if (copy_from_user(&pipe_id, (void __user *)uarg, sizeof(pipe_id))) {
    printk("couldn't copy arg from user.");
    return -EFAULT;
  }

  notif_buf_pair = chr_dev_bk->notif_buf_pair;
  rx_enso_pipes = chr_dev_bk->rx_pipes;
  pipe = rx_enso_pipes[pipe_id];

  if(pipe == NULL) {
      printk("Pipe ID %d is NULL\n", pipe_id);
      return -EFAULT;
  }

  smp_wmb();
  iowrite32(pipe->rx_head, pipe->buf_head_ptr);

  up(&dev_bk->sem);
  return pipe_id;
}

/******************************************************************************
 * Helper functions
 *****************************************************************************/
/**
 * free_rx_tx_buf() - Frees the RX/TX notification buffers.
 *                    Helper function to alloc_notif_buf_pair.
 *
 * @chr_dev_bk: Structure containing information about the current
 *              character file handle.
 */
void free_rx_tx_buf(struct chr_dev_bookkeep *chr_dev_bk) {
  // Each RX/TX notification buffer is 2MB in size. There are
  // 512 4KB pages in one rx/tx buffer.
  size_t rx_tx_buf_size = 512 * PAGE_SIZE;
  uint32_t page_ind = 0;
  struct rx_notification *rx_notif = NULL;
  if(chr_dev_bk == NULL) {
    return;
  }
  if(chr_dev_bk->notif_buf_pair == NULL) {
    return;
  }
  rx_notif = chr_dev_bk->notif_buf_pair->rx_buf;
  for(;page_ind < rx_tx_buf_size;
       page_ind += PAGE_SIZE) {
    ClearPageReserved(virt_to_page(((unsigned long)rx_notif) + page_ind));
  }
  kfree(rx_notif);
}

/**
 * update_tx_head() - Checks which TX notifications have been
 *                    processed and updated the relevant pointers
 *                    and variables in the notification_buf_pair.
 *                    Used by send_tx_pipe and get_unreported_completions.
 *
 * @notif_buf_pair: Structure containing information about the notification
 *                  buffer.
 */
// TODO: Fix the magic numbers.
void update_tx_head(struct notification_buf_pair* notif_buf_pair) {
  struct tx_notification* tx_buf = notif_buf_pair->tx_buf;
  uint32_t head = notif_buf_pair->tx_head;
  uint32_t tail = notif_buf_pair->tx_tail;
  struct tx_notification* tx_notif;
  uint16_t i;
  uint8_t wrap_tracker_mask;
  uint8_t no_wrap;

  if (head == tail) {
    return;
  }

  // Advance pointer for pkt queues that were already sent.
  for (i = 0; i < 64; ++i) {
    if (head == tail) {
      break;
    }
    tx_notif = tx_buf + head;

    // Notification has not yet been consumed by hardware.
    if (tx_notif->signal != 0) {
      break;
    }

    // Requests that wrap around need two notifications but should only signal
    // a single completion notification. Therefore, we only increment
    // `nb_unreported_completions` in the second notification.
    // TODO(sadok): If we implement the logic to have two notifications in the
    // same cache line, we can get rid of `wrap_tracker` and instead check
    // for two notifications.
    wrap_tracker_mask = 1 << (head & 0x7);
    no_wrap =
        !(notif_buf_pair->wrap_tracker[head / 8] & wrap_tracker_mask);
    notif_buf_pair->nb_unreported_completions += no_wrap;
    notif_buf_pair->wrap_tracker[head / 8] &= ~wrap_tracker_mask;

    head = (head + 1) % NOTIFICATION_BUF_SIZE;
  }

  notif_buf_pair->tx_head = head;
}

int free_rx_pipe(struct rx_pipe_internal *pipe) {
  struct queue_regs *rep_q_regs;

  if(!pipe->allocated) {
    return 0;
  }

  rep_q_regs = pipe->regs;
  printk("Freeing enso RX pipe ID = %d\n", pipe->id);

  smp_wmb();
  iowrite32(0, &rep_q_regs->rx_mem_low);
  smp_wmb();
  iowrite32(0, &rep_q_regs->rx_mem_high);

  pipe->allocated = false;

  return 0;
}

static uint16_t get_new_tails(struct notification_buf_pair *notif_buf_pair) {
  struct rx_notification* rx_notif;
  struct rx_notification* curr_notif;
  uint32_t notification_buf_head;
  uint16_t next_rx_ids_tail;
  uint16_t nb_consumed_notifications = 0;
  uint32_t enso_pipe_id;
  uint16_t ind = 0;

  rx_notif = notif_buf_pair->rx_buf;
  notification_buf_head = notif_buf_pair->rx_head;
  next_rx_ids_tail = notif_buf_pair->next_rx_ids_tail;

  for (;ind < BATCH_SIZE; ++ind) {
    curr_notif = rx_notif + notification_buf_head;

    // Check if the next notification was updated by the NIC.
    if (curr_notif->signal == 0) {
      break;
    }

    curr_notif->signal = 0;
    notification_buf_head = (notification_buf_head + 1) % NOTIFICATION_BUF_SIZE;

    enso_pipe_id = curr_notif->queue_id;
    notif_buf_pair->pending_rx_pipe_tails[enso_pipe_id] =
        (uint32_t)curr_notif->tail;

    notif_buf_pair->next_rx_pipe_ids[next_rx_ids_tail] = enso_pipe_id;
    next_rx_ids_tail = (next_rx_ids_tail + 1) % NOTIFICATION_BUF_SIZE;

    ++nb_consumed_notifications;
  }

  notif_buf_pair->next_rx_ids_tail = next_rx_ids_tail;

  if (likely(nb_consumed_notifications > 0)) {
    // Update notification buffer head.
    smp_wmb();
    iowrite32(notification_buf_head, notif_buf_pair->rx_head_ptr);
    notif_buf_pair->rx_head = notification_buf_head;
  }
  return nb_consumed_notifications;
}

static uint32_t consume_queue(struct notification_buf_pair *notif_buf_pair,
                              struct rx_pipe_internal *pipe,
                              uint32_t *new_rx_tail) {
  uint32_t enso_pipe_head;
  uint32_t flit_aligned_size = 0;
  uint32_t enso_pipe_id;
  uint32_t enso_pipe_new_tail;

  enso_pipe_head = pipe->rx_tail;
  enso_pipe_id = pipe->id; // get the pipe id from the userspace
  enso_pipe_new_tail = notif_buf_pair->pending_rx_pipe_tails[enso_pipe_id];
  if(enso_pipe_new_tail == enso_pipe_head) {
      return 0;
  }
  flit_aligned_size = ((enso_pipe_new_tail - enso_pipe_head)
                                % ENSO_PIPE_SIZE) * 64;
  // we update the rx tail in the kernel
  enso_pipe_head = (enso_pipe_head + flit_aligned_size / 64)
                   % ENSO_PIPE_SIZE;
  pipe->rx_tail = enso_pipe_head;
  // we send this back to the application
  *new_rx_tail = enso_pipe_head;
  return flit_aligned_size;
}

static int32_t get_next_pipe_id(struct notification_buf_pair *notif_buf_pair) {
  uint16_t next_rx_ids_head;
  uint16_t next_rx_ids_tail;
  uint16_t nb_consumed_notifications = 0;
  int32_t enso_pipe_id;

  next_rx_ids_head = notif_buf_pair->next_rx_ids_head;
  next_rx_ids_tail = notif_buf_pair->next_rx_ids_tail;

  if (next_rx_ids_head == next_rx_ids_tail) {
    nb_consumed_notifications = get_new_tails(notif_buf_pair);
    if (unlikely(nb_consumed_notifications == 0)) {
      return -1;
    }
  }

  enso_pipe_id = notif_buf_pair->next_rx_pipe_ids[next_rx_ids_head];

  notif_buf_pair->next_rx_ids_head =
                 (next_rx_ids_head + 1) % NOTIFICATION_BUF_SIZE;

  return enso_pipe_id;
}

static int32_t get_next_rx_pipe(struct notification_buf_pair *notif_buf_pair,
                                struct rx_pipe_internal **rx_enso_pipes) {
  struct rx_pipe_internal *pipe;
  int32_t pipe_id;
  uint32_t enso_pipe_head;
  uint32_t enso_pipe_tail;

  pipe_id = get_next_pipe_id(notif_buf_pair);
  while(pipe_id >= 0) {
    pipe = rx_enso_pipes[pipe_id];
    if(pipe == NULL) {
      printk("Pipe ID = %d is NULL\n", pipe_id);
      return -1;
    }
    enso_pipe_head = pipe->rx_tail;
    enso_pipe_tail = notif_buf_pair->pending_rx_pipe_tails[pipe_id];
    if(enso_pipe_head != enso_pipe_tail) {
      smp_wmb();
      iowrite32(pipe->rx_head, pipe->buf_head_ptr);
      break;
    }
    pipe_id = get_next_pipe_id(notif_buf_pair);
  }

  return pipe_id;
}
