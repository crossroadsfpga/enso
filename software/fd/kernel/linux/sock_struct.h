#ifndef SOCK_STRUCT_H_
#define SOCK_STRUCT_H_

#include "intel_fpga_pcie_setup.h"

#define DESC_HEAD_INVALID (-1)
#define MAX_KERN_SOCKS 7
#define MEMORY_SPACE_PER_APP (1<<12)
#define MAX_KERN_DESCS (MAX_KERN_SOCKS * 2)
#define F2C_DSC_BUF_SIZE 1024
#define F2C_PKT_BUF_SIZE 4192

/* WARNING: mirrors struct in fd/pcie.h */
typedef struct pcie_block {
    uint32_t dsc_buf_tail;
    uint32_t dsc_buf_head;
    uint32_t dsc_buf_mem_low;
    uint32_t dsc_buf_mem_high;
    uint32_t pkt_buf_tail;
    uint32_t pkt_buf_head;
    uint32_t pkt_buf_mem_low;
    uint32_t pkt_buf_mem_high;
    uint32_t c2f_tail;
    uint32_t c2f_head;
    uint32_t c2f_kmem_low;
    uint32_t c2f_kmem_high;
    uint32_t padding[4];
} pcie_block_t;

/* WARNING: mirrors struct in fd/pcie.h */
typedef struct {
    uint64_t signal;         // 1 = busy, 0 = avail
    uint64_t pkt_queue_id;   // for retrieving pkt buf
    uint64_t tail;           // for pkt_buf
    uint64_t pad[5];         // padding
} pcie_pkt_desc_t;

/* kernel socket structure for bookkeeping */
typedef struct {
    /* socket in use? */
    uint32_t active;

    /* packet descriptors */
    pcie_pkt_desc_t *dsc_buf;
    uint32_t dsc_buf_head; // DESC_HEAD_INVALID if application running

    /* app information*/
    int app_id;
    struct task_struct *app_thr; // assume app is single-thr
    pcie_block_t *uio_data_bar2;

    /* socket identifier */
    uint64_t sock_id;
} kern_sock_norman_t;

#endif
