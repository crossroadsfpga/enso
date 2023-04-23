#include <arpa/inet.h>
#include <enso/consts.h>
#include <enso/helpers.h>
#include <enso/ixy_helpers.h>
#include <immintrin.h>
#include <pcap/pcap.h>
#include <sched.h>
#include <string.h>
#include <time.h>

#include <algorithm>
#include <cassert>
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <ctime>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <vector>

#include "pcie.h"
#include "syscall_api/intel_fpga_pcie_api.hpp"

#define MAX_NUM_PACKETS 512
#define MOCK_BATCH_SIZE 16
#define ENSO_PIPE_SIZE 2048

typedef struct packet {
  u_char* pkt_bytes;
  uint32_t pkt_len;
} packet_t;

struct PcapHandlerContext {
  packet_t** buf;
  int buf_position;
  uint32_t hugepage_offset;
  pcap_t* pcap;
};

/**
 * @brief Mock enso pipe structure.
 *
 */
typedef struct enso_pipe {
  u_char pipe_buffer[ENSO_PIPE_SIZE];
  int head;
  int tail;
  int index;
} enso_pipe_t;

std::vector<enso_pipe_t*> enso_pipes_vector;