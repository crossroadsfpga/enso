/*
 * Copyright (c) 2022, Carnegie Mellon University
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted (subject to the limitations in the disclaimer
 * below) provided that the following conditions are met:
 *
 *      * Redistributions of source code must retain the above copyright notice,
 *      this list of conditions and the following disclaimer.
 *
 *      * Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *      * Neither the name of the copyright holder nor the names of its
 *      contributors may be used to endorse or promote products derived from
 *      this software without specific prior written permission.
 *
 * NO EXPRESS OR IMPLIED LICENSES TO ANY PARTY'S PATENT RIGHTS ARE GRANTED BY
 * THIS LICENSE. THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
 * NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <enso/consts.h>
#include <enso/helpers.h>
#include <enso/socket.h>
#include <fcntl.h>
#include <getopt.h>
#include <pcap/pcap.h>
#include <pthread.h>
#include <sched.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <unistd.h>

#include <algorithm>
#include <array>
#include <cerrno>
#include <chrono>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <future>
#include <iostream>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

// Number of loop iterations to wait before probing the TX notification buffer
// again when reclaiming buffer space.
#define TX_RECLAIM_DELAY 1024

// If defined, ignore received packets.
// #define IGNORE_RX

// When we are done transmitting. The RX thread still tries to receive all
// packets. The following defines the maximum number of times that we can try to
// receive packets in a row while getting no packet back. Once this happens we
// assume that we are no longer receiving packets and can stop trying.
#define ITER_NO_PKT_THRESH (1 << 28)

// Default core ID to run.
#define DEFAULT_CORE_ID 0

// Default number of queues to use.
#define DEFAULT_NB_QUEUES 4

// Default histogram array offset.
#define DEFAULT_HIST_OFFSET 400

// Default histogram array length.
#define DEFAULT_HIST_LEN 1000000

// Default delay between displayed stats (in milliseconds).
#define DEFAULT_STATS_DELAY 1000

// Number of CLI arguments.
#define NB_CLI_ARGS 3

// Maximum number of bytes that we can receive at once.
#define RECV_BUF_LEN 10000000

// Huge page size that we are using (in bytes).
#define HUGEPAGE_SIZE (2UL << 20)

// Size of the buffer that we keep packets in.
#define BUFFER_SIZE enso::kMaxTransferLen

// Number of transfers required to send a buffer full of packets.
#define TRANSFERS_PER_BUFFER (((BUFFER_SIZE - 1) / enso::kMaxTransferLen) + 1)

static volatile int keep_running = 1;
static volatile int force_stop = 0;
static volatile int rx_ready = 0;
static volatile int rx_done = 0;
static volatile int tx_done = 0;

void int_handler(int signal __attribute__((unused))) {
  if (!keep_running) {
    force_stop = 1;
  }
  keep_running = 0;
}

static void print_usage(const char* program_name) {
  printf(
      "%s PCAP_FILE RATE_NUM RATE_DEN\n"
      " [--help]\n"
      " [--count NB_PKTS]\n"
      " [--core CORE_ID]\n"
      " [--queues NB_QUEUES]\n"
      " [--save SAVE_FILE]\n"
      " [--single-core]\n"
      " [--rtt]\n"
      " [--rtt-hist HIST_FILE]\n"
      " [--rtt-hist-offset HIST_OFFSET]\n"
      " [--rtt-hist-len HIST_LEN]\n"
      " [--stats-delay STATS_DELAY]\n"
      " [--pcie-addr PCIE_ADDR]\n"
      " [--timestamp-offset]\n\n"

      "  PCAP_FILE: Pcap file with packets to transmit.\n"
      "  RATE_NUM: Numerator of the rate used to transmit packets.\n"
      "  RATE_DEN: Denominator of the rate used to transmit packets.\n\n"

      "  --help: Show this help and exit.\n"
      "  --count: Specify number of packets to transmit.\n"
      "  --core: Specify CORE_ID to run on (default: %d).\n"
      "  --queues: Specify number of RX queues (default: %d).\n"
      "  --save: Save RX and TX stats to SAVE_FILE.\n"
      "  --single-core: Use the same core for receiving and transmitting.\n"
      "  --rtt: Enable packet timestamping and report average RTT.\n"
      "  --rtt-hist: Save RTT histogram to HIST_FILE (implies --rtt).\n"
      "  --rtt-hist-offset: Offset to be used when saving the histogram\n"
      "                     (default: %d).\n"
      "  --rtt-hist-len: Size of the histogram array (default: %d).\n"
      "                  If an RTT is outside the RTT hist array range, it\n"
      "                  will still be saved, but there will be a\n"
      "                  performance penalty.\n"
      "  --stats-delay: Delay between displayed stats in milliseconds\n"
      "                 (default: %d).\n"
      "  --pcie-addr: Specify the PCIe address of the NIC to use.\n"
      "  --timestamp-offset: Specify the packet offset to place the timestamp\n"
      "                      on (default: %d).\n",
      program_name, DEFAULT_CORE_ID, DEFAULT_NB_QUEUES, DEFAULT_HIST_OFFSET,
      DEFAULT_HIST_LEN, DEFAULT_STATS_DELAY, enso::kDefaultRttOffset);
}

#define CMD_OPT_HELP "help"
#define CMD_OPT_COUNT "count"
#define CMD_OPT_CORE "core"
#define CMD_OPT_QUEUES "queues"
#define CMD_OPT_SAVE "save"
#define CMD_OPT_SINGLE_CORE "single-core"
#define CMD_OPT_RTT "rtt"
#define CMD_OPT_RTT_HIST "rtt-hist"
#define CMD_OPT_RTT_HIST_OFF "rtt-hist-offset"
#define CMD_OPT_RTT_HIST_LEN "rtt-hist-len"
#define CMD_OPT_STATS_DELAY "stats-delay"
#define CMD_OPT_PCIE_ADDR "pcie-addr"
#define CMD_OPT_TIMESTAMP_OFFSET "timestamp-offset"

// Map long options to short options.
enum {
  CMD_OPT_HELP_NUM = 256,
  CMD_OPT_COUNT_NUM,
  CMD_OPT_CORE_NUM,
  CMD_OPT_QUEUES_NUM,
  CMD_OPT_SAVE_NUM,
  CMD_OPT_SINGLE_CORE_NUM,
  CMD_OPT_RTT_NUM,
  CMD_OPT_RTT_HIST_NUM,
  CMD_OPT_RTT_HIST_OFF_NUM,
  CMD_OPT_RTT_HIST_LEN_NUM,
  CMD_OPT_STATS_DELAY_NUM,
  CMD_OPT_PCIE_ADDR_NUM,
  CMD_OPT_TIMESTAMP_OFFSET_NUM
};

static const char short_options[] = "";

static const struct option long_options[] = {
    {CMD_OPT_HELP, no_argument, NULL, CMD_OPT_HELP_NUM},
    {CMD_OPT_COUNT, required_argument, NULL, CMD_OPT_COUNT_NUM},
    {CMD_OPT_CORE, required_argument, NULL, CMD_OPT_CORE_NUM},
    {CMD_OPT_QUEUES, required_argument, NULL, CMD_OPT_QUEUES_NUM},
    {CMD_OPT_SAVE, required_argument, NULL, CMD_OPT_SAVE_NUM},
    {CMD_OPT_SINGLE_CORE, no_argument, NULL, CMD_OPT_SINGLE_CORE_NUM},
    {CMD_OPT_RTT, no_argument, NULL, CMD_OPT_RTT_NUM},
    {CMD_OPT_RTT_HIST, required_argument, NULL, CMD_OPT_RTT_HIST_NUM},
    {CMD_OPT_RTT_HIST_OFF, required_argument, NULL, CMD_OPT_RTT_HIST_OFF_NUM},
    {CMD_OPT_RTT_HIST_LEN, required_argument, NULL, CMD_OPT_RTT_HIST_LEN_NUM},
    {CMD_OPT_STATS_DELAY, required_argument, NULL, CMD_OPT_STATS_DELAY_NUM},
    {CMD_OPT_PCIE_ADDR, required_argument, NULL, CMD_OPT_PCIE_ADDR_NUM},
    {CMD_OPT_TIMESTAMP_OFFSET, required_argument, NULL,
     CMD_OPT_TIMESTAMP_OFFSET_NUM},
    {0, 0, 0, 0}};

struct parsed_args_t {
  int core_id;
  uint32_t nb_queues;
  bool save;
  bool single_core;
  bool enable_rtt;
  bool enable_rtt_history;
  std::string hist_file;
  std::string pcap_file;
  std::string save_file;
  uint16_t rate_num;
  uint16_t rate_den;
  uint64_t nb_pkts;
  uint32_t rtt_hist_offset;
  uint32_t rtt_hist_len;
  uint32_t stats_delay;
  std::string pcie_addr;
  uint8_t timestamp_offset;
};

static int parse_args(int argc, char** argv,
                      struct parsed_args_t& parsed_args) {
  int opt;
  int long_index;

  parsed_args.nb_pkts = 0;
  parsed_args.core_id = DEFAULT_CORE_ID;
  parsed_args.nb_queues = DEFAULT_NB_QUEUES;
  parsed_args.save = false;
  parsed_args.single_core = false;
  parsed_args.enable_rtt = false;
  parsed_args.enable_rtt_history = false;
  parsed_args.rtt_hist_offset = DEFAULT_HIST_OFFSET;
  parsed_args.rtt_hist_len = DEFAULT_HIST_LEN;
  parsed_args.stats_delay = DEFAULT_STATS_DELAY;
  parsed_args.timestamp_offset = enso::kDefaultRttOffset;

  while ((opt = getopt_long(argc, argv, short_options, long_options,
                            &long_index)) != EOF) {
    switch (opt) {
      case CMD_OPT_HELP_NUM:
        return 1;
      case CMD_OPT_COUNT_NUM:
        parsed_args.nb_pkts = atoi(optarg);
        break;
      case CMD_OPT_CORE_NUM:
        parsed_args.core_id = atoi(optarg);
        break;
      case CMD_OPT_QUEUES_NUM:
        parsed_args.nb_queues = atoi(optarg);
        break;
      case CMD_OPT_SAVE_NUM:
        parsed_args.save = true;
        parsed_args.save_file = optarg;
        break;
      case CMD_OPT_SINGLE_CORE_NUM:
        parsed_args.single_core = true;
        break;
      case CMD_OPT_RTT_HIST_NUM:
        parsed_args.enable_rtt_history = true;
        parsed_args.hist_file = optarg;
        // fall through
      case CMD_OPT_RTT_NUM:
        parsed_args.enable_rtt = true;
        break;
      case CMD_OPT_RTT_HIST_OFF_NUM:
        parsed_args.rtt_hist_offset = atoi(optarg);
        break;
      case CMD_OPT_RTT_HIST_LEN_NUM:
        parsed_args.rtt_hist_len = atoi(optarg);
        break;
      case CMD_OPT_STATS_DELAY_NUM:
        parsed_args.stats_delay = atoi(optarg);
        break;
      case CMD_OPT_PCIE_ADDR_NUM:
        parsed_args.pcie_addr = optarg;
        break;
      case CMD_OPT_TIMESTAMP_OFFSET_NUM: {
        int timestamp_offset = atoi(optarg);
        if (timestamp_offset < 0 || timestamp_offset > 60) {
          std::cerr << "Invalid timestamp offset" << std::endl;
          return -1;
        }
        parsed_args.timestamp_offset = (uint8_t)timestamp_offset;
        break;
      }
      default:
        return -1;
    }
  }

  if ((argc - optind) != NB_CLI_ARGS) {
    return -1;
  }

  parsed_args.pcap_file = argv[optind++];
  parsed_args.rate_num = atoi(argv[optind++]);
  parsed_args.rate_den = atoi(argv[optind++]);

  if (parsed_args.rate_num == 0) {
    std::cerr << "Rate must be greater than 0" << std::endl;
    return -1;
  }

  if (parsed_args.rate_den == 0) {
    std::cerr << "Rate denominator must be greater than 0" << std::endl;
    return -1;
  }

  return 0;
}

// Adapted from ixy.
static void* get_huge_page(size_t size) {
  static int id = 0;
  int fd;
  char huge_pages_path[128];

  snprintf(huge_pages_path, sizeof(huge_pages_path), "/mnt/huge/ensogen:%i",
           id);
  ++id;

  fd = open(huge_pages_path, O_CREAT | O_RDWR, S_IRWXU);
  if (fd == -1) {
    std::cerr << "(" << errno << ") Problem opening huge page file descriptor"
              << std::endl;
    return NULL;
  }

  if (ftruncate(fd, (off_t)size)) {
    std::cerr << "(" << errno
              << ") Could not truncate huge page to size: " << size
              << std::endl;
    close(fd);
    unlink(huge_pages_path);
    return NULL;
  }

  void* virt_addr = (void*)mmap(NULL, size, PROT_READ | PROT_WRITE,
                                MAP_SHARED | MAP_HUGETLB, fd, 0);

  if (virt_addr == (void*)-1) {
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
  if (lseek(fd, (uintptr_t)virt / pagesize * sizeof(uintptr_t), SEEK_SET) < 0) {
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
  return (uint64_t)((phy & 0x7fffffffffffffULL) * pagesize +
                    ((uintptr_t)virt) % pagesize);
}

struct EnsoPipe {
  EnsoPipe(uint8_t* buf, uint32_t length, uint32_t good_bytes, uint32_t nb_pkts)
      : buf(buf), length(length), good_bytes(good_bytes), nb_pkts(nb_pkts) {
    phys_addr = virt_to_phys(buf);
  }
  uint8_t* buf;
  uint32_t length;
  uint32_t good_bytes;
  uint32_t nb_pkts;
  uint64_t phys_addr;
};

struct PcapHandlerContext {
  std::vector<struct EnsoPipe> enso_pipes;
  uint32_t free_flits;
  uint32_t hugepage_offset;
  pcap_t* pcap;
};

struct RxStats {
  explicit RxStats(uint32_t rtt_hist_len = 0, uint32_t rtt_hist_offset = 0)
      : pkts(0),
        bytes(0),
        rtt_sum(0),
        nb_batches(0),
        rtt_hist_len(rtt_hist_len),
        rtt_hist_offset(rtt_hist_offset) {
    if (rtt_hist_len > 0) {
      rtt_hist = new uint64_t[rtt_hist_len]();
    }
  }
  ~RxStats() {
    if (rtt_hist_len > 0) {
      delete[] rtt_hist;
    }
  }

  RxStats(const RxStats& other) = delete;
  RxStats(RxStats&& other) = default;
  RxStats& operator=(const RxStats& other) = delete;
  RxStats& operator=(RxStats&& other) = delete;

  inline void add_rtt_to_hist(const uint32_t rtt) {
    // Insert RTTs into the rtt_hist array if they are in its range,
    // otherwise use the backup_rtt_hist.
    if (unlikely((rtt >= (rtt_hist_len - rtt_hist_offset)) ||
                 (rtt < rtt_hist_offset))) {
      backup_rtt_hist[rtt]++;
    } else {
      rtt_hist[rtt - rtt_hist_offset]++;
    }
  }

  uint64_t pkts;
  uint64_t bytes;
  uint64_t rtt_sum;
  uint64_t nb_batches;
  const uint32_t rtt_hist_len;
  const uint32_t rtt_hist_offset;
  uint64_t* rtt_hist;
  std::unordered_map<uint32_t, uint64_t> backup_rtt_hist;
};

struct RxArgs {
  bool enable_rtt;
  bool enable_rtt_history;
  int socket_fd;
  uint8_t timestamp_offset;
};

struct TxStats {
  TxStats() : pkts(0), bytes(0) {}
  uint64_t pkts;
  uint64_t bytes;
};

struct TxArgs {
  TxArgs(std::vector<EnsoPipe>& enso_pipes, uint64_t total_bytes_to_send,
         uint64_t total_good_bytes_to_send, uint64_t pkts_in_last_buffer,
         int socket_fd)
      : ignored_reclaims(0),
        total_remaining_bytes(total_bytes_to_send),
        total_remaining_good_bytes(total_good_bytes_to_send),
        transmissions_pending(0),
        pkts_in_last_buffer(pkts_in_last_buffer),
        enso_pipes(enso_pipes),
        current_enso_pipe(enso_pipes.begin()),
        socket_fd(socket_fd) {}
  uint64_t ignored_reclaims;
  uint64_t total_remaining_bytes;
  uint64_t total_remaining_good_bytes;
  uint32_t transmissions_pending;
  uint64_t pkts_in_last_buffer;
  std::vector<EnsoPipe>& enso_pipes;
  std::vector<EnsoPipe>::iterator current_enso_pipe;
  int socket_fd;
};

void pcap_pkt_handler(u_char* user, const struct pcap_pkthdr* pkt_hdr,
                      const u_char* pkt_bytes) {
  (void)pkt_hdr;
  struct PcapHandlerContext* context = (struct PcapHandlerContext*)user;

  const struct ether_header* l2_hdr = (struct ether_header*)pkt_bytes;
  if (l2_hdr->ether_type != htons(ETHERTYPE_IP)) {
    std::cerr << "Non-IPv4 packets are not supported" << std::endl;
    exit(8);
  }

  uint32_t len = enso::get_pkt_len(pkt_bytes);
  uint32_t nb_flits = (len - 1) / 64 + 1;

  if (nb_flits > context->free_flits) {
    uint8_t* buf;
    if ((context->hugepage_offset + BUFFER_SIZE) > HUGEPAGE_SIZE) {
      // Need to allocate another huge page.
      buf = (uint8_t*)get_huge_page(HUGEPAGE_SIZE);
      if (buf == NULL) {
        pcap_breakloop(context->pcap);
        return;
      }
      context->hugepage_offset = BUFFER_SIZE;
    } else {
      struct EnsoPipe& enso_pipe = context->enso_pipes.back();
      buf = enso_pipe.buf + BUFFER_SIZE;
      context->hugepage_offset += BUFFER_SIZE;
    }
    context->enso_pipes.emplace_back(buf, 0, 0, 0);
    context->free_flits = BUFFER_SIZE / 64;
  }

  struct EnsoPipe& enso_pipe = context->enso_pipes.back();
  uint8_t* dest = enso_pipe.buf + enso_pipe.length;

  memcpy(dest, pkt_bytes, len);

  enso_pipe.length += nb_flits * 64;  // Packets must be cache aligned.
  enso_pipe.good_bytes += len;
  ++(enso_pipe.nb_pkts);
  context->free_flits -= nb_flits;
}

inline uint64_t receive_pkts(const struct RxArgs& rx_args,
                             struct RxStats& rx_stats) {
  uint64_t nb_pkts = 0;
#ifdef IGNORE_RX
  (void)rx_args;
  (void)rx_stats;
#else   // IGNORE_RX
  uint8_t* recv_buf;
  int socket_fd;
  int recv_len = enso::recv_select(rx_args.socket_fd, &socket_fd,
                                   (void**)&recv_buf, RECV_BUF_LEN, 0);

  if (unlikely(recv_len < 0)) {
    std::cerr << "Error receiving" << std::endl;
    exit(7);
  }

  if (likely(recv_len > 0)) {
    int processed_bytes = 0;
    uint64_t recv_bytes = 0;
    uint8_t* pkt = recv_buf;

    while (processed_bytes < recv_len) {
      uint16_t pkt_len = enso::get_pkt_len(pkt);
      uint16_t nb_flits = (pkt_len - 1) / 64 + 1;
      uint16_t pkt_aligned_len = nb_flits * 64;

      if (rx_args.enable_rtt) {
        uint32_t rtt = enso::get_pkt_rtt(pkt, rx_args.timestamp_offset);
        rx_stats.rtt_sum += rtt;

        if (rx_args.enable_rtt_history) {
          rx_stats.add_rtt_to_hist(rtt);
        }
      }

      pkt += pkt_aligned_len;
      processed_bytes += pkt_aligned_len;
      recv_bytes += pkt_len;
      ++nb_pkts;
    }

    rx_stats.pkts += nb_pkts;
    ++(rx_stats.nb_batches);
    rx_stats.bytes += recv_bytes;
    enso::free_enso_pipe(socket_fd, recv_len);
  }
#endif  // IGNORE_RX
  return nb_pkts;
}

inline void transmit_pkts(struct TxArgs& tx_args, struct TxStats& tx_stats) {
  // Avoid transmitting new data when the TX buffer is full.
  const uint32_t buf_fill_thresh =
      enso::kNotificationBufSize - TRANSFERS_PER_BUFFER - 1;

  if (likely(tx_args.transmissions_pending < buf_fill_thresh)) {
    uint32_t transmission_length = (uint32_t)std::min(
        (uint64_t)(BUFFER_SIZE), tx_args.total_remaining_bytes);
    transmission_length =
        std::min(transmission_length, tx_args.current_enso_pipe->length);

    uint32_t good_transmission_length =
        (uint32_t)std::min(tx_args.total_remaining_good_bytes,
                           (uint64_t)tx_args.current_enso_pipe->good_bytes);

    uint64_t phys_addr = tx_args.current_enso_pipe->phys_addr;

    enso::send(tx_args.socket_fd, phys_addr, transmission_length, 0);
    tx_stats.bytes += good_transmission_length;
    ++tx_args.transmissions_pending;

    tx_args.total_remaining_bytes -= transmission_length;
    tx_args.total_remaining_good_bytes -= good_transmission_length;

    if (unlikely(tx_args.total_remaining_bytes == 0)) {
      tx_stats.pkts += tx_args.pkts_in_last_buffer;
      keep_running = 0;
      return;
    }

    // Move to next packet buffer.
    tx_stats.pkts += tx_args.current_enso_pipe->nb_pkts;
    tx_args.current_enso_pipe = std::next(tx_args.current_enso_pipe);
    if (tx_args.current_enso_pipe == tx_args.enso_pipes.end()) {
      tx_args.current_enso_pipe = tx_args.enso_pipes.begin();
    }
  }

  // Reclaim TX notification buffer space.
  if ((tx_args.transmissions_pending > (enso::kNotificationBufSize / 4))) {
    if (tx_args.ignored_reclaims > TX_RECLAIM_DELAY) {
      tx_args.ignored_reclaims = 0;
      tx_args.transmissions_pending -= enso::get_completions(tx_args.socket_fd);
    } else {
      ++tx_args.ignored_reclaims;
    }
  }
}

inline void reclaim_all_buffers(struct TxArgs& tx_args) {
  while (tx_args.transmissions_pending) {
    tx_args.transmissions_pending -= enso::get_completions(tx_args.socket_fd);
  }
}

int main(int argc, char** argv) {
  struct parsed_args_t parsed_args;
  int ret = parse_args(argc, argv, parsed_args);
  if (ret) {
    print_usage(argv[0]);
    if (ret == 1) {
      return 0;
    }
    return 1;
  }

  // Parse the PCI address in format 0000:00:00.0 or 00:00.0.
  if (parsed_args.pcie_addr != "") {
    uint32_t domain, bus, dev, func;
    if (sscanf(parsed_args.pcie_addr.c_str(), "%x:%x:%x.%x", &domain, &bus,
               &dev, &func) != 4) {
      if (sscanf(parsed_args.pcie_addr.c_str(), "%x:%x.%x", &bus, &dev,
                 &func) != 3) {
        std::cerr << "Invalid PCI address" << std::endl;
        return 1;
      }
    }
    uint16_t bdf = (bus << 8) | (dev << 3) | (func & 0x7);
    enso::set_bdf(bdf);
  }

  char errbuf[PCAP_ERRBUF_SIZE];

  pcap_t* pcap = pcap_open_offline(parsed_args.pcap_file.c_str(), errbuf);
  if (pcap == NULL) {
    std::cerr << "Error loading pcap file (" << errbuf << ")" << std::endl;
    return 2;
  }

  struct PcapHandlerContext context;
  context.free_flits = 0;
  context.hugepage_offset = HUGEPAGE_SIZE;
  context.pcap = pcap;
  std::vector<EnsoPipe>& enso_pipes = context.enso_pipes;

  // Initialize packet buffers with packets read from pcap file.
  if (pcap_loop(pcap, 0, pcap_pkt_handler, (u_char*)&context) < 0) {
    std::cerr << "Error while reading pcap (" << pcap_geterr(pcap) << ")"
              << std::endl;
    return 3;
  }

  // For small pcaps we copy the same packets over the remaining of the
  // buffer. This reduces the number of transfers that we need to issue.
  if ((enso_pipes.size() == 1) &&
      (enso_pipes.front().length < BUFFER_SIZE / 2)) {
    EnsoPipe& buffer = enso_pipes.front();
    uint32_t original_buf_length = buffer.length;
    uint32_t original_good_bytes = buffer.good_bytes;
    uint32_t original_nb_pkts = buffer.nb_pkts;
    while ((buffer.length + original_buf_length) <= BUFFER_SIZE) {
      memcpy(buffer.buf + buffer.length, buffer.buf, original_buf_length);
      buffer.length += original_buf_length;
      buffer.good_bytes += original_good_bytes;
      buffer.nb_pkts += original_nb_pkts;
    }
  }

  uint64_t total_pkts_in_buffers = 0;
  uint64_t total_bytes_in_buffers = 0;
  uint64_t total_good_bytes_in_buffers = 0;
  for (auto& buffer : enso_pipes) {
    total_pkts_in_buffers += buffer.nb_pkts;
    total_bytes_in_buffers += buffer.length;
    total_good_bytes_in_buffers += buffer.good_bytes;
  }

  // To restrict the number of packets, we track the total number of bytes.
  // This avoids the need to look at every sent packet only to figure out the
  // number bytes to send in the very last buffer. But to be able to do this,
  // we need to compute the total number of bytes that we have to send.
  uint64_t total_bytes_to_send;
  uint64_t total_good_bytes_to_send;
  uint64_t pkts_in_last_buffer = 0;
  if (parsed_args.nb_pkts > 0) {
    uint64_t nb_pkts_remaining = parsed_args.nb_pkts % total_pkts_in_buffers;
    uint64_t nb_full_iters = parsed_args.nb_pkts / total_pkts_in_buffers;

    total_bytes_to_send = nb_full_iters * total_bytes_in_buffers;
    total_good_bytes_to_send = nb_full_iters * total_good_bytes_in_buffers;

    if (nb_pkts_remaining == 0) {
      pkts_in_last_buffer = enso_pipes.back().nb_pkts;
    }

    for (auto& buffer : enso_pipes) {
      if (nb_pkts_remaining < buffer.nb_pkts) {
        uint8_t* pkt = buffer.buf;
        while (nb_pkts_remaining > 0) {
          uint16_t pkt_len = enso::get_pkt_len(pkt);
          uint16_t nb_flits = (pkt_len - 1) / 64 + 1;

          total_bytes_to_send += nb_flits * 64;
          --nb_pkts_remaining;
          ++pkts_in_last_buffer;

          pkt = enso::get_next_pkt(pkt);
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
    total_good_bytes_to_send = 0xffffffffffffffff;
  }

  uint32_t rtt_hist_len = 0;
  uint32_t rtt_hist_offset = 0;

  if (parsed_args.enable_rtt_history) {
    rtt_hist_len = parsed_args.rtt_hist_len;
    rtt_hist_offset = parsed_args.rtt_hist_offset;
  }

  RxStats rx_stats(rtt_hist_len, rtt_hist_offset);
  TxStats tx_stats;

  signal(SIGINT, int_handler);

  std::vector<std::thread> threads;

  // When using single_core we use the same thread for RX and TX, otherwise we
  // launch separate threads for RX and TX.
  if (!parsed_args.single_core) {
    std::thread rx_thread = std::thread([&parsed_args, &rx_stats] {
      std::this_thread::sleep_for(std::chrono::milliseconds(500));

      std::vector<int> socket_fds;

      int socket_fd = 0;
      for (uint32_t i = 0; i < parsed_args.nb_queues; ++i) {
        socket_fd = enso::socket(AF_INET, SOCK_DGRAM, 0, true);

        if (socket_fd == -1) {
          std::cerr << "Problem creating socket (" << errno
                    << "): " << strerror(errno) << std::endl;
          exit(2);
        }

        socket_fds.push_back(socket_fd);
      }

      enso::enable_device_rate_limit(socket_fd, parsed_args.rate_num,
                                     parsed_args.rate_den);
      enso::enable_device_round_robin(socket_fd);

      if (parsed_args.enable_rtt) {
        enso::enable_device_timestamp(socket_fd, parsed_args.timestamp_offset);
      } else {
        enso::disable_device_timestamp(socket_fd);
      }

      RxArgs rx_args;
      rx_args.enable_rtt = parsed_args.enable_rtt;
      rx_args.enable_rtt_history = parsed_args.enable_rtt_history;
      rx_args.timestamp_offset = parsed_args.timestamp_offset;
      rx_args.socket_fd = socket_fd;

      std::cout << "Running RX on core " << sched_getcpu() << std::endl;

      rx_ready = 1;

      while (keep_running) {
        receive_pkts(rx_args, rx_stats);
      }

      uint64_t nb_iters_no_pkt = 0;

      // Receive packets until packets stop arriving or user force stops.
      while (!force_stop && (nb_iters_no_pkt < ITER_NO_PKT_THRESH)) {
        uint64_t nb_pkts = receive_pkts(rx_args, rx_stats);
        if (unlikely(nb_pkts == 0)) {
          ++nb_iters_no_pkt;
        } else {
          nb_iters_no_pkt = 0;
        }
      }

      rx_done = true;

      enso::disable_device_rate_limit(socket_fd);
      enso::disable_device_round_robin(socket_fd);

      if (parsed_args.enable_rtt) {
        enso::disable_device_timestamp(socket_fd);
      }

      for (auto& s : socket_fds) {
        enso::shutdown(s, SHUT_RDWR);
      }
    });

    std::thread tx_thread = std::thread(
        [total_bytes_to_send, total_good_bytes_to_send, pkts_in_last_buffer,
         &parsed_args, &enso_pipes, &tx_stats] {
          std::this_thread::sleep_for(std::chrono::seconds(1));

          int socket_fd = enso::socket(AF_INET, SOCK_DGRAM, 0, false);

          if (socket_fd == -1) {
            std::cerr << "Problem creating socket (" << errno
                      << "): " << strerror(errno) << std::endl;
            exit(2);
          }

          while (!rx_ready) continue;

          std::cout << "Running TX on core " << sched_getcpu() << std::endl;

          TxArgs tx_args(enso_pipes, total_bytes_to_send,
                         total_good_bytes_to_send, pkts_in_last_buffer,
                         socket_fd);

          while (keep_running) {
            transmit_pkts(tx_args, tx_stats);
          }

          tx_done = 1;

          while (!rx_done) continue;

          reclaim_all_buffers(tx_args);
        });

    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(parsed_args.core_id, &cpuset);
    int result = pthread_setaffinity_np(rx_thread.native_handle(),
                                        sizeof(cpuset), &cpuset);
    if (result < 0) {
      std::cerr << "Error setting CPU affinity for RX thread." << std::endl;
      return 6;
    }

    CPU_ZERO(&cpuset);
    CPU_SET(parsed_args.core_id + 1, &cpuset);
    result = pthread_setaffinity_np(tx_thread.native_handle(), sizeof(cpuset),
                                    &cpuset);
    if (result < 0) {
      std::cerr << "Error setting CPU affinity for TX thread." << std::endl;
      return 7;
    }

    threads.push_back(std::move(rx_thread));
    threads.push_back(std::move(tx_thread));

  } else {
    // Send and receive packets within the same thread.
    std::thread rx_tx_thread = std::thread(
        [&parsed_args, &rx_stats, total_bytes_to_send, total_good_bytes_to_send,
         pkts_in_last_buffer, &enso_pipes, &tx_stats] {
          std::this_thread::sleep_for(std::chrono::milliseconds(500));

          std::vector<int> socket_fds;

          int socket_fd = 0;
          for (uint32_t i = 0; i < parsed_args.nb_queues; ++i) {
            socket_fd = enso::socket(AF_INET, SOCK_DGRAM, 0, true);

            if (socket_fd == -1) {
              std::cerr << "Problem creating socket (" << errno
                        << "): " << strerror(errno) << std::endl;
              exit(2);
            }

            socket_fds.push_back(socket_fd);
          }

          enso::enable_device_rate_limit(socket_fd, parsed_args.rate_num,
                                         parsed_args.rate_den);
          enso::enable_device_round_robin(socket_fd);

          if (parsed_args.enable_rtt) {
            enso::enable_device_timestamp(socket_fd);
          }

          std::cout << "Running RX and TX on core " << sched_getcpu()
                    << std::endl;

          RxArgs rx_args;
          rx_args.enable_rtt = parsed_args.enable_rtt;
          rx_args.enable_rtt_history = parsed_args.enable_rtt_history;
          rx_args.socket_fd = socket_fd;

          TxArgs tx_args(enso_pipes, total_bytes_to_send,
                         total_good_bytes_to_send, pkts_in_last_buffer,
                         socket_fd);

          rx_ready = 1;

          while (keep_running) {
            receive_pkts(rx_args, rx_stats);
            transmit_pkts(tx_args, tx_stats);
          }

          tx_done = 1;

          uint64_t nb_iters_no_pkt = 0;

          // Receive packets until packets stop arriving or user force stops.
          while (!force_stop && (nb_iters_no_pkt < ITER_NO_PKT_THRESH)) {
            uint64_t nb_pkts = receive_pkts(rx_args, rx_stats);
            if (unlikely(nb_pkts == 0)) {
              ++nb_iters_no_pkt;
            } else {
              nb_iters_no_pkt = 0;
            }
          }

          rx_done = true;

          reclaim_all_buffers(tx_args);

          enso::disable_device_rate_limit(socket_fd);
          enso::disable_device_round_robin(socket_fd);

          if (parsed_args.enable_rtt) {
            enso::disable_device_timestamp(socket_fd);
          }

          for (auto& s : socket_fds) {
            enso::shutdown(s, SHUT_RDWR);
          }
        });

    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(parsed_args.core_id, &cpuset);
    int result = pthread_setaffinity_np(rx_tx_thread.native_handle(),
                                        sizeof(cpuset), &cpuset);
    if (result < 0) {
      std::cerr << "Error setting CPU affinity for RX thread." << std::endl;
      return 6;
    }

    threads.push_back(std::move(rx_tx_thread));
  }

  // Write header to save file.
  if (parsed_args.save) {
    std::ofstream save_file;
    save_file.open(parsed_args.save_file);
    save_file
        << "rx_goodput_mbps,rx_tput_mbps,rx_pkt_rate_kpps,rx_bytes,rx_packets,"
           "tx_goodput_mbps,tx_tput_mbps,tx_pkt_rate_kpps,tx_bytes,tx_packets";
    if (parsed_args.enable_rtt) {
      save_file << ",mean_rtt_ns";
    }
    save_file << std::endl;
    save_file.close();
  }

  while (!rx_ready) continue;

  std::cout << "Starting..." << std::endl;

  // Continuously print statistics.
  while (!rx_done) {
    _enso_compiler_memory_barrier();
    uint64_t last_rx_bytes = rx_stats.bytes;
    uint64_t last_rx_pkts = rx_stats.pkts;
    uint64_t last_tx_bytes = tx_stats.bytes;
    uint64_t last_tx_pkts = tx_stats.pkts;
    uint64_t last_aggregated_rtt_ns =
        rx_stats.rtt_sum * enso::kNsPerTimestampCycle;

    std::this_thread::sleep_for(
        std::chrono::milliseconds(parsed_args.stats_delay));

    uint64_t rx_bytes = rx_stats.bytes;
    uint64_t rx_pkts = rx_stats.pkts;
    uint64_t tx_bytes = tx_stats.bytes;
    uint64_t tx_pkts = tx_stats.pkts;

    double interval_s = parsed_args.stats_delay / 1000.;

    uint64_t rx_pkt_diff = rx_pkts - last_rx_pkts;
    uint64_t rx_goodput_mbps =
        (rx_bytes - last_rx_bytes) * 8. / (1e6 * interval_s);
    uint64_t rx_pkt_rate = (rx_pkt_diff / interval_s);
    uint64_t rx_pkt_rate_kpps = rx_pkt_rate / 1e3;
    uint64_t rx_tput_mbps = rx_goodput_mbps + 24 * 8 * rx_pkt_rate / 1e6;

    uint64_t tx_pkt_diff = tx_pkts - last_tx_pkts;
    uint64_t tx_goodput_mbps =
        (tx_bytes - last_tx_bytes) * 8. / (1e6 * interval_s);
    uint64_t tx_tput_mbps =
        (tx_bytes - last_tx_bytes + tx_pkt_diff * 24) * 8. / (1e6 * interval_s);
    uint64_t tx_pkt_rate = (tx_pkt_diff / interval_s);
    uint64_t tx_pkt_rate_kpps = tx_pkt_rate / 1e3;

    uint64_t rtt_sum_ns = rx_stats.rtt_sum * enso::kNsPerTimestampCycle;
    uint64_t rtt_ns;
    if (rx_pkt_diff != 0) {
      rtt_ns = (rtt_sum_ns - last_aggregated_rtt_ns) / rx_pkt_diff;
    } else {
      rtt_ns = 0;
    }

    // TODO(sadok): don't print metrics that are unreliable before the first
    // two samples.

    std::cout << std::dec << "      RX: Throughput: " << rx_tput_mbps << " Mbps"
              << "  Rate: " << rx_pkt_rate_kpps << " kpps" << std::endl

              << "          #bytes: " << rx_bytes << "  #packets: " << rx_pkts
              << std::endl;

    std::cout << "      TX: Throughput: " << tx_tput_mbps << " Mbps"
              << "  Rate: " << tx_pkt_rate_kpps << " kpps" << std::endl

              << "          #bytes: " << tx_bytes << "  #packets: " << tx_pkts
              << std::endl;

    if (parsed_args.enable_rtt) {
      std::cout << "Mean RTT: " << rtt_ns << " ns  " << std::endl;
    }

    if (parsed_args.save) {
      std::ofstream save_file;
      save_file.open(parsed_args.save_file, std::ios_base::app);
      save_file << rx_goodput_mbps << "," << rx_tput_mbps << ","
                << rx_pkt_rate_kpps << "," << rx_bytes << "," << rx_pkts << ","
                << tx_goodput_mbps << "," << tx_pkt_rate_kpps << ","
                << tx_tput_mbps << "," << tx_bytes << "," << tx_pkts;
      if (parsed_args.enable_rtt) {
        save_file << "," << rtt_ns;
      }
      save_file << std::endl;
      save_file.close();
    }

    std::cout << std::endl;
  }

  if (parsed_args.save) {
    std::cout << "Saved statistics to \"" << parsed_args.save_file << "\""
              << std::endl;
  }

  ret = 0;
  if (parsed_args.enable_rtt_history) {
    std::ofstream hist_file;
    hist_file.open(parsed_args.hist_file);

    for (uint32_t rtt = 0; rtt < parsed_args.rtt_hist_len; ++rtt) {
      if (rx_stats.rtt_hist[rtt] != 0) {
        uint32_t corrected_rtt =
            (rtt + parsed_args.rtt_hist_offset) * enso::kNsPerTimestampCycle;
        hist_file << corrected_rtt << "," << rx_stats.rtt_hist[rtt]
                  << std::endl;
      }
    }

    if (rx_stats.backup_rtt_hist.size() != 0) {
      std::cout << "Warning: " << rx_stats.backup_rtt_hist.size()
                << " rtt hist entries in backup" << std::endl;
      for (auto const& i : rx_stats.backup_rtt_hist) {
        hist_file << i.first * enso::kNsPerTimestampCycle << "," << i.second
                  << std::endl;
      }
    }

    hist_file.close();
    std::cout << "Saved RTT histogram to \"" << parsed_args.hist_file << "\""
              << std::endl;

    if (rx_stats.pkts != tx_stats.pkts) {
      std::cout << "Warning: did not get all packets back." << std::endl;
      ret = 1;
    }
  }

  for (auto& thread : threads) {
    thread.join();
  }

  for (auto& buffer : enso_pipes) {
    // Only free hugepage-aligned buffers.
    if ((buffer.phys_addr & (HUGEPAGE_SIZE - 1)) == 0) {
      munmap(buffer.buf, HUGEPAGE_SIZE);
    }
  }

  return ret;
}
