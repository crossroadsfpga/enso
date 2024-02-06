#ifndef SOFTWARE_KERNEL_LINUX_ENSO_IOCTL_H_
#define SOFTWARE_KERNEL_LINUX_ENSO_IOCTL_H_

#include "enso_setup.h"

/*
 * struct enso_send_tx_pipe_params - Structure used to send a TxPipe.
 * */
struct enso_send_tx_pipe_params {
  uint64_t phys_addr;
  uint32_t len;
  uint32_t id;
} __attribute__((packed));

struct enso_pipe_init_params {
  uint64_t phys_addr;
  uint32_t id;
} __attribute__((packed));

struct enso_consume_rx_params {
  uint32_t id;
  uint32_t new_rx_tail;
} __attribute__((packed));

struct enso_get_next_batch_params {
  uint32_t notif_id;
  uint32_t pipe_id;
  uint32_t new_rx_tail;
};

struct enso_advance_pipe_params {
  uint32_t id;
  size_t len;
};

#define ENSO_IOCTL_MAGIC 0x07
#define ENSO_IOCTL_TEST \
  _IOR(ENSO_IOCTL_MAGIC, 0, unsigned int)
#define ENSO_IOCTL_GET_NB_FALLBACK_QUEUES \
  _IOR(ENSO_IOCTL_MAGIC, 1, unsigned int *)
#define ENSO_IOCTL_SET_RR_STATUS \
  _IOR(ENSO_IOCTL_MAGIC, 2, bool)
#define ENSO_IOCTL_GET_RR_STATUS \
  _IOR(ENSO_IOCTL_MAGIC, 3, bool *)
#define ENSO_IOCTL_ALLOC_NOTIF_BUFFER \
  _IOR(ENSO_IOCTL_MAGIC, 4, unsigned int *)
#define ENSO_IOCTL_FREE_NOTIF_BUFFER \
  _IOR(ENSO_IOCTL_MAGIC, 5, unsigned int)
#define ENSO_IOCTL_ALLOC_PIPE \
  _IOR(ENSO_IOCTL_MAGIC, 6, unsigned int *)
#define ENSO_IOCTL_FREE_PIPE \
  _IOR(ENSO_IOCTL_MAGIC, 7, unsigned int)
#define ENSO_IOCTL_ALLOC_NOTIF_BUF_PAIR \
  _IOR(ENSO_IOCTL_MAGIC, 8, unsigned int)
#define ENSO_IOCTL_SEND_TX_PIPE \
  _IOR(ENSO_IOCTL_MAGIC, 9, struct enso_send_tx_pipe_params *)
#define ENSO_IOCTL_GET_UNREPORTED_COMPLETIONS \
  _IOR(ENSO_IOCTL_MAGIC, 10, unsigned int *)
#define ENSO_IOCTL_SEND_CONFIG \
  _IOR(ENSO_IOCTL_MAGIC, 11, struct tx_notification *)
#define ENSO_IOCTL_ALLOC_RX_ENSO_PIPE \
  _IOR(ENSO_IOCTL_MAGIC, 12, struct enso_pipe_init_params *)
#define ENSO_IOCTL_FREE_RX_ENSO_PIPE \
  _IOR(ENSO_IOCTL_MAGIC, 13, unsigned int)
#define ENSO_IOCTL_CONSUME_RX \
  _IOR(ENSO_IOCTL_MAGIC, 14, struct enso_consume_rx_params *)
#define ENSO_IOCTL_FULL_ADV_PIPE \
  _IOR(ENSO_IOCTL_MAGIC, 15, unsigned int *)
#define ENSO_IOCTL_GET_NEXT_BATCH \
  _IOR(ENSO_IOCTL_MAGIC, 16, struct enso_get_next_batch_params *)
#define ENSO_IOCTL_ADVANCE_PIPE \
  _IOR(ENSO_IOCTL_MAGIC, 17, struct enso_advance_pipe_params *)
#define ENSO_IOCTL_NEXT_RX_PIPE_RCV \
  _IOR(ENSO_IOCTL_MAGIC, 18, unsigned int)
#define ENSO_IOCTL_PREFETCH_PIPE \
  _IOR(ENSO_IOCTL_MAGIC, 19, unsigned int *)
#define ENSO_IOCTL_MAXNR 19

long enso_unlocked_ioctl(struct file *filp, unsigned int cmd,
                         unsigned long arg);
int free_rx_pipe(struct rx_pipe_internal *pipe);

#endif  // SOFTWARE_KERNEL_LINUX_ENSO_IOCTL_H_
