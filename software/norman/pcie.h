

#ifndef PCIE_H
#define PCIE_H

#include <endian.h>
#include <netinet/ether.h>
#include <netinet/ip.h>

#include "api/intel_fpga_pcie_api.hpp"

namespace norman {

#define RULE_ID_LINE_LEN 64 // bytes
#define RULE_ID_SIZE 2 // bytes
#define NB_RULES_IN_LINE (RULE_ID_LINE_LEN/RULE_ID_SIZE)

#define MAX_PKT_SIZE 24 // in flits, if changed, must also change hardware

// These determine the maximum number of descriptor and packet queues, these
// macros also exist in hardware and **must be kept in sync**. Update the
// variables with the same name on `hardware/src/constants.sv` and 
// `hardware_test/hwtest/my_stats.tcl`.
#define MAX_NB_APPS 1024
#define MAX_NB_FLOWS 8192

#if MAX_NB_FLOWS < 65536
typedef uint16_t pkt_q_id_t;
#else
typedef uint32_t pkt_q_id_t;
#endif

#define MAX_TRANSFER_LEN 131072

#define MAX_PENDING_TX_REQUESTS (DSC_BUF_SIZE-1)

#ifndef BATCH_SIZE
// Maximum number of packets to process in call to get_next_batch_from_queue
#define BATCH_SIZE 64
#endif

#ifndef DSC_BUF_SIZE
// This should be the max buffer supported by the hardware, we may override this
// value when compiling. It is defined in number of flits (64 bytes).
#define DSC_BUF_SIZE 16384
#endif

#ifndef PKT_BUF_SIZE
// This should be the max buffer supported by the hardware, we may override this
// value when compiling. It is defined in number of flits (64 bytes).
#define PKT_BUF_SIZE 32768
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

// Offset of the RTT when timestamp is enabled (in bytes).
#define PACKET_RTT_OFFSET 18

// The maximum number of flits (64 byte chunks) that the hardware can send per
// second. This is simply the frequency of the `rate_limiter` module -- which is
// currently 200MHz.
#define MAX_HARDWARE_FLIT_RATE (200e6)

#define _norman_compiler_memory_barrier() do { \
    asm volatile ("" : : : "memory");   \
} while (0)

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
    TIMESTAMP_CONFIG_ID = 2,
    RATE_LIMIT_CONFIG_ID = 3
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

typedef struct __attribute__((__packed__)) {
    uint64_t signal;
    uint64_t config_id;
    uint16_t denominator;
    uint16_t numerator;
    uint32_t enable;
    uint8_t  pad[40];
} rate_limit_config_t;

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

    uint8_t* wrap_tracker;
    uint32_t* pending_pkt_tails;

    // HACK(sadok): This is used to decrement the packet queue id and use it as
    // an index to the pending_pkt_tails array. This only works because packet
    // queues for the same app are contiguous. This will no longer hold in the
    // future. How bad would it be to use a hash table to keep
    // `pending_pkt_tails`?
    // Another option is to get rid of the pending_pkt_tails array and instead
    // save the tails with `last_rx_ids`.
    uint32_t pkt_queue_id_offset;
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
                   int* pkt_queue_id, void** buf, size_t len);

/*
 * Free the next `len` bytes in the packet buffer associated with the
 * `socket_entry` socket. If `len` is greater than the number of allocated bytes
 * in the buffer, the behavior is undefined.
 */
void advance_ring_buffer(socket_internal* socket_entry, size_t len);

/**
 * insert_flow_entry() - Insert flow entry in the data plane flow table.
 * @dsc_queue: Descriptor queue to send configuration through.
 * @dst_port: Destination port number of the flow entry.
 * @src_port: Source port number of the flow entry.
 * @dst_ip: Destination IP address of the flow entry.
 * @src_ip: Source IP address of the flow entry.
 * @protocol: Protocol of the flow entry.
 * @pkt_queue_id: Packet queue ID that will be associated with the flow entry.
 * 
 * Inserts a rule in the data plane flow table that will direct all packets
 * matching the flow entry to the `pkt_queue_id`.
 * 
 * Return: Return 0 if configuration was successful.
 */
int insert_flow_entry(dsc_queue_t* dsc_queue, uint16_t dst_port,
                      uint16_t src_port, uint32_t dst_ip, uint32_t src_ip,
                      uint32_t protocol, uint32_t pkt_queue_id);

/**
 * enable_timestamp() - Enable hardware timestamping.
 * @dsc_queue: Descriptor queue to send configuration through.
 * 
 * All outgoing packets will receive a timestamp and all incoming packets will
 * have an RTT (in number of cycles). Use `get_pkt_rtt` to retrieve the value.
 * 
 * Return: Return 0 if configuration was successful.
 */
int enable_timestamp(dsc_queue_t* dsc_queue);

/**
 * disable_timestamp() - Disable hardware timestamping.
 * @dsc_queue: Descriptor queue to send configuration through.
 * 
 * Return: Return 0 if configuration was successful.
 */
int disable_timestamp(dsc_queue_t* dsc_queue);

/**
 * enable_rate_limit() - Enable hardware rate limit.
 * @dsc_queue: Descriptor queue to send configuration through.
 * @num: Rate numerator.
 * @den: Rate denominator.
 * 
 * Once rate limiting is enabled, packets from all queues are sent at a rate of
 * (num/den * MAX_HARDWARE_FLIT_RATE) flits per second (a flit is 64 bytes).
 * Note that this is slightly different from how we typically define throughput
 * and you may need to take the packet sizes into account to set this properly.
 * 
 * For example, suppose that you are sending 64-byte packets. Each packet 
 * occupies exactly one flit. For this packet size, line rate at 100 Gbps is
 * 148.8Mpps. So if MAX_HARDWARE_FLIT_RATE is 200MHz, line rate actually
 * corresponds to a 744/1000 rate. Therefore, if you want to send at 50Gbps (50%
 * of line rate), you can use a 372/1000 (or 93/250) rate.
 * 
 * The other thing to notice is that, while it might be tempting to use a large
 * denominator in order to increase the rate precision. This has the side effect
 * of increasing burstiness. The way the rate limit is implemented, we send a
 * burst of `num` consecutive flits every `den` cycles. Which means that if
 * `num` is too large, it might overflow the receiver buffer. For instance, in
 * the example above, 93/250 would be a better rate than 372/1000. And 3/8 would
 * be even better with a slight loss in precision.
 * 
 * You can find the maximum packet rate for any packet size by using the
 * expression: line_rate/((pkt_size + 20)*8). So for 100Gbps and 128-byte
 * packets we have: 100e9/((128+20)*8) packets per second. Given that each
 * packet is two flits, for MAX_HARDWARE_FLIT_RATE=200e6, the maximum rate is
 * 100e9/((128+20)*8)*2/200e6, which is approximately 125/148.
 * 
 * Return: Return 0 if configuration was successful.
 */
int enable_rate_limit(dsc_queue_t* dsc_queue, uint16_t num, uint16_t den);

/**
 * disable_rate_limit() - Disable hardware rate limit.
 * @dsc_queue: Descriptor queue to send configuration through.
 * 
 * Return: Return 0 if configuration was successful.
 */
int disable_rate_limit(dsc_queue_t* dsc_queue);

/**
 * get_pkt_rtt() - Return RTT, in number of cycles, for a given packet.
 * @pkt: Packet to retrieve the RTT from.
 * 
 * This assumes that the packet has been timestamped by hardware. To enable
 * timestamping call the `enable_timestamp` function.
 * 
 * To convert from number of cycles to ns. Do `cycles * NS_PER_TIMESTAMP_CYCLE`.
 * 
 * Return: Return RTT measure for the packet in nanoseconds. If timestamp is
 *         not enabled the value returned is undefined.
 */
inline uint32_t get_pkt_rtt(uint8_t* pkt)
{
    uint32_t rtt = *((uint32_t*) (pkt + PACKET_RTT_OFFSET));
    return be32toh(rtt);
}

/**
 * send_config() - Send configuration to the dataplane.
 * @dsc_queue: Descriptor queue to send configuration through.
 * @config_dsc: Configuration descriptor.
 * 
 * Return: Return 0 if configuration was successful.
 */
int send_config(dsc_queue_t* dsc_queue, pcie_tx_dsc_t* config_dsc);

/**
 * send_to_queue() - Send data through a given queue.
 * @dsc_queue: Descriptor queue to send data through.
 * @phys_addr: Physical memory address of the data to be sent.
 * @len: Length, in bytes, of the data.
 * 
 * This function returns as soon as a transmission requests has been enqueued to
 * the TX dsc queue. That means that it is not safe to modify or deallocate the
 * buffer pointed by `phys_addr` right after it returns. Instead, the caller
 * must use `get_unreported_completions` to figure out when the transmission is
 * complete.
 * 
 * This function currently blocks if there is not enough space in the descriptor
 * queue.
 * 
 * Return: Return 0 if transfer was successful.
 */
int send_to_queue(dsc_queue_t* dsc_queue, void* phys_addr, size_t len);

/**
 * get_unreported_completions() - Return the number of transmission requests
 * that were completed since the last call to this function.
 * @dsc_queue: Descriptor queue to get completions from.
 * 
 * Since transmissions are always completed in order, one can figure out which
 * transmissions were completed by keeping track of all the calls to 
 * `send_to_queue`. There can be only up to `MAX_PENDING_TX_REQUESTS` requests
 * completed between two calls to `send_to_queue`. However, if `send` is called
 * multiple times, without calling `get_unreported_completions` the number of
 * completed requests can surpass `MAX_PENDING_TX_REQUESTS`.
 * 
 * Return: Return the number of transmission requests that were completed since
 *         the last call to this function.
 */
uint32_t get_unreported_completions(dsc_queue_t* dsc_queue);

/**
 * update_tx_head() - Update the tx head and the number of TX completions.
 * @dsc_queue: Descriptor queue to be updated.
 */
void update_tx_head(dsc_queue_t* dsc_queue);

int dma_finish(socket_internal* socket_entry);

uint32_t get_pkt_queue_id_from_socket(socket_internal* socket_entry);

void print_queue_regs(queue_regs_t * pb);

void print_slot(uint32_t *rp_addr, uint32_t start, uint32_t range);

void print_fpga_reg(intel_fpga_pcie_dev *dev, unsigned nb_regs);

void print_buf(void* buf, const uint32_t nb_cache_lines);

void print_stats(socket_internal* socket_entry, bool print_global);

inline uint16_t be_to_le_16(uint16_t le) {
    return ((le & (uint16_t) 0x00ff) << 8) | ((le & (uint16_t) 0xff00) >> 8);
}

static inline uint16_t get_pkt_len(uint8_t *addr) {
    struct ether_header* l2_hdr = (struct ether_header*) addr;
    struct iphdr* l3_hdr = (struct iphdr*) (l2_hdr + 1);
    uint16_t total_len = be_to_le_16(l3_hdr->tot_len) + sizeof(*l2_hdr);

    return total_len;
}

static inline uint8_t* get_next_pkt(uint8_t *pkt) {
    uint16_t pkt_len = get_pkt_len(pkt);
    uint16_t nb_flits = (pkt_len - 1) / 64 + 1;
    return pkt + nb_flits * 64;
}

}  // namespace norman

#endif // PCIE_H
