
#include <algorithm>
#include <array>
#include <cerrno>
#include <chrono>
#include <csignal>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

#include <sched.h>
#include <pthread.h>

#include <pcap/pcap.h>

#include "norman/socket.h"

// #include "rdtsc.h"

#include "app.h"

#define BUF_LEN 10000000
#define HUGEPAGE_SIZE (1UL << 21)
#define NB_TRANSFERS_PER_BUFFER 4

// Number of loop iterations to wait before probing the TX dsc queue again when
// reclaiming buffer space.
#define TX_RECLAIM_DELAY 1024

// If defined, ignore received packets.
// #define IGNORE_RX


static volatile int keep_running = 1;


void int_handler(int signal __attribute__((unused)))
{
    keep_running = 0;
}


// Adapted from ixy.
static void* get_huge_page(size_t size) {
    static int id = 0;
    int fd;
    char huge_pages_path[128];

    snprintf(huge_pages_path, 128, "/mnt/huge/pktgen:%i", id);
    ++id;

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

    // Don't keep it around in the hugetlbfs.
    close(fd);
    unlink(huge_pages_path);

    return virt_addr;
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


struct PktBuffer {
    PktBuffer(uint8_t* buf, uint32_t length, uint32_t nb_pkts)
        : buf(buf), length(length), nb_pkts(nb_pkts)
    {
        phys_addr = virt_to_phys(buf);
    }
    uint8_t* buf;
    uint32_t length;
    uint32_t nb_pkts;
    uint64_t phys_addr;
};


struct PcapHandlerContext {
    std::vector<struct PktBuffer> pkt_buffers;
    uint32_t free_flits;
    pcap_t* pcap;
};


void pcap_pkt_handler(u_char* user, const struct pcap_pkthdr *pkt_hdr,
                      const u_char *pkt_bytes)
{
    struct PcapHandlerContext* context = (struct PcapHandlerContext*) user;
    uint32_t len = pkt_hdr->len;
    uint32_t len_flits = (len - 1) / 64 + 1;

    // Need to allocate another huge page.
    if (len_flits > context->free_flits) {
        uint8_t* buf = (uint8_t*) get_huge_page(HUGEPAGE_SIZE);
        if (buf == NULL) {
            pcap_breakloop(context->pcap);
            return;
        }
        context->pkt_buffers.emplace_back(buf, 0, 0);
        context->free_flits = HUGEPAGE_SIZE / 64;
    }

    struct PktBuffer& pkt_buffer = context->pkt_buffers.back();
    uint8_t* dest = pkt_buffer.buf + pkt_buffer.length;

    memcpy(dest, pkt_bytes, len);

    pkt_buffer.length += len_flits * 64;  // Packets must be cache aligned.
    ++(pkt_buffer.nb_pkts);
    context->free_flits -= len_flits;
}


int main(int argc, const char* argv[])
{
    if (argc != 6) {
        std::cerr << "Usage: " << argv[0]
                  << " pcap_file core_id rate_num rate_den nb_queues"
                  << std::endl;
        return 1;
    }

    const char* pcap_file = argv[1];
    int core_id = atoi(argv[2]);
    const uint16_t rate_num = atoi(argv[3]);
    const uint16_t rate_den = atoi(argv[4]);
    const int nb_queues = atoi(argv[5]);

    char errbuf[PCAP_ERRBUF_SIZE];

    pcap_t* pcap = pcap_open_offline(pcap_file, errbuf);
    if (pcap == NULL) {
        std::cerr << "Error loading pcap file (" << errbuf << ")" << std::endl;
        return 2;
    }

    struct PcapHandlerContext context;
    context.free_flits = 0;
    context.pcap = pcap;
    std::vector<PktBuffer>& pkt_buffers = context.pkt_buffers;

    // Initialize packet buffers with packets read from pcap file.
    if (pcap_loop(pcap, 0, pcap_pkt_handler, (u_char*) &context) < 0) {
        std::cerr << "Error while reading pcap (" << pcap_geterr(pcap) << ")"
                  << std::endl;
        return 3;
    }

    // For small pcaps we copy the same packets over the remaining of the
    // buffer. This reduces the number of transfers that we need to issue.
    if ((pkt_buffers.size() == 1)
            && (pkt_buffers.front().length < HUGEPAGE_SIZE / 2)) {
        PktBuffer& buffer = pkt_buffers.front();
        uint32_t original_buf_length = buffer.length;
        uint32_t original_nb_pkts = buffer.nb_pkts;
        while ((buffer.length + original_buf_length) <= HUGEPAGE_SIZE) {
            memcpy(buffer.buf + buffer.length, buffer.buf, original_buf_length);
            buffer.length += original_buf_length;
            buffer.nb_pkts += original_nb_pkts;
        }
    }

    uint64_t tx_bytes = 0;
    uint64_t tx_pkts = 0;
    uint64_t rx_bytes = 0;
    uint64_t rx_pkts = 0;
    uint64_t aggregated_rtt = 0;

    signal(SIGINT, int_handler);
    
    std::thread pktgen_thread = std::thread([
        nb_queues, rate_num, rate_den, &pkt_buffers, &tx_bytes, &tx_pkts,
        &rx_bytes, &rx_pkts, &aggregated_rtt
    ]{
        std::this_thread::sleep_for(std::chrono::seconds(1));

        std::cout << "Running pktgen on core " << sched_getcpu() << std::endl;

        for (int i = 0; i < nb_queues; ++i) {
            std::cout << "creating queue " << i << std::endl;
            int socket_fd = socket(AF_INET, SOCK_DGRAM, nb_queues);

            if (socket_fd == -1) {
                std::cerr << "Problem creating socket (" << errno << "): "
                          << strerror(errno) << std::endl;
                exit(2);
            }
        }

        enable_device_rate_limit(rate_num, rate_den);
        enable_device_timestamp();

        auto current_pkt_buf = pkt_buffers.begin();
        uint32_t cur_bytes_sent = 0;
        uint32_t transmissions_pending = 0;
        uint64_t ignored_reclaims = 0;
        std::unordered_map<uint32_t, uint64_t> rtt_hist;

        std::cout << "Starting packet generation" << std::endl;

        while (keep_running) {
#ifndef IGNORE_RX
            uint8_t* recv_buf;
            int socket_fd;

            int recv_len = recv_select(0, &socket_fd, (void**) &recv_buf, BUF_LEN,
                                       0);
            
            if (unlikely(recv_len < 0)) {
                std::cerr << "Error receiving" << std::endl;
                exit(4);
            }

            if (likely(recv_len > 0)) {
                int processed_bytes = 0;
                uint8_t* pkt = recv_buf;

                while (processed_bytes < recv_len) {
                    uint16_t pkt_len = get_pkt_size(pkt);
                    uint16_t nb_flits = (pkt_len - 1) / 64 + 1;
                    uint16_t pkt_aligned_len = nb_flits * 64;
                    uint32_t rtt = get_pkt_rtt(pkt);

                    aggregated_rtt += rtt;
                    // rtt_hist[rtt]++;

                    pkt += pkt_aligned_len;
                    processed_bytes += pkt_aligned_len;
                    ++rx_pkts;
                }

                rx_bytes += recv_len;
                free_pkt_buf(socket_fd, recv_len);
            }
#endif  // IGNORE_RX

            if (likely(transmissions_pending < (DSC_BUF_SIZE - 1))) {

                uint32_t transmission_length = std::min(
                    (uint32_t) (HUGEPAGE_SIZE / NB_TRANSFERS_PER_BUFFER),
                    current_pkt_buf->length - cur_bytes_sent
                );

                void* phys_addr = 
                    (void*) (current_pkt_buf->phys_addr + cur_bytes_sent);

                send(0, phys_addr, transmission_length, 0);
                tx_bytes += transmission_length;
                ++transmissions_pending;

                cur_bytes_sent += transmission_length;
                
                // Move to next packet buffer.
                if (cur_bytes_sent == current_pkt_buf->length) {
                    tx_pkts += current_pkt_buf->nb_pkts;
                    current_pkt_buf = std::next(current_pkt_buf);
                    if (current_pkt_buf == pkt_buffers.end()) {
                        current_pkt_buf = pkt_buffers.begin();
                    }

                    cur_bytes_sent = 0;
                }
            }

            // Reclaim TX descriptor buffer space.
            if ((transmissions_pending > DSC_BUF_SIZE / 4)) {
                if (ignored_reclaims > TX_RECLAIM_DELAY) {
                    ignored_reclaims = 0;
                    transmissions_pending -= get_completions(0);
                } else {
                    ++ignored_reclaims;
                }
            }
        }

        disable_device_rate_limit();
        disable_device_timestamp();

        for (int socket_fd = 0; socket_fd < nb_queues; ++socket_fd) {
            print_sock_stats(socket_fd);
            shutdown(socket_fd, SHUT_RDWR);
        }
    });

    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(core_id, &cpuset);
    int result = pthread_setaffinity_np(pktgen_thread.native_handle(),
                                        sizeof(cpuset), &cpuset);
    if (result < 0) {
        std::cerr << "Error setting CPU affinity" << std::endl;
        return 6;
    }

    while (keep_running) {
        uint64_t last_rx_bytes = rx_bytes;
        uint64_t last_rx_pkts = rx_pkts;
        uint64_t last_tx_bytes = tx_bytes;
        uint64_t last_tx_pkts = tx_pkts;
        uint64_t last_aggregated_rtt = aggregated_rtt;

        std::this_thread::sleep_for(std::chrono::seconds(1));

        uint64_t rx_goodput_mbps = (rx_bytes - last_rx_bytes) * 8. / 1e6;
        uint64_t rx_pkt_rate = rx_pkts - last_rx_pkts;
        uint64_t rx_pkt_rate_kpps = rx_pkt_rate / 1e3;
        uint64_t tx_goodput_mbps = (tx_bytes - last_tx_bytes) * 8. / 1e6;
        uint64_t tx_pkt_rate = tx_pkts - last_tx_pkts;
        uint64_t tx_pkt_rate_kpps = tx_pkt_rate / 1e3;
        uint64_t rtt_ns;
        if (rx_pkt_rate != 0) {
            rtt_ns = (aggregated_rtt - last_aggregated_rtt) / rx_pkt_rate;
        } else {
            rtt_ns = 0;
        }

        std::cout << std::dec
                  << "RX:"
                  << "  Goodput: " << rx_goodput_mbps << " Mbps"
                  << "  Rate: " << rx_pkt_rate_kpps << " kpps"
                  << std::endl
                  << "     #bytes: " << rx_bytes
                  << "  #packets: " << rx_pkts
                  << std::endl
                  << "TX:"
                  << "  Goodput: " << tx_goodput_mbps << " Mbps"
                  << "  Rate: " << tx_pkt_rate_kpps << " kpps"
                  << std::endl
                  << "     #bytes: " << tx_bytes
                  << "  #packets: " << tx_pkts
                  << std::endl
                  << "RTT: " << rtt_ns << " ns  "
                  << std::endl << std::endl;
    }

    pktgen_thread.join();

    return 0;
}
