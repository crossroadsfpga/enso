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

#include <enso/helpers.h>
#include <enso/pipe.h>
#include <pthread.h>
#include <sched.h>
#include <unistd.h>  // for usleep

#include <chrono>
#include <csignal>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <memory>

#include "example_helpers.h"

static volatile bool keep_running = true;
static volatile bool setup_done = false;

struct EchoArgs {
  uint32_t nb_queues;
  uint32_t core_id;
  uint32_t nb_cycles;
  enso::stats_t* stats;
  uint32_t application_id;
};

std::array<int, kMaxNbFlows> pipe_id_to_eventfds_map_ = {};

void int_handler([[maybe_unused]] int signal) { keep_running = false; }

void* run_echo_copy(void* arg) {
  struct EchoArgs* args = (struct EchoArgs*)arg;
  uint32_t nb_queues = args->nb_queues;
  uint32_t core_id = args->core_id;
  uint32_t nb_cycles = args->nb_cycles;
  enso::stats_t* stats = args->stats;
  uint32_t application_id = args->application_id;

  enso::set_self_core_id(core_id);

  usleep(1000000);

  std::cout << "Running on core " << sched_getcpu() << std::endl;

  using enso::RxPipe;
  using enso::TxPipe;

  std::array<RxPipe*, kMaxNbFlows> rx_pipes_map;
  std::vector<TxPipe*> tx_pipes;

  // for uthreads, do not create a notification buffer!
  std::unique_ptr<Device> dev =
      Device::Create(application_id, NULL, false, false);
  int my_eventfd = dev->GetEventFd();

  if (!dev) {
    std::cerr << "Problem creating device" << std::endl;
    exit(2);
  }

  for (uint32_t i = 0; i < nb_queues; ++i) {
    RxPipe* rx_pipe = dev->AllocateRxPipe();
    if (!rx_pipe) {
      std::cerr << "Problem creating RX pipe" << std::endl;
      exit(3);
    }
    pipe_id_to_eventfds_map_[rx_pipe->id] = my_eventfd;

    uint32_t dst_ip = kBaseIpAddress + core_id * nb_queues + i;
    rx_pipe->Bind(kDstPort, 0, dst_ip, 0, kProtocol);

    rx_pipes_map[rx_pipe->id] = rx_pipe;

    TxPipe* tx_pipe = dev->AllocateTxPipe();
    if (!tx_pipe) {
      std::cerr << "Problem creating TX pipe" << std::endl;
      exit(3);
    }
    tx_pipes.push_back(tx_pipe);
  }

  setup_done = true;

  // need to read from eventfd now
  dev->Wait();

  while (keep_running) {
    int32_t next_enso_pipe_id = dev->next_pipe_id_;
    if (next_enso_pipe_id < 0) {
      continue;
    }

    // get the uthread associated with this pipe ID: store a hashtable mapping
    // pipe IDs to eventfds then write to the eventfd of that
    // uthread and read from your own eventfd
    // need to make sure context switching is disabled here
    int eventfd = pipe_id_to_eventfds_map_[next_enso_pipe_id];
    if (eventfd != my_eventfd) {
      // notification for not my pipe!
      write(eventfd, NULL, 0);
      read(eventfd, NULL, 0);
    } else {
      // notification for my pipe
      auto& rx_pipe = rx_pipes_map[next_enso_pipe_id];
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
    // after reawakening, read the new notification buffer information
    dev->UpdateNotificationBuffer();
  }

  return NULL;
}

int main(int argc, const char* argv[]) {
  if (argc != 6) {
    std::cerr << "Usage: " << argv[0]
              << " NB_UTHREADS NB_QUEUES NB_CYCLES CORE_ID" << std::endl
              << std::endl;
    std::cerr << "NB_UTHREADS: Number of uthreads to create." << std::endl;
    std::cerr << "NB_QUEUES: Number of queues per uthread." << std::endl;
    std::cerr << "NB_CYCLES: Number of cycles to busy loop when processing each"
                 " packet."
              << std::endl;
    std::cerr << "CORE_ID: Which core to run the uthreads on" << std::endl;
    std::cerr << "APPLICATION_ID: Count of number of applications started "
                 "before this application, starting from 0."
              << std::endl;
    return 1;
  }

  uint32_t nb_cores = atoi(argv[1]);
  uint32_t nb_queues = atoi(argv[2]);
  uint32_t nb_cycles = atoi(argv[3]);
  uint32_t application_id = atoi(argv[4]);
  uint32_t core_id = atoi(argv[5]);

  signal(SIGINT, int_handler);

  std::vector<pthread_t> threads;
  std::vector<enso::stats_t> thread_stats(nb_cores);

  std::unique_ptr<Device> dev =
      Device::Create(application_id, NULL, false, false);

  for (uint32_t i = 0; i < nb_cores; ++i) {
    pthread_t thread;
    struct EchoArgs args;
    args.nb_queues = nb_queues;
    args.nb_cycles = nb_cycles;
    args.stats = &(thread_stats[core_id]);
    args.application_id = application_id;
    pthread_create(&thread, NULL, run_echo_copy, (void*)&args);
    threads.push_back(thread);
    // wait for previous thread to start waiting
    while (!setup_done) continue;
    setup_done = false;
  }

  while (!setup_done) continue;  // Wait for setup to be done.

  // initialize kthread

  show_stats(thread_stats, &keep_running);

  for (auto& thread : threads) {
    pthread_join(thread, NULL);
  }

  return 0;
}
