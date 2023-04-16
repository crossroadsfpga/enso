/**
 * @file mock_rss_helpers.h
 * @author Kaajal Gupta (kaajalg)
 * @brief
 * @version 0.1
 * @date 2023-04-16
 *
 * @copyright Copyright (c) 2023
 *
 */
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

#include "pcie.h"
#include "syscall_api/intel_fpga_pcie_api.hpp"

int rss_hash_packet(packet_t* pkt);