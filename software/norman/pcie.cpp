
#include <algorithm>
#include <termios.h>
#include <time.h>
#include <cassert>
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <ctime>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <system_error>
#include <string.h>

#include <immintrin.h>

#include <sched.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include "api/intel_fpga_pcie_api.hpp"
// #include "intel_fpga_pcie_link_test.hpp"
#include "pcie.h"


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


// Adapted from ixy.
static uint64_t virt_to_phys(void* virt) {
	long pagesize = sysconf(_SC_PAGESIZE);
    int fd = open("/proc/self/pagemap", O_RDONLY);
    if (fd < 0) {
        return 0;
    }
	// pagemap is an array of pointers for each normal-sized page
	if (lseek(fd, (uintptr_t) virt / pagesize * sizeof(uintptr_t),
            SEEK_SET) < 0) {
        close(fd);
        return 0;
    }
	
    uintptr_t phy = 0;
    if (read(fd, &phy, sizeof(phy)) < 0) {
        close(fd);
        return 0;
    }
    close(fd);

	if (!phy) {
        return 0;
	}
	// bits 0-54 are the page number
	return (uint64_t) ((phy & 0x7fffffffffffffULL) * pagesize 
                       + ((uintptr_t) virt) % pagesize);
}


// Adapted from ixy.
static void* get_huge_page(int queue_id, size_t size) {
    int fd;
    char huge_pages_path[128];

    snprintf(huge_pages_path, 128, "/mnt/huge/norman:%i", queue_id);

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

    void* virt_addr = (void*) mmap(NULL, size * 2,
        PROT_READ | PROT_WRITE, MAP_SHARED | MAP_HUGETLB, fd, 0);

    if (virt_addr == (void*) -1) {
        std::cerr << "(" << errno << ") Could not mmap huge page" << std::endl;
        close(fd);
        unlink(huge_pages_path);
        return NULL;
    }

    // Allocate same huge page at the end of the last one.
    void* ret = (void*) mmap((uint8_t*) virt_addr + size, size,
        PROT_READ | PROT_WRITE, MAP_FIXED | MAP_SHARED | MAP_HUGETLB, fd, 0);

    if (ret == (void*) -1) {
        std::cerr << "(" << errno << ") Could not mmap second huge page"
                  << std::endl;
        close(fd);
        unlink(huge_pages_path);
        free(virt_addr);
        return NULL;
    }
    
    if (mlock(virt_addr, size)) {
        std::cerr << "(" << errno << ") Could not lock huge page" << std::endl;
        munmap(virt_addr, size);
        close(fd);
        unlink(huge_pages_path);
        return NULL;
    }

    // Don't keep it around in the hugetlbfs.
    close(fd);
    unlink(huge_pages_path);

    return virt_addr;
}


int dma_init(socket_internal* socket_entry, unsigned socket_id,
             unsigned nb_queues)
{
    dsc_queue_t* dsc_queue = socket_entry->dsc_queue;
    void* uio_mmap_bar2_addr;
    int dsc_queue_id, pkt_queue_id;
    intel_fpga_pcie_dev *dev = socket_entry->dev;

    printf("Running with BATCH_SIZE: %i\n", BATCH_SIZE);
    printf("Running with DSC_BUF_SIZE: %i\n", DSC_BUF_SIZE);
    printf("Running with PKT_BUF_SIZE: %i\n", PKT_BUF_SIZE);

    // We need this to allow the same huge page to be mapped to contiguous
    // memory regions.
    // TODO(sadok): support other buffer sizes. It may be possible to support
    // other buffer sizes by overlaying regular pages on top of the huge pages.
    // We might use those only for requests that overlap to avoid adding too
    // many entries to the TLB.
    assert(PKT_BUF_SIZE*64 == BUF_PAGE_SIZE);

    // FIXME(sadok) should find a better identifier than core id.
    pkt_queue_id = sched_getcpu() * nb_queues + socket_id;
    dsc_queue_id = sched_getcpu();
    if (pkt_queue_id < 0) {
        std::cerr << "Could not get cpu id" << std::endl;
        return -1;
    }

    uio_mmap_bar2_addr = dev->uio_mmap(
        (1<<12) * (MAX_NB_FLOWS + MAX_NB_APPS), 2);
    if (uio_mmap_bar2_addr == MAP_FAILED) {
        std::cerr << "Could not get mmap uio memory!" << std::endl;
        return -1;
    }

    // set descriptor queue only for the first socket
    if (dsc_queue->ref_cnt == 0) {
        // Register associated with the descriptor queue. Descriptor queue
        // registers come after the packet queue ones, that's why we use 
        // MAX_NB_FLOWS as an offset.
        queue_regs_t *dsc_queue_regs = (queue_regs_t *) (
            (uint8_t*) uio_mmap_bar2_addr + 
            (dsc_queue_id + MAX_NB_FLOWS) * MEMORY_SPACE_PER_QUEUE
        );

        // Make sure the queue is disabled.
        dsc_queue_regs->rx_mem_low = 0;
        dsc_queue_regs->rx_mem_high = 0;
        _norman_compiler_memory_barrier();
        while (dsc_queue_regs->rx_mem_low != 0
                || dsc_queue_regs->rx_mem_high != 0)
            continue;

        // Make sure head and tail start at zero.
        dsc_queue_regs->rx_head = 0;
        dsc_queue_regs->rx_tail = 0;
        _norman_compiler_memory_barrier();
        while (dsc_queue_regs->rx_head != 0 || dsc_queue_regs->rx_tail != 0)
            continue;

        dsc_queue->regs = dsc_queue_regs;
        dsc_queue->rx_buf = (pcie_rx_dsc_t*) get_huge_page(
            dsc_queue_id + MAX_NB_FLOWS, ALIGNED_DSC_BUF_PAIR_SIZE);
        if (dsc_queue->rx_buf == NULL) {
            std::cerr << "Could not get huge page" << std::endl;
            return -1;
        }
        dsc_queue->tx_buf = (pcie_tx_dsc_t*) (
            (uint64_t) dsc_queue->rx_buf + ALIGNED_DSC_BUF_PAIR_SIZE / 2);

        uint64_t phys_addr = virt_to_phys(dsc_queue->rx_buf);

        // Use first half of the huge page for RX and second half for TX.
        dsc_queue_regs->rx_mem_low = (uint32_t) phys_addr;
        dsc_queue_regs->rx_mem_high = (uint32_t) (phys_addr >> 32);

        phys_addr += ALIGNED_DSC_BUF_PAIR_SIZE / 2;
        dsc_queue_regs->tx_mem_low = (uint32_t) phys_addr;
        dsc_queue_regs->tx_mem_high = (uint32_t) (phys_addr >> 32);

        dsc_queue->rx_head_ptr = &dsc_queue_regs->rx_head;
        dsc_queue->tx_tail_ptr = &dsc_queue_regs->tx_tail;
        dsc_queue->rx_head = dsc_queue_regs->rx_head;
        
        // Preserve TX DSC tail and make head match the same value.
        dsc_queue->tx_tail = dsc_queue_regs->tx_tail;
        dsc_queue->tx_head = dsc_queue->tx_tail;
        dsc_queue_regs->tx_head = dsc_queue->tx_head;

        // HACK(sadok) assuming that we know the number of queues beforehand
        dsc_queue->pending_pkt_tails = (uint32_t*) malloc(
            sizeof(*(dsc_queue->pending_pkt_tails)) * nb_queues);
        if (dsc_queue->pending_pkt_tails == NULL) {
            std::cerr << "Could not allocate memory" << std::endl;
            return -1;
        }
        memset(dsc_queue->pending_pkt_tails, 0, nb_queues);

        dsc_queue->wrap_tracker = (uint8_t*) malloc(DSC_BUF_SIZE/8);
        if (dsc_queue->wrap_tracker == NULL) {
            std::cerr << "Could not allocate memory" << std::endl;
            return -1;
        }
        memset(dsc_queue->wrap_tracker, 0, DSC_BUF_SIZE/8);

        dsc_queue->last_rx_ids =
            (pkt_q_id_t*) malloc(DSC_BUF_SIZE * sizeof(pkt_q_id_t));
        if (dsc_queue->last_rx_ids == NULL) {
            std::cerr << "Could not allocate memory" << std::endl;
            return -1;
        }

        dsc_queue->pending_rx_ids = 0;
        dsc_queue->consumed_rx_ids = 0;
        dsc_queue->tx_full_cnt = 0;
        dsc_queue->nb_unreported_completions = 0;

        // HACK(sadok): This only works because pkt queues for the same app are
        // currently placed back to back.
        dsc_queue->pkt_queue_id_offset = pkt_queue_id;
    }

    ++(dsc_queue->ref_cnt);

    // register associated with the packet queue
    queue_regs_t *pkt_queue_regs = (queue_regs_t *) (
        (uint8_t*) uio_mmap_bar2_addr + pkt_queue_id * MEMORY_SPACE_PER_QUEUE
    );
    socket_entry->pkt_queue.regs = pkt_queue_regs;

    // Make sure the queue is disabled.
    pkt_queue_regs->rx_mem_low = 0;
    pkt_queue_regs->rx_mem_high = 0;
    _norman_compiler_memory_barrier();
    while (pkt_queue_regs->rx_mem_low != 0 || pkt_queue_regs->rx_mem_high != 0)
        continue;
    
    // Make sure head and tail start at zero.
    pkt_queue_regs->rx_head = 0;
    pkt_queue_regs->rx_tail = 0;
    _norman_compiler_memory_barrier();
    while (pkt_queue_regs->rx_head != 0 || pkt_queue_regs->rx_tail != 0)
        continue;

    socket_entry->pkt_queue.buf = 
        (uint32_t*) get_huge_page(pkt_queue_id, BUF_PAGE_SIZE);
    if (socket_entry->pkt_queue.buf == NULL) {
        std::cerr << "Could not get huge page" << std::endl;
        return -1;
    }
    uint64_t phys_addr = virt_to_phys(socket_entry->pkt_queue.buf);

    socket_entry->pkt_queue.buf_phys_addr = phys_addr;
    socket_entry->pkt_queue.phys_buf_offset =
        phys_addr - (uint64_t) (socket_entry->pkt_queue.buf);

    socket_entry->queue_id = pkt_queue_id - dsc_queue->pkt_queue_id_offset;
    socket_entry->pkt_queue.buf_head_ptr = &pkt_queue_regs->rx_head;
    socket_entry->pkt_queue.rx_head = 0;
    socket_entry->pkt_queue.rx_tail = 0;

    // make sure the last tail matches the current head
    dsc_queue->pending_pkt_tails[socket_entry->queue_id] = 
        socket_entry->pkt_queue.rx_head;

    // Setting the address enables the queue. Do this last.
    _norman_compiler_memory_barrier();
    pkt_queue_regs->rx_mem_low = (uint32_t) phys_addr + dsc_queue_id;
    pkt_queue_regs->rx_mem_high = (uint32_t) (phys_addr >> 32);

    return 0;
}


static inline uint16_t get_new_tails(dsc_queue_t* dsc_queue)
{
    pcie_rx_dsc_t* dsc_buf = dsc_queue->rx_buf;
    uint32_t dsc_buf_head = dsc_queue->rx_head;
    uint16_t nb_consumed_dscs = 0;

    for (uint16_t i = 0; i < BATCH_SIZE; ++i) {
        pcie_rx_dsc_t* cur_desc = dsc_buf + dsc_buf_head;

        // check if the next descriptor was updated by the FPGA
        if (cur_desc->signal == 0) {
            break;
        }

        cur_desc->signal = 0;
        dsc_buf_head = (dsc_buf_head + 1) % DSC_BUF_SIZE;

        pkt_q_id_t pkt_queue_id =
            cur_desc->queue_id - dsc_queue->pkt_queue_id_offset;
        dsc_queue->pending_pkt_tails[pkt_queue_id] = (uint32_t) cur_desc->tail;
        dsc_queue->last_rx_ids[nb_consumed_dscs] = pkt_queue_id;

        ++nb_consumed_dscs;

        // TODO(sadok) consider prefetching. Two options to consider:
        // (1) prefetch all the packets;
        // (2) pass the current queue as argument and prefetch packets for it,
        //     including potentially old packets.
    }

    if (likely(nb_consumed_dscs > 0)) {
        // update descriptor buffer head
        _norman_compiler_memory_barrier();
        *(dsc_queue->rx_head_ptr) = dsc_buf_head;
        dsc_queue->rx_head = dsc_buf_head;
    }

    return nb_consumed_dscs;
}


static inline int consume_queue(socket_internal* socket_entry, void** buf,
                                size_t len)
{
    uint32_t* pkt_buf = socket_entry->pkt_queue.buf;
    uint32_t pkt_buf_head = socket_entry->pkt_queue.rx_tail;
    dsc_queue_t* dsc_queue = socket_entry->dsc_queue;
    int queue_id = socket_entry->queue_id;

    *buf = &pkt_buf[pkt_buf_head * 16];

    uint32_t pkt_buf_tail = dsc_queue->pending_pkt_tails[queue_id];

    if (pkt_buf_tail == pkt_buf_head) {
        return 0;
    }

    _mm_prefetch(buf, _MM_HINT_T0);

    uint32_t flit_aligned_size = 
        ((pkt_buf_tail - pkt_buf_head) % PKT_BUF_SIZE) * 64;

    // Reached the buffer limit.
    if (unlikely(flit_aligned_size > len)) {
        flit_aligned_size = len & 0xffffffc0;  // Align len to 64 bytes.
    }

    pkt_buf_head = (pkt_buf_head + flit_aligned_size / 64) % PKT_BUF_SIZE;

    socket_entry->pkt_queue.rx_tail = pkt_buf_head;
    return flit_aligned_size;
}


int get_next_batch_from_queue(socket_internal* socket_entry, void** buf,
                              size_t len)
{
    get_new_tails(socket_entry->dsc_queue);
    return consume_queue(socket_entry, buf, len);
}


// Return next batch among all open sockets.
int get_next_batch(dsc_queue_t* dsc_queue, socket_internal* socket_entries,
                   int* pkt_queue_id, void** buf, size_t len)
{
    // Consume up to a batch of descriptors at a time. If the number of
    // consumed is the same as the number of pending, we are done processing
    // the last batch and can get the next one. Using batches here performs
    // **significantly** better compared to always fetching the latest
    // descriptor.
    if (dsc_queue->pending_rx_ids == dsc_queue->consumed_rx_ids) {
        dsc_queue->pending_rx_ids = get_new_tails(dsc_queue);
        dsc_queue->consumed_rx_ids = 0;
        if (unlikely(dsc_queue->pending_rx_ids == 0)) {
            return 0;
        }
    }

    pkt_q_id_t __pkt_queue_id =
        dsc_queue->last_rx_ids[dsc_queue->consumed_rx_ids++];
    *pkt_queue_id = __pkt_queue_id;

    socket_internal* socket_entry = &socket_entries[__pkt_queue_id];

    return consume_queue(socket_entry, buf, len);
}


void advance_ring_buffer(socket_internal* socket_entry, size_t len)
{
    uint32_t rx_pkt_head = socket_entry->pkt_queue.rx_head;
    uint32_t nb_flits = ((uint64_t) len - 1) / 64 + 1;
    rx_pkt_head = (rx_pkt_head + nb_flits) % PKT_BUF_SIZE;

    _norman_compiler_memory_barrier();
    *(socket_entry->pkt_queue.buf_head_ptr) = rx_pkt_head;

    socket_entry->pkt_queue.rx_head = rx_pkt_head;
}


int send_to_queue(dsc_queue_t* dsc_queue, void* phys_addr, size_t len)
{
    pcie_tx_dsc_t* tx_buf = dsc_queue->tx_buf;
    uint32_t tx_tail = dsc_queue->tx_tail;
    uint64_t missing_bytes = len;

    uint64_t transf_addr = (uint64_t) phys_addr;
    uint64_t hugepage_mask = ~((uint64_t) BUF_PAGE_SIZE - 1);
    uint64_t hugepage_base_addr = transf_addr & hugepage_mask;
    uint64_t hugepage_boundary = hugepage_base_addr + BUF_PAGE_SIZE;

    while (missing_bytes > 0) {
        uint32_t free_slots = (dsc_queue->tx_head - tx_tail - 1) % DSC_BUF_SIZE;
        
        // Block until we can send.
        while (unlikely(free_slots == 0)) {
            ++dsc_queue->tx_full_cnt;
            update_tx_head(dsc_queue);
            free_slots = (dsc_queue->tx_head - tx_tail - 1) % DSC_BUF_SIZE;
        }

        pcie_tx_dsc_t* tx_dsc = tx_buf + tx_tail;
        uint64_t req_length = std::min(missing_bytes,
                                       (uint64_t) MAX_TRANSFER_LEN);

        // If transmission wraps around hugepage, we need to send two requests
        // and set a bit in the wrap tracker.
        uint64_t missing_bytes_in_page = hugepage_boundary - transf_addr;

        uint8_t wrap_tracker_mask =
            (req_length > missing_bytes_in_page) << (tx_tail & 0x7);
        dsc_queue->wrap_tracker[tx_tail / 8] |= wrap_tracker_mask;

        req_length = std::min(req_length, missing_bytes_in_page);

        tx_dsc->length = req_length;
        tx_dsc->signal = 1;
        tx_dsc->phys_addr = transf_addr;

        uint64_t huge_page_offset = (transf_addr + req_length) % BUF_PAGE_SIZE;
        transf_addr = hugepage_base_addr + huge_page_offset;

        _mm_clflushopt(tx_dsc);

        tx_tail = (tx_tail + 1) % DSC_BUF_SIZE;
        missing_bytes -= req_length;
    }

    dsc_queue->tx_tail = tx_tail;

    _norman_compiler_memory_barrier();
    *(dsc_queue->tx_tail_ptr) = tx_tail;

    return 0;
}


uint32_t get_unreported_completions(dsc_queue_t* dsc_queue)
{
    uint32_t completions;
    update_tx_head(dsc_queue);
    completions = dsc_queue->nb_unreported_completions;
    dsc_queue->nb_unreported_completions = 0;

    return completions;
}


int send_config(dsc_queue_t* dsc_queue, pcie_tx_dsc_t* config_dsc)
{
    pcie_tx_dsc_t* tx_buf = dsc_queue->tx_buf;
    uint32_t tx_tail = dsc_queue->tx_tail;
    uint32_t free_slots = (dsc_queue->tx_head - tx_tail - 1) % DSC_BUF_SIZE;

    // Make sure it's a config descriptor.
    if (config_dsc->signal < 2) {
        return -1;
    }

    // Block until we can send.
    while (unlikely(free_slots == 0)) {
        ++dsc_queue->tx_full_cnt;
        update_tx_head(dsc_queue);
        free_slots = (dsc_queue->tx_head - tx_tail - 1) % DSC_BUF_SIZE;
    }

    pcie_tx_dsc_t* tx_dsc = tx_buf + tx_tail;
    *tx_dsc = *config_dsc;

    _mm_clflushopt(tx_dsc);

    tx_tail = (tx_tail + 1) % DSC_BUF_SIZE;
    dsc_queue->tx_tail = tx_tail;

    _norman_compiler_memory_barrier();
    *(dsc_queue->tx_tail_ptr) = tx_tail;

    // Wait for request to be consumed.
    uint32_t nb_unreported_completions = dsc_queue->nb_unreported_completions;
    while (dsc_queue->nb_unreported_completions == nb_unreported_completions) {
        update_tx_head(dsc_queue);
    }
    dsc_queue->nb_unreported_completions = nb_unreported_completions;

    return 0;
}


int insert_flow_entry(dsc_queue_t* dsc_queue, uint16_t dst_port,
                      uint16_t src_port, uint32_t dst_ip, uint32_t src_ip,
                      uint32_t protocol, uint32_t pkt_queue_id)
{
    flow_table_config_t config;

    config.signal = 2;
    config.config_id = FLOW_TABLE_CONFIG_ID;
    config.dst_port = dst_port;
    config.src_port = src_port;
    config.dst_ip = dst_ip;
    config.src_ip = src_ip;
    config.protocol = protocol;
    config.pkt_queue_id = pkt_queue_id;

    return send_config(dsc_queue, (pcie_tx_dsc_t*) &config);
}


int enable_timestamp(dsc_queue_t* dsc_queue)
{
    timestamp_config_t config;
    
    config.signal = 2;
    config.config_id = TIMESTAMP_CONFIG_ID;
    config.enable = -1;
    
    return send_config(dsc_queue, (pcie_tx_dsc_t*) &config);
}


int disable_timestamp(dsc_queue_t* dsc_queue)
{
    timestamp_config_t config;
    
    config.signal = 2;
    config.config_id = TIMESTAMP_CONFIG_ID;
    config.enable = 0;
    
    return send_config(dsc_queue, (pcie_tx_dsc_t*) &config);
}


int enable_rate_limit(dsc_queue_t* dsc_queue, uint16_t num, uint16_t den)
{
    rate_limit_config_t config;

    config.signal = 2;
    config.config_id = RATE_LIMIT_CONFIG_ID;
    config.denominator = den;
    config.numerator = num;
    config.enable = -1;

    return send_config(dsc_queue, (pcie_tx_dsc_t*) &config);
}


int disable_rate_limit(dsc_queue_t* dsc_queue)
{
    rate_limit_config_t config;

    config.signal = 2;
    config.config_id = RATE_LIMIT_CONFIG_ID;
    config.enable = 0;

    return send_config(dsc_queue, (pcie_tx_dsc_t*) &config);
}


void update_tx_head(dsc_queue_t* dsc_queue)
{
    pcie_tx_dsc_t* tx_buf = dsc_queue->tx_buf;
    uint32_t head = dsc_queue->tx_head;
    uint32_t tail = dsc_queue->tx_tail;

    // Advance pointer for pkt queues that were already sent.
    for (uint16_t i = 0; i < BATCH_SIZE; ++i) {
        if (head == tail) {
            break;
        }
        pcie_tx_dsc_t* tx_dsc = tx_buf + head;

        // Descriptor has not yet been consumed by hardware.
        if (tx_dsc->signal != 0) {
            break;
        }

        // Requests that wrap around need two descriptors but should only signal
        // a single completion notification. Therefore, we only increment
        // `nb_unreported_completions` in the second descriptor.
        // TODO(sadok): If we implement the logic to have two descriptors in the
        // same cache line, we can get rid of `wrap_tracker` and instead check
        // for two descriptors.
        uint8_t wrap_tracker_mask = 1 << (head & 0x7);
        uint8_t no_wrap =
            !(dsc_queue->wrap_tracker[head / 8] & wrap_tracker_mask);
        dsc_queue->nb_unreported_completions += no_wrap;
        dsc_queue->wrap_tracker[head / 8] &= ~wrap_tracker_mask;

        head = (head + 1) % DSC_BUF_SIZE;
    }

    dsc_queue->tx_head = head;
}


int dma_finish(socket_internal* socket_entry)
{
    dsc_queue_t* dsc_queue = socket_entry->dsc_queue;
    queue_regs_t* pkt_queue_regs = socket_entry->pkt_queue.regs;
    pkt_queue_regs->rx_mem_low = 0;
    pkt_queue_regs->rx_mem_high = 0;

    munmap(socket_entry->pkt_queue.buf, BUF_PAGE_SIZE);

    if (dsc_queue->ref_cnt == 0) {
        return 0;
    }

    if (--(dsc_queue->ref_cnt) == 0) {
        dsc_queue->regs->rx_mem_low = 0;
        dsc_queue->regs->rx_mem_high = 0;

        dsc_queue->regs->tx_mem_low = 0;
        dsc_queue->regs->tx_mem_high = 0;
        munmap(dsc_queue->rx_buf, ALIGNED_DSC_BUF_PAIR_SIZE);
        free(dsc_queue->pending_pkt_tails);
        free(dsc_queue->wrap_tracker);
        free(dsc_queue->last_rx_ids);
    }

    return 0;
}


uint32_t get_pkt_queue_id_from_socket(socket_internal* socket_entry)
{
    dsc_queue_t* dsc_queue = socket_entry->dsc_queue;
    return (uint32_t) socket_entry->queue_id + dsc_queue->pkt_queue_id_offset;
}


void print_fpga_reg(intel_fpga_pcie_dev *dev, unsigned nb_regs)
{
    uint32_t temp_r;
    for (unsigned int i = 0; i < nb_regs; ++i) {
        dev->read32(2, reinterpret_cast<void*>(0 + i*4), &temp_r);
        printf("fpga_reg[%d] = 0x%08x \n", i, temp_r);
    }
} 


void print_queue_regs(queue_regs* regs)
{
    printf("rx_tail = %d \n", regs->rx_tail);
    printf("rx_head = %d \n", regs->rx_head);
    printf("rx_mem_low = 0x%08x \n", regs->rx_mem_low);
    printf("rx_mem_high = 0x%08x \n", regs->rx_mem_high);

    printf("tx_tail = %d \n", regs->tx_tail);
    printf("tx_head = %d \n", regs->tx_head);
    printf("tx_mem_low = 0x%08x \n", regs->tx_mem_low);
    printf("tx_mem_high = 0x%08x \n", regs->tx_mem_high);
}


void print_stats(socket_internal* socket_entry, bool print_global)
{
    dsc_queue_t* dsc_queue = socket_entry->dsc_queue;

    if (print_global) {
        printf("TX descriptor queue full counter: %lu\n\n",
               dsc_queue->tx_full_cnt);
        printf("Dsc RX head: %d\n", dsc_queue->rx_head);
        printf("Dsc TX tail: %d\n", dsc_queue->tx_tail);
        printf("Dsc TX head: %d\n\n", dsc_queue->tx_head);
    }

    printf("Pkt RX tail: %d\n", socket_entry->pkt_queue.rx_tail);
    printf("Pkt RX head: %d\n", socket_entry->pkt_queue.rx_head);
}
