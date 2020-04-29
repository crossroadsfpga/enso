

#ifndef PCIE_H
#define PCIE_H

#include "api/intel_fpga_pcie_api.hpp"

#define RULE_ID_LINE_LEN 64 // bytes
#define RULE_ID_SIZE 2 // bytes
#define NB_RULES_IN_LINE (RULE_ID_LINE_LEN/RULE_ID_SIZE)

// N * 512 bits, N * 16 dwords
#define BUFFER_SIZE 8191
#define C2F_BUFFER_SIZE 512
//Interms of dwords. 1 means the first 16 dwords are global registers
//the 1024 is the extra page for memory-copy
#define C2F_BUFFER_OFFSET ((BUFFER_SIZE+1)*16+1024)
// 4 bytes, 1 dword
#define HEAD_OFFSET 4
#define C2F_TAIL_OFFSET 16

#define PDU_ID_OFFSET 0
#define PDU_SIZE_OFFSET 6
#define PDU_FLIT_OFFSET 7
#define ACTION_OFFSET 8

#define ACTION_NO_MATCH 1
#define ACTION_MATCH 2

#define likely(x)       __builtin_expect((x),1)
#define unlikely(x)     __builtin_expect((x),0)

typedef struct pcie_block {
    uint32_t tail1;
    uint32_t head1;
    uint32_t kmem_low1;
    uint32_t kmem_high1;
    uint32_t c2f_tail;
    uint32_t c2f_head;
    uint32_t c2f_kmem_low;
    uint32_t c2f_kmem_high;
    uint32_t tail2;
    uint32_t head2;
    uint32_t kmem_low2;
    uint32_t kmem_high2;
    uint32_t padding4;
    uint32_t padding5;
    uint32_t padding6;
    uint32_t padding7;
} pcie_block_t;

typedef struct block {
    uint32_t pdu_id;
    uint16_t dst_port;
    uint16_t src_port;
    uint32_t dst_ip;
    uint32_t src_ip;
    uint32_t protocol;
    uint32_t num_rule_id; // number of 512-bit lines in the rule_id block
    uint32_t pdu_size; // in bytes
    uint32_t pdu_flit;
    uint32_t action;
    uint8_t *pdu_payload; // immediately after pdu_hdr
    uint16_t *rule_id; // after the pdu_payload, 512bit aligned
} block_s;

typedef struct {
    intel_fpga_pcie_dev* dev;
    uint32_t* kdata;
    pcie_block_t* uio_data_bar2;
    uint32_t last_flits;
    unsigned int cpu_head;
    uint32_t* tail_ptr;
    uint32_t* head_ptr;
} socket_internal;

int dma_init(socket_internal* socket_entry);
int dma_run(socket_internal* socket_entry, void** buf, size_t len);
void advance_ring_buffer(socket_internal* socket_entry);
int dma_finish(socket_internal* socket_entry);
void print_pcie_block(pcie_block_t * pb);
void print_slot(uint32_t *rp_addr, uint32_t start, uint32_t range);
void print_fpga_reg(intel_fpga_pcie_dev *dev);
void print_block(block_s *block);
void fill_block(uint32_t *addr, block_s *block);
uint32_t c2f_copy_head(uint32_t c2f_tail, pcie_block_t *global_block, 
         block_s *block, uint32_t *kdata);

#endif // PCIE_H
