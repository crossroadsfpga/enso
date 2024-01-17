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

#ifndef ENSO_SOFTWARE_INCLUDE_ENSO_IXY_HELPERS_H_
#define ENSO_SOFTWARE_INCLUDE_ENSO_IXY_HELPERS_H_

#include <cstdint>
#include <string>

namespace enso {

/**
 * Converts a virtual address to a physical address.
 *
 * @param virt The virtual address to convert.
 * @return The physical address.
 */
uint64_t virt_to_phys(void* virt);

/**
 * Allocates a huge page and returns a pointer to it.
 *
 * Huge pages are allocated to be `kBufPageSize` bytes in size.
 *
 * @param path Path to huge page file.
 * @param size The size of the huge page to be allocated. If 0, defaults to
 *            `kBufPageSize`.
 * @param mirror Whether to mirror the huge page or not. Mirroring means that
 *               the same page is mapped again right after the allocated memory.
 *               This is useful to handle wrap-around in the buffers. Defaults
 *               to false.
 * @return A pointer to the allocated huge page.
 */
void* get_huge_page(const std::string& path, size_t size = 0,
                    bool mirror = false);

}  // namespace enso

#endif  // ENSO_SOFTWARE_INCLUDE_ENSO_IXY_HELPERS_H_
