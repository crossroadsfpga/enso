
#include <algorithm>
#include <termios.h>
#include <time.h>
#include <cassert>
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <ctime>
#include <endian.h>
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

#define SEND_BACK

static dsc_queue_t dsc_queue;
static uint32_t* pending_pkt_tails;

static pkt_q_id_t* rx_pkt_queue_ids;

// HACK(sadok) This is used to decrement the packet queue id and use it as an
// index to the pending_pkt_tails array. This only works because packet queues
// for the same app are contiguous. This will no longer hold in the future. How
// bad would it be to use a hash table to keep pending_pkt_tails?
// Another option is to get rid of the pending_pkt_tails array and instead save
// the tails with `last_rx_ids`.
static uint32_t pkt_queue_id_offset;

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
static void* get_huge_pages(int queue_id, size_t size) {
    int fd;
    char huge_pages_path[128];

    snprintf(huge_pages_path, 128, "/mnt/huge/fd:%i", queue_id);

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

int dma_init(socket_internal* socket_entry, unsigned socket_id, unsigned nb_queues)
{
    void* uio_mmap_bar2_addr;
    int queue_id;
    intel_fpga_pcie_dev *dev = socket_entry->dev;

    printf("Running with BATCH_SIZE: %i\n", BATCH_SIZE);
    printf("Running with DSC_BUF_SIZE: %i\n", DSC_BUF_SIZE);
    printf("Running with PKT_BUF_SIZE: %i\n", PKT_BUF_SIZE);

    // FIXME(sadok) should find a better identifier than core id
    queue_id = sched_getcpu() * nb_queues + socket_id;
    if (queue_id < 0) {
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
    if (dsc_queue.ref_cnt == 0) {
        // Register associated with the descriptor queue. Descriptor queue
        // registers come after the packet queue ones, that's why we use 
        // MAX_NB_FLOWS as an offset.
        queue_regs_t *dsc_queue_regs = (queue_regs_t *) (
            (uint8_t*) uio_mmap_bar2_addr + 
            (queue_id + MAX_NB_FLOWS) * MEMORY_SPACE_PER_QUEUE
        );

        dsc_queue.regs = dsc_queue_regs;
        dsc_queue.rx_buf =
            (pcie_rx_dsc_t*) get_huge_pages(queue_id, ALIGNED_DSC_BUF_PAIR_SIZE);
        if (dsc_queue.rx_buf == NULL) {
            std::cerr << "Could not get huge page" << std::endl;
            return -1;
        }
        dsc_queue.tx_buf = (pcie_tx_dsc_t*) (
            (uint64_t) dsc_queue.rx_buf + ALIGNED_DSC_BUF_PAIR_SIZE / 2);

        uint64_t phys_addr = (uint64_t) virt_to_phys(dsc_queue.rx_buf);

        // Use first half of the huge page for RX and second half for TX.
        dsc_queue_regs->rx_mem_low = (uint32_t) phys_addr;
        dsc_queue_regs->rx_mem_high = (uint32_t) (phys_addr >> 32);

        phys_addr += ALIGNED_DSC_BUF_PAIR_SIZE / 2;
        dsc_queue_regs->tx_mem_low = (uint32_t) phys_addr;
        dsc_queue_regs->tx_mem_high = (uint32_t) (phys_addr >> 32);

        dsc_queue.rx_head_ptr = &dsc_queue_regs->rx_head;
        dsc_queue.tx_tail_ptr = &dsc_queue_regs->tx_tail;
        dsc_queue.rx_head = dsc_queue_regs->rx_head;
        dsc_queue.old_rx_head = dsc_queue.rx_head;
        dsc_queue.tx_head = dsc_queue_regs->tx_head;
        dsc_queue.tx_tail = dsc_queue_regs->tx_tail;

        // HACK(sadok) assuming that we know the number of queues beforehand
        pending_pkt_tails = (uint32_t*) malloc(
            sizeof(*pending_pkt_tails) * nb_queues);
        if (pending_pkt_tails == NULL) {
            std::cerr << "Could not allocate memory" << std::endl;
            return -1;
        }
        memset(pending_pkt_tails, 0, nb_queues);

        dsc_queue.last_rx_ids =
            (pkt_q_id_t*) malloc(DSC_BUF_SIZE * sizeof(pkt_q_id_t));
        if (dsc_queue.last_rx_ids == NULL) {
            std::cerr << "Could not allocate memory" << std::endl;
            return -1;
        }

        dsc_queue.pending_rx_ids = 0;
        dsc_queue.consumed_rx_ids = 0;
        dsc_queue.tx_full_cnt = 0;

        pkt_queue_id_offset = queue_id - socket_id;

        // HACK(sadok): Holds an associated queue id for every TX descriptor.
        // TODO(sadok): Figure out queue from address.
        rx_pkt_queue_ids = (pkt_q_id_t*) malloc(
            sizeof(*rx_pkt_queue_ids) * DSC_BUF_SIZE);
        if (rx_pkt_queue_ids == NULL) {
            std::cerr << "Could not allocate memory" << std::endl;
            return -1;
        }
    }

    ++(dsc_queue.ref_cnt);

    // register associated with the packet queue
    queue_regs_t *pkt_queue_regs = (queue_regs_t *) (
        (uint8_t*) uio_mmap_bar2_addr + queue_id * MEMORY_SPACE_PER_QUEUE
    );
    socket_entry->pkt_queue.regs = pkt_queue_regs;

    socket_entry->pkt_queue.buf = 
        (uint32_t*) get_huge_pages(queue_id, BUF_PAGE_SIZE);
    if (socket_entry->pkt_queue.buf == NULL) {
        std::cerr << "Could not get huge page" << std::endl;
        return -1;
    }
    uint64_t phys_addr = (uint64_t) virt_to_phys(socket_entry->pkt_queue.buf);

    pkt_queue_regs->rx_mem_low = (uint32_t) phys_addr;
    pkt_queue_regs->rx_mem_high = (uint32_t) (phys_addr >> 32);

    socket_entry->pkt_queue.buf_phys_addr = phys_addr;

    socket_entry->queue_id = queue_id;
    socket_entry->pkt_queue.buf_head_ptr = &pkt_queue_regs->rx_head;
    socket_entry->pkt_queue.rx_head = pkt_queue_regs->rx_head;
    socket_entry->pkt_queue.old_rx_head = socket_entry->pkt_queue.rx_head;
    socket_entry->pkt_queue.rx_tail = socket_entry->pkt_queue.rx_head;

    // make sure the last tail matches the current head
    pending_pkt_tails[socket_id] = socket_entry->pkt_queue.rx_head;

    return 0;
}

inline void get_new_tx_head(socket_internal* socket_entries)
{
    pcie_tx_dsc_t* tx_buf = dsc_queue.tx_buf;
    uint32_t head = dsc_queue.tx_head;
    uint32_t tail = dsc_queue.tx_tail;

    // Advance pointer for pkt queues that were already sent.
    for (uint16_t i = 0; i < BATCH_SIZE; ++i) {
        if (head == tail) {
            break;
        }
        pcie_tx_dsc_t* tx_dsc = tx_buf + head;

        // Descriptor has not yet been consumed by hardware.
        if (tx_dsc->signal == 1) {
            break;
        }

        pkt_q_id_t pkt_queue_id = rx_pkt_queue_ids[head];
        socket_internal* socket_entry = &socket_entries[pkt_queue_id];
        uint32_t old_pktq_rx_head = socket_entry->pkt_queue.old_rx_head;

        old_pktq_rx_head = (
            old_pktq_rx_head + (tx_dsc->length) / 64
        ) % PKT_BUF_SIZE;

        asm volatile ("" : : : "memory"); // compiler memory barrier
        *(socket_entry->pkt_queue.buf_head_ptr) = old_pktq_rx_head;
        socket_entry->pkt_queue.old_rx_head = old_pktq_rx_head;

        head = (head + 1) % DSC_BUF_SIZE;
    }

    dsc_queue.tx_head = head;
}

static inline uint16_t get_new_tails(socket_internal* socket_entries)
{
    pcie_rx_dsc_t* dsc_buf = dsc_queue.rx_buf;
    uint32_t dsc_buf_head = dsc_queue.rx_head;
    uint16_t nb_consumed_dscs = 0;

    for (uint16_t i = 0; i < BATCH_SIZE; ++i) {
        pcie_rx_dsc_t* cur_desc = dsc_buf + dsc_buf_head;

        // check if the next descriptor was updated by the FPGA
        if (cur_desc->signal == 0) {
            break;
        }

        cur_desc->signal = 0;
        dsc_buf_head = (dsc_buf_head + 1) % DSC_BUF_SIZE;

        pkt_q_id_t pkt_queue_id = cur_desc->queue_id - pkt_queue_id_offset;
        pending_pkt_tails[pkt_queue_id] = (uint32_t) cur_desc->tail;
        dsc_queue.last_rx_ids[nb_consumed_dscs] = pkt_queue_id;

        ++nb_consumed_dscs;

        // TODO(sadok) consider prefetching. Two options to consider:
        // (1) prefetch all the packets;
        // (2) pass the current queue as argument and prefetch packets for it,
        //     including potentially old packets.
    }

#ifdef SEND_BACK
    // HACK(sadok): expose this to applications instead.
    get_new_tx_head(socket_entries);
#endif

    if (likely(nb_consumed_dscs > 0)) {
        // update descriptor buffer head
        asm volatile ("" : : : "memory"); // compiler memory barrier
        *(dsc_queue.rx_head_ptr) = dsc_buf_head;
        dsc_queue.rx_head = dsc_buf_head;
    }

    return nb_consumed_dscs;
}

static inline int consume_queue(socket_internal* socket_entry, void** buf,
                                size_t len)
{
    uint32_t* pkt_buf = socket_entry->pkt_queue.buf;
    uint32_t pkt_buf_head = socket_entry->pkt_queue.rx_head;
    int queue_id = socket_entry->queue_id;

    *buf = &pkt_buf[pkt_buf_head * 16];

    uint32_t pkt_buf_tail = pending_pkt_tails[queue_id];

    if (pkt_buf_tail == pkt_buf_head) {
        return 0;
    }

    _mm_prefetch(buf, _MM_HINT_T0);

    // TODO(sadok): map the same page back to the end of the buffer so that we
    // can handle this case while avoiding that we trim the request to the end
    // of the buffer.
    // To ensure that we can return a contiguous region, we ceil the tail to 
    // PKT_BUF_SIZE
    uint32_t ceiled_tail;
    
    if (pkt_buf_tail > pkt_buf_head) {
        ceiled_tail = pkt_buf_tail;
    } else {
        ceiled_tail = PKT_BUF_SIZE;
    }

    uint32_t flit_aligned_size = (ceiled_tail - pkt_buf_head) * 64;

    // reached the buffer limit
    if (unlikely(flit_aligned_size > len)) {
        flit_aligned_size = len & 0xffffffc0; // align len to 64 bytes
    }

    pkt_buf_head = (pkt_buf_head + flit_aligned_size / 64) % PKT_BUF_SIZE;

    socket_entry->pkt_queue.rx_tail = pkt_buf_head;
    return flit_aligned_size;
}

int get_next_batch_from_queue(socket_internal* socket_entry, void** buf,
                              size_t len, socket_internal* socket_entries)
{
    get_new_tails(socket_entries);
    return consume_queue(socket_entry, buf, len);
}

// return next batch among all open sockets
int get_next_batch(socket_internal* socket_entries, int* sockfd, void** buf,
                   size_t len)
{
    // Consume up to a batch of descriptors at a time. If the number of
    // consumed is the same as the number of pending, we are done processing
    // the last batch and can get the next one. Using batches here performs
    // **significanlty** better compared to always fetching the latest
    // descriptor.
    if (dsc_queue.pending_rx_ids == dsc_queue.consumed_rx_ids) {
        dsc_queue.pending_rx_ids = get_new_tails(socket_entries);
        dsc_queue.consumed_rx_ids = 0;
        if (unlikely(dsc_queue.pending_rx_ids == 0)) {
            return 0;
        }
    }

    pkt_q_id_t pkt_queue_id = dsc_queue.last_rx_ids[dsc_queue.consumed_rx_ids++];
    *sockfd = pkt_queue_id;

    socket_internal* socket_entry = &socket_entries[pkt_queue_id];

    return consume_queue(socket_entry, buf, len);
}

inline void transmit_chunk(uint64_t buf_phys_addr, pcie_tx_dsc_t* tx_buf,
                           int queue_id, int64_t length, uint32_t offset,
                           socket_internal* socket_entries)
{
    uint32_t tx_tail = dsc_queue.tx_tail;

    if (unlikely(length == 0)) {
        return;
    }

    while (length > 0) {
        uint32_t free_slots = (dsc_queue.tx_head - tx_tail - 1) % DSC_BUF_SIZE;
        // Block until we can send.
        while (unlikely(free_slots == 0)) {
            ++dsc_queue.tx_full_cnt;
            get_new_tx_head(socket_entries);
            free_slots = (dsc_queue.tx_head - tx_tail - 1) % DSC_BUF_SIZE;
        }

        pcie_tx_dsc_t* tx_dsc = tx_buf + tx_tail;
        tx_dsc->length = std::min(length, (int64_t) MAX_TRANSFER_LEN);
        rx_pkt_queue_ids[tx_tail] = queue_id;
        tx_dsc->signal = 1;
        tx_dsc->phys_addr = buf_phys_addr + offset;

        _mm_clflushopt(tx_dsc);

        tx_tail = (tx_tail + 1) % DSC_BUF_SIZE;
        length -= MAX_TRANSFER_LEN;
    }

    dsc_queue.tx_tail = tx_tail;
}

// HACK(sadok): socket_entries is used to retrieve new head and should not be
//              needed.
void advance_ring_buffer(socket_internal* socket_entries,
                         socket_internal* socket_entry)
{
    uint32_t rx_pkt_tail = socket_entry->pkt_queue.rx_tail;
    
    // HACK(sadok): also sending packet here. Should move to a separate
    //              function.
#ifdef SEND_BACK
    uint64_t buf_phys_addr = socket_entry->pkt_queue.buf_phys_addr;
    uint32_t rx_pkt_head = socket_entry->pkt_queue.rx_head;
    int queue_id = socket_entry->queue_id;
    pcie_tx_dsc_t* tx_buf = dsc_queue.tx_buf;
    uint32_t old_rx_head = socket_entry->pkt_queue.old_rx_head;

    if (unlikely(rx_pkt_head == rx_pkt_tail)) {
        return;
    }

    // Buffer wraps around. We need to send two descriptors.
    if (rx_pkt_head > rx_pkt_tail) {
        transmit_chunk(buf_phys_addr, tx_buf, queue_id,
                       (PKT_BUF_SIZE - rx_pkt_head) * 64, rx_pkt_head * 64,
                       socket_entries);

        // Reset pkt buffer to the beginning.
        rx_pkt_head = 0;
    }

    transmit_chunk(buf_phys_addr, tx_buf, queue_id,
                   (rx_pkt_tail - rx_pkt_head) * 64, rx_pkt_head * 64, 
                   socket_entries);

    asm volatile ("" : : : "memory"); // compiler memory barrier
    *(dsc_queue.tx_tail_ptr) = dsc_queue.tx_tail;

    // Hack to force new descriptor to be sent.
    *(socket_entry->pkt_queue.buf_head_ptr) = old_rx_head;
#else
    asm volatile ("" : : : "memory"); // compiler memory barrier
    *(socket_entry->pkt_queue.buf_head_ptr) = rx_pkt_tail;
#endif  // SEND_BACK

    socket_entry->pkt_queue.rx_head = rx_pkt_tail;
}

int send_to_queue(socket_internal* socket_entries,
                  socket_internal* socket_entry, void* buf, size_t len)
{
    pcie_tx_dsc_t* tx_buf = dsc_queue.tx_buf;
    int queue_id = socket_entry->queue_id;

    transmit_chunk((uint64_t) buf, tx_buf, queue_id, len, 0, socket_entries);

    asm volatile ("" : : : "memory"); // compiler memory barrier
    *(dsc_queue.tx_tail_ptr) = dsc_queue.tx_tail;

    return 0;
}

int dma_finish(socket_internal* socket_entry)
{
    queue_regs_t* pkt_queue_regs = socket_entry->pkt_queue.regs;
    pkt_queue_regs->rx_tail = 0;
    pkt_queue_regs->rx_head = 0;
    pkt_queue_regs->rx_mem_low = 0;
    pkt_queue_regs->rx_mem_high = 0;

    munmap(socket_entry->pkt_queue.buf, BUF_PAGE_SIZE);

    if (dsc_queue.ref_cnt == 0) {
        return 0;
    }

    if (--(dsc_queue.ref_cnt) == 0) {
        dsc_queue.regs->rx_tail = 0;
        dsc_queue.regs->rx_head = 0;
        dsc_queue.regs->rx_mem_low = 0;
        dsc_queue.regs->rx_mem_high = 0;

        dsc_queue.regs->tx_mem_low = 0;
        dsc_queue.regs->tx_mem_high = 0;
        munmap(dsc_queue.rx_buf, ALIGNED_DSC_BUF_PAIR_SIZE);
        free(pending_pkt_tails);
        free(rx_pkt_queue_ids);
        free(dsc_queue.last_rx_ids);
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

void print_buffer(uint32_t* buf, uint32_t nb_flits)
{
    for (uint32_t i = 0; i < nb_flits; ++i) {
        for (uint32_t j = 0; j < 8; ++j) {
            for (uint32_t k = 0; k < 8; ++k) {
                printf("%02x ", ((uint8_t*) buf)[i*64 + j*8 + k] );
            }
            printf("\n");
        }
        printf("\n");
    }
}

void print_stats(socket_internal* socket_entry, bool print_global)
{
    if (print_global) {
        printf("TX descriptor queue full counter: %lu\n\n", dsc_queue.tx_full_cnt);
        printf("Dsc RX head: %d\n", dsc_queue.rx_head);
        printf("Dsc TX tail: %d\n", dsc_queue.tx_tail);
        printf("Dsc TX head: %d\n\n", dsc_queue.tx_head);
    }

    printf("Pkt RX tail: %d\n", socket_entry->pkt_queue.rx_tail);
    printf("Pkt RX head: %d\n", socket_entry->pkt_queue.rx_head);
    printf("Pkt Old RX head: %d\n", socket_entry->pkt_queue.old_rx_head);
}
