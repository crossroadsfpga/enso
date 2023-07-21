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

/**
 * @file
 * @brief Device backend wrapper for Intel FPGAs.
 *
 * @author Hugo Sadok <sadok@cmu.edu>
 */

#ifndef SOFTWARE_SRC_BACKENDS_INTEL_FPGA_DEV_BACKEND_H_
#define SOFTWARE_SRC_BACKENDS_INTEL_FPGA_DEV_BACKEND_H_

#include <enso/helpers.h>

#include "intel_fpga_pcie_api.hpp"

namespace enso {

class DevBackend {
 public:
  static DevBackend* Create(unsigned int bdf, int bar) noexcept {
    DevBackend* dev = new (std::nothrow) DevBackend(bdf, bar);

    if (dev == nullptr) {
      return nullptr;
    }

    if (dev->Init()) {
      delete dev;
      return nullptr;
    }

    return dev;
  }

  ~DevBackend() noexcept {
    if (dev_ != nullptr) {
      delete dev_;
    }
  }

  void* uio_mmap(size_t size, unsigned int mapping) {
    return dev_->uio_mmap(size, mapping);
  }

  static _enso_always_inline void mmio_write32(volatile uint32_t* addr,
                                               uint32_t value) {
    _enso_compiler_memory_barrier();
    *addr = value;
  }

  static _enso_always_inline uint32_t mmio_read32(volatile uint32_t* addr) {
    _enso_compiler_memory_barrier();
    return *addr;
  }

  /**
   * @brief Converts an address in the application's virtual address space to an
   *        address that can be used by the device (typically the physical
   *        address).
   * @param virt_addr Address in the application's virtual address space.
   * @return Address that can be used by the device.
   */
  uint64_t ConvertVirtAddrToDevAddr(void* virt_addr) {
    return virt_to_phys(virt_addr);
  }

 private:
  explicit DevBackend(unsigned int bdf, int bar) noexcept
      : bdf_(bdf), bar_(bar) {}

  DevBackend(const DevBackend& other) = delete;
  DevBackend& operator=(const DevBackend& other) = delete;
  DevBackend(DevBackend&& other) = delete;
  DevBackend& operator=(DevBackend&& other) = delete;

  int Init() noexcept {
    dev_ = intel_fpga_pcie_api::IntelFpgaPcieDev::Create(bdf_, bar_);
    if (dev_ == nullptr) {
      return -1;
    }
    return 0;
  }

  intel_fpga_pcie_api::IntelFpgaPcieDev* dev_;
  unsigned int bdf_;
  int bar_;
};

}  // namespace enso

#endif  // SOFTWARE_SRC_BACKENDS_INTEL_FPGA_DEV_BACKEND_H_
