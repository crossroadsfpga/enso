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
#include "enso_defines.h"
#include <linux/kthread.h>
#include <linux/delay.h>


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

static long alloc_notif_buf_pair(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg);
static long send_tx_pipe(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg);
static long send_config(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg);
static long get_unreported_completions(struct chr_dev_bookkeep *chr_dev_bk, unsigned int __user *user_addr);
static long alloc_rx_enso_pipe(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg);
static long free_rx_enso_pipe(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg);
static long consume_rx_pipe(struct chr_dev_bookkeep *chr_dev_bk, unsigned long uarg);

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
    retval = !access_ok(VERIFY_WRITE, (void __user *)uarg, _IOC_SIZE(cmd));
  } else if (_IOC_DIR(cmd) & _IOC_WRITE) {
    retval = !access_ok(VERIFY_READ, (void __user *)uarg, _IOC_SIZE(cmd));
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
    case INTEL_FPGA_PCIE_IOCTL_ALLOC_NOTIF_BUF_PAIR:
      retval = alloc_notif_buf_pair(chr_dev_bk, uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_SEND_TX_PIPE:
      retval = send_tx_pipe(chr_dev_bk, uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_GET_UNREPORTED_COMPLETIONS:
      retval = get_unreported_completions(chr_dev_bk, (unsigned int __user *) uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_SEND_CONFIG:
      retval = send_config(chr_dev_bk, uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_ALLOC_RX_ENSO_PIPE:
      retval = alloc_rx_enso_pipe(chr_dev_bk, uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_FREE_RX_ENSO_PIPE:
      retval = free_rx_enso_pipe(chr_dev_bk, uarg);
      break;
    case INTEL_FPGA_PCIE_IOCTL_CONSUME_RX:
      retval = consume_rx_pipe(chr_dev_bk, uarg);
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

/**
 * get_unreported_completions() - Returns a count of the number of unreported
 *                                TX notifications that have been marked completed
 *                                by the NIC but the application has not freed their buffer.
 *
 * @chr_dev_bk: Structure containing information about the current
 *              character file handle.
 * @user_addr:  Copy the unreported count to this variable in userspace.
 */
static long get_unreported_completions(struct chr_dev_bookkeep *chr_dev_bk, unsigned int __user *user_addr) {
  struct dev_bookkeep *dev_bk;
  uint32_t completions;
  struct notification_buf_pair *notif_buf_pair;

  notif_buf_pair = chr_dev_bk->notif_buf_pair;
  dev_bk = chr_dev_bk->dev_bk;
  // printk(KERN_CRIT "get_unreported_completions\n");
  if (unlikely(down_interruptible(&dev_bk->sem))) {
    INTEL_FPGA_PCIE_DEBUG(
        "interrupted while attempting to obtain "
        "device semaphore.");
    return -ERESTARTSYS;
  }
  if(notif_buf_pair == NULL) {
    INTEL_FPGA_PCIE_DEBUG("Notification buf pair is NULL");
    return -EINVAL;
  }

  // first we update the tx head
  update_tx_head(notif_buf_pair);
  completions = notif_buf_pair->nb_unreported_completions;
  if (copy_to_user(user_addr, &completions, sizeof(completions))) {
    INTEL_FPGA_PCIE_DEBUG("couldn't copy information to user.");
    return -EFAULT;
  }
  notif_buf_pair->nb_unreported_completions = 0; // reset
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
    INTEL_FPGA_PCIE_DEBUG(
        "interrupted while attempting to obtain "
        "device semaphore.");
    return -ERESTARTSYS;
  }

  notif_buf_pair->id = buf_id;

  // Check that the buffer ID is valid.
  if (buf_id < 0 || buf_id >= MAX_NB_APPS) {
    INTEL_FPGA_PCIE_DEBUG("invalid buffer ID.");
    return -EINVAL;
  }

  // check if notification buf pair already allocated
  if(notif_buf_pair->allocated) {
    printk("Notification buf pair already allocated.\n");
    return -EINVAL;
  }

  // 2. Map BAR into queue regs
  bar2_addr = (uint8_t *) dev_bk->bar[2].base_addr;
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
    INTEL_FPGA_PCIE_DEBUG("RX_TX allocation failed");
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
    INTEL_FPGA_PCIE_DEBUG("Pending RX pipe tails allocation failed");
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
    INTEL_FPGA_PCIE_DEBUG("Pending RX pipe tails allocation failed");
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
    INTEL_FPGA_PCIE_DEBUG("couldn't copy arg from user.");
    return -EFAULT;
  }

  if(notif_buf_pair == NULL) {
    INTEL_FPGA_PCIE_DEBUG("Notification buffer is invalid");
    return -EFAULT;
  }
  dev_bk = chr_dev_bk->dev_bk;

  if (unlikely(down_interruptible(&dev_bk->sem))) {
    INTEL_FPGA_PCIE_DEBUG(
        "interrupted while attempting to obtain "
        "device semaphore.");
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
    INTEL_FPGA_PCIE_DEBUG("couldn't copy arg from user.");
    return -EFAULT;
  }

  dev_bk = chr_dev_bk->dev_bk;
  if (unlikely(down_interruptible(&dev_bk->sem))) {
    INTEL_FPGA_PCIE_DEBUG(
        "interrupted while attempting to obtain "
        "device semaphore.");
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

int32_t alloc_enso_pipe_id(struct chr_dev_bookkeep *chr_dev_bk, bool is_fallback) {
  int32_t i, j;
  int32_t pipe_id = -1;
  struct dev_bookkeep *dev_bk;
  dev_bk = chr_dev_bk->dev_bk;

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

  if (pipe_id < 0) {
    INTEL_FPGA_PCIE_DEBUG("couldn't allocate pipe.");
    return -1;
  }

  // Set status bit for both the device bitvector and the character device
  // bitvector.
  i = pipe_id / 8;
  j = pipe_id % 8;
  dev_bk->pipe_status[i] |= (1 << j);
  chr_dev_bk->pipe_status[i] |= (1 << j);

  return 0;
}

static long alloc_rx_enso_pipe(struct chr_dev_bookkeep *chr_dev_bk,
                               unsigned long uarg) {
  struct enso_pipe_init_params params;
  struct dev_bookkeep *dev_bk;
  struct rx_enso_pipe_internal *rx_enso_pipe;
  uint8_t *bar2_addr;
  struct queue_regs *rep_q_regs;
  int32_t pipe_id;
  uint64_t rx_buf_phys_addr;

  rx_enso_pipe = chr_dev_bk->enso_pipe_internal;
  dev_bk = chr_dev_bk->dev_bk;

  printk("Allocating enso RX pipe\n");
  if (unlikely(down_interruptible(&dev_bk->sem))) {
    INTEL_FPGA_PCIE_DEBUG(
        "interrupted while attempting to obtain "
        "device semaphore.");
    return -ERESTARTSYS;
  }

  if (copy_from_user(&params, (void __user *)uarg, sizeof(params))) {
    INTEL_FPGA_PCIE_DEBUG("couldn't copy arg from user.");
    return -EFAULT;
  }

  pipe_id = params.id;
  rx_enso_pipe->id = pipe_id;

  // check if notification buf pair already allocated
  if(rx_enso_pipe->allocated) {
    printk("Rx enso pipe already allocated.\n");
    return -EINVAL;
  }

  // 2. Map BAR into queue regs
  bar2_addr = (uint8_t *) dev_bk->bar[2].base_addr;
  rep_q_regs = (struct queue_regs *)(bar2_addr
                                   + (rx_enso_pipe->id
                                   * MEM_PER_QUEUE));
  rx_enso_pipe->regs = (struct queue_regs *) rep_q_regs;

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

  rx_enso_pipe->rx_head = 0;
  rx_enso_pipe->rx_tail = 0;

  chr_dev_bk->notif_buf_pair->pending_rx_pipe_tails[rx_enso_pipe->id] = rx_enso_pipe->rx_head;
  rx_buf_phys_addr = params.phys_addr;

  smp_wmb();
  iowrite32((uint32_t)rx_buf_phys_addr + chr_dev_bk->notif_buf_pair->id,
            &rep_q_regs->rx_mem_low);
  smp_wmb();
  iowrite32((uint32_t)(rx_buf_phys_addr >> 32), &rep_q_regs->rx_mem_high);

  rx_enso_pipe->allocated = true;

  up(&dev_bk->sem);

  return 0;
}

int32_t free_enso_pipe_id(struct chr_dev_bookkeep *chr_dev_bk,
                          int32_t pipe_id) {
  struct dev_bookkeep *dev_bk;
  int32_t i, j;

  dev_bk = chr_dev_bk->dev_bk;
  // Check that the pipe ID is valid.
  if (pipe_id < 0 || pipe_id >= MAX_NB_FLOWS) {
    printk("invalid pipe ID.");
    return -1;
  }

  // Check that the pipe ID is allocated.
  i = pipe_id / 8;
  j = pipe_id % 8;
  if (!(chr_dev_bk->pipe_status[i] & (1 << j))) {
    printk("pipe ID is not allocated for this file handle.");
    return -1;
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

  return 0;
}
EXPORT_SYMBOL(free_enso_pipe_id);

int ext_free_rx_enso_pipe(struct chr_dev_bookkeep *chr_dev_bk) {
  struct rx_enso_pipe_internal *rx_enso_pipe;
  struct queue_regs *rep_q_regs;
  int32_t ret;

  rx_enso_pipe = chr_dev_bk->enso_pipe_internal;
  rep_q_regs = rx_enso_pipe->regs;
  printk("Freeing enso RX pipe\n");

  smp_wmb();
  iowrite32(0, &rep_q_regs->rx_mem_low);
  smp_wmb();
  iowrite32(0, &rep_q_regs->rx_mem_high);

  rx_enso_pipe->allocated = false;
  // printk("Stopping RX tails thread\n");

  ret = free_enso_pipe_id(chr_dev_bk, rx_enso_pipe->id);
  if(ret < 0) {
    printk("Couldn't free Enso pipe id\n");
    return -EFAULT;
  }

  return 0;
}
EXPORT_SYMBOL(ext_free_rx_enso_pipe);

static long free_rx_enso_pipe(struct chr_dev_bookkeep *chr_dev_bk,
                              unsigned long uarg) {
  struct dev_bookkeep *dev_bk;
  struct rx_enso_pipe_internal *rx_enso_pipe;
  int32_t pipe_id = (int32_t)uarg;
  struct queue_regs *rep_q_regs;
  int32_t ret;

  rx_enso_pipe = chr_dev_bk->enso_pipe_internal;
  rep_q_regs = rx_enso_pipe->regs;
  dev_bk = chr_dev_bk->dev_bk;
  printk("Freeing enso RX pipe\n");

  if (unlikely(down_interruptible(&dev_bk->sem))) {
    INTEL_FPGA_PCIE_DEBUG(
        "interrupted while attempting to obtain "
        "device semaphore.");
    return -ERESTARTSYS;
  }

  smp_wmb();
  iowrite32(0, &rep_q_regs->rx_mem_low);
  smp_wmb();
  iowrite32(0, &rep_q_regs->rx_mem_high);

  ret = free_enso_pipe_id(chr_dev_bk, pipe_id);
  if(ret < 0) {
    printk("Couldn't free Enso pipe id\n");
    return -EFAULT;
  }
  rx_enso_pipe->allocated = false;
  // printk("Stopping RX tails thread\n");

  up(&dev_bk->sem);

  return 0;
}

static long consume_rx_pipe(struct chr_dev_bookkeep *chr_dev_bk,
                            unsigned long uarg) {
  struct dev_bookkeep *dev_bk;
  struct rx_notification* rx_notif;
  struct rx_notification* curr_notif;
  uint32_t notification_buf_head;
  uint16_t next_rx_ids_tail;
  uint16_t nb_consumed_notifications = 0;
  struct notification_buf_pair *notif_buf_pair;
  struct rx_enso_pipe_internal *enso_pipe;
  uint16_t ind = 0;
  uint32_t enso_pipe_id;
  uint32_t enso_pipe_new_tail;
  uint32_t flit_aligned_size = 0;
  uint32_t enso_pipe_head;
  struct enso_consume_rx_params params;

  dev_bk = chr_dev_bk->dev_bk;
  if (unlikely(down_interruptible(&dev_bk->sem))) {
    INTEL_FPGA_PCIE_DEBUG(
        "interrupted while attempting to obtain "
        "device semaphore.");
    return -ERESTARTSYS;
  }

  if (copy_from_user(&params, (void __user *)uarg, sizeof(params))) {
    INTEL_FPGA_PCIE_DEBUG("couldn't copy arg from user.");
    return -EFAULT;
  }

  // printk("Consuming packets from RX Enso pipe\n");

  notif_buf_pair = chr_dev_bk->notif_buf_pair;
  rx_notif = notif_buf_pair->rx_buf;
  notification_buf_head = notif_buf_pair->rx_head;
  next_rx_ids_tail = notif_buf_pair->next_rx_ids_tail;
  enso_pipe = chr_dev_bk->enso_pipe_internal;

  // we first check for any new notifications
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
    printk("Consumed %d packets\n", nb_consumed_notifications);
    // Update notification buffer head.
    smp_wmb();
    iowrite32(notification_buf_head, notif_buf_pair->rx_head_ptr);
    notif_buf_pair->rx_head = notification_buf_head;

    // also get the new rx pipe tail
    enso_pipe_head = enso_pipe->rx_tail;
    enso_pipe_id = params.id; // get the pipe id from the userspace
    enso_pipe_new_tail = notif_buf_pair->pending_rx_pipe_tails[enso_pipe_id];
    if(enso_pipe_new_tail == enso_pipe_head) {
        up(&dev_bk->sem);
        return 0;
    }
    flit_aligned_size = ((enso_pipe_new_tail - enso_pipe_head)
                                  % ENSO_PIPE_SIZE) * 64;
    if(!params.peek) {
        enso_pipe_head = (enso_pipe_head + flit_aligned_size / 64)
                         % ENSO_PIPE_SIZE;
        enso_pipe->rx_tail = enso_pipe_head;
    }
  }

  up(&dev_bk->sem);
  return flit_aligned_size;
}

/*__consume_queue(struct RxEnsoPipeInternal* enso_pipe,
                struct NotificationBufPair* notification_buf_pair, void** buf,
                bool peek = false) {
  struct dev_bookkeep *dev_bk;
  struct rx_enso_pipe_internal *enso_pipe_internal;
  uint32_t* enso_pipe_buf;
  uint32_t enso_pipe_head;
  int queue_id;

  struct rx_notification* rx_notif;
  struct rx_notification* curr_notif;
  uint32_t notification_buf_head;
  uint16_t next_rx_ids_tail;
  uint16_t nb_consumed_notifications = 0;
  struct notification_buf_pair *notif_buf_pair;

  uint32_t* enso_pipe_buf = enso_pipe->buf;
  uint32_t enso_pipe_head = enso_pipe->rx_tail;
  int queue_id = enso_pipe->id;

  *buf = &enso_pipe_buf[enso_pipe_head * 16];

  uint32_t enso_pipe_tail =
      notification_buf_pair->pending_rx_pipe_tails[queue_id];

  if (enso_pipe_tail == enso_pipe_head) {
    return 0;
  }

  uint32_t flit_aligned_size =
      ((enso_pipe_tail - enso_pipe_head) % ENSO_PIPE_SIZE) * 64;

  if (!peek) {
    enso_pipe_head = (enso_pipe_head + flit_aligned_size / 64) % ENSO_PIPE_SIZE;
    enso_pipe->rx_tail = enso_pipe_head;
  }

  return flit_aligned_size;
}*/

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
