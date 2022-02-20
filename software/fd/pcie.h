

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

// Assumes that the FPGA `clk_datamover` runs at 200MHz. If we change the clock,
// we must also change this value.
#define NS_PER_TIMESTAMP_CYCLE 5

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

enum ConfigId {
    FLOW_TABLE_CONFIG_ID = 1,
    TIMESTAMP_CONFIG_ID = 2
};

typedef struct __attribute__((__packed__)) {
    uint64_t signal;
    uint64_t config_id;
    uint16_t dst_port;
    uint16_t src_port;
    uint32_t dst_ip;
    uint32_t src_ip;
    uint32_t protocol;
    uint32_t pkt_queue_id;
    uint8_t  pad[28];
} flow_table_config_t;

typedef struct __attribute__((__packed__)) {
    uint64_t signal;
    uint64_t config_id;
    uint64_t enable;
    uint8_t  pad[40];
} timestamp_config_t;

typedef struct __attribute__((__packed__))  {
    uint64_t signal;
    uint64_t queue_id;
    uint64_t tail;
    uint64_t pad[5];
} pcie_rx_dsc_t;

typedef struct __attribute__((__packed__)) {
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
    uint16_t pending_rx_ids;
    uint16_t consumed_rx_ids;
    uint32_t nb_unreported_completions;
    uint32_t __gap;

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
    uint32_t rx_tail;
    uint64_t phys_buf_offset; // Use to convert between phys and virt address.
} pkt_queue_t;

typedef struct {
    dsc_queue_t* dsc_queue;
    intel_fpga_pcie_dev* dev;
    pkt_queue_t pkt_queue;
    int queue_id;
} socket_internal;

int dma_init(socket_internal* socket_entry, unsigned socket_id,
             unsigned nb_queues);

int get_next_batch_from_queue(socket_internal* socket_entry, void** buf,
                              size_t len);

int get_next_batch(dsc_queue_t* dsc_queue, socket_internal* socket_entries,
                   int* sockfd, void** buf, size_t len);

/*
 * Free the next `len` bytes in the packet buffer associated with the
 * `socket_entry` socket. If `len` is greater than the number of allocated bytes
 * in the buffer, the behavior is undefined.
 */
void advance_ring_buffer(socket_internal* socket_entry, size_t len);

/*
 * Insert flow entry in the data plane flow table.
 */
int insert_flow_entry(socket_internal* socket_entry, uint16_t dst_port,
                      uint16_t src_port, uint32_t dst_ip, uint32_t src_ip,
                      uint32_t protocol, uint32_t pkt_queue_id);

/*
 * Enable hardware timestamping. All outgoing packets will receive a timestamp
 * and all incoming packets will have an RTT (in number of cycles). Use
 * `get_pkt_rtt` to retrieve the value.
 */
int enable_timestamp(socket_internal* socket_entry);

/*
 * Disable hardware timestamping.
 */
int disable_timestamp(socket_internal* socket_entry);

/*
 * Return RTT, in number of cycles, for a given packet. This assumes that the
 * packet has been timestamped by hardware. To enable this call the
 * `enable_timestamp` function. If timestamp is not enabled the value returned
 * is undefined.
 */
uint32_t get_pkt_rtt(uint8_t* pkt);

/*
 * Send configuration to the dataplane. (Can only be used with queue 0.)
 */
int send_config(socket_internal* socket_entry, pcie_tx_dsc_t* config_dsc);

/*
 * Send data pointed by `phys_addr` using the 
 */
int send_to_queue(socket_internal* socket_entry, void* phys_addr, size_t len);

/*
 * Update the tx head and the number of TX completions.
 */
void update_tx_head(dsc_queue_t* dsc_queue);

int dma_finish(socket_internal* socket_entry);

uint32_t get_pkt_queue_id_from_socket(socket_internal* socket_entry);

void print_queue_regs(queue_regs_t * pb);

void print_slot(uint32_t *rp_addr, uint32_t start, uint32_t range);

void print_fpga_reg(intel_fpga_pcie_dev *dev, unsigned nb_regs);

void print_buffer(uint8_t* buf, uint32_t nb_flits);

void print_stats(socket_internal* socket_entry, bool print_global);

#endif // PCIE_H
