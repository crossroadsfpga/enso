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

struct ConfigArgs {
  uint32_t nb_queues;
  uint32_t dst_ip_1;
  uint32_t dst_ip_2;
  uint32_t ns_interval;
  uint32_t core_id;
};

struct EchoArgs {
  uint32_t core_id;
  uint32_t nb_cycles;
  enso::stats_t* stats;
  uint32_t application_id;
  uint32_t nb_queues;
};

void int_handler([[maybe_unused]] int signal) { keep_running = false; }

std::chrono::nanoseconds get_time() {
  return std::chrono::duration_cast<std::chrono::nanoseconds>(
      std::chrono::system_clock::now().time_since_epoch());
}

void* change_config(void* arg) {
  struct ConfigArgs* args = (struct ConfigArgs*)arg;
  uint32_t nb_queues = args->nb_queues;
  uint32_t ns_interval = args->ns_interval;
  uint32_t core_id = args->core_id;

  enso::set_self_core_id(core_id);

  std::cout << "HIIIII In change config thread, running on core "
            << sched_getcpu() << std::endl;

  using enso::Device;
  using enso::RxPipe;
  using std::chrono;

  std::unique_ptr<Device> dev = Device::Create(0, NULL);
  std::vector<RxPipe*> pipes;

  if (!dev) {
    std::cerr << "Problem creating device" << std::endl;
    exit(2);
  }

  uint32_t dst_ip_1 = kBaseIpAddress + core_id * 2;
  uint32_t dst_ip_2 = kBaseIpAddress + core_id * 2 + 1;

  for (uint32_t i = 0; i < nb_queues; ++i) {
    RxPipe* pipe = dev->AllocateRxPipe();
    if (!pipe) {
      std::cerr << "Problem creating RX/TX pipe" << std::endl;
      exit(3);
    }
    if (i % 2 == 0) {
      pipe->Bind(kDstPort, 0, dst_ip_1, 0, kProtocol);
    } else {
      pipe->Bind(kDstPort, 0, dst_ip_2, 0, kProtocol);
    }

    pipes.push_back(pipe);
  }

  nanoseconds last_time = get_time();

  while (keep_running) {
    nanoseconds now = get_time();
    bool change = false;
    long long diff = (now - last_time).count();
    if (diff >= ns_interval) {
      change = true;
      last_time = now;
    }

    int i = 0;
    for (auto& pipe : pipes) {
      // bind pipes to the same socket
      if (change) {
        if (i % 2 == 0) {
          pipe->Bind(kDstPort, 0, dst_ip_1, 0, kProtocol);
        } else {
          pipe->Bind(kDstPort, 0, dst_ip_2, 0, kProtocol);
        }
        i++;
      }
    }
  }
  return NULL;
}

void* run_experiment(void* arg) {
  struct EchoArgs* args = (struct EchoArgs*)arg;
  uint32_t core_id = args->core_id;
  uint32_t nb_cycles = args->nb_cycles;
  enso::stats_t* stats = args->stats;
  uint32_t application_id = args->application_id;
  uint32_t nb_queues = args->nb_queues;

  enso::set_self_core_id(core_id);

  usleep(1000000);

  std::cout << "Running on core " << sched_getcpu() << std::endl;

  using enso::Device;
  using enso::RxPipe;
  using std::chrono;

  std::unique_ptr<Device> dev = Device::Create(application_id, NULL);
  if (!dev) {
    std::cerr << "Problem creating device" << std::endl;
    exit(2);
  }
  std::vector<RxPipe*> pipes;

  for (uint32_t i = 0; i < nb_queues; ++i) {
    RxPipe* pipe = dev->AllocateRxPipe();
    if (!pipe) {
      std::cerr << "Problem creating RX/TX pipe" << std::endl;
      exit(3);
    }
    uint32_t dst_ip = kBaseIpAddress + core_id * nb_queues + i;
    pipe->Bind(kDstPort, 0, dst_ip, 0, kProtocol);

    pipes.push_back(pipe);
  }

  setup_done = true;

  while (keep_running) {
    for (auto& pipe : pipes) {
      auto batch = pipe->RecvPkts();

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

      pipe->Clear();
    }
  }
  return NULL;
}

int main(int argc, const char* argv[]) {
  if (argc != 5) {
    std::cerr << "Usage: " << argv[0] << " NB_CORES NB_QUEUES NB_CYCLES"
              << std::endl
              << std::endl;
    std::cerr << "NB_CORES: Number of cores to use." << std::endl;
    std::cerr << "NB_CYCLES: Number of cycles to busy loop when processing each"
                 " packet."
              << std::endl;
    std::cerr << "APPLICATION_ID: Count of number of applications started "
                 "before this application, starting from 0."
              << std::endl;
    std::cerr
        << "NS_INTERVAL: Time between each configuration update in nanoseconds."
        << std::endl;
    return 1;
  }

  uint32_t nb_cores = atoi(argv[1]);
  uint32_t nb_cycles = atoi(argv[2]);
  uint32_t application_id = atoi(argv[3]);
  uint32_t ns_interval = atoi(argv[4]);

  signal(SIGINT, int_handler);

  std::vector<pthread_t> threads;
  std::vector<enso::stats_t> thread_stats(nb_cores);

  uint32_t nb_queues = 2;

  pthread_t thread;
  struct ConfigArgs args;
  args.nb_queues = nb_queues;
  args.ns_interval = ns_interval;
  args.core_id = nb_cores;
  pthread_create(&thread, NULL, change_config, (void*)&args);
  threads.push_back(thread);

  for (uint32_t core_id = 0; core_id < nb_cores; ++core_id) {
    pthread_t thread;
    struct EchoArgs args;
    args.core_id = core_id;
    args.nb_cycles = nb_cycles;
    args.stats = &(thread_stats[core_id]);
    args.application_id = application_id;
    args.nb_queues = nb_queues;
    pthread_create(&thread, NULL, run_experiment, (void*)&args);
    threads.push_back(thread);
    usleep(100000);
  }

  while (!setup_done) continue;  // Wait for setup to be done.

  show_stats(thread_stats, &keep_running);

  for (auto& thread : threads) {
    pthread_join(thread, NULL);
  }

  return 0;
}
