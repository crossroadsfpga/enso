// (C) 2017-2018 Intel Corporation.
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

#include <termios.h>
#include <time.h>
#include <cassert>
#include <cerrno>
#include <cstdlib>
#include <ctime>
#include <endian.h>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <system_error>
#include <string.h>

#include <sched.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include "api/intel_fpga_pcie_api.hpp"
// #include "intel_fpga_pcie_link_test.hpp"
#include "pcie.h"

// C2F_BUFFER_OFFSET is in dwords
static const unsigned f2c_allocated_size = C2F_BUFFER_OFFSET * 4;
static const unsigned c2f_allocated_size = C2F_BUFFER_SIZE * 64;
static const unsigned allocated_size = f2c_allocated_size + c2f_allocated_size;


static inline uint16_t get_pkt_size(uint8_t *addr) {
    uint16_t l2_len = 14 + 4;
    uint16_t l3_len = be16toh(*((uint16_t*) (addr+14+2))); // ipv4 total length
    uint16_t total_len = l2_len + l3_len;
    return total_len;
}

int dma_init(socket_internal* socket_entry, unsigned socket_id, unsigned nb_queues)
{
    int result;
    void *mmap_addr, *uio_mmap_bar2_addr;
    int app_id;
    intel_fpga_pcie_dev *dev = socket_entry->dev;

    printf("Running with HEAD_UPDATE_PERIOD: %i\n", HEAD_UPDATE_PERIOD);
    printf("Running with BATCH_SIZE: %i\n", BATCH_SIZE);
    printf("Running with BUFFER_SIZE: %i\n", BUFFER_SIZE);

    // FIXME(sadok) should find a better identifier than core id
    app_id = sched_getcpu() * nb_queues + socket_id;
    if (app_id < 0) {
        std::cerr << "Could not get cpu id" << std::endl;
        return -1;
    }

    // Obtain kernel memory.
    result = dev->set_kmem_size(f2c_allocated_size, c2f_allocated_size, app_id);
    if (result != 1) {
        std::cerr << "Could not get kernel memory!" << std::endl;
        return -1;
    }
    mmap_addr = dev->kmem_mmap(allocated_size, 0);
    if (mmap_addr == MAP_FAILED) {
        std::cerr << "Could not get mmap kernel memory!" << std::endl;
        return -1;
    }
    socket_entry->kdata = reinterpret_cast<uint32_t *>(mmap_addr);

    pcie_block_t *global_block; // The global 512-bit register array.
    global_block = (pcie_block_t *) socket_entry->kdata;

    uio_mmap_bar2_addr = dev->uio_mmap((1<<12) * MAX_NB_APPS, 2);
    if (uio_mmap_bar2_addr == MAP_FAILED) {
        std::cerr << "Could not get mmap uio memory!" << std::endl;
        return -1;
    }
    socket_entry->uio_data_bar2 = (pcie_block_t *) (
        (uint8_t*) uio_mmap_bar2_addr + app_id * MEMORY_SPACE_PER_APP
    );

    socket_entry->head_ptr = &socket_entry->uio_data_bar2->head;

    // the global block is unique per buffer so we use the first tail
    // regardless of the core id
    socket_entry->tail_ptr = &global_block->tail;

    socket_entry->app_id = app_id;
    socket_entry->c2f_cpu_tail = 0;
    socket_entry->cpu_head = *(socket_entry->head_ptr);
    socket_entry->cpu_tail = *(socket_entry->tail_ptr);

    socket_entry->nb_head_updates = 0;

    return 0;
}

int dma_run(socket_internal* socket_entry, void** buf, size_t len)
{
    unsigned int cpu_head = socket_entry->cpu_head;
    unsigned int cpu_tail;
    int free_slot; // number of free slots in ring buffer
    unsigned int copy_size;
    uint32_t* kdata = socket_entry->kdata;


    cpu_tail = *(socket_entry->tail_ptr);
    socket_entry->cpu_tail = cpu_tail;

    if (unlikely(cpu_tail == cpu_head)) {
        return 0;
    }

    // calculate free_slot
    if (cpu_tail <= cpu_head) {
        free_slot = cpu_head - cpu_tail;
    } else {
        free_slot = BUFFER_SIZE - cpu_tail + cpu_head;
    }

    // printf("CPU head = %d; CPU tail = %d; free_slot = %d \n", 
    //         cpu_head, cpu_tail, free_slot);
    if (unlikely(free_slot < 1)) {
        printf("cpu_tail: %i cpu_head: %i\n", cpu_tail, cpu_head);
        printf("FPGA breaks free_slot assumption!\n");
        return -1;
    }

    *buf = &kdata[(cpu_head + 1) * 16];
    uint8_t* my_buf = (uint8_t*) *buf;

    uint32_t total_size = 0;
    uint32_t total_flits = 0;
    
    // TODO(sadok) does it make sense to limit the number of packets we retrieve
    // at once?
    for (uint16_t i = 0; i < BATCH_SIZE; ++i) {
        uint32_t pkt_size = get_pkt_size(my_buf);
        uint32_t pdu_flit = ((pkt_size-1) >> 6) + 1; // number of 64-byte blocks
        uint32_t flit_aligned_size = pdu_flit * 64;

        // check transfer_flit
        if (unlikely(pdu_flit == 0)) {
            printf("transfer_flit has to be bigger than 0!\n");
            return -1;
        }

        // reached the buffer limit
        if (unlikely((total_size + flit_aligned_size) > len)) {
            socket_entry->cpu_head = cpu_head;
            return total_size;
        }

        // TODO(sadok) Handle packets that are not flit-aligned? There will be a
        // gap, what should we do?
        total_size += flit_aligned_size;
        total_flits += pdu_flit;

        // TODO(sadok) this may be a performance problem
        // We need to copy the begining of the ring buffer to the last page
        if ((cpu_head + pdu_flit) >= BUFFER_SIZE) {
            if ((cpu_head + pdu_flit) != BUFFER_SIZE) {
                copy_size = cpu_head + pdu_flit - BUFFER_SIZE;
                memcpy(&kdata[(BUFFER_SIZE + 1) * 16], &kdata[1 * 16],
                       copy_size * 16 * 4);
            }
            cpu_head = cpu_head + pdu_flit - BUFFER_SIZE;
            break;
        }
        my_buf += flit_aligned_size;
        cpu_head += pdu_flit;

        if (cpu_head == cpu_tail) {
            break;
        }
    }

    socket_entry->cpu_head = cpu_head;
    return total_size;
}

void advance_ring_buffer(socket_internal* socket_entry)
{

    // We don't really need this now that we are using batch.
    // Worse, it can actually cause the host buffer to be "full" forever, as we
    // may never update the head pointer if we only call advance_ring_buffer
    // once after dma_run. Therefore it is now disabled by default
    if (socket_entry->nb_head_updates > HEAD_UPDATE_PERIOD) {
        asm volatile ("" : : : "memory"); // compiler memory barrier
        *(socket_entry->head_ptr) = socket_entry->cpu_head;
        socket_entry->nb_head_updates = 0;
    }
    ++(socket_entry->nb_head_updates);
}

// FIXME(sadok) This should be in the kernel
int send_control_message(socket_internal* socket_entry, unsigned int nb_rules,
                         unsigned int nb_queues)
{
    block_s block;
    pcie_block_t* global_block = (pcie_block_t *) socket_entry->kdata;
    pcie_block_t* uio_data_bar2 = socket_entry->uio_data_bar2;

    if (socket_entry->app_id != 0) {
        std::cerr << "Can only send control messages from app 0" << std::endl;
        return -1;
    }

#ifdef CONTROL_MSG
    unsigned next_queue = 0;
    for (unsigned i = 0; i < nb_rules; ++i) {
        block.pdu_id = 0;
        block.dst_port = 80;
        block.src_port = 8080;
        block.dst_ip = 0xc0a80101; // inet_addr("192.168.1.1");
        block.src_ip = 0xc0a80000 + i; // inet_addr("192.168.0.0");
        block.protocol = 0x11;
        block.pdu_size = 0x0;
        block.pdu_flit = 0x0;
        block.queue_id = next_queue; // FIXME(sadok) specify the relevant queue

        next_queue = (next_queue + 1) % nb_queues;

        // std::cout << "Setting rule: " << nb_rules << std::endl;
        // print_block(&block);

        socket_entry->c2f_cpu_tail = c2f_copy_head(socket_entry->c2f_cpu_tail,
            global_block, &block, socket_entry->kdata);
        asm volatile ("" : : : "memory"); // compiler memory barrier
        uio_data_bar2->c2f_tail = socket_entry->c2f_cpu_tail;

        // asm volatile ("" : : : "memory"); // compiler memory barrier
        // print_pcie_block(uio_data_bar2);
    }
#endif // CONTROL_MSG

    return 0;
}

int dma_finish(socket_internal* socket_entry)
{
    uint32_t* kdata = socket_entry->kdata;

    // pcie_block_t *global_block; // The global 512-bit register array.
    // global_block = (pcie_block_t *) kdata;
    // unsigned int c2f_cpu_head = global_block->c2f_head;
    // std::cout << std::dec;
    // std::cout << "rx pkts: " << rx_pkts << std::endl;
    // std::cout << "cpu_head: " << cpu_head << std::endl;
    // std::cout << "cpu_tail: " << cpu_tail << std::endl;
    // std::cout << "c2f_cpu_head: " << c2f_cpu_head << std::endl;
    // std::cout << "c2f_cpu_tail: " << c2f_cpu_tail << std::endl;

    int result = socket_entry->dev->kmem_munmap(
        reinterpret_cast<void*>(kdata),
        allocated_size
    );
    if (result != 1) {
        std::cerr << "Could not unmap kernel memory!" << std::endl;
        return -1;
    }

    return 0;
}

void print_slot(uint32_t *rp_addr, uint32_t start, uint32_t range)
{
    for (unsigned int i = 0; i < range*16; ++i) {
        if (i%16==0) {
            printf("\n");
        }
        printf("rp_addr[%d] = 0x%08x \n", 16*start + i, rp_addr[16*start+i]);
    }
}

void print_fpga_reg(intel_fpga_pcie_dev *dev)
{
    uint32_t temp_r;
    for (unsigned int i = 0; i < 16; ++i) {
        dev->read32(2, reinterpret_cast<void*>(0 + i*4), &temp_r);
        printf("fpga_reg[%d] = 0x%08x \n", i, temp_r);
    }
} 

void print_pcie_block(pcie_block_t * pb)
{
    printf("pb->tail = %d \n", pb->tail);
    printf("pb->head = %d \n", pb->head);
    printf("pb->kmem_low = 0x%08x \n", pb->kmem_low);
    printf("pb->kmem_high = 0x%08x \n", pb->kmem_high);

    #ifdef CONTROL_MSG
    printf("pb->c2f_tail = %d \n", pb->c2f_tail);
    printf("pb->c2f_head = %d \n", pb->c2f_head);
    printf("pb->c2f_kmem_low = 0x%08x \n", pb->c2f_kmem_low);
    printf("pb->c2f_kmem_high = 0x%08x \n", pb->c2f_kmem_high);
    #endif // CONTROL_MSG
}

void print_block(block_s *block) {
    printf("=============PRINT BLOCK=========\n");
    printf("pdu_id      : 0x%08x \n", block->pdu_id);
    printf("dst_port    : 0x%04x \n", block->dst_port);
    printf("src_port    : 0x%04x \n", block->src_port);
    printf("dst_ip      : 0x%08x \n", block->dst_ip);
    printf("src_ip      : 0x%08x \n", block->src_ip);
    printf("protocol    : 0x%08x \n", block->protocol);
    printf("pdu_size    : 0x%08x \n", block->pdu_size);
    printf("pdu_flit    : 0x%08x \n", block->pdu_flit);
    printf("queue id    : 0x%016lx \n", block->queue_id);
    printf("----PDU payload------\n");
    for (uint32_t i = 0; i < block->pdu_size; i++) {
        printf("%02x ", block->pdu_payload[i]);
        if ((i + 1) % 8 == 0) {
            printf(" ");
        }
        if ((i + 1) % 16 == 0) {
            printf("\n");
        }
    }
    printf("\n");
}

uint32_t c2f_copy_head(uint32_t c2f_tail, pcie_block_t *global_block, 
        block_s *block, uint32_t *kdata) {
#ifdef CONTROL_MSG
    // uint32_t pdu_flit;
    // uint32_t copy_flit;
    uint32_t free_slot;
    uint32_t c2f_head;
    // uint32_t copy_size;
    uint32_t base_addr;

    c2f_head = global_block->c2f_head;
    // calculate free_slot
    if (c2f_tail < c2f_head) {
        free_slot = c2f_head - c2f_tail - 1;
    } else {
        //CPU2FPGA ring buffer does not have the global register. 
        //the free_slot should be at most one slot smaller than CPU2FPGA ring buffer.
        free_slot = C2F_BUFFER_SIZE - c2f_tail + c2f_head - 1;
    }
    //printf("free_slot = %d; c2f_head = %d; c2f_tail = %d\n", 
    //        free_slot, c2f_head, c2f_tail);   
    //block when the CPU2FPGA ring buffer is almost full
    while (free_slot < 1) { 
        //recalculate free_slot
    	c2f_head = global_block->c2f_head;
    	if (c2f_tail < c2f_head) {
    	    free_slot = c2f_head - c2f_tail - 1;
    	} else {
    	    free_slot = C2F_BUFFER_SIZE - c2f_tail + c2f_head - 1;
    	}
    }
    base_addr = C2F_BUFFER_OFFSET + c2f_tail * 16;

    // printf("c2f base addr: 0x%08x\n", base_addr);

    //memcpy(&kdata[base_addr], src_addr, 16*4); //each flit is 512 bit

    //Fake match
    kdata[base_addr + PDU_ID_OFFSET] = block->pdu_id;
    //PDU_SIZE
    kdata[base_addr + PDU_PORTS_OFFSET] = (((uint32_t) block->src_port) << 16) | ((uint32_t) block->dst_port);
    kdata[base_addr + PDU_DST_IP_OFFSET] = block->dst_ip;
    kdata[base_addr + PDU_SRC_IP_OFFSET] = block->src_ip;
    kdata[base_addr + PDU_PROTOCOL_OFFSET] = block->protocol;
    kdata[base_addr + PDU_SIZE_OFFSET] = block->pdu_size;
    //exclude the rule flits and header flit
    kdata[base_addr + PDU_FLIT_OFFSET] = block->pdu_flit - 1;
    kdata[base_addr + ACTION_OFFSET] = ACTION_NO_MATCH;
    kdata[base_addr + QUEUE_ID_LO_OFFSET] = block->queue_id & 0xFFFFFFFF;
    kdata[base_addr + QUEUE_ID_HI_OFFSET] = (block->queue_id >> 32) & 0xFFFFFFFF;
    
    // print_slot(kdata, base_addr/16, 1);

    //update c2f_tail
    if(c2f_tail == C2F_BUFFER_SIZE-1){
        c2f_tail = 0;
    } else {
        c2f_tail += 1;
    }
    return c2f_tail;
#else
    return 0;
#endif // CONTROL_MSG
}
