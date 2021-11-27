

#ifndef PCIE_H
#define PCIE_H

#include "api/intel_fpga_pcie_api.hpp"

#define RULE_ID_LINE_LEN 64 // bytes
#define RULE_ID_SIZE 2 // bytes
#define NB_RULES_IN_LINE (RULE_ID_LINE_LEN/RULE_ID_SIZE)

#define MAX_PKT_SIZE 24 // in flits, if changed, must also change hardware

// These determine the maximum number of descriptor and packet queues, these
// macros also exist in hardware and **must be kept in sync**. Update the
// variables with the same name on `hardware/src/constants.sv` and 
// `hardware_test/hwtest/my_stats.tcl`.
#define MAX_NB_APPS 256
#define MAX_NB_FLOWS 8192

#if MAX_NB_FLOWS < 65536
typedef uint16_t pkt_q_id_t;
#else
typedef uint32_t pkt_q_id_t;
#endif

#define MAX_TRANSFER_LEN 1048576

#ifndef BATCH_SIZE
// Maximum number of packets to process in call to get_next_batch_from_queue
#define BATCH_SIZE 64
#endif

#ifndef DSC_BUF_SIZE
// This should be the max buffer supported by the hardware, we may override this
// value when compiling. It is defined in number of flits (64 bytes)
#define DSC_BUF_SIZE 256
#endif

#ifndef PKT_BUF_SIZE
// This should be the max buffer supported by the hardware, we may override this
// value when compiling. It is defined in number of flits (64 bytes)
#define PKT_BUF_SIZE 1024
#endif

#define C2F_BUFFER_SIZE 512

#define BUF_PAGE_SIZE (1UL << 21) // using 2MB huge pages (size in bytes)

// Sizes aligned to the huge page size, but if both buffers fit in a single
// page, we may put them in the same page
#define ALIGNED_DSC_BUF_PAIR_SIZE ((((DSC_BUF_SIZE * 64 * 2 - 1) \
    / BUF_PAGE_SIZE + 1) * BUF_PAGE_SIZE))

// 4 bytes, 1 dword
#define HEAD_OFFSET 4
#define C2F_TAIL_OFFSET 16

#define PDU_ID_OFFSET 0
#define PDU_PORTS_OFFSET 1
#define PDU_DST_IP_OFFSET 2
#define PDU_SRC_IP_OFFSET 3
#define PDU_PROTOCOL_OFFSET 4
#define PDU_SIZE_OFFSET 5
#define PDU_FLIT_OFFSET 6
#define ACTION_OFFSET 7
#define QUEUE_ID_LO_OFFSET 8
#define QUEUE_ID_HI_OFFSET 9

#define ACTION_NO_MATCH 1
#define ACTION_MATCH 2

#define MEMORY_SPACE_PER_QUEUE (1<<12)

#define likely(x)       __builtin_expect((x),1)
#define unlikely(x)     __builtin_expect((x),0)

#define REGISTERS_PER_APP 8
typedef struct queue_regs {
    uint32_t rx_tail;
    uint32_t rx_head;
    uint32_t rx_mem_low;
    uint32_t rx_mem_high;
    uint32_t tx_tail;
    uint32_t tx_head;
    uint32_t tx_mem_low;
    uint32_t tx_mem_high;
    uint32_t padding[8];
} queue_regs_t;

typedef struct block {
    uint32_t pdu_id;
    uint16_t dst_port;
    uint16_t src_port;
    uint32_t dst_ip;
    uint32_t src_ip;
    uint32_t protocol;
    uint32_t pdu_size; // in bytes
    uint32_t pdu_flit;
    uint32_t action;
    uint64_t queue_id;
    uint8_t *pdu_payload; // immediately after pdu_hdr
} block_s;

typedef struct {
    uint64_t signal;
    uint64_t queue_id;
    uint64_t tail;
    uint64_t pad[5];
} pcie_rx_dsc_t;

typedef struct {
    uint64_t signal;
    uint64_t phys_addr;
    uint64_t length;  // In bytes (up to 1MB).
    uint64_t pad[5];
} pcie_tx_dsc_t;

typedef struct {
    // First cache line:
    pcie_rx_dsc_t* rx_buf;
    pkt_q_id_t* last_rx_ids;  // Last queue ids consumed from rx_buf.
    pcie_tx_dsc_t* tx_buf;
    uint32_t* rx_head_ptr;
    uint32_t* tx_tail_ptr;
    uint32_t rx_head;
    uint32_t tx_head;
    uint32_t tx_tail;
    uint32_t old_rx_head;
    uint32_t pending_rx_ids;
    uint32_t consumed_rx_ids;

    // Second cache line:
    queue_regs_t* regs;
    uint64_t tx_full_cnt;
    uint32_t ref_cnt;
} dsc_queue_t;

typedef struct {
    uint32_t* buf;
    uint64_t buf_phys_addr;
    queue_regs_t* regs;
    uint32_t* buf_head_ptr;
    uint32_t rx_head;
    uint32_t old_rx_head;  // The head that HW knows about.
    uint32_t rx_tail;
} pkt_queue_t;

typedef struct {
    intel_fpga_pcie_dev* dev;
    pkt_queue_t pkt_queue;
    int queue_id;
} socket_internal;

int dma_init(socket_internal* socket_entry, unsigned socket_id,
             unsigned nb_queues);
int get_next_batch_from_queue(socket_internal* socket_entry, void** buf,
                              size_t len, socket_internal* socket_entries);
int get_next_batch(socket_internal* socket_entries, int* sockfd, void** buf,
                   size_t len);
void advance_ring_buffer(socket_internal* socket_entries,
                         socket_internal* socket_entry);
int send_control_message(socket_internal* socket_entry, unsigned int nb_rules,
                         unsigned int nb_queues);
int send_to_queue(socket_internal* socket_entries,
                  socket_internal* socket_entry, void* buf, size_t len);
int dma_finish(socket_internal* socket_entry);
void print_queue_regs(queue_regs_t * pb);
void print_slot(uint32_t *rp_addr, uint32_t start, uint32_t range);
void print_fpga_reg(intel_fpga_pcie_dev *dev, unsigned nb_regs);
void print_buffer(uint32_t* buf, uint32_t nb_flits);
void print_block(block_s *block);
void fill_block(uint32_t *addr, block_s *block);
uint32_t tx_copy_head(uint32_t tx_tail, queue_regs_t *global_block, 
                       block_s *block, uint32_t *kdata);
void print_stats(socket_internal* socket_entry, bool print_global);

#endif // PCIE_H
