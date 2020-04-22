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
#include <cerrno>
#include <cstdlib>
#include <ctime>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <system_error>
#include <string.h>

#include <sched.h>

#include "api/intel_fpga_pcie_api.hpp"
// #include "intel_fpga_pcie_link_test.hpp"
#include "pcie.h"

using namespace std;

void dma_run(intel_fpga_pcie_dev* dev, proc_packet_f* proc_pkt, 
             volatile int* keep_running)
{
    int result;
    void *mmap_addr, *uio_mmap_bar2_addr;
    uint32_t *kdata; //, *cpu_head_reg;
    pcie_block_t *uio_data_bar2;
    int core_id;

    unsigned int cpu_head = 0; // head ptr
    unsigned int cpu_tail;
    int free_slot; // number of free slots in ring buffer
    unsigned int allocated_size;
    unsigned int copy_size;

    unsigned int c2f_cpu_head; // head ptr
    unsigned int c2f_cpu_tail = 0;

    block_s pdu; //current PDU block
    pcie_block_t *global_block; // The global 512-bit register array.

    allocated_size = (BUFFER_SIZE+1+C2F_BUFFER_SIZE)*16*4 + 4096; //Add one more page for rounding pkts. 

    // Obtain kernel memory.
    result = dev->set_kmem_size(allocated_size);
    if (result != 1) {
        cout << "Could not get kernel memory!" << endl;
        return;
    }
    mmap_addr = dev->kmem_mmap(allocated_size, 0);
    if (mmap_addr == MAP_FAILED) {
        cout << "Could not get mmap kernel memory!" << endl;
        return;
    }
    kdata = reinterpret_cast<uint32_t *>(mmap_addr);

    uio_mmap_bar2_addr = dev->uio_mmap(sizeof(pcie_block), 2);
    if (uio_mmap_bar2_addr == MAP_FAILED) {
        cout << "Could not get mmap uio memory!" << endl;
        return;
    }
    uio_data_bar2 = reinterpret_cast<pcie_block_t *>(uio_mmap_bar2_addr);
    
    //get cpu_id
    core_id = sched_getcpu();
    if (core_id < 0) {
        cout << "Could not get cpu id!" << endl;
        return;
    }

    // cpu_head_reg = &(uio_data_bar2->head) + (core_id - 1) * 16/4; // start from core 0
    // *cpu_head_reg = core_id;

    // Global registers is the first slot of the ring buffer.
    global_block = (pcie_block_t *) kdata;

    // print the first slot, start 0, range 1
    print_fpga_reg(dev);

    unsigned long long rx_pkts = 0;
    unsigned long long num_rules = 0;

    // Main Loop
    while (*keep_running) {
        cpu_tail = global_block->tail; // only read it once.
        if (cpu_tail == cpu_head) { // if empty, wait
            continue;
        }

        // calculate free_slot
        if (cpu_tail <= cpu_head) {
            free_slot = cpu_head - cpu_tail;
        } else {
            free_slot = BUFFER_SIZE - cpu_tail + cpu_head;
        }

        //printf("CPU head = %d; CPU tail = %d; free_slot = %d \n", 
        //         cpu_head,cpu_tail,free_slot);
        if (free_slot < 1) {
            printf("FPGA breaks free_slot assumption! \n");
            exit(1);
        }

        // fill in the pdu hdr
        fill_block(&kdata[(cpu_head+1)*16],&pdu);

        // check transfer_flit
        if (pdu.pdu_flit == 0) {
            printf("transfer_flit has to be bigger than 0 ! \n");
            exit(1);
        }

        // We need to copy the begining of the ring buffer to the last page
        if ((cpu_head + pdu.pdu_flit) > BUFFER_SIZE) {
            //printf("memcpy, cpu.head = %d, pdu.pdu_flit = %d \n", cpu_head,pdu.pdu_flit);
            if ((cpu_head + pdu.pdu_flit) != BUFFER_SIZE) {
                copy_size = cpu_head + pdu.pdu_flit - BUFFER_SIZE;
                memcpy(&kdata[(BUFFER_SIZE+1)*16], &kdata[1*16], copy_size*16*4);
            }
        }

        proc_pkt(&pdu);

        // update cpu_head
        if ((cpu_head + pdu.pdu_flit) < BUFFER_SIZE) {
            cpu_head = cpu_head + pdu.pdu_flit;
        } else {
            cpu_head = cpu_head + pdu.pdu_flit - BUFFER_SIZE;
        }

        // method using syscall
        // dev->write32(2, reinterpret_cast<void *>(HEAD_OFFSET), cpu_head);

        // method using UIO
        asm volatile ("" : : : "memory"); // compiler memory barrier
        uio_data_bar2->head = cpu_head;

        ++rx_pkts;
        num_rules += pdu.num_rule_id;
    }
    c2f_cpu_head = global_block->c2f_head;

    cout << dec;
    cout << "rx pkts: " << rx_pkts << endl;
    cout << "num rules: " << num_rules << endl;
    cout << "cpu_head: " << cpu_head << endl;
    cout << "cpu_tail: " << cpu_tail << endl;
    cout << "c2f_cpu_head: " << c2f_cpu_head << endl;
    cout << "c2f_cpu_tail: " << c2f_cpu_tail << endl;

    result = dev->kmem_munmap(mmap_addr, allocated_size);
    if (result != 1) {
        cout << "Could not unmap kernel memory!" << endl;
        return;
    }
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
        printf("fpga_reg[%d] = 0x%08x \n",i, temp_r);
    }
} 

void print_pcie_block(pcie_block_t * pb)
{
    printf("pb->tail = %d \n", pb->tail);
    printf("pb->head = %d \n", pb->head);
    printf("pb->kmem_low = 0x%08x \n", pb->kmem_low);
    printf("pb->kmem_high = 0x%08x \n", pb->kmem_high);
}

void fill_block(uint32_t *addr, block_s *block) {
    int reminder;
    int offset;

    block->pdu_id = addr[0];
    block->dst_port = addr[1] & 0xFFFF;
    block->src_port = (addr[1] >> 16) & 0xFFFF;
    block->dst_ip = addr[2];
    block->src_ip = addr[3];
    block->protocol = addr[4];

    block->num_rule_id = addr[5];

    block->pdu_size = addr[6];
    //block->pdu_flit = addr[7];
    block->pdu_flit = 25; //quick fix
    block->pdu_payload = (uint8_t*) &addr[16];

    // Calculate the offset of the rule_id
    reminder = block->pdu_size & 0x3F;
    offset = block->pdu_size >> 6;
    if (reminder > 0){
        offset += 1;
    }
    // include the hdr entry
    offset = (offset + 1) * 16; // 16 * 32 bit = 512 bit

    block->rule_id = (uint16_t *)&addr[offset];
}

void print_block(block_s *block) {
    uint32_t i;
    printf("=============PRINT BLOCK=========\n");
    printf("pdu_id      : 0x%08x \n", block->pdu_id);
    printf("dst_port    : 0x%04x \n", block->dst_port);
    printf("src_port    : 0x%04x \n", block->src_port);
    printf("dst_ip      : 0x%08x \n", block->dst_ip);
    printf("src_ip      : 0x%08x \n", block->src_ip);
    printf("protocol    : 0x%08x \n", block->protocol);
    printf("num_rule_id : 0x%08x \n", block->num_rule_id);
    printf("pdu_size    : 0x%08x \n", block->pdu_size);
    printf("pdu_flit    : 0x%08x \n", block->pdu_flit);
    printf("----PDU payload------\n");
    for (i = 0; i < block->pdu_size; i++) {
        printf("%02x ", block->pdu_payload[i]);
        if ((i + 1) % 8 == 0) {
            printf(" ");
        }
        if ((i + 1) % 16 == 0) {
            printf("\n");
        }
    }
    printf("\n----Rule IDs------\n");
    //512-bit aligned. 32 16-bit rule ID per line.
    for(i=0;i<block->num_rule_id*32;i++){
        if(block->rule_id[i]!=0){
            printf("ruleID[%d] = 0x%04x \n",i, block->rule_id[i]);
        }
    }
}

uint32_t c2f_copy_head(uint32_t c2f_tail, pcie_block_t *global_block, 
        block_s *block, uint32_t *kdata) {
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
    base_addr = C2F_BUFFER_OFFSET+c2f_tail*16;

    //memcpy(&kdata[base_addr], src_addr, 16*4); //each flit is 512 bit

    //Fake match
    kdata[base_addr + PDU_ID_OFFSET] = block->pdu_id;
    //PDU_SIZE
    kdata[base_addr + PDU_SIZE_OFFSET] = block->pdu_size;
    //exclude the rule flits and header flit
    kdata[base_addr + PDU_FLIT_OFFSET] = block->pdu_flit - block->num_rule_id - 1;
    kdata[base_addr + ACTION_OFFSET] = ACTION_NO_MATCH;
    //kdata[base_addr + ACTION_OFFSET] = ACTION_MATCH;
    
    //print_slot(kdata,base_addr/16, 1);

    //update c2f_tail
    if(c2f_tail == C2F_BUFFER_SIZE-1){
        c2f_tail = 0;
    } else {
        c2f_tail += 1;
    }
    return c2f_tail;
}
