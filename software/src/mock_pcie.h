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

#include <endian.h>
#include <enso/internals.h>
#include <netinet/ether.h>
#include <netinet/ip.h>

#include <unordered_map>
#include <vector>

#include "syscall_api/intel_fpga_pcie_api.hpp"

namespace enso {

#define MAX_NUM_PACKETS 512
#define MOCK_BATCH_SIZE 16
#define MOCK_ENSO_PIPE_SIZE (2048 * 16)

struct Packet {
  u_char* pkt_bytes;
  uint32_t pkt_len;
};

typedef struct RxEnsoPipeInternal* MockEnsoPipe;

/**
 * @brief Hashmap of all enso pipes in mock
 *
 */
static std::unordered_map<uint16_t, MockEnsoPipe> enso_pipes_map;
static std::vector<MockEnsoPipe> enso_pipes_vector;

}  // namespace enso

#endif  // SOFTWARE_SRC_MOCK_PCIE_H_
