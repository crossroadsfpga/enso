#include <sched.h>
#include <sys/mman.h>
#include <unistd.h>

#include <iostream>
#include <stdexcept>

#include "../enso_api.hpp"

namespace enso_api {

EnsoDev *EnsoDev::Create() noexcept {
  EnsoDev *dev = new (std::nothrow) EnsoDev();
  if (!dev) {
    return NULL;
  }

  if (dev->Init()) {
    delete dev;
    return NULL;
  }

  return dev;
}

/******************************************************************************
 * Enso device class methods
 *****************************************************************************/
int EnsoDev::Init() noexcept {
  ssize_t fd;

  fd = open("/dev/enso", O_RDWR | O_CLOEXEC);

  if (fd == -1) {
    std::cerr << "could not open character device; ensure that Enso "
                 "kernel driver has been loaded"
              << std::endl;
    return -1;
  }
  m_dev_handle = fd;
  return 0;
}

EnsoDev::~EnsoDev(void) {
  close(m_dev_handle);
}

void EnsoDev::test(void) {
  ioctl(m_dev_handle, ENSO_IOCTL_TEST);
}

int EnsoDev::get_nb_fallback_queues() {
  int result;
  unsigned int nb_fallback_queues;
  result = ioctl(m_dev_handle, ENSO_IOCTL_GET_NB_FALLBACK_QUEUES,
                 &nb_fallback_queues);

  if (result != 0) {
    return -1;
  }

  return nb_fallback_queues;
}

int EnsoDev::set_rr_status(bool enable_rr) {
  return ioctl(m_dev_handle, ENSO_IOCTL_SET_RR_STATUS, enable_rr);
}

int EnsoDev::get_rr_status() {
  int result;
  bool rr_status;
  result = ioctl(m_dev_handle, ENSO_IOCTL_GET_RR_STATUS, &rr_status);

  if (result != 0) {
    return -1;
  }

  return rr_status;
}

int EnsoDev::allocate_notif_buf() {
  int result;
  unsigned int buf_id;
  result =
      ioctl(m_dev_handle, ENSO_IOCTL_ALLOC_NOTIF_BUFFER, &buf_id);

  if (result != 0) {
    return -1;
  }

  return buf_id;
}

int EnsoDev::free_notif_buf(int id) {
  return ioctl(m_dev_handle, ENSO_IOCTL_FREE_NOTIF_BUFFER, id);
}

int EnsoDev::allocate_pipe(bool fallback) {
  int result;
  unsigned int uarg = fallback;
  result = ioctl(m_dev_handle, ENSO_IOCTL_ALLOC_PIPE, &uarg);

  if (result != 0) {
    return -1;
  }

  return uarg;
}

int EnsoDev::free_pipe(int id) {
  return ioctl(m_dev_handle, ENSO_IOCTL_FREE_PIPE, id);
}

int EnsoDev::allocate_notif_buf_pair(int id) {
  int result;
  result =
      ioctl(m_dev_handle, ENSO_IOCTL_ALLOC_NOTIF_BUF_PAIR, id);

  if (result != 0) {
    return -1;
  }

  return result;
}

int EnsoDev::send_tx_pipe(uint64_t phys_addr, uint32_t len, uint32_t buf_id) {
  int result;
  struct enso_send_tx_pipe_params stpp;
  stpp.phys_addr = phys_addr;
  stpp.len = len;
  stpp.id = buf_id;
  result =
      ioctl(m_dev_handle, ENSO_IOCTL_SEND_TX_PIPE, &stpp);

  if (result != 0) {
    std::cout << "failure at send_tx ioctl " << result << std::endl;
    return -1;
  }

  return result;
}

int EnsoDev::get_unreported_completions() {
  int result;
  unsigned int completions;
  result = ioctl(m_dev_handle, ENSO_IOCTL_GET_UNREPORTED_COMPLETIONS,
                 &completions);

  if (result != 0) {
    std::cout << "unreported completions failed" << std::endl;
    return -1;
  }

  return completions;
}

int EnsoDev::send_config(struct TxNotification *txNotification) {
  int result;
  result =
      ioctl(m_dev_handle, ENSO_IOCTL_SEND_CONFIG, txNotification);

  if (result != 0) {
    std::cout << "failure at send_confif ioctl " << result << std::endl;
    return -1;
  }

  return result;
}

int EnsoDev::allocate_enso_rx_pipe(int pipe_id, uint64_t buf_phys_addr) {
  int result;
  struct enso_pipe_init_params param;
  param.phys_addr = buf_phys_addr;
  param.id = pipe_id;
  result = ioctl(m_dev_handle, ENSO_IOCTL_ALLOC_RX_ENSO_PIPE, &param);

  if (result != 0) {
    return -1;
  }

  return result;
}

int EnsoDev::free_enso_rx_pipe(int pipe_id) {
  int result;
  result = ioctl(m_dev_handle, ENSO_IOCTL_FREE_RX_ENSO_PIPE, pipe_id);

  if (result != 0) {
    return -1;
  }

  return 0;
}

int EnsoDev::consume_rx_pipe(int &pipe_id, uint32_t &krx_tail) {
  int result;
  struct enso_consume_rx_params param;
  param.id = pipe_id;
  param.new_rx_tail = 0;
  result = ioctl(m_dev_handle, ENSO_IOCTL_CONSUME_RX, &param);
  krx_tail = param.new_rx_tail;
  pipe_id = param.id;
  return result;
}

int EnsoDev::full_adv_pipe(int pipe_id) {
  int result;
  result = ioctl(m_dev_handle, ENSO_IOCTL_FULL_ADV_PIPE, &pipe_id);
  return result;
}

int EnsoDev::get_next_batch(int notif_id, int &pipe_id, uint32_t &krx_tail) {
  int result;
  struct enso_get_next_batch_params param;
  param.notif_id = notif_id;
  param.new_rx_tail = 0;
  param.pipe_id = -1;
  result = ioctl(m_dev_handle, ENSO_IOCTL_GET_NEXT_BATCH, &param);
  if(result < 0) {
    return -1;
  }
  krx_tail = param.new_rx_tail;
  pipe_id = param.pipe_id;
  return result;
}

int EnsoDev::advance_pipe(int pipe_id, size_t len) {
  int result;
  struct enso_advance_pipe_params param;
  param.id = pipe_id;
  param.len = len;
  result = ioctl(m_dev_handle, ENSO_IOCTL_ADVANCE_PIPE, &param);
  return result;
}

int EnsoDev::next_rx_pipe_to_recv() {
  int result;
  result = ioctl(m_dev_handle, ENSO_IOCTL_NEXT_RX_PIPE_RCV, 0);
  return result;
}

int EnsoDev::prefetch_pipe(int pipe_id) {
  int result;
  result = ioctl(m_dev_handle, ENSO_IOCTL_PREFETCH_PIPE, &pipe_id);
  return result;
}

}  // namespace enso_api
