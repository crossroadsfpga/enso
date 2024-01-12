/*
 * Copyright (c) 2024, Carnegie Mellon University
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
/*
 * @file: ensogen.cpp
 *
 * @brief: Packet generator program that uses the Enso library to send and
 * receive packets. It uses libpcap to read and process packets from a pcap file.
 *
 * Example:
 *
 * sudo ./scripts/ensogen.sh ./scripts/sample_pcaps/2_64_1_2.pcap 100 \
 * --pcie-addr 65:00.0
 *
 * */

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

/******************************************************************************
 * Macros and Globals
 *****************************************************************************/
// Number of loop iterations to wait before probing the TX notification buffer
// again when reclaiming buffer space.
#define TX_RECLAIM_DELAY                    1024

// Scientific notation for 10^6, treated as double. Used for stats calculations.
#define ONE_MILLION                         1e6

// Scientific notation for 10^3, treated as double. Used for stats calculations.
#define ONE_THOUSAND                        1e3

// Ethernet's per packet overhead added by the FPGA (in bytes).
#define FPGA_PACKET_OVERHEAD                24

// Minimum size of a packet aligned to cache (in bytes).
#define MIN_PACKET_ALIGNED_SIZE             64

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

// Macros for cmd line option names
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

static volatile int keep_running = 1;
static volatile int force_stop = 0;
static volatile int rx_ready = 0;
static volatile int rx_done = 0;
static volatile int tx_done = 0;

using enso::Device;
using enso::RxPipe;
using enso::TxPipe;

/******************************************************************************
 * Structure Definitions
 *****************************************************************************/
/*
 * @brief: Structure to store the command line arguments.
 *
 * */
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

/*
 * @brief: Structure to store an Enso TxPipe object and attributes related
 * to it.
 *
 * */
struct EnsoTxPipe {
  EnsoTxPipe(TxPipe *pipe)
            : tx_pipe(pipe), nb_aligned_bytes(0), nb_raw_bytes(0),
              nb_pkts(0) {}
  // Enso TxPipe
  TxPipe *tx_pipe;
  // Number of cache aligned bytes in the pipe
  uint32_t nb_aligned_bytes;
  // Number of raw bytes in the pipe
  uint32_t nb_raw_bytes;
  // Number of packets in the pipe
  uint32_t nb_pkts;
};


/*
 * @brief: Structure to store variables needed for processing the PCAP
 * file and are passed to the callback function.
 *
 * */
struct PcapHandlerContext {
  PcapHandlerContext(std::unique_ptr<Device> &dev_, pcap_t* pcap_) :
                     dev(dev_), buf(NULL), free_flits_cur_pipe(0),
                     pcap(pcap_) {}
  // Pointer to Enso device
  std::unique_ptr<Device> &dev;
  // Pipes to store the packets from the PCAP file
  std::vector<struct EnsoTxPipe> tx_pipes;
  // Pointer to the buffer of the current pipe
  uint8_t *buf;
  // Total number of free flits in the current pipe
  uint32_t free_flits_cur_pipe;
  // libpcap object associated with the opened PCAP file
  pcap_t* pcap;
};

/*
 * @brief: Structure to store the Rx related stats.
 *
 * */
struct RxStats {
  explicit RxStats(uint32_t rtt_hist_len = 0, uint32_t rtt_hist_offset = 0)
      : pkts(0),
        bytes(0),
        nb_batches(0),
        rtt_sum(0),
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
    }
    else {
      rtt_hist[rtt - rtt_hist_offset]++;
    }
  }

  // Number of packets received
  uint64_t pkts;
  // Number of bytes received
  uint64_t bytes;
  // Number of RxNotifications or batches
  uint64_t nb_batches;
  // RTT calculation related
  uint64_t rtt_sum;
  const uint32_t rtt_hist_len;
  const uint32_t rtt_hist_offset;
  uint64_t* rtt_hist;
  std::unordered_map<uint32_t, uint64_t> backup_rtt_hist;
};

/*
 * @brief: Structure to store the variables needed by the receive_pkts
 * function.
 *
 * */
struct RxArgs {
  RxArgs(bool enbl_rtt, bool enbl_rtt_hist, std::unique_ptr<Device> &dev_) :
        enable_rtt(enbl_rtt),
        enable_rtt_history(enbl_rtt_hist),
        dev(dev_) {}
  // Check for whether RTT needs to be calculated
  bool enable_rtt;
  // Check for whether RTT history needs to be calculated
  bool enable_rtt_history;
  // Pointer to the Enso device
  std::unique_ptr<Device> &dev;
};

/*
 * @brief: Structure to store the Tx related stats.
 *
 * */
struct TxStats {
  TxStats() : pkts(0), bytes(0) {}
  // Number of packets received
  uint64_t pkts;
  // Number of bytes received
  uint64_t bytes;
};

/*
 * @brief: Structure to store the arguments needed by the transmit_pkts
 * function.
 *
 * */
struct TxArgs {
  TxArgs(std::vector<struct EnsoTxPipe> &pipes, uint64_t total_aligned_bytes,
         uint64_t total_raw_bytes, uint64_t pkts_in_last_pipe,
         uint32_t pipes_size, std::unique_ptr<Device> &dev_)
        : tx_pipes(pipes),
          total_remaining_aligned_bytes(total_aligned_bytes),
          total_remaining_raw_bytes(total_raw_bytes),
          nb_pkts_in_last_pipe(pkts_in_last_pipe),
          cur_ind(0),
          total_pipes(pipes_size),
          transmissions_pending(0),
          ignored_reclaims(0),
          dev(dev_) {}
  // TxPipes handled by the thread
  std::vector<struct EnsoTxPipe> &tx_pipes;
  // Number of aligned bytes that need to be sent
  uint64_t total_remaining_aligned_bytes;
  // Number of raw bytes that need to be sent
  uint64_t total_remaining_raw_bytes;
  // Number of packets in the last pipe - needed for stats calculation
  uint64_t nb_pkts_in_last_pipe;
  // Index in tx_pipes vector. Points to the current pipe being sent
  uint32_t cur_ind;
  // Total number of pipes in tx_pipes vector
  uint32_t total_pipes;
  // Total number of notifications created and sent by the application
  uint32_t transmissions_pending;
  // Used to track the number of times the thread did not check for notification
  // consumption by the NIC
  uint32_t ignored_reclaims;
  // Pointer to the Enso device object
  std::unique_ptr<Device> &dev;
};

/******************************************************************************
 * Function Definitions
 *****************************************************************************/
/*
 * @brief: Signal handler for SIGINT (Ctrl+C).
 *
 * */
void int_handler(int signal __attribute__((unused))) {
  if (!keep_running) {
    // user interrupted the second time, we force stop
    force_stop = 1;
  }
  // user interrupted the first time, we signal the thread(s) to stop
  keep_running = 0;
}

/*
 * @brief: Prints the help message on stdout.
 *
 * */
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

/*
 * Command line options related. Used in parse_args function.
 *
 * */
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
    {0, 0, 0, 0}
};

/*
 * @brief: Parses the command line arguments. Called from the main function.
 *
 * @param argc: Number of arguments entered by the user.
 * @param argv: Value of the arguments entered by the user.
 * @param parsed_args: Structure filled by this function after parsing the
 *                     arguments and used in main().
 *
 * */
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

/*
 * @brief: libpcap callback registered by the main function. Called for each
 * packet present in the PCAP file by libpcap.
 *
 * @param user: Structure allocated in main to read and store relevant information.
 * @param pkt_hdr: Contains packet metadata like timestamp, length, etc. (UNUSED)
 * @param pkt_bytes: Packet data to be copied into a buffer.
 *
 * */
void pcap_pkt_handler(u_char* user, const struct pcap_pkthdr* pkt_hdr,
                      const u_char* pkt_bytes) {
  (void) pkt_hdr;
  struct PcapHandlerContext* context = (struct PcapHandlerContext*)user;

  const struct ether_header* l2_hdr = (struct ether_header*)pkt_bytes;
  if (l2_hdr->ether_type != htons(ETHERTYPE_IP)) {
    std::cerr << "Non-IPv4 packets are not supported" << std::endl;
    free(context->buf);
    exit(8);
  }

  uint32_t len = enso::get_pkt_len(pkt_bytes);
  uint32_t nb_flits = (len - 1) / MIN_PACKET_ALIGNED_SIZE + 1;

  if (nb_flits > context->free_flits_cur_pipe) {
    // initialize a new pipe
    TxPipe* tx_pipe = context->dev->AllocateTxPipe();
    if (!tx_pipe) {
      std::cerr << "Problem creating TX pipe" << std::endl;
      pcap_breakloop(context->pcap);
      return;
    }
    struct EnsoTxPipe enso_tx_pipe(tx_pipe);
    context->tx_pipes.push_back(enso_tx_pipe);
    context->free_flits_cur_pipe = BUFFER_SIZE / MIN_PACKET_ALIGNED_SIZE;
    context->buf = tx_pipe->buf();
  }

  // We copy the packets in the pipe's buffer in multiples of 64 bytes
  // or MIN_PACKET_ALIGNED SIZE. However, we also keep track of the number
  // of raw bytes on a per pipe basis since we need it for stats calculation.
  struct EnsoTxPipe& tx_pipe = context->tx_pipes.back();
  uint8_t* dest = context->buf + tx_pipe.nb_aligned_bytes;
  memcpy(dest, pkt_bytes, len);

  tx_pipe.nb_aligned_bytes += nb_flits * MIN_PACKET_ALIGNED_SIZE;
  tx_pipe.nb_raw_bytes += len;
  tx_pipe.nb_pkts++;
  context->free_flits_cur_pipe -= nb_flits;
}

/*
 * @brief: This function is used to receive packets. The approach used in this
 * function is slightly different from the one described in Enso's library for
 * the RxPipe abstraction (Allocate->Bind->Recv->Clear). We use the NextRxPipeToRecv
 * abstraction to take advantage of notification prefetching and use fallback
 * queues.
 *
 * @param rx_args: Arguments needed by this function. See RxArgs definition.
 * @param rx_stats: Rx stats that need to be updated in every iteration.
 *
 * */
inline uint64_t receive_pkts(const struct RxArgs& rx_args,
                             struct RxStats& rx_stats) {
  uint64_t nb_pkts = 0;
#ifdef IGNORE_RX
  (void)rx_args;
  (void)rx_stats;
#else   // IGNORE_RX
  RxPipe* rx_pipe = rx_args.dev->NextRxPipeToRecv();
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
    nb_pkts++;
  }

  uint32_t batch_length = batch.processed_bytes();
  rx_pipe->ConfirmBytes(batch_length);

  rx_stats.pkts += nb_pkts;
  rx_stats.nb_batches++;
  rx_stats.bytes += recv_bytes;

  rx_pipe->Clear();

#endif  // IGNORE_RX
  return nb_pkts;
}

/*
 * @brief: This function is called to send packets. Note that the approach we
 * use here to send packets is different from the one defined in Enso's library
 * using the TxPipe abstraction. This approach dissociates the sending part
 * (creating TX notifications) from processing the completions (which TX notif-
 * ications have been consumed by the NIC). It needed to be done this way to meet
 * the performance requirements (full 100 G) for single core.
 *
 * @param tx_args: Arguments needed by this function. See TxArgs definition.
 * @param tx_stats: Tx stats that need to be updated in every iteration.
 *
 * */
inline void transmit_pkts(struct TxArgs& tx_args,
                          struct TxStats& tx_stats) {
  // Avoid transmitting new data when too many TX notifications are pending
  const uint32_t buf_fill_thresh = enso::kNotificationBufSize
                                   - TRANSFERS_PER_BUFFER - 1;
  if (likely(tx_args.transmissions_pending < buf_fill_thresh)) {
    struct EnsoTxPipe &cur_pipe = tx_args.tx_pipes[tx_args.cur_ind];
    uint32_t transmission_length = std::min(tx_args.total_remaining_aligned_bytes,
                                            (uint64_t) cur_pipe.nb_aligned_bytes);
    uint32_t transmission_raw_length = std::min(tx_args.total_remaining_raw_bytes,
                                                (uint64_t) cur_pipe.nb_raw_bytes);

    uint64_t buf_phys_addr = cur_pipe.tx_pipe->GetBufPhysAddr();
    tx_args.dev->SendOnly(buf_phys_addr, transmission_length);
    tx_args.transmissions_pending++;
    tx_args.total_remaining_aligned_bytes -= transmission_length;
    tx_args.total_remaining_raw_bytes -= transmission_raw_length;

    // update the stats
    // the stats need be calculated based on raw bytes
    tx_stats.bytes += transmission_raw_length;
    if(tx_args.total_remaining_aligned_bytes == 0) {
      keep_running = 0;
      tx_stats.pkts += tx_args.nb_pkts_in_last_pipe;
      return;
    }
    tx_stats.pkts += cur_pipe.nb_pkts;

    // move to the next pipe
    tx_args.cur_ind = (tx_args.cur_ind + 1) % tx_args.total_pipes;
  }

  // Reclaim TX notification buffer space.
  if ((tx_args.transmissions_pending > (enso::kNotificationBufSize / 4))) {
    if (tx_args.ignored_reclaims > TX_RECLAIM_DELAY) {
      tx_args.ignored_reclaims = 0;
      uint32_t num_processed = tx_args.dev->ProcessCompletionsOnly();
      if(num_processed > tx_args.transmissions_pending) {
        tx_args.transmissions_pending = 0;
      }
      else {
        tx_args.transmissions_pending -= num_processed;
      }
    }
    else {
      tx_args.ignored_reclaims++;
    }
  }
}

/*
 * @brief: Waits until the NIC has consumed all the Tx notifications.
 *
 * @param tx_args: Arguments needed by this function. See TxArgs definition.
 *
 * */
inline void reclaim_all_buffers(struct TxArgs& tx_args) {
  while (tx_args.transmissions_pending > 0) {
    uint32_t num_processed = tx_args.dev->ProcessCompletionsOnly();
    if(num_processed > tx_args.transmissions_pending) {
      tx_args.transmissions_pending = 0;
      break;
    }
    tx_args.transmissions_pending -= num_processed;
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

  std::unique_ptr<Device> dev = Device::Create(parsed_args.pcie_addr);
  if (!dev) {
    std::cerr << "Problem creating device" << std::endl;
    exit(2);
  }

  char errbuf[PCAP_ERRBUF_SIZE];

  pcap_t* pcap = pcap_open_offline(parsed_args.pcap_file.c_str(), errbuf);
  if (pcap == NULL) {
    std::cerr << "Error loading pcap file (" << errbuf << ")" << std::endl;
    return 2;
  }

  struct PcapHandlerContext context(dev, pcap);

  std::vector<struct EnsoTxPipe> &tx_pipes = context.tx_pipes;

  // Initialize pipes with packets read from pcap file.
  if (pcap_loop(pcap, 0, pcap_pkt_handler, (u_char*)&context) < 0) {
    std::cerr << "Error while reading pcap (" << pcap_geterr(pcap) << ")"
              << std::endl;
    return 3;
  }

  // For small pcaps we copy the same packets over the remaining of the
  // buffer. This reduces the number of transfers that we need to issue.
  // If there is only one pipe, nb_bytes contains the number of bytes
  // in that pipe only.
  if ((tx_pipes.size() == 1) &&
      (tx_pipes.front().nb_aligned_bytes < BUFFER_SIZE / 2)) {
    struct EnsoTxPipe& tx_pipe = tx_pipes.front();
    uint8_t *pipe_buf = tx_pipe.tx_pipe->buf();
    uint32_t cur_buf_length = tx_pipe.nb_aligned_bytes;
    uint32_t original_buf_length = cur_buf_length;
    uint32_t original_nb_pkts = tx_pipe.nb_pkts;
    uint32_t original_raw_bytes = tx_pipe.nb_raw_bytes;
    while ((cur_buf_length + original_buf_length) <= BUFFER_SIZE) {
      memcpy(pipe_buf + cur_buf_length, pipe_buf, original_buf_length);
      cur_buf_length += original_buf_length;
      tx_pipe.nb_pkts += original_nb_pkts;
      tx_pipe.nb_raw_bytes += original_raw_bytes;
    }
    tx_pipe.nb_aligned_bytes = cur_buf_length;
  }

  // calculate total aligned bytes, raw bytes and packets in all the pipes
  uint64_t total_pkts_in_pipes = 0;
  uint64_t total_aligned_bytes_in_pipes = 0;
  uint64_t total_raw_bytes_in_pipes = 0;
  for (auto& pipe : tx_pipes) {
    total_pkts_in_pipes += pipe.nb_pkts;
    total_aligned_bytes_in_pipes += pipe.nb_aligned_bytes;
    total_raw_bytes_in_pipes += pipe.nb_raw_bytes;
  }

  // Handling the --count option. calculate the number of bytes that
  // need to be sent. if the user requests 'x' packets, we start sending
  // from the start of the first pipe (order is the same as the PCAP file)
  // and wrap around if x is greater than total_pkts_in_pipes.
  uint64_t total_aligned_bytes_to_send;
  uint64_t total_raw_bytes_to_send;
  uint64_t pkts_in_last_pipe = 0;
  if (parsed_args.nb_pkts > 0) {
    uint64_t nb_full_iters = parsed_args.nb_pkts / total_pkts_in_pipes;
    uint64_t nb_pkts_remaining = parsed_args.nb_pkts % total_pkts_in_pipes;

    total_aligned_bytes_to_send = nb_full_iters * total_aligned_bytes_in_pipes;
    total_raw_bytes_to_send = nb_full_iters * total_raw_bytes_in_pipes;

    if (nb_pkts_remaining == 0) {
      pkts_in_last_pipe = tx_pipes.back().nb_pkts;
    }

    // calculate the length of the first 'x % total_pkts_in_pipes' packets
    for (auto& pipe : tx_pipes) {
      if (nb_pkts_remaining < pipe.nb_pkts) {
        uint8_t* pkt = pipe.tx_pipe->buf();
        while (nb_pkts_remaining > 0) {
          uint16_t pkt_len = enso::get_pkt_len(pkt);
          uint16_t nb_flits = (pkt_len - 1) / 64 + 1;

          total_aligned_bytes_to_send += nb_flits * 64;
          nb_pkts_remaining--;
          pkts_in_last_pipe++;

          pkt = enso::get_next_pkt(pkt);
        }
        break;
      }
      total_aligned_bytes_to_send += pipe.nb_aligned_bytes;
      nb_pkts_remaining -= pipe.nb_pkts;
    }
  }
  else {
    // Treat nb_pkts == 0 as unbounded. The following value should be enough
    // to send 64-byte packets for around 400 years using Tb Ethernet.
    total_aligned_bytes_to_send = 0xffffffffffffffff;
    total_raw_bytes_to_send = 0xffffffffffffffff;
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
    std::thread rx_thread = std::thread([&parsed_args, &rx_stats, &dev] {
      std::this_thread::sleep_for(std::chrono::milliseconds(500));

      std::vector<RxPipe*> rx_pipes;

      for (uint32_t i = 0; i < parsed_args.nb_queues; i++) {
        // we create fallback queues by passing true in AllocateRxPipe
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

      RxArgs rx_args(parsed_args.enable_rtt,
                     parsed_args.enable_rtt_history,
                     dev);

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
          nb_iters_no_pkt++;
        }
        else {
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
        [total_aligned_bytes_to_send, total_raw_bytes_to_send,
         pkts_in_last_pipe, &parsed_args, &tx_stats, &dev, &tx_pipes] {
          std::this_thread::sleep_for(std::chrono::seconds(1));

          while (!rx_ready) continue;

          std::cout << "Running TX on core " << sched_getcpu() << std::endl;

          TxArgs tx_args(tx_pipes, total_aligned_bytes_to_send,
                         total_raw_bytes_to_send, pkts_in_last_pipe,
                         tx_pipes.size(), dev);

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
  }
  else {
    // Send and receive packets within the same thread.
    std::thread rx_tx_thread = std::thread(
        [total_aligned_bytes_to_send, total_raw_bytes_to_send,
         pkts_in_last_pipe, &parsed_args, &tx_stats, &rx_stats,
         &dev, &tx_pipes] {
          std::this_thread::sleep_for(std::chrono::milliseconds(500));

          std::vector<RxPipe*> rx_pipes;

          for (uint32_t i = 0; i < parsed_args.nb_queues; i++) {
            // we create fallback queues by passing true in AllocateRxPipe
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

          RxArgs rx_args(parsed_args.enable_rtt,
                         parsed_args.enable_rtt_history,
                         dev);

          TxArgs tx_args(tx_pipes, total_aligned_bytes_to_send,
                         total_raw_bytes_to_send, pkts_in_last_pipe,
                         tx_pipes.size(), dev);

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
              nb_iters_no_pkt++;
            }
            else {
              nb_iters_no_pkt = 0;
            }
          }

          rx_done = true;

          reclaim_all_buffers(tx_args);

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
        << "rx_rawput_mbps,rx_tput_mbps,rx_pkt_rate_kpps,rx_bytes,rx_packets,"
           "tx_rawput_mbps,tx_tput_mbps,tx_pkt_rate_kpps,tx_bytes,tx_packets";
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
    uint64_t rx_rawput_mbps =
        (rx_bytes - last_rx_bytes) * 8. / (ONE_MILLION * interval_s);
    uint64_t rx_pkt_rate = (rx_pkt_diff / interval_s);
    uint64_t rx_pkt_rate_kpps = rx_pkt_rate / ONE_THOUSAND;
    uint64_t rx_tput_mbps = rx_rawput_mbps + FPGA_PACKET_OVERHEAD
                            * 8 * rx_pkt_rate / ONE_MILLION;

    uint64_t tx_pkt_diff = tx_pkts - last_tx_pkts;
    uint64_t tx_rawput_mbps =
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
    }
    else {
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
      save_file << rx_rawput_mbps << "," << rx_tput_mbps << ","
                << rx_pkt_rate_kpps << "," << rx_bytes << "," << rx_pkts << ","
                << tx_rawput_mbps << "," << tx_pkt_rate_kpps << ","
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

    for (uint32_t rtt = 0; rtt < parsed_args.rtt_hist_len; rtt++) {
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

  dev.reset();
  return ret;
}
