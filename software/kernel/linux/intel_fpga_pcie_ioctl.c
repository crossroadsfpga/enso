/*
 * Copyright (c) 2017-2018, Intel Corporation.
 * Intel, the Intel logo, Intel, MegaCore, NIOS II, Quartus and TalkBack
 * words and logos are trademarks of Intel Corporation or its subsidiaries
 * in the U.S. and/or other countries. Other marks and brands may be
 * claimed as the property of others. See Trademarks on intel.com for
 * full list of Intel trademarks or the Trademarks & Brands Names Database
 * (if Intel) or see www.intel.com/legal (if Altera).
 * All rights reserved.
 *
 * This software is available to you under a choice of one of two
 * licenses. You may choose to be licensed under the terms of the GNU
 * General Public License (GPL) Version 2, available from the file
 * COPYING in the main directory of this source tree, or the
 * BSD 3-Clause license below:
 *
 *     Redistribution and use in source and binary forms, with or
 *     without modification, are permitted provided that the following
 *     conditions are met:
 *
 *      - Redistributions of source code must retain the above
 *        copyright notice, this list of conditions and the following
 *        disclaimer.
 *
 *      - Redistributions in binary form must reproduce the above
 *        copyright notice, this list of conditions and the following
 *        disclaimer in the documentation and/or other materials
 *        provided with the distribution.
 *
 *      - Neither Intel nor the names of its contributors may be
 *        used to endorse or promote products derived from this
 *        software without specific prior written permission.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include "intel_fpga_pcie_ioctl.h"

#include "intel_fpga_pcie.h"
#include "intel_fpga_pcie_dma.h"
#include "intel_fpga_pcie_setup.h"

// In bytes
#define FPGA2CPU_OFFSET 8
#define CPU2FPGA_OFFSET 24

/******************************************************************************
 * Static function prototypes
 *****************************************************************************/
static long sel_dev(struct chr_dev_bookkeep *dev_bk, unsigned long new_bdf);
static long get_dev(struct chr_dev_bookkeep *chr_dev_bk,
                    unsigned int __user *user_addr);
static long sel_bar(struct chr_dev_bookkeep *dev_bk, unsigned long new_bar);
static long get_bar(struct chr_dev_bookkeep *chr_dev_bk,
                    unsigned int __user *user_addr);
static long checked_cfg_access(struct pci_dev *dev, unsigned long uarg);
static long set_kmem_size(struct dev_bookkeep *dev_bk, unsigned long uarg);
static long get_uio_dev_name(struct chr_dev_bookkeep *chr_dev_bk,
                             char __user *user_addr);
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

/******************************************************************************
 * Device and I/O control function
 *****************************************************************************/
/**
 * intel_fpga_pcie_unlocked_ioctl() - Responds to the system call ioctl(2).
 * @filp: Pointer to file struct.
 * @cmd:  The command value corresponding to some desired action.
 * @uarg: Optional argument passed to the system call. This could actually
 *        be data or it could be a pointer to some structure which has been
 *        casted.
 *
 * Return: 0 on success, negative error code on failure.
 */
long intel_fpga_pcie_unlocked_ioctl(struct file *filp, unsigned int cmd,
                                    unsigned long uarg) {
  struct chr_dev_bookkeep *chr_dev_bk;
  struct dev_bookkeep *dev_bk;
  long retval = 0;
  int numvfs;

  if (unlikely(_IOC_TYPE(cmd) != INTEL_FPGA_PCIE_IOCTL_MAGIC)) {
    INTEL_FPGA_PCIE_VERBOSE_DEBUG(
        "ioctl called with wrong magic "
        "number: %d",
        _IOC_TYPE(cmd));
    return -ENOTTY;
  }

  if (unlikely(_IOC_NR(cmd) > INTEL_FPGA_PCIE_IOCTL_MAXNR)) {
    INTEL_FPGA_PCIE_VERBOSE_DEBUG(
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
    retval = !access_ok((void __user *)uarg, _IOC_SIZE(cmd));
  } else if (_IOC_DIR(cmd) & _IOC_WRITE) {
    retval = !access_ok((void __user *)uarg, _IOC_SIZE(cmd));
  }
#endif

  if (unlikely(retval)) {
    INTEL_FPGA_PCIE_DEBUG("ioctl access violation.");
    return -EFAULT;
  }

  // Retrieve bookkeeping information.
  chr_dev_bk = filp->private_data;
  dev_bk = chr_dev_bk->dev_bk;

  // Determine access type.
  switch (cmd) {
    case INTEL_FPGA_PCIE_IOCTL_CHR_SEL_DEV:
      retval = sel_dev(chr_dev_bk, uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_CHR_GET_DEV:
      retval = get_dev(chr_dev_bk, (unsigned int __user *)uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_CHR_SEL_BAR:
      retval = sel_bar(chr_dev_bk, uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_CHR_GET_BAR:
      retval = get_bar(chr_dev_bk, (unsigned int __user *)uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_CHR_USE_CMD:
      chr_dev_bk->use_cmd = (bool)uarg;
      break;
    case INTEL_FPGA_PCIE_IOCTL_CFG_ACCESS:
      retval = checked_cfg_access(dev_bk->dev, uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_SRIOV_NUMVFS:
      numvfs = intel_fpga_pcie_sriov_configure(dev_bk->dev, (int)uarg);

      // SR-IOV configure returns number of VFs enabled.
      if (numvfs == (int)uarg)
        retval = 0;
      else if (numvfs > 0)
        retval = -ENODEV;
      else
        retval = (long)numvfs;
      break;
    case INTEL_FPGA_PCIE_IOCTL_SET_KMEM_SIZE:
      retval = set_kmem_size(dev_bk, uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_DMA_QUEUE:
      retval = intel_fpga_pcie_dma_queue(dev_bk, uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_DMA_SEND:
      retval = intel_fpga_pcie_dma_send(dev_bk, uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_CHR_GET_UIO_DEV_NAME:
      retval = get_uio_dev_name(chr_dev_bk, (char __user *)uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_GET_NB_FALLBACK_QUEUES:
      retval = get_nb_fallback_queues(dev_bk, (unsigned int __user *)uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_SET_RR_STATUS:
      retval = set_rr_status(dev_bk, (bool)uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_GET_RR_STATUS:
      retval = get_rr_status(dev_bk, (bool __user *)uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_ALLOC_NOTIF_BUFFER:
      retval = alloc_notif_buffer(chr_dev_bk, (unsigned int __user *)uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_FREE_NOTIF_BUFFER:
      retval = free_notif_buffer(chr_dev_bk, uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_ALLOC_PIPE:
      retval = alloc_pipe(chr_dev_bk, (unsigned int __user *)uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_FREE_PIPE:
      retval = free_pipe(chr_dev_bk, uarg);
      break;
    default:
      retval = -ENOTTY;
  }

  return retval;
}

/******************************************************************************
 * Helper functions
 *****************************************************************************/
/**
 * sel_dev() - Switches the selected device to a potentially different
 *             device.
 *
 * @chr_dev_bk: Structure containing information about the current
 *              character file handle.
 * @new_bdf:    The BDF of the potentially different device to select.
 *
 * Searches through the list of devices probed by this driver. If a device
 * with matching BDF is found, it is selected to be accessed by the
 * particular file handle. During this process, both old and new devices'
 * bookkeeping structures are locked to ensure consistency.
 *
 * Return: 0 if successful, negative error code otherwise.
 */
static long sel_dev(struct chr_dev_bookkeep *chr_dev_bk,
                    unsigned long new_bdf) {
  struct dev_bookkeep *new_dev_bk, *old_dev_bk;
  unsigned long old_bdf;

  // Search for device with new BDF number.
  if (unlikely(mutex_lock_interruptible(&global_bk.lock))) {
    INTEL_FPGA_PCIE_DEBUG(
        "interrupted while attempting to obtain "
        "global lock.");
    return -ERESTARTSYS;
  }
  new_dev_bk = radix_tree_lookup(&global_bk.dev_tree, new_bdf);
  mutex_unlock(&global_bk.lock);

  if (new_dev_bk == NULL) {
    INTEL_FPGA_PCIE_DEBUG("could not find device with BDF %04lx.", new_bdf);
    return -ENODEV;
  }

  old_dev_bk = chr_dev_bk->dev_bk;
  old_bdf = old_dev_bk->bdf;

  if (old_bdf == new_bdf) {
    // 'Switched' to the same BDF! No bookkeeping update required; exit.
    INTEL_FPGA_PCIE_VERBOSE_DEBUG("didn't have to change device.");
    return 0;
  } else if (likely(old_bdf < new_bdf)) {
    /*
     * Two semaphores required - always obtain lower-numbered
     * BDF's lock first to avoid deadlock. The old BDF should
     * typically be lower since default device selected always
     * has the lowest BDF, and it is not expected that the
     * selected device is changed more than once.
     */
    if (unlikely(down_interruptible(&old_dev_bk->sem))) {
      INTEL_FPGA_PCIE_DEBUG(
          "interrupted while attempting to obtain "
          "old device semaphore.");
      return -ERESTARTSYS;
    }
    if (unlikely(down_interruptible(&new_dev_bk->sem))) {
      INTEL_FPGA_PCIE_DEBUG(
          "interrupted while attempting to obtain "
          "new device semaphore.");
      up(&old_dev_bk->sem);
      return -ERESTARTSYS;
    }
  } else {
    if (unlikely(down_interruptible(&new_dev_bk->sem))) {
      INTEL_FPGA_PCIE_DEBUG(
          "interrupted while attempting to obtain "
          "new device semaphore.");
      return -ERESTARTSYS;
    }
    if (unlikely(down_interruptible(&old_dev_bk->sem))) {
      up(&new_dev_bk->sem);
      INTEL_FPGA_PCIE_DEBUG(
          "interrupted while attempting to obtain "
          "old device semaphore.");
      return -ERESTARTSYS;
    }
  }

  // Update counters
  --old_dev_bk->chr_open_cnt;
  ++new_dev_bk->chr_open_cnt;

  // Release order doesn't matter.
  up(&old_dev_bk->sem);
  up(&new_dev_bk->sem);

  chr_dev_bk->dev_bk = new_dev_bk;
  return 0;
}

/**
 * get_dev() - Copies the currently selected device's BDF to the user.
 *
 * @chr_dev_bk: Structure containing information about the current
 *              character file handle.
 * @user_addr:  Address to an unsigned int in user-space.
 *
 * Return: 0 if successful, negative error code otherwise.
 */
static long get_dev(struct chr_dev_bookkeep *chr_dev_bk,
                    unsigned int __user *user_addr) {
  struct dev_bookkeep *dev_bk;
  unsigned int bdf;

  dev_bk = chr_dev_bk->dev_bk;
  bdf = (unsigned int)dev_bk->bdf;

  if (copy_to_user(user_addr, &bdf, sizeof(bdf))) {
    INTEL_FPGA_PCIE_DEBUG("couldn't copy BDF information to user.");
    return -EFAULT;
  }

  return 0;
}

/**
 * get_uio_dev_name() - Copies the currently selected device's uio device name
 *                      to userspace.
 *
 * @chr_dev_bk: Structure containing information about the current
 *              character file handle.
 * @user_addr:  Address to a string buffer in user-space.
 *
 * Return: 0 if successful, negative error code otherwise.
 */
static long get_uio_dev_name(struct chr_dev_bookkeep *chr_dev_bk,
                             char __user *user_addr) {
  struct dev_bookkeep *dev_bk;
  const char *dev_name;
  size_t dev_name_size;

  dev_bk = chr_dev_bk->dev_bk;
  dev_name = dev_bk->info.uio_dev->dev.kobj.name;

  if (dev_name == NULL) {
    INTEL_FPGA_PCIE_DEBUG("couldn't get uio device name.");
    return -EFAULT;
  }

  dev_name_size = strlen(dev_name);

  if (copy_to_user(user_addr, dev_name, dev_name_size)) {
    INTEL_FPGA_PCIE_DEBUG("couldn't copy uio dev information to user.");
    return -EFAULT;
  }

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
    INTEL_FPGA_PCIE_DEBUG("couldn't copy nb_fb_queues information to user.");
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
    INTEL_FPGA_PCIE_DEBUG(
        "interrupted while attempting to obtain "
        "device semaphore.");
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
    INTEL_FPGA_PCIE_DEBUG("couldn't copy rr_status information to user.");
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
    INTEL_FPGA_PCIE_DEBUG(
        "interrupted while attempting to obtain "
        "device semaphore.");
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
    INTEL_FPGA_PCIE_DEBUG("couldn't allocate notification buffer.");
    return -ENOMEM;
  }

  if (copy_to_user(user_addr, &buf_id, sizeof(buf_id))) {
    INTEL_FPGA_PCIE_DEBUG("couldn't copy buf_id information to user.");
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
 */
static long free_notif_buffer(struct chr_dev_bookkeep *chr_dev_bk,
                              unsigned long uarg) {
  int32_t i, j;
  int32_t buf_id = (int32_t)uarg;
  struct dev_bookkeep *dev_bk;

  dev_bk = chr_dev_bk->dev_bk;

  if (unlikely(down_interruptible(&dev_bk->sem))) {
    INTEL_FPGA_PCIE_DEBUG(
        "interrupted while attempting to obtain "
        "device semaphore.");
    return -ERESTARTSYS;
  }

  // Check that the buffer ID is valid.
  if (buf_id < 0 || buf_id >= MAX_NB_APPS) {
    INTEL_FPGA_PCIE_DEBUG("invalid buffer ID.");
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
 */
static long alloc_pipe(struct chr_dev_bookkeep *chr_dev_bk,
                       unsigned int __user *user_addr) {
  int32_t i, j;
  bool is_fallback;
  int32_t pipe_id = -1;
  struct dev_bookkeep *dev_bk;
  dev_bk = chr_dev_bk->dev_bk;

  if (unlikely(down_interruptible(&dev_bk->sem))) {
    INTEL_FPGA_PCIE_DEBUG(
        "interrupted while attempting to obtain "
        "device semaphore.");
    return -ERESTARTSYS;
  }

  if (copy_from_user(&is_fallback, user_addr, 1)) {
    INTEL_FPGA_PCIE_DEBUG("couldn't copy is_fallback information from user.");
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
        INTEL_FPGA_PCIE_DEBUG("fallback pipes are not contiguous.");
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
    INTEL_FPGA_PCIE_DEBUG("couldn't allocate pipe.");
    return -ENOMEM;
  }

  // Set status bit for both the device bitvector and the character device
  // bitvector.
  i = pipe_id / 8;
  j = pipe_id % 8;
  dev_bk->pipe_status[i] |= (1 << j);
  chr_dev_bk->pipe_status[i] |= (1 << j);

  if (copy_to_user(user_addr, &pipe_id, sizeof(pipe_id))) {
    INTEL_FPGA_PCIE_DEBUG("couldn't copy buf_id information to user.");
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
 */
static long free_pipe(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg) {
  int32_t i, j;
  int32_t pipe_id = (int32_t)uarg;
  struct dev_bookkeep *dev_bk;

  dev_bk = chr_dev_bk->dev_bk;

  if (unlikely(down_interruptible(&dev_bk->sem))) {
    INTEL_FPGA_PCIE_DEBUG(
        "interrupted while attempting to obtain "
        "device semaphore.");
    return -ERESTARTSYS;
  }

  // Check that the pipe ID is valid.
  if (pipe_id < 0 || pipe_id >= MAX_NB_FLOWS) {
    INTEL_FPGA_PCIE_DEBUG("invalid pipe ID.");
    return -EINVAL;
  }

  // Check that the pipe ID is allocated.
  i = pipe_id / 8;
  j = pipe_id % 8;
  if (!(chr_dev_bk->pipe_status[i] & (1 << j))) {
    INTEL_FPGA_PCIE_DEBUG("pipe ID is not allocated for this file handle.");
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
 * sel_bar() - Switches the selected device to a potentially different
 *             device.
 *
 * @chr_dev_bk: Structure containing information about the current
 *              character file handle.
 * @new_bar:    The potentially different BAR to select.
 *
 * Return: 0 if successful, negative error code otherwise.
 */
static long sel_bar(struct chr_dev_bookkeep *chr_dev_bk,
                    unsigned long new_bar) {
  if (new_bar >= 6) {
    INTEL_FPGA_PCIE_VERBOSE_DEBUG(
        "requested a BAR number "
        "which is too large.");
    return -EINVAL;
  }

  // Disallow changing of BAR if command structure is being used for comm.
  if (chr_dev_bk->use_cmd) {
    INTEL_FPGA_PCIE_VERBOSE_DEBUG(
        "command structure is in use; "
        "selected BAR will not be changed.");
    return -EPERM;
  }

  // Ensure valid BAR is selected.
  if (chr_dev_bk->dev_bk->bar[new_bar].base_addr == NULL) {
    INTEL_FPGA_PCIE_VERBOSE_DEBUG(
        "requested a BAR number "
        "which is unallocated.");
    return -EINVAL;
  }

  chr_dev_bk->cur_bar_num = new_bar;

  return 0;
}

/**
 * get_bar() - Copies the currently selected device BAR to the user.
 *
 * @chr_dev_bk: Structure containing information about the current
 *              character file handle.
 * @user_addr:  Address to an unsigned int in user-space.
 *
 * Return: 0 if successful, negative error code otherwise.
 */
static long get_bar(struct chr_dev_bookkeep *chr_dev_bk,
                    unsigned int __user *user_addr) {
  unsigned int bar;

  bar = chr_dev_bk->cur_bar_num;

  if (copy_to_user(user_addr, &bar, sizeof(bar))) {
    INTEL_FPGA_PCIE_DEBUG("couldn't copy BAR information to user.");
    return -EFAULT;
  }

  return 0;
}

/**
 * checked_cfg_access() - Do a configuration space access after checking
 *                        access validity.
 * @dev:  PCI device to access.
 * @uarg: Pointer to the IOCTL command structure located
 *        within the user-space.
 *
 * Return: 0 if successful, negative error code otherwise.
 */
static long checked_cfg_access(struct pci_dev *dev, unsigned long uarg) {
  struct intel_fpga_pcie_arg karg;
  uint8_t temp[4];
  int cfg_addr;
  uint32_t count;
  int retval;

  if (copy_from_user(&karg, (void __user *)uarg, sizeof(karg))) {
    INTEL_FPGA_PCIE_DEBUG("couldn't copy arg from user.");
    return -EFAULT;
  }
  count = karg.size;

  // Copy write data from user if writing.
  if (!karg.is_read && copy_from_user(&temp, karg.user_addr, count)) {
    INTEL_FPGA_PCIE_DEBUG("couldn't copy data from user.");
    return -EFAULT;
  }

  if (unlikely(karg.ep_addr > (uint64_t)INT_MAX)) {
    INTEL_FPGA_PCIE_DEBUG("address is out of range.");
    return -EINVAL;
  } else {
    cfg_addr = (int)karg.ep_addr;
  }

  /*
   * Check alignment - this also ensures that the access does not cross
   * out of bounds.
   */
  if (unlikely((cfg_addr % count) != 0)) {
    INTEL_FPGA_PCIE_VERBOSE_DEBUG("config access is misaligned.");
    return -EINVAL;
  }
  if (unlikely(cfg_addr >= 0xC00)) {
    /*
     * Config space extends to 0xFFF according to PCIe specification
     * but the PCIe IP requires >= 0xC00 to be implemented in user space
     * of the FPGA. Without user implementation of cfg access response,
     * the FPGA device may hang.
     */
    INTEL_FPGA_PCIE_VERBOSE_DEBUG("address is out of config space.");
    return -EINVAL;
  }

  // Do access
  if (karg.is_read) {
    switch (count) {
      case 1:
        retval = pci_read_config_byte(dev, cfg_addr, temp);
        break;
      case 2:
        retval = pci_read_config_word(dev, cfg_addr, (uint16_t *)temp);
        break;
      case 4:
        retval = pci_read_config_dword(dev, cfg_addr, (uint32_t *)temp);
        break;
      default:
        INTEL_FPGA_PCIE_VERBOSE_DEBUG("access size is invalid.");
        return -EINVAL;
    }
  } else {
    switch (count) {
      case 1:
        retval = pci_write_config_byte(dev, cfg_addr, temp[0]);
        break;
      case 2:
        retval = pci_write_config_word(dev, cfg_addr, *(uint16_t *)temp);
        break;
      case 4:
        retval = pci_write_config_dword(dev, cfg_addr, *(uint32_t *)temp);
        break;
      default:
        INTEL_FPGA_PCIE_VERBOSE_DEBUG("access size is invalid.");
        return -EINVAL;
    }
  }

  // Copy read data to user if reading.
  if (karg.is_read && copy_to_user(karg.user_addr, &temp, count)) {
    INTEL_FPGA_PCIE_DEBUG("couldn't copy data to user.");
    return -EFAULT;
  }

  return retval;
}

/**
 * set_kmem_size() - If size is non-zero, obtains DMA-capable kernel memory
 *                   for use as a bounce buffer or for scratch memory.
 *
 * @dev_bk:     Pointer to the device bookkeeping structure. The structure
 *              is accessed to retrieve information about existing kernel
 *              memories allocated for the same purpose, and allocated
 *              memory is accessed through this structure.
 *  @uarg:       Pointer to intel_fpga_pcie_ksize structure
 *
 * Obtains DMA-capable kernel memory for use as a bounce buffer or for
 * scratch memory. This memory is accessible through dev_bk structure.
 * Only one such memory can be allocated per device at any time.
 *
 * For simplicity, memory resizing is not supported - previously
 * allocated memory will be freed and replaced by a new memory region.
 * If the new memory region cannot be obtained, the old memory region
 * will be retained.
 *
 *
 * Return: 0 if successful, negative error code otherwise.
 */
static long set_kmem_size(struct dev_bookkeep *dev_bk, unsigned long uarg) {
  long retval = 0;
  struct kmem_info old_info;
  uint32_t kmem_addr_l, kmem_addr_h;
  void *__iomem ep_addr;
  // unsigned long local_size;
  // uint32_t cpu2fpga;
  int core_id;
  unsigned int size;

  struct intel_fpga_pcie_ksize karg;

  if (copy_from_user(&karg, (void __user *)uarg, sizeof(karg))) {
    INTEL_FPGA_PCIE_DEBUG("couldn't copy arg from user.");
    return -EFAULT;
  }

  core_id = karg.core_id;
  size = karg.rx_size + karg.tx_size;

  if (unlikely(down_interruptible(&dev_bk->sem))) {
    INTEL_FPGA_PCIE_DEBUG(
        "interrupted while attempting to obtain "
        "device semaphore.");
    return -ERESTARTSYS;
  }

  old_info.size = dev_bk->kmem_info.size;
  old_info.virt_addr = dev_bk->kmem_info.virt_addr;
  old_info.bus_addr = dev_bk->kmem_info.bus_addr;

  // TODO(sadok) Are we deallocating this somewhere?
  // Get new memory region first if requested.
  if (size > 0) {
    retval = dma_set_mask_and_coherent(&dev_bk->dev->dev, DMA_BIT_MASK(64));
    if (retval) {
      printk(KERN_INFO "dma_set_mask returned: %li\n", retval);
      return -EIO;
    }
    dev_bk->kmem_info.virt_addr = dma_alloc_coherent(
        &dev_bk->dev->dev, size, &dev_bk->kmem_info.bus_addr, GFP_KERNEL);
    if (!dev_bk->kmem_info.virt_addr) {
      INTEL_FPGA_PCIE_DEBUG("couldn't obtain kernel buffer.");
      // Restore old memory region.
      dev_bk->kmem_info.virt_addr = old_info.virt_addr;
      dev_bk->kmem_info.bus_addr = old_info.bus_addr;
      retval = -ENOMEM;
    } else {
      dev_bk->kmem_info.size = size;
    }
  } else {
    dev_bk->kmem_info.size = 0;
    dev_bk->kmem_info.virt_addr = NULL;
    dev_bk->kmem_info.bus_addr = 0;

    INTEL_FPGA_PCIE_VERBOSE_DEBUG("freeing previously allocated memory.");
    dma_free_coherent(&dev_bk->dev->dev, old_info.size, old_info.virt_addr,
                      old_info.bus_addr);
  }

  up(&dev_bk->sem);

  kmem_addr_l = dev_bk->kmem_info.bus_addr & 0xFFFFFFFF;
  kmem_addr_h = (dev_bk->kmem_info.bus_addr >> 32) & 0xFFFFFFFF;
  ep_addr = dev_bk->bar[2].base_addr;

  iowrite32(kmem_addr_l, ep_addr + FPGA2CPU_OFFSET + core_id * PAGE_SIZE);
  iowrite32(kmem_addr_h, ep_addr + FPGA2CPU_OFFSET + 4 + core_id * PAGE_SIZE);

  if (core_id == 0) {
    iowrite32(kmem_addr_l + karg.rx_size, ep_addr + CPU2FPGA_OFFSET);

    // kmem_addr_h should have an offset of 1 if kmem_addr_l overflows
    if ((kmem_addr_l + karg.rx_size) < kmem_addr_l) {
      ++kmem_addr_h;
    }
    iowrite32(kmem_addr_h, ep_addr + CPU2FPGA_OFFSET + 4);
  }

  return retval;
}
