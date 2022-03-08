
#include <algorithm>
#include <array>
#include <cerrno>
#include <chrono>
#include <csignal>
#include <cstdlib>
#include <cstring>
#include <future>
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

// Number of attempts to receive packets after we are done transmitting.
#define NB_FLUSH_RX (1 << 28)

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

struct RxStats {
    RxStats() : pkts(0), bytes(0), rtt_sum(0) {}
    uint64_t pkts;
    uint64_t bytes;
    uint64_t rtt_sum;
    uint64_t nb_batches;
    std::unordered_map<uint32_t, uint64_t> rtt_hist;
};

struct TxStats {
    TxStats() : pkts(0), bytes(0) {}
    uint64_t pkts;
    uint64_t bytes;
};


void pcap_pkt_handler(u_char* user, const struct pcap_pkthdr *pkt_hdr,
                      const u_char *pkt_bytes)
{
    struct PcapHandlerContext* context = (struct PcapHandlerContext*) user;
    uint32_t len = pkt_hdr->len;
    uint32_t nb_flits = (len - 1) / 64 + 1;

    // Need to allocate another huge page.
    if (nb_flits > context->free_flits) {
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

    pkt_buffer.length += nb_flits * 64;  // Packets must be cache aligned.
    ++(pkt_buffer.nb_pkts);
    context->free_flits -= nb_flits;
}

inline void receive_pkts(struct RxStats& rx_stats)
{
#ifdef IGNORE_RX
    (void) rtt_sum;
    (void) rx_pkts;
    (void) rx_bytes;
#else  // IGNORE_RX
    uint8_t* recv_buf;
    int socket_fd;
    int recv_len = recv_select(0, &socket_fd, (void**) &recv_buf, BUF_LEN, 0);
    
    if (unlikely(recv_len < 0)) {
        std::cerr << "Error receiving" << std::endl;
        exit(4);
    }

    if (likely(recv_len > 0)) {
        int processed_bytes = 0;
        uint8_t* pkt = recv_buf;

        while (processed_bytes < recv_len) {
            uint16_t pkt_len = get_pkt_len(pkt);
            uint16_t nb_flits = (pkt_len - 1) / 64 + 1;
            uint16_t pkt_aligned_len = nb_flits * 64;
            uint32_t rtt = get_pkt_rtt(pkt);

            rx_stats.rtt_sum += rtt;
            // rtt_hist[rtt]++;

            pkt += pkt_aligned_len;
            processed_bytes += pkt_aligned_len;
            ++(rx_stats.pkts);
        }

        ++(rx_stats.nb_batches);
        rx_stats.bytes += recv_len;
        free_pkt_buf(socket_fd, recv_len);
    }
#endif  // IGNORE_RX
}


int main(int argc, const char* argv[])
{
    if (argc != 7) {
        std::cerr << "Usage: " << argv[0]
                  << " pcap_file core_id rate_num rate_den nb_queues nb_pkts"
                  << std::endl;
        return 1;
    }

    const char* pcap_file = argv[1];
    int core_id = atoi(argv[2]);
    const uint16_t rate_num = atoi(argv[3]);
    const uint16_t rate_den = atoi(argv[4]);
    const int nb_queues = atoi(argv[5]);
    const uint64_t nb_pkts = atoll(argv[6]);

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

    // To restrict the number of packets, we track the total number of bytes.
    // This avoids the need to look at every sent packet only to figure out the
    // number bytes to send in the very last buffer. But to be able to do this,
    // we need to compute the total number of bytes that we have to send.
    uint64_t total_bytes_to_send;
    uint64_t pkts_in_last_buffer = 0;
    if (nb_pkts > 0) {
        uint64_t total_pkts_in_buffers = 0;
        uint64_t total_bytes_in_buffers = 0;
        for (auto buffer : pkt_buffers) {
            total_pkts_in_buffers += buffer.nb_pkts;
            total_bytes_in_buffers += buffer.length;
        }

        uint64_t nb_pkts_remaining = nb_pkts % total_pkts_in_buffers;
        uint64_t nb_full_iters = nb_pkts / total_pkts_in_buffers;
        
        total_bytes_to_send = nb_full_iters * total_bytes_in_buffers;

        for (auto buffer : pkt_buffers) {
            if (nb_pkts_remaining < buffer.nb_pkts) {
                pkts_in_last_buffer = nb_pkts_remaining;

                uint8_t* pkt = buffer.buf;
                while (nb_pkts_remaining > 0) {
                    uint16_t pkt_len = get_pkt_len(pkt);
                    uint16_t nb_flits = (pkt_len - 1) / 64 + 1;

                    total_bytes_to_send += nb_flits * 64;
                    --nb_pkts_remaining;

                    pkt = get_next_pkt(pkt);
                }
                break;
            }
            total_bytes_to_send += buffer.length;
            nb_pkts_remaining -= buffer.nb_pkts;
        }
    } else {
        // Treat nb_pkts == 0 as unbounded. The following value should be enough
        // to send 64-byte packets for around 400 years using Tb Ethernet.
        total_bytes_to_send = 0xffffffffffffffff;
    }

    RxStats rx_stats;
    TxStats tx_stats;

    std::atomic<bool> rx_done(false);
    std::atomic<bool> rx_ready(false);

    signal(SIGINT, int_handler);

    std::thread rx_thread = std::thread([
        nb_queues, rate_num, rate_den, &rx_stats, &rx_done, &rx_ready
    ]{
        std::this_thread::sleep_for(std::chrono::milliseconds(500));

        for (int i = 0; i < nb_queues; ++i) {
            std::cout << "Creating queue " << i << std::endl;
            int socket_fd = socket(AF_INET, SOCK_DGRAM, nb_queues);

            if (socket_fd == -1) {
                std::cerr << "Problem creating socket (" << errno << "): "
                            << strerror(errno) << std::endl;
                exit(2);
            }
        }

        enable_device_rate_limit(rate_num, rate_den);
        enable_device_timestamp();

        std::cout << "Running RX on core " << sched_getcpu() << std::endl;

        rx_ready = true;

        while (keep_running) {
            receive_pkts(rx_stats);
        }

        // Receive packets for a little bit longer.
        for (uint64_t i = 0; i < NB_FLUSH_RX; ++i) {
            receive_pkts(rx_stats);
        }

        disable_device_rate_limit();
        disable_device_timestamp();

        for (int socket_fd = 0; socket_fd < nb_queues; ++socket_fd) {
            // print_sock_stats(socket_fd);
            shutdown(socket_fd, SHUT_RDWR);
        }

        rx_done = true;
    });
    
    std::thread tx_thread = std::thread([
        nb_pkts, total_bytes_to_send, pkts_in_last_buffer, nb_queues,
        &pkt_buffers, &tx_stats, &rx_ready
    ]{
        std::this_thread::sleep_for(std::chrono::seconds(1));

        std::cout << "Running TX on core " << sched_getcpu() << std::endl;

        auto current_pkt_buf = pkt_buffers.begin();
        uint32_t cur_bytes_sent = 0;
        uint32_t transmissions_pending = 0;
        uint64_t ignored_reclaims = 0;
        uint64_t total_remaining_bytes = total_bytes_to_send;

        std::cout << "Creating TX queue" << std::endl;
        int socket_fd = socket(AF_INET, SOCK_DGRAM, nb_queues);
        std::cout << "socket fd: " << socket_fd << std::endl;

        if (socket_fd == -1) {
            std::cerr << "Problem creating socket (" << errno << "): "
                        << strerror(errno) << std::endl;
            exit(2);
        }

        while (keep_running) {
            if (likely(transmissions_pending < (DSC_BUF_SIZE - 1))) {
                uint32_t transmission_length = (uint32_t) std::min(
                    (uint64_t) (HUGEPAGE_SIZE / NB_TRANSFERS_PER_BUFFER),
                    total_remaining_bytes
                );
                transmission_length = std::min(transmission_length,
                    current_pkt_buf->length - cur_bytes_sent);

                void* phys_addr = 
                    (void*) (current_pkt_buf->phys_addr + cur_bytes_sent);

                send(socket_fd, phys_addr, transmission_length, 0);
                tx_stats.bytes += transmission_length;
                ++transmissions_pending;

                cur_bytes_sent += transmission_length;
                total_remaining_bytes -= transmission_length;

                if (unlikely(total_remaining_bytes == 0)) {
                    tx_stats.pkts += pkts_in_last_buffer;
                    keep_running = 0;
                    break;
                }
                
                // Move to next packet buffer.
                if (cur_bytes_sent == current_pkt_buf->length) {
                    tx_stats.pkts += current_pkt_buf->nb_pkts;
                    current_pkt_buf = std::next(current_pkt_buf);
                    if (current_pkt_buf == pkt_buffers.end()) {
                        current_pkt_buf = pkt_buffers.begin();
                    }

                    cur_bytes_sent = 0;
                }
            }

            // Reclaim TX descriptor buffer space.
            if ((transmissions_pending > (DSC_BUF_SIZE / 4))) {
                if (ignored_reclaims > TX_RECLAIM_DELAY) {
                    ignored_reclaims = 0;
                    transmissions_pending -= get_completions(socket_fd);
                } else {
                    ++ignored_reclaims;
                }
            }
        }
    });

    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(core_id, &cpuset);
    int result = pthread_setaffinity_np(rx_thread.native_handle(),
                                        sizeof(cpuset), &cpuset);
    if (result < 0) {
        std::cerr << "Error setting CPU affinity for RX thread." << std::endl;
        return 6;
    }

    CPU_ZERO(&cpuset);
    CPU_SET(core_id + 1, &cpuset);
    result = pthread_setaffinity_np(tx_thread.native_handle(),
                                    sizeof(cpuset), &cpuset);
    if (result < 0) {
        std::cerr << "Error setting CPU affinity for TX thread." << std::endl;
        return 7;
    }

    while (!rx_done) {
        uint64_t last_rx_bytes = rx_stats.bytes;
        uint64_t last_rx_pkts = rx_stats.pkts;
        uint64_t last_rx_batches = rx_stats.nb_batches;
        uint64_t last_tx_bytes = tx_stats.bytes;
        uint64_t last_tx_pkts = tx_stats.pkts;
        uint64_t last_aggregated_rtt = rx_stats.rtt_sum;

        std::this_thread::sleep_for(std::chrono::seconds(1));

        uint64_t rx_goodput_mbps = (rx_stats.bytes - last_rx_bytes) * 8. / 1e6;
        uint64_t rx_pkt_rate = rx_stats.pkts - last_rx_pkts;
        uint64_t rx_nb_batches = rx_stats.nb_batches - last_rx_batches;
        uint64_t rx_pkt_rate_kpps = rx_pkt_rate / 1e3;
        uint64_t tx_goodput_mbps = (tx_stats.bytes - last_tx_bytes) * 8. / 1e6;
        uint64_t tx_pkt_rate = tx_stats.pkts - last_tx_pkts;
        uint64_t tx_pkt_rate_kpps = tx_pkt_rate / 1e3;
        uint64_t rtt_ns;
        uint64_t mean_pkt_per_batch;
        if (rx_pkt_rate != 0) {
            rtt_ns = (rx_stats.rtt_sum - last_aggregated_rtt) / rx_pkt_rate;
            mean_pkt_per_batch = rx_pkt_rate / rx_nb_batches;
        } else {
            rtt_ns = 0;
            mean_pkt_per_batch = 0;
        }

        // TODO(sadok): don't print metrics that are unreliable before the first
        // two samples.

        std::cout << std::dec
                  << "RX:"
                  << "  Goodput: " << rx_goodput_mbps << " Mbps"
                  << "  Rate: " << rx_pkt_rate_kpps << " kpps"
                  << std::endl
                  << "     #bytes: " << rx_stats.bytes
                  << "  #packets: " << rx_stats.pkts
                  << std::endl
                  << "     Mean #packets/batch: " << mean_pkt_per_batch
                  << std::endl
                  << "TX:"
                  << "  Goodput: " << tx_goodput_mbps << " Mbps"
                  << "  Rate: " << tx_pkt_rate_kpps << " kpps"
                  << std::endl
                  << "     #bytes: " << tx_stats.bytes
                  << "  #packets: " << tx_stats.pkts
                  << std::endl
                  << "RTT: " << rtt_ns << " ns  "
                  << std::endl << std::endl;
    }

    tx_thread.join();
    rx_thread.join();

    return 0;
}
