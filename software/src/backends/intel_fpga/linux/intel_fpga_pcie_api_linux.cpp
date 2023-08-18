// Copyright 2017-2018 Intel Corporation.
//
// Intel, the Intel logo, Intel, MegaCore, NIOS II, Quartus and TalkBack words
// and logos are trademarks of Intel Corporation or its subsidiaries in the
// U.S. and/or other countries. Other marks and brands may be claimed as the
// property of others. See Trademarks on intel.com for full list of Intel
// trademarks or the Trademarks & Brands Names Database (if Intel) or see
// www.intel.com/legal (if Altera). Your use of Intel Corporation's design
// tools, logic functions and other software and tools, and its AMPP partner
// logic functions, and any output files any of the foregoing (including
// device programming or simulation files), and any associated documentation
// or information are expressly subject to the terms and conditions of the
// Altera Program License Subscription Agreement, Intel MegaCore Function
// License Agreement, or other applicable license agreement, including,
// without limitation, that your use is for the sole purpose of programming
// logic devices manufactured by Intel and sold by Intel or its authorized
// distributors. Please refer to the applicable agreement for further details.

#include <sched.h>
#include <sys/mman.h>
#include <unistd.h>

#include <iostream>
#include <stdexcept>

#include "../intel_fpga_pcie_api.hpp"

namespace intel_fpga_pcie_api {

/******************************************************************************
 * Templated access functions.
 *****************************************************************************/
template <typename T>
int linux_read(ssize_t fd, void *addr, T *data_ptr) {
  ssize_t result;
  result =
      pread(fd, data_ptr, sizeof(*data_ptr), reinterpret_cast<off_t>(addr));
  return result == sizeof(*data_ptr);
}

template <typename T>
int linux_write(ssize_t fd, void *addr, T *data_ptr) {
  ssize_t result;
  result =
      pwrite(fd, data_ptr, sizeof(*data_ptr), reinterpret_cast<off_t>(addr));
  return result == sizeof(*data_ptr);
}

template <typename T>
int linux_bar_read(ssize_t fd, unsigned int bar, void *addr, T *data_ptr) {
  ssize_t result;
  struct intel_fpga_pcie_cmd cmd;

  cmd.bar_num = bar;
  cmd.bar_offset = reinterpret_cast<uint64_t>(addr);
  cmd.user_addr = data_ptr;
  result = read(fd, &cmd, sizeof(*data_ptr));
  return result == sizeof(*data_ptr);
}

template <typename T>
int linux_bar_write(ssize_t fd, unsigned int bar, void *addr, T *data_ptr) {
  ssize_t result;
  struct intel_fpga_pcie_cmd cmd;

  cmd.bar_num = bar;
  cmd.bar_offset = reinterpret_cast<uint64_t>(addr);
  cmd.user_addr = data_ptr;
  result = write(fd, &cmd, sizeof(*data_ptr));
  return result == sizeof(*data_ptr);
}

template <typename T>
int linux_cfg_access(ssize_t fd, void *addr, T *data_ptr, bool is_read) {
  int result;
  struct intel_fpga_pcie_arg arg;

  arg.ep_addr = reinterpret_cast<uint64_t>(addr);
  arg.user_addr = data_ptr;
  arg.size = sizeof(*data_ptr);
  arg.is_read = is_read;

  result = ioctl(fd, INTEL_FPGA_PCIE_IOCTL_CFG_ACCESS, &arg);
  return result == 0;
}

IntelFpgaPcieDev *IntelFpgaPcieDev::Create(unsigned int bdf, int bar) noexcept {
  IntelFpgaPcieDev *dev = new (std::nothrow) IntelFpgaPcieDev();
  if (!dev) {
    return nullptr;
  }

  if (dev->Init(bdf, bar)) {
    delete dev;
    return nullptr;
  }

  if (dev->use_cmd(true) != 1) {
    delete dev;
    return nullptr;
  }

  return dev;
}

/******************************************************************************
 * Intel FPGA PCIe device class methods
 *****************************************************************************/
int IntelFpgaPcieDev::Init(unsigned int bdf, int bar) noexcept {
  ssize_t fd;
  int result;
  unsigned int u_bar;

  fd = open("/dev/intel_fpga_pcie_drv", O_RDWR | O_CLOEXEC);

  if (fd == -1) {
    std::cerr << "could not open character device; ensure that Intel FPGA "
                 "kernel driver has been loaded"
              << std::endl;
    return -1;
  }
  m_dev_handle = fd;

  if (bdf > 0) {
    result = ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_CHR_SEL_DEV, bdf);
    if (result != 0) {
      close(m_dev_handle);
      std::cerr << "could not select desired device" << std::endl;
      return -1;
    }
  } else {
    result = ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_CHR_GET_DEV, &bdf);
    if (result != 0) {
      close(m_dev_handle);
      std::cerr << "could not retrieve the BDF of the selected device"
                << std::endl;
      return -1;
    }
  }

  if (bar >= 0) {
    m_bar = static_cast<unsigned int>(bar);
    result = ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_CHR_SEL_BAR, m_bar);
    if (result != 0) {
      close(m_dev_handle);
      std::cerr << "could not select desired BAR" << std::endl;
      return -1;
    }
  } else {
    result = ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_CHR_GET_BAR, &u_bar);
    if (result != 0) {
      close(m_dev_handle);
      std::cerr << "could not retrieve the selected BAR" << std::endl;
      return -1;
    }
    m_bar = u_bar;
  }

  char device_name[1000] = "/dev/";
  if (get_uio_dev_name(device_name + 5)) {
    close(m_dev_handle);
    std::cerr << "could not get uio device name" << std::endl;
    return -1;
  }

  std::cout << "Using UIO device: " << device_name << std::endl;

  fd = open(device_name, O_RDWR | O_CLOEXEC);

  if (fd == -1) {
    close(m_dev_handle);
    std::cerr << "could not open uio character device; ensure that Intel FPGA "
                 "kernel driver has been loaded"
              << std::endl;
    return -1;
  }
  m_uio_dev_handle = fd;

  m_bdf = bdf;
  m_kmem_size = 0;

  return 0;
}

IntelFpgaPcieDev::~IntelFpgaPcieDev(void) {
  use_cmd(false);
  close(m_dev_handle);
  close(m_uio_dev_handle);
}

int IntelFpgaPcieDev::read8(void *addr, uint8_t *data_ptr) {
  return linux_read(m_dev_handle, addr, data_ptr);
}

int IntelFpgaPcieDev::read16(void *addr, uint16_t *data_ptr) {
  return linux_read(m_dev_handle, addr, data_ptr);
}

int IntelFpgaPcieDev::read32(void *addr, uint32_t *data_ptr) {
  return linux_read(m_dev_handle, addr, data_ptr);
}

int IntelFpgaPcieDev::read64(void *addr, uint64_t *data_ptr) {
  return linux_read(m_dev_handle, addr, data_ptr);
}

int IntelFpgaPcieDev::write8(void *addr, uint8_t data) {
  return linux_write(m_dev_handle, addr, &data);
}

int IntelFpgaPcieDev::write16(void *addr, uint16_t data) {
  return linux_write(m_dev_handle, addr, &data);
}

int IntelFpgaPcieDev::write32(void *addr, uint32_t data) {
  return linux_write(m_dev_handle, addr, &data);
}

int IntelFpgaPcieDev::write64(void *addr, uint64_t data) {
  return linux_write(m_dev_handle, addr, &data);
}

int IntelFpgaPcieDev::read8(unsigned int bar, void *addr, uint8_t *data_ptr) {
  return linux_bar_read(m_dev_handle, bar, addr, data_ptr);
}

int IntelFpgaPcieDev::read16(unsigned int bar, void *addr, uint16_t *data_ptr) {
  return linux_bar_read(m_dev_handle, bar, addr, data_ptr);
}

int IntelFpgaPcieDev::read32(unsigned int bar, void *addr, uint32_t *data_ptr) {
  return linux_bar_read(m_dev_handle, bar, addr, data_ptr);
}

int IntelFpgaPcieDev::read64(unsigned int bar, void *addr, uint64_t *data_ptr) {
  return linux_bar_read(m_dev_handle, bar, addr, data_ptr);
}

int IntelFpgaPcieDev::write8(unsigned int bar, void *addr, uint8_t data) {
  return linux_bar_write(m_dev_handle, bar, addr, &data);
}

int IntelFpgaPcieDev::write16(unsigned int bar, void *addr, uint16_t data) {
  return linux_bar_write(m_dev_handle, bar, addr, &data);
}

int IntelFpgaPcieDev::write32(unsigned int bar, void *addr, uint32_t data) {
  return linux_bar_write(m_dev_handle, bar, addr, &data);
}

int IntelFpgaPcieDev::write64(unsigned int bar, void *addr, uint64_t data) {
  return linux_bar_write(m_dev_handle, bar, addr, &data);
}

int IntelFpgaPcieDev::read(void *src, ssize_t count, void *dst) {
  ssize_t result;
  result = pread(m_dev_handle, dst, count, reinterpret_cast<off_t>(src));
  return result == count;
}

int IntelFpgaPcieDev::read(unsigned int bar, void *src, ssize_t count,
                           void *dst) {
  ssize_t result;
  struct intel_fpga_pcie_cmd cmd;

  cmd.bar_num = bar;
  cmd.bar_offset = reinterpret_cast<uint64_t>(src);
  cmd.user_addr = dst;
  result = ::read(m_dev_handle, &cmd, count);
  return result == count;
}

int IntelFpgaPcieDev::write(void *dst, ssize_t count, void *src) {
  ssize_t result;
  result = pwrite(m_dev_handle, src, count, reinterpret_cast<off_t>(dst));
  return result == count;
}

int IntelFpgaPcieDev::write(unsigned int bar, void *dst, ssize_t count,
                            void *src) {
  ssize_t result;
  struct intel_fpga_pcie_cmd cmd;

  cmd.bar_num = bar;
  cmd.bar_offset = reinterpret_cast<uint64_t>(dst);
  cmd.user_addr = src;
  result = ::write(m_dev_handle, &cmd, count);
  return result == count;
}

int IntelFpgaPcieDev::cfg_read8(void *addr, uint8_t *data_ptr) {
  return linux_cfg_access(m_dev_handle, addr, data_ptr, true);
}

int IntelFpgaPcieDev::cfg_read16(void *addr, uint16_t *data_ptr) {
  return linux_cfg_access(m_dev_handle, addr, data_ptr, true);
}

int IntelFpgaPcieDev::cfg_read32(void *addr, uint32_t *data_ptr) {
  return linux_cfg_access(m_dev_handle, addr, data_ptr, true);
}

int IntelFpgaPcieDev::cfg_write8(void *addr, uint8_t data) {
  return linux_cfg_access(m_dev_handle, addr, &data, false);
}

int IntelFpgaPcieDev::cfg_write16(void *addr, uint16_t data) {
  return linux_cfg_access(m_dev_handle, addr, &data, false);
}

int IntelFpgaPcieDev::cfg_write32(void *addr, uint32_t data) {
  return linux_cfg_access(m_dev_handle, addr, &data, false);
}

int IntelFpgaPcieDev::sel_dev(unsigned int bdf) {
  int result;
  bdf &= 0xFFFFU;  // BDF is 16 bits.
  result = ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_CHR_SEL_DEV, bdf);
  if (result == 0) {
    m_bdf = bdf;
  }
  return result == 0;
}

unsigned int IntelFpgaPcieDev::get_dev(void) { return m_bdf; }

int IntelFpgaPcieDev::sel_bar(unsigned int bar) {
  int result;
  result = ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_CHR_SEL_BAR, bar);
  if (result == 0) {
    m_bar = bar;
  }
  return result == 0;
}

unsigned int IntelFpgaPcieDev::get_bar(void) { return m_bar; }

int IntelFpgaPcieDev::use_cmd(bool enable) {
  int result;
  result = ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_CHR_USE_CMD, enable);
  return result == 0;
}

int IntelFpgaPcieDev::set_sriov_numvfs(unsigned int num_vfs) {
  int result;
  result = ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_SRIOV_NUMVFS, num_vfs);
  return result == 0;
}

int IntelFpgaPcieDev::set_kmem_size(unsigned int rx_size, unsigned int tx_size,
                                    unsigned int app_id) {
  int result;
  unsigned int page_size = sysconf(_SC_PAGESIZE);

  struct intel_fpga_pcie_ksize arg;

  // Ensure that size is at least a page
  if ((rx_size + tx_size) < page_size) {
    rx_size = page_size - tx_size;
  }

  arg.rx_size = rx_size;
  arg.tx_size = tx_size;
  // FIXME(sadok) must also change arg.core_id to arg.app_id
  // FIXME(sadok) how to check if the application should have access here?
  arg.core_id = app_id;

  result = ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_SET_KMEM_SIZE, &arg);

  if (result == 0) {
    m_kmem_size = rx_size + tx_size;
  }
  return result == 0;
}

void *IntelFpgaPcieDev::kmem_mmap(unsigned int size, unsigned int offset) {
  if ((size + offset) > m_kmem_size) {
    return MAP_FAILED;
  }

  return mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, m_dev_handle,
              offset);
}

void *IntelFpgaPcieDev::uio_mmap(size_t size, unsigned int mapping) {
  unsigned int offset = mapping * getpagesize();

  return mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, m_uio_dev_handle,
              offset);
}

int IntelFpgaPcieDev::kmem_munmap(void *addr, unsigned int size) {
  int result;
  result = munmap(addr, size);

  return result == 0;
}

int IntelFpgaPcieDev::dma_queue_read(uint64_t ep_offset, unsigned int size,
                                     uint64_t kmem_offset) {
  int result;
  struct intel_fpga_pcie_arg arg;

  arg.ep_addr = ep_offset;
  arg.user_addr = reinterpret_cast<void *>(kmem_offset);
  arg.size = size;
  arg.is_read = true;

  result = ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_DMA_QUEUE, &arg);
  return result == 0;
}

int IntelFpgaPcieDev::dma_queue_write(uint64_t ep_offset, unsigned int size,
                                      uint64_t kmem_offset) {
  int result;
  struct intel_fpga_pcie_arg arg;

  arg.ep_addr = ep_offset;
  arg.user_addr = reinterpret_cast<void *>(kmem_offset);
  arg.size = size;
  arg.is_read = false;

  result = ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_DMA_QUEUE, &arg);
  return result == 0;
}

int IntelFpgaPcieDev::dma_send_read(void) {
  int result = ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_DMA_SEND, 0x1U);
  return result == 0;
}

int IntelFpgaPcieDev::dma_send_write(void) {
  int result = ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_DMA_SEND, 0x2U);
  return result == 0;
}

int IntelFpgaPcieDev::dma_send_all(void) {
  int result = ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_DMA_SEND, 0x3U);
  return result == 0;
}

unsigned int IntelFpgaPcieDev::get_ktimer(void) {
  int result;
  unsigned int timer_usec;
  result = ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_GET_KTIMER, &timer_usec);

  if (result != 0) {
    timer_usec = 0;
  }

  return timer_usec;
}

int IntelFpgaPcieDev::get_uio_dev_name(char *uio_dev_name) {
  return ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_CHR_GET_UIO_DEV_NAME,
               uio_dev_name);
}

int IntelFpgaPcieDev::get_nb_fallback_queues() {
  int result;
  unsigned int nb_fallback_queues;
  result = ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_GET_NB_FALLBACK_QUEUES,
                 &nb_fallback_queues);

  if (result != 0) {
    return -1;
  }

  return nb_fallback_queues;
}

int IntelFpgaPcieDev::set_rr_status(bool enable_rr) {
  return ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_SET_RR_STATUS, enable_rr);
}

int IntelFpgaPcieDev::get_rr_status() {
  int result;
  bool rr_status;
  result = ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_GET_RR_STATUS, &rr_status);

  if (result != 0) {
    return -1;
  }

  return rr_status;
}

int IntelFpgaPcieDev::allocate_notif_buf() {
  int result;
  unsigned int buf_id;
  result =
      ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_ALLOC_NOTIF_BUFFER, &buf_id);

  if (result != 0) {
    return -1;
  }

  return buf_id;
}

int IntelFpgaPcieDev::free_notif_buf(int id) {
  return ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_FREE_NOTIF_BUFFER, id);
}

int IntelFpgaPcieDev::allocate_pipe(bool fallback) {
  int result;
  unsigned int uarg = fallback;
  result = ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_ALLOC_PIPE, &uarg);

  if (result != 0) {
    return -1;
  }

  return uarg;
}

int IntelFpgaPcieDev::free_pipe(int id) {
  return ioctl(m_dev_handle, INTEL_FPGA_PCIE_IOCTL_FREE_PIPE, id);
}

}  // namespace intel_fpga_pcie_api
