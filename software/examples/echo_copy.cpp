/*
 * Copyright (c) 2023, Carnegie Mellon University
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
#include <enso/pipe.h>
#include <enso/queue.h>
#include <pthread.h>
#include <sched.h>
#include <unistd.h>  // for usleep

#include <chrono>
#include <csignal>
#include <cstdint>
#include <cstring>
extern "C" {
#include <base/log.h>
}
#include <fastscheduler/defs.hpp>
#include <fastscheduler/kthread.hpp>
#include <fastscheduler/sched.hpp>
#include <iostream>
#include <memory>
#include <vector>

#include "example_helpers.h"

static volatile bool keep_running = true;
static volatile bool setup_done = false;

struct EchoArgs {
  uint32_t nb_queues;
  uint32_t core_id;
  uint32_t nb_cycles;
  enso::stats_t* stats;
  uint32_t uthread_id;
};

void int_handler([[maybe_unused]] int signal) { keep_running = false; }

void run_echo_copy(void* arg) {
  struct EchoArgs* args = (struct EchoArgs*)arg;
  uint32_t nb_queues = args->nb_queues;
  uint32_t core_id = args->core_id;
  uint32_t nb_cycles = args->nb_cycles;
  enso::stats_t* stats = args->stats;
  uint32_t uthread_id = args->uthread_id;

  usleep(1000000);

  log_info("Running %u", uthread_id);

  using enso::Device;
  using enso::RxPipe;
  using enso::TxPipe;

  std::vector<RxPipe*> rx_pipes;
  std::vector<TxPipe*> tx_pipes;

  std::unique_ptr<Device> dev = Device::Create(uthread_id);

  if (!dev) {
    std::cerr << "Problem creating device" << std::endl;
    exit(2);
  }

  for (uint32_t i = 0; i < nb_queues; ++i) {
    RxPipe* rx_pipe = dev->AllocateRxPipe();
    if (!rx_pipe) {
      log_err("Problem creating RX pipe");
      exit(3);
    }

    uint32_t dst_ip = kBaseIpAddress + core_id * nb_queues + i;
    rx_pipe->Bind(kDstPort, 0, dst_ip, 0, kProtocol);

    rx_pipes.push_back(rx_pipe);

    TxPipe* tx_pipe = dev->AllocateTxPipe();
    if (!tx_pipe) {
      log_err("Problem creating TX pipe");
      exit(3);
    }
    tx_pipes.push_back(tx_pipe);
  }

  setup_done = true;

  while (keep_running) {
    for (uint32_t i = 0; i < nb_queues; ++i) {
      auto& rx_pipe = rx_pipes[i];
      auto batch = rx_pipe->RecvPkts();

      if (unlikely(batch.available_bytes() == 0)) {
        continue;
      }

      for (auto pkt : batch) {
        ++pkt[63];  // Increment payload.

        for (uint32_t i = 0; i < nb_cycles; ++i) {
          asm("nop");
        }

        ++(stats->nb_pkts);
      }
      uint32_t batch_length = batch.processed_bytes();
      stats->recv_bytes += batch_length;
      ++(stats->nb_batches);

      auto& tx_pipe = tx_pipes[i];
      uint8_t* tx_buf = tx_pipe->AllocateBuf(batch_length);

      memcpy(tx_buf, batch.buf(), batch_length);

      rx_pipe->Clear();

      tx_pipe->SendAndFree(batch_length);
    }
  }
}

int main(int argc, const char* argv[]) {
  if (argc != 7) {
    std::cerr << "Usage: " << argv[0]
              << " STARTING_CORE NB_CORES NB_UTHREADS NB_QUEUES NB_CYCLES "
                 "APPLICATION_ID"
              << std::endl
              << std::endl;
    std::cerr << "STARTING_CORE: Core to start running on." << std::endl;
    std::cerr << "NB_CORES: Number of cores to run on." << std::endl;
    std::cerr << "NB_UTHREADS: Number of uthreads to create." << std::endl;
    std::cerr << "NB_QUEUES: Number of queues per uthread." << std::endl;
    std::cerr << "NB_CYCLES: Number of cycles to busy loop when processing each"
                 " packet."
              << std::endl;
    std::cerr << "APPLICATION_ID: Count of number of applications started "
                 "before this application, starting from 0."
              << std::endl;
    return 1;
  }

  using sched::kthread_t;
  using sched::uthread_t;

  uint32_t starting_core = atoi(argv[1]);
  uint32_t nb_cores = atoi(argv[2]);
  uint32_t nb_uthreads = atoi(argv[3]);
  uint32_t nb_queues = atoi(argv[4]);
  uint32_t nb_cycles = atoi(argv[5]);
  uint32_t application_id = atoi(argv[6]);

  signal(SIGINT, int_handler);

  std::vector<kthread_t*> kthreads;
  std::vector<enso::stats_t> thread_stats(nb_cores);

  /**
   * Barrier to ensure that all kthreads start looking at their runqueues only
   * after all kthreads have been initialized & all uthreads have been added
   * to runqueues
   */
  pthread_barrier_t init_barrier;
  pthread_barrier_init(&init_barrier, NULL, nb_cores + 1);

  /* Create all of the kthreads */
  for (uint32_t i = 0; i < nb_cores; ++i) {
    log_info("Creating kthread on core %d", i);
    kthread_t* kthread =
        sched::kthread_create(application_id, i, &init_barrier);
    kthreads.push_back(kthread);
  }

  /* Add all of the uthreads to the kthreads' runqueues */
  for (uint32_t uthread_id = 0; uthread_id < nb_uthreads; ++uthread_id) {
    uint32_t current_kthread = uthread_id % nb_cores;
    struct EchoArgs* args = (struct EchoArgs*)malloc(sizeof(struct EchoArgs));
    args->nb_queues = nb_queues;
    args->nb_cycles = nb_cycles;
    args->stats = &(thread_stats[current_kthread]);
    args->core_id = starting_core + uthread_id;
    args->uthread_id = uthread_id;

    kthread_t* k = kthreads[current_kthread];
    sched::uthread_create(application_id, k, uthread_id, run_echo_copy,
                          (void*)args);
  }

  pthread_barrier_wait(&init_barrier);

  show_stats(thread_stats, &keep_running);

  for (auto& k : kthreads) {
    sched::kthread_join(k);
  }

  return 0;
}
