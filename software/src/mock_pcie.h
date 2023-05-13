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
#define MOCK_ENSO_PIPE_SIZE 2048

typedef struct packet {
  u_char* pkt_bytes;
  uint32_t pkt_len;
} packet_t;

/**
 * @brief Mock enso pipe structure.
 *
 */
typedef struct enso_pipe {
  u_char pipe_buffer[ENSO_PIPE_SIZE];  // buffer to store packet contents
  int head;   // position of head: where to read packets frmo
  int tail;   // position of tail: where to write packets to
  int index;  // index of this enso pipe in the enso pipes vector
} enso_pipe_t;

/**
 * @brief Vector of all enso pipes in mock
 *
 */
std::vector<enso_pipe_t*> enso_pipes_vector;