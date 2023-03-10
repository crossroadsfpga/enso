/*
 * Copyright (c) 2017, Paul Emmerich
 * Copyright (c) 2023, Hugo Sadok
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     1. Redistributions of source code must retain the above copyright notice,
 *        this list of conditions and the following disclaimer.
 *
 *     2. Redistributions in binary form must reproduce the above copyright
 *        notice, this list of conditions and the following disclaimer in the
 *        documentation and/or other materials provided with the distribution.
 *
 *     3. Neither the name of the copyright holder nor the names of its
 *        contributors may be used to endorse or promote products derived from
 *        this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * @file
 * @brief Helper functions adapted from the
 *        [ixy driver](https://github.com/emmericp/ixy/blob/master/src/memory.c)
 */

#include <enso/consts.h>
#include <enso/ixy_helpers.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#include <cstdint>
#include <cstdio>
#include <iostream>
#include <string>

namespace enso {

#ifdef MOCK
uint64_t virt_to_phys(void *virt) {
  return virt;
}
#else
uint64_t virt_to_phys(void* virt) {

  long page_size = sysconf(_SC_PAGESIZE);
  int fd = open("/proc/self/pagemap", O_RDONLY);

  if (fd < 0) {
    return 0;
  }

  // Pagemap is an array of pointers for each normal-sized page.
  off_t offset = (uintptr_t)virt / page_size * sizeof(uintptr_t);
  if (lseek(fd, offset, SEEK_SET) < 0) {
    close(fd);
    return 0;
  }

  uintptr_t phy = 0;
  if (read(fd, &phy, sizeof(phy)) < 0) {
    close(fd);
    return 0;
  }
  close(fd);

  if (!phy) {
    return 0;
  }

  // Bits 0-54 are the page number.
  return (uint64_t)((phy & 0x7fffffffffffffULL) * page_size +
                    ((uintptr_t)virt) % page_size);
}
#endif

void* get_huge_page(const std::string& name, bool mirror) {
  int fd;
  char huge_pages_path[128];
  constexpr uint32_t kSize = kBufPageSize;

  snprintf(huge_pages_path, sizeof(huge_pages_path), "/mnt/huge/%s",
           name.c_str());

  fd = open(huge_pages_path, O_CREAT | O_RDWR, S_IRWXU);
  if (fd == -1) {
    std::cerr << "(" << errno << ") Problem opening huge page file descriptor"
              << std::endl;
    return nullptr;
  }

  if (ftruncate(fd, (off_t)kSize)) {
    std::cerr << "(" << errno
              << ") Could not truncate huge page to size: " << kSize
              << std::endl;
    close(fd);
    unlink(huge_pages_path);
    return nullptr;
  }

  void* virt_addr = (void*)mmap(nullptr, kSize * 2, PROT_READ | PROT_WRITE,
                                MAP_SHARED | MAP_HUGETLB, fd, 0);

  if (virt_addr == (void*)-1) {
    std::cerr << "(" << errno << ") Could not mmap huge page" << std::endl;
    close(fd);
    unlink(huge_pages_path);
    return nullptr;
  }

  if (mirror) {
    // Allocate same huge page at the end of the last one.
    void* ret =
        (void*)mmap((uint8_t*)virt_addr + kSize, kSize, PROT_READ | PROT_WRITE,
                    MAP_FIXED | MAP_SHARED | MAP_HUGETLB, fd, 0);

    if (ret == (void*)-1) {
      std::cerr << "(" << errno << ") Could not mmap second huge page"
                << std::endl;
      close(fd);
      unlink(huge_pages_path);
      free(virt_addr);
      return nullptr;
    }
  }

  if (mlock(virt_addr, kSize)) {
    std::cerr << "(" << errno << ") Could not lock huge page" << std::endl;
    munmap(virt_addr, kSize);
    close(fd);
    unlink(huge_pages_path);
    return nullptr;
  }

  // Don't keep it around in the hugetlbfs.
  close(fd);
  unlink(huge_pages_path);

  return virt_addr;
}

}  // namespace enso
