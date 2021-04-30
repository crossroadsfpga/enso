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

static const bool alloc_single_buf = (F2C_DSC_BUF_SIZE + \
    F2C_PKT_BUF_SIZE_EXTRA_ROOM) > BUF_PAGE_SIZE/64;

static inline uint16_t get_pkt_size(uint8_t *addr) {
    uint16_t l2_len = 14 + 4;
    uint16_t l3_len = be16toh(*((uint16_t*) (addr+14+2))); // ipv4 total length
    uint16_t total_len = l2_len + l3_len;
    return total_len;
}

void print_buf(void* buf, const uint32_t nb_cache_lines)
{
    for (uint32_t i = 0; i < nb_cache_lines * 64; i++) {
        printf("%02x ", ((uint8_t*) buf)[i]);
        if ((i + 1) % 8 == 0) {
            printf(" ");
        }
        if ((i + 1) % 16 == 0) {
            printf("\n");
        }
        if ((i + 1) % 64 == 0) {
            printf("\n");
        }
    }
}

// adapted from ixy
static void* virt_to_phys(void* virt) {
	long pagesize = sysconf(_SC_PAGESIZE);
    int fd = open("/proc/self/pagemap", O_RDONLY);
    if (fd < 0) {
        return NULL;
    }
	// pagemap is an array of pointers for each normal-sized page
	if (lseek(fd, (uintptr_t) virt / pagesize * sizeof(uintptr_t),
            SEEK_SET) < 0) {
        close(fd);
        return NULL;
    }

    uintptr_t phy = 0;
    if (read(fd, &phy, sizeof(phy)) < 0) {
        close(fd);
        return NULL;
    }
    close(fd);

	if (!phy) {
        return NULL;
	}
	// bits 0-54 are the page number
	return (void*) ((phy & 0x7fffffffffffffULL) * pagesize
                    + ((uintptr_t) virt) % pagesize);
}

// adapted from ixy
static void* get_huge_pages(int app_id, size_t size) {
    int fd;
    char huge_pages_path[128];

    snprintf(huge_pages_path, 128, "/mnt/huge/fd:%i", app_id);

    fd = open(huge_pages_path, O_CREAT | O_RDWR, S_IRWXU);
    if (fd == -1) {
        std::cerr << "(" << errno
                  << ") Problem opening huge page file descriptor" << std::endl;
        return NULL;
    }

    if (ftruncate(fd, (off_t) size)) {
        std::cerr << "(" << errno << ") Could not truncate huge page to size: "
                  << size << std::endl;
        close(fd);
        unlink(huge_pages_path);
        return NULL;
    }

    void* virt_addr = (void*) mmap(NULL, size,
        PROT_READ | PROT_WRITE, MAP_SHARED | MAP_HUGETLB, fd, 0);

    if (virt_addr == (void*) -1) {
        std::cerr << "(" << errno << ") Could not mmap huge page" << std::endl;
        close(fd);
        unlink(huge_pages_path);
        return NULL;
    }

    if (mlock(virt_addr, size)) {
        std::cerr << "(" << errno << ") Could not lock huge page" << std::endl;
        munmap(virt_addr, size);
        close(fd);
        unlink(huge_pages_path);
        return NULL;
    }

    // don't keep it around in the hugetlbfs
    close(fd);
    unlink(huge_pages_path);

    return virt_addr;
}

// TODO fix this entire thing
int dma_init(socket_internal* socket_entry, unsigned socket_id, unsigned nb_queues)
{
    void* uio_mmap_bar2_addr;
    int app_id;
    intel_fpga_pcie_dev *dev = socket_entry->dev;

    printf("Running with BATCH_SIZE: %i\n", BATCH_SIZE);
    printf("Running with F2C_DSC_BUF_SIZE: %i\n", F2C_DSC_BUF_SIZE);
    printf("Running with F2C_PKT_BUF_SIZE: %i\n", F2C_PKT_BUF_SIZE);

    // FIXME(sadok) should find a better identifier than core id
    app_id = sched_getcpu() * nb_queues + socket_id;
    if (app_id < 0) {
        std::cerr << "Could not get cpu id" << std::endl;
        return -1;
    }

    uio_mmap_bar2_addr = dev->uio_mmap((1<<12) * MAX_NB_APPS, 2);
    if (uio_mmap_bar2_addr == MAP_FAILED) {
        std::cerr << "Could not get mmap uio memory!" << std::endl;
        return -1;
    }
    pcie_block_t *uio_data_bar2 = (pcie_block_t *) (
        (uint8_t*) uio_mmap_bar2_addr + app_id * MEMORY_SPACE_PER_APP
    );
    socket_entry->uio_data_bar2 = uio_data_bar2;

    // if the descriptor and packet buffers cannot fit together in a single huge
    // page, we need to allocate them separately
    if (alloc_single_buf) {
        // TODO (soup) check fd, also offset??
        socket_entry->dsc_buf =
            (pcie_pkt_desc_t *)dev->kmem_mmap(
             ALIGNED_F2C_DSC_BUF_SIZE, 0);
        if (socket_entry->dsc_buf == NULL) {
            std::cerr << "Could not get kern fake hugepage" << std::endl;
            return -1;
        }
	printf("dsc buf from dma_init: 0x%x\n", socket_entry->dsc_buf);
        uint64_t phys_addr = (uint64_t) virt_to_phys(socket_entry->dsc_buf);
        // uio_data_bar2->dsc_buf_mem_low = (uint32_t) phys_addr;
        // uio_data_bar2->dsc_buf_mem_high = (uint32_t) (phys_addr >> 32);

        socket_entry->pkt_buf =
            (uint32_t*) get_huge_pages(app_id, ALIGNED_F2C_PKT_BUF_SIZE);

        if (socket_entry->pkt_buf == NULL) {
            std::cerr << "Could not get huge page" << std::endl;
            return -1;
        }
        phys_addr = (uint64_t) virt_to_phys(socket_entry->pkt_buf);
        // uio_data_bar2->pkt_buf_mem_low = (uint32_t) phys_addr;
        // uio_data_bar2->pkt_buf_mem_high = (uint32_t) (phys_addr >> 32);
    } else {
        // TODO (soup) check fd, also offset??
        void *base_addr =
            (pcie_pkt_desc_t *)dev->kmem_mmap(
             BUF_PAGE_SIZE, 0);
        if (base_addr == NULL) {
            std::cerr << "Could not get kern fake hugepage" << std::endl;
            return -1;
        }

        socket_entry->dsc_buf = (pcie_pkt_desc_t*) base_addr;
	printf("dsc buf from dma_init: 0x%x\n", socket_entry->dsc_buf);

        uint64_t phys_addr = (uint64_t) virt_to_phys(base_addr);
        // uio_data_bar2->dsc_buf_mem_low = (uint32_t) phys_addr;
        // uio_data_bar2->dsc_buf_mem_high = (uint32_t) (phys_addr >> 32);

        // socket_entry->pkt_buf = (uint32_t*) base_addr + F2C_DSC_BUF_SIZE * 16;

        // phys_addr += F2C_DSC_BUF_SIZE * 64;
        // uio_data_bar2->pkt_buf_mem_low = (uint32_t) phys_addr;
        // uio_data_bar2->pkt_buf_mem_high = (uint32_t) (phys_addr >> 32);
    }

    socket_entry->dsc_buf_head_ptr = &uio_data_bar2->dsc_buf_head;
    socket_entry->pkt_buf_head_ptr = &uio_data_bar2->pkt_buf_head;

    socket_entry->app_id = app_id;
    socket_entry->dsc_buf_head = uio_data_bar2->dsc_buf_head;
    socket_entry->pkt_buf_head = uio_data_bar2->pkt_buf_head;
    socket_entry->active = true;

    return 0;
}

/**
 *  @brief reads from socket buffers
 *  @param buf user buffer?
 *  @param len max num packets to read
 *  @return number of packets read
 */
int dma_run(socket_internal* socket_entry, void** buf, size_t len)
{
    pcie_pkt_desc_t* dsc_buf = socket_entry->dsc_buf;
    uint32_t* pkt_buf = socket_entry->pkt_buf;
    uint32_t dsc_buf_head = socket_entry->dsc_buf_head;
    uint32_t pkt_buf_head = socket_entry->pkt_buf_head;

    // 16 = CACHE_LINE_SIZE / sizeof(*pkt_buf)
    *buf = &pkt_buf[pkt_buf_head * 16];
    uint8_t* my_buf = (uint8_t*) *buf;

    uint32_t total_size = 0;
    uint32_t total_flits = 0;

    for (uint16_t i = 0; i < BATCH_SIZE; ++i) {
        // TODO(sadok) right now we have one descriptor queue per packet queue,
        // we will need to consider the queue id once this changes
        pcie_pkt_desc_t* cur_desc = dsc_buf + dsc_buf_head;

	printf("dereference cur_desc / dsc_buf\n");
    	printf("dereference dsc_buf: 0x%x\n", dsc_buf);
	printf("cur_desc->signal = %d\n", cur_desc->signal);
	printf("cur_desc->queue_id = %d\n", cur_desc->queue_id);
	printf("\n");

        // check if the next descriptor was updated by the FPGA
        if (unlikely(cur_desc->signal == 0)) {
            break;
        }

        uint32_t pkt_size = get_pkt_size(my_buf);
        uint32_t pdu_flit = ((pkt_size-1) >> 6) + 1; // number of 64-byte blocks
        uint32_t flit_aligned_size = pdu_flit * 64;

        // reached the buffer limit
        if (unlikely((total_size + flit_aligned_size) > len)) {
            break;
        }

        // If we reach this point, it's safe to return the packet to the user
        cur_desc->signal = 0;
        dsc_buf_head = dsc_buf_head == F2C_DSC_BUF_SIZE-1 ? 0 : dsc_buf_head+1;

        // TODO(sadok) Handle packets that are not flit-aligned. There will be a
        // gap, what should we do?
        total_size += flit_aligned_size;
        total_flits += pdu_flit;

        // Packets may go beyond the buffer size, but the next packet is
        // guaranteed to start at index zero. Also, since the next packet starts
        // at the beginning of the buffer, we need to return immediately to
        // ensure that we always return a contiguous set of packets.
        if ((pkt_buf_head + pdu_flit) >= F2C_PKT_BUF_SIZE) {
            pkt_buf_head = 0;
            break;
        }
        my_buf += flit_aligned_size;
        pkt_buf_head += pdu_flit;
    }

    // update descriptor buffer head
    asm volatile ("" : : : "memory"); // compiler memory barrier
    *(socket_entry->dsc_buf_head_ptr) = dsc_buf_head;

    socket_entry->dsc_buf_head = dsc_buf_head;
    socket_entry->pkt_buf_head = pkt_buf_head;
    return total_size;
}

void advance_ring_buffer(socket_internal* socket_entry)
{
    asm volatile ("" : : : "memory"); // compiler memory barrier
    *(socket_entry->pkt_buf_head_ptr) = socket_entry->pkt_buf_head;
}

// FIXME(sadok) This should be in the kernel
// int send_control_message(socket_internal* socket_entry, unsigned int nb_rules,
//                          unsigned int nb_queues)
// {
//     unsigned next_queue = 0;
//     block_s block;
//     pcie_block_t* global_block = (pcie_block_t *) socket_entry->kdata;
//     pcie_block_t* uio_data_bar2 = socket_entry->uio_data_bar2;

//     if (socket_entry->app_id != 0) {
//         std::cerr << "Can only send control messages from app 0" << std::endl;
//         return -1;
//     }

//     for (unsigned i = 0; i < nb_rules; ++i) {
//         block.pdu_id = 0;
//         block.dst_port = 80;
//         block.src_port = 8080;
//         block.dst_ip = 0xc0a80101; // inet_addr("192.168.1.1");
//         block.src_ip = 0xc0a80000 + i; // inet_addr("192.168.0.0");
//         block.protocol = 0x11;
//         block.pdu_size = 0x0;
//         block.pdu_flit = 0x0;
//         block.queue_id = next_queue; // FIXME(sadok) specify the relevant queue

//         next_queue = (next_queue + 1) % nb_queues;

//         // std::cout << "Setting rule: " << nb_rules << std::endl;
//         // print_block(&block);

//         socket_entry->c2f_cpu_tail = c2f_copy_head(socket_entry->c2f_cpu_tail,
//             global_block, &block, socket_entry->kdata);
//         asm volatile ("" : : : "memory"); // compiler memory barrier
//         uio_data_bar2->c2f_tail = socket_entry->c2f_cpu_tail;

//         // asm volatile ("" : : : "memory"); // compiler memory barrier
//         // print_pcie_block(uio_data_bar2);
//     }

//     return 0;
// }

int dma_finish(socket_internal* socket_entry)
{
    pcie_block_t* uio_data_bar2 = socket_entry->uio_data_bar2;

    uio_data_bar2->dsc_buf_mem_low = 0;
    uio_data_bar2->dsc_buf_mem_high = 0;
    uio_data_bar2->pkt_buf_mem_low = 0;
    uio_data_bar2->pkt_buf_mem_high = 0;

    if (alloc_single_buf) {
        munmap(socket_entry->dsc_buf, ALIGNED_F2C_DSC_BUF_SIZE);
        munmap(socket_entry->pkt_buf, ALIGNED_F2C_PKT_BUF_SIZE);
    } else {
        munmap(socket_entry->dsc_buf, BUF_PAGE_SIZE);
    }

    socket_entry->active = false;

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
    printf("pb->dsc_buf_tail = %d \n", pb->dsc_buf_tail);
    printf("pb->dsc_buf_head = %d \n", pb->dsc_buf_head);
    printf("pb->dsc_buf_mem_low = 0x%08x \n", pb->dsc_buf_mem_low);
    printf("pb->dsc_buf_mem_high = 0x%08x \n", pb->dsc_buf_mem_high);

    printf("pb->pkt_buf_tail = %d \n", pb->pkt_buf_tail);
    printf("pb->pkt_buf_head = %d \n", pb->pkt_buf_head);
    printf("pb->pkt_buf_mem_low = 0x%08x \n", pb->pkt_buf_mem_low);
    printf("pb->pkt_buf_mem_high = 0x%08x \n", pb->pkt_buf_mem_high);

    #ifdef CONTROL_MSG
    printf("pb->c2f_tail = %d \n", pb->c2f_tail);
    printf("pb->c2f_head = %d \n", pb->c2f_head);
    printf("pb->c2f_kmem_low = 0x%08x \n", pb->c2f_kmem_low);
    printf("pb->c2f_kmem_high = 0x%08x \n", pb->c2f_kmem_high);
    #endif // CONTROL_MSG
}


// uint32_t c2f_copy_head(uint32_t c2f_tail, pcie_block_t *global_block,
//         block_s *block, uint32_t *kdata) {
//     // uint32_t pdu_flit;
//     // uint32_t copy_flit;
//     uint32_t free_slot;
//     uint32_t c2f_head;
//     // uint32_t copy_size;
//     uint32_t base_addr;

//     c2f_head = global_block->c2f_head;
//     // calculate free_slot
//     if (c2f_tail < c2f_head) {
//         free_slot = c2f_head - c2f_tail - 1;
//     } else {
//         //CPU2FPGA ring buffer does not have the global register.
//         //the free_slot should be at most one slot smaller than CPU2FPGA ring buffer.
//         free_slot = C2F_BUFFER_SIZE - c2f_tail + c2f_head - 1;
//     }
//     //printf("free_slot = %d; c2f_head = %d; c2f_tail = %d\n",
//     //        free_slot, c2f_head, c2f_tail);
//     //block when the CPU2FPGA ring buffer is almost full
//     while (free_slot < 1) {
//         //recalculate free_slot
//     	c2f_head = global_block->c2f_head;
//     	if (c2f_tail < c2f_head) {
//     	    free_slot = c2f_head - c2f_tail - 1;
//     	} else {
//     	    free_slot = C2F_BUFFER_SIZE - c2f_tail + c2f_head - 1;
//     	}
//     }
//     base_addr = C2F_BUFFER_OFFSET + c2f_tail * 16;

//     // printf("c2f base addr: 0x%08x\n", base_addr);

//     //memcpy(&kdata[base_addr], src_addr, 16*4); //each flit is 512 bit

//     //Fake match
//     kdata[base_addr + PDU_ID_OFFSET] = block->pdu_id;
//     //PDU_SIZE
//     kdata[base_addr + PDU_PORTS_OFFSET] = (((uint32_t) block->src_port) << 16) | ((uint32_t) block->dst_port);
//     kdata[base_addr + PDU_DST_IP_OFFSET] = block->dst_ip;
//     kdata[base_addr + PDU_SRC_IP_OFFSET] = block->src_ip;
//     kdata[base_addr + PDU_PROTOCOL_OFFSET] = block->protocol;
//     kdata[base_addr + PDU_SIZE_OFFSET] = block->pdu_size;
//     //exclude the rule flits and header flit
//     kdata[base_addr + PDU_FLIT_OFFSET] = block->pdu_flit - 1;
//     kdata[base_addr + ACTION_OFFSET] = ACTION_NO_MATCH;
//     kdata[base_addr + QUEUE_ID_LO_OFFSET] = block->queue_id & 0xFFFFFFFF;
//     kdata[base_addr + QUEUE_ID_HI_OFFSET] = (block->queue_id >> 32) & 0xFFFFFFFF;

//     // print_slot(kdata, base_addr/16, 1);

//     //update c2f_tail
//     if(c2f_tail == C2F_BUFFER_SIZE-1){
//         c2f_tail = 0;
//     } else {
//         c2f_tail += 1;
//     }
//     return c2f_tail;
// }
