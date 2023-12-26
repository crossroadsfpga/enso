#include <enso/consts.h>
#include <enso/helpers.h>
#include <enso/socket.h>
#include <enso/pipe.h>
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
#define TX_RECLAIM_DELAY                    1024

// Scientific notation for 10^6, treated as double. Used for stats calculations.
#define ONE_MILLION                         1e6

// Scientific notation for 10^3, treated as double. Used for stats calculations.
#define ONE_THOUSAND                        1e3

// Packet overhead added by the FPGA in bytes
#define FPGA_PACKET_OVERHEAD                24

// Minimum size of a packet aligned to cache
#define MIN_PACKET_ALIGNED_SIZE             64

// Minimum size of a raw packet
#define MIN_PACKET_RAW_SIZE                 60

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

// Num of min sized packets that would fit in a BUFFER_SIZE bytes buffer
#define MAX_PKTS_IN_BUFFER 2048

// Number of transfers required to send a buffer full of packets.
#define TRANSFERS_PER_BUFFER (((BUFFER_SIZE - 1) / enso::kMaxTransferLen) + 1)

static volatile int keep_running = 1;
static volatile int force_stop = 0;
static volatile int rx_ready = 0;
static volatile int rx_done = 0;
static volatile int tx_done = 0;

using enso::Device;
using enso::RxPipe;
using enso::TxPipe;

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
      " [--pcie-addr PCIE_ADDR]\n\n"

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
      "  --pcie-addr: Specify the PCIe address of the NIC to use.\n",
      program_name, DEFAULT_CORE_ID, DEFAULT_NB_QUEUES, DEFAULT_HIST_OFFSET,
      DEFAULT_HIST_LEN, DEFAULT_STATS_DELAY);
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

struct PcapHandlerContext {
  uint8_t *buf;
  uint32_t nb_bytes;
  uint32_t nb_good_bytes;
  uint32_t nb_pkts;
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
};

struct TxStats {
  TxStats() : pkts(0), bytes(0) {}
  uint64_t pkts;
  uint64_t bytes;
};

struct TxArgs {
  TxArgs(TxPipe *pipe, uint8_t *buf, uint64_t pkts_in_buf,
         uint64_t total_pkts_to_send)
      : tx_pipe(pipe),
        main_buf(buf),
        pkts_in_main_buf(pkts_in_buf),
        total_remaining_pkts(total_pkts_to_send) {}
  TxPipe *tx_pipe;
  uint8_t *main_buf;
  uint64_t pkts_in_main_buf;
  uint64_t total_remaining_pkts;
  uint32_t transmissions_pending;
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
  context->nb_pkts++;
  if(context->nb_pkts > MAX_PKTS_IN_BUFFER) {
    std::cerr << "Only " << MAX_PKTS_IN_BUFFER << " can be in the PCAP file"
              << std::endl;
    free(context->buf);
    exit(9);
  }

  uint32_t len = enso::get_pkt_len(pkt_bytes);
  uint32_t nb_flits = (len - 1) / MIN_PACKET_ALIGNED_SIZE + 1;
  memcpy(context->buf + context->nb_bytes, pkt_bytes, len);
  context->nb_bytes += nb_flits * MIN_PACKET_ALIGNED_SIZE;
  context->nb_good_bytes += len;
}

inline uint64_t receive_pkts(const struct RxArgs& rx_args,
                             struct RxStats& rx_stats,
                             std::unique_ptr<Device> &dev) {
  uint64_t nb_pkts = 0;
#ifdef IGNORE_RX
  (void)rx_args;
  (void)rx_stats;
#else   // IGNORE_RX
  RxPipe* rx_pipe = dev->NextRxPipeToRecv();
  if (unlikely(rx_pipe == nullptr)) {
    return 0;
  }
  auto batch = rx_pipe->PeekPkts();
  uint64_t recv_bytes = 0;
  for (auto pkt : batch) {
    uint16_t pkt_len = enso::get_pkt_len(pkt);

    if (rx_args.enable_rtt) {
      uint32_t rtt = enso::get_pkt_rtt(pkt);
      rx_stats.rtt_sum += rtt;

      if (rx_args.enable_rtt_history) {
        rx_stats.add_rtt_to_hist(rtt);
      }
    }

    recv_bytes += pkt_len;
    ++nb_pkts;
  }

  uint32_t batch_length = batch.processed_bytes();
  rx_pipe->ConfirmBytes(batch_length);

  rx_stats.pkts += nb_pkts;
  ++(rx_stats.nb_batches);
  rx_stats.bytes += recv_bytes;

  rx_pipe->Clear();

#endif  // IGNORE_RX
  return nb_pkts;
}

inline void transmit_pkts(struct TxArgs& tx_args, struct TxStats& tx_stats) {
  // decide whether we need to send an entire buffer worth of packets
  // or less than that based on user request
  uint32_t nb_pkts_to_send = std::min(tx_args.pkts_in_main_buf,
                                      tx_args.total_remaining_pkts);
  // the packets are copied in the main buffer based on the minimum packet size
  uint32_t transmission_length = nb_pkts_to_send * MIN_PACKET_ALIGNED_SIZE;

  // allocate the bytes in the TX pipe and copy the required
  // number of bytes from the main buffer
  uint8_t* pipe_buf = tx_args.tx_pipe->AllocateBuf(transmission_length);
  if(pipe_buf == NULL) {
    std::cout << "Buffer allocation for TX pipe failed" << std::endl;
    return;
  }
  // memcpy(pipe_buf, tx_args.main_buf, transmission_length);
  enso::memcpy_64_align(pipe_buf, tx_args.main_buf, transmission_length);
  // send the packets
  tx_args.tx_pipe->SendAndFree(transmission_length);

  // update the stats
  // the stats need be calculated based on good bytes
  // rather than the transmission length
  tx_stats.pkts += nb_pkts_to_send;
  tx_stats.bytes += nb_pkts_to_send * MIN_PACKET_RAW_SIZE;
  tx_args.total_remaining_pkts -= nb_pkts_to_send;
  if(tx_args.total_remaining_pkts == 0) {
    keep_running = 0;
    return;
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

  // we copy the packets in this buffer using libpcap
  uint8_t *pkt_buf = (uint8_t *) malloc(BUFFER_SIZE);
  if(pkt_buf == NULL) {
    std::cerr << "Could not allocate packet buffer" << std::endl;
    exit(1);
  }

  struct PcapHandlerContext context;
  context.pcap = pcap;
  context.buf = pkt_buf;
  context.nb_bytes = 0;
  context.nb_good_bytes = 0;
  context.nb_pkts = 0;

  // Initialize packet buffers with packets read from pcap file.
  if (pcap_loop(pcap, 0, pcap_pkt_handler, (u_char*)&context) < 0) {
    std::cerr << "Error while reading pcap (" << pcap_geterr(pcap) << ")"
              << std::endl;
    return 3;
  }

  // For small pcaps we copy the same packets over the remaining of the
  // buffer. This reduces the number of transfers that we need to issue.
  if (context.nb_bytes < BUFFER_SIZE) {
    uint32_t original_buf_length = context.nb_bytes;
    uint32_t original_nb_pkts = context.nb_pkts;
    uint32_t original_good_bytes = context.nb_good_bytes;
    while ((context.nb_bytes + original_buf_length) <= BUFFER_SIZE) {
      memcpy(pkt_buf + context.nb_bytes, pkt_buf, original_buf_length);
      context.nb_bytes += original_buf_length;
      context.nb_pkts += original_nb_pkts;
      context.nb_good_bytes += original_good_bytes;
    }
  }

  uint64_t total_pkts_in_buffer = context.nb_pkts;
  uint64_t total_pkts_to_send;
  if (parsed_args.nb_pkts > 0) {
    total_pkts_to_send = parsed_args.nb_pkts;
  } else {
    // Treat nb_pkts == 0 as unbounded. The following value should be enough
    // to send 64-byte packets for around 400 years using Tb Ethernet.
    total_pkts_to_send = 0xffffffffffffffff;
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

  std::unique_ptr<Device> dev = Device::Create();
  if (!dev) {
    std::cerr << "Problem creating device" << std::endl;
    free(pkt_buf);
    exit(2);
  }

  // When using single_core we use the same thread for RX and TX, otherwise we
  // launch separate threads for RX and TX.
  if (!parsed_args.single_core) {
    std::thread rx_thread = std::thread([&parsed_args, &rx_stats, &dev] {
      std::this_thread::sleep_for(std::chrono::milliseconds(500));

      std::vector<RxPipe*> rx_pipes;

      for (uint32_t i = 0; i < parsed_args.nb_queues; ++i) {
        RxPipe* rx_pipe = dev->AllocateRxPipe(true);
        if (!rx_pipe) {
          std::cerr << "Problem creating RX pipe" << std::endl;
          exit(3);
        }
        rx_pipes.push_back(rx_pipe);
      }

      dev->EnableRateLimiting(parsed_args.rate_num, parsed_args.rate_den);
      dev->EnableRoundRobin();

      if (parsed_args.enable_rtt) {
        dev->EnableTimeStamping();
      }
      else {
        dev->DisableTimeStamping();
      }

      RxArgs rx_args;
      rx_args.enable_rtt = parsed_args.enable_rtt;
      rx_args.enable_rtt_history = parsed_args.enable_rtt_history;

      std::cout << "Running RX on core " << sched_getcpu() << std::endl;

      rx_ready = 1;

      while (keep_running) {
        receive_pkts(rx_args, rx_stats, dev);
      }

      uint64_t nb_iters_no_pkt = 0;

      // Receive packets until packets stop arriving or user force stops.
      while (!force_stop && (nb_iters_no_pkt < ITER_NO_PKT_THRESH)) {
        uint64_t nb_pkts = receive_pkts(rx_args, rx_stats, dev);
        if (unlikely(nb_pkts == 0)) {
          ++nb_iters_no_pkt;
        } else {
          nb_iters_no_pkt = 0;
        }
      }

      rx_done = true;

      dev->DisableRateLimiting();
      dev->DisableRoundRobin();

      if (parsed_args.enable_rtt) {
        dev->DisableTimeStamping();
      }

    });

    std::thread tx_thread = std::thread(
        [pkt_buf, total_pkts_in_buffer, total_pkts_to_send,
         &parsed_args, &tx_stats, &dev] {
          std::this_thread::sleep_for(std::chrono::seconds(1));

          TxPipe* tx_pipe = dev->AllocateTxPipe();
          if (!tx_pipe) {
            std::cerr << "Problem creating TX pipe" << std::endl;
            exit(3);
          }

          while (!rx_ready) continue;

          std::cout << "Running TX on core " << sched_getcpu() << std::endl;

          TxArgs tx_args(tx_pipe, pkt_buf, total_pkts_in_buffer,
                         total_pkts_to_send);

          while (keep_running) {
            transmit_pkts(tx_args, tx_stats);
          }

          tx_done = 1;

          while (!rx_done) continue;

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
        [pkt_buf, total_pkts_in_buffer, total_pkts_to_send,
         &parsed_args, &tx_stats, &rx_stats, &dev] {
          std::this_thread::sleep_for(std::chrono::milliseconds(500));

          std::vector<RxPipe*> rx_pipes;

          for (uint32_t i = 0; i < parsed_args.nb_queues; ++i) {
            RxPipe* rx_pipe = dev->AllocateRxPipe(true);
            if (!rx_pipe) {
              std::cerr << "Problem creating RX pipe" << std::endl;
              exit(3);
            }
            rx_pipes.push_back(rx_pipe);
          }

          dev->EnableRateLimiting(parsed_args.rate_num, parsed_args.rate_den);
          dev->EnableRoundRobin();

          if (parsed_args.enable_rtt) {
            dev->EnableTimeStamping();
          }
          else {
            dev->DisableTimeStamping();
          }

          std::cout << "Running RX and TX on core " << sched_getcpu()
                    << std::endl;

          RxArgs rx_args;
          rx_args.enable_rtt = parsed_args.enable_rtt;
          rx_args.enable_rtt_history = parsed_args.enable_rtt_history;

          TxPipe* tx_pipe = dev->AllocateTxPipe();
          if (!tx_pipe) {
            std::cerr << "Problem creating TX pipe" << std::endl;
            exit(3);
          }

          TxArgs tx_args(tx_pipe, pkt_buf, total_pkts_in_buffer,
                         total_pkts_to_send);

          rx_ready = 1;

          while (keep_running) {
            receive_pkts(rx_args, rx_stats, dev);
            transmit_pkts(tx_args, tx_stats);
          }

          tx_done = 1;

          uint64_t nb_iters_no_pkt = 0;

          // Receive packets until packets stop arriving or user force stops.
          while (!force_stop && (nb_iters_no_pkt < ITER_NO_PKT_THRESH)) {
            uint64_t nb_pkts = receive_pkts(rx_args, rx_stats, dev);
            if (unlikely(nb_pkts == 0)) {
              ++nb_iters_no_pkt;
            } else {
              nb_iters_no_pkt = 0;
            }
          }

          rx_done = true;

          dev->DisableRateLimiting();
          dev->DisableRoundRobin();

          if (parsed_args.enable_rtt) {
            dev->DisableTimeStamping();
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

    double interval_s = (double) parsed_args.stats_delay / ONE_THOUSAND;

    uint64_t rx_pkt_diff = rx_pkts - last_rx_pkts;
    uint64_t rx_goodput_mbps =
        (rx_bytes - last_rx_bytes) * 8. / (ONE_MILLION * interval_s);
    uint64_t rx_pkt_rate = (rx_pkt_diff / interval_s);
    uint64_t rx_pkt_rate_kpps = rx_pkt_rate / ONE_THOUSAND;
    uint64_t rx_tput_mbps = rx_goodput_mbps + FPGA_PACKET_OVERHEAD
                            * 8 * rx_pkt_rate / ONE_MILLION;

    uint64_t tx_pkt_diff = tx_pkts - last_tx_pkts;
    uint64_t tx_goodput_mbps =
        (tx_bytes - last_tx_bytes) * 8. / (ONE_MILLION * interval_s);
    uint64_t tx_tput_mbps =
        (tx_bytes - last_tx_bytes + tx_pkt_diff * FPGA_PACKET_OVERHEAD) * 8.
        / (ONE_MILLION * interval_s);
    uint64_t tx_pkt_rate = (tx_pkt_diff / interval_s);
    uint64_t tx_pkt_rate_kpps = tx_pkt_rate / ONE_THOUSAND;

    uint64_t rtt_sum_ns = rx_stats.rtt_sum * enso::kNsPerTimestampCycle;
    uint64_t rtt_ns;
    if (rx_pkt_diff != 0) {
      rtt_ns = (rtt_sum_ns - last_aggregated_rtt_ns) / rx_pkt_diff;
    } else {
      rtt_ns = 0;
    }

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

  free(pkt_buf);
  return ret;
}
