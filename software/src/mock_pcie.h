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

/**
 * @file
 * @brief Functions to initialize and interface directly with the mock PCIe
 * device.
 *
 * @author Kaajal Gupta <kaajalg@andrew.cmu.edu>
 */

#ifndef SOFTWARE_SRC_MOCK_PCIE_H_
#define SOFTWARE_SRC_MOCK_PCIE_H_

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

#endif  // SOFTWARE_SRC_MOCK_PCIE_H_
