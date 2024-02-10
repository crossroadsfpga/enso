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
 * @brief Helper queue for inter-thread communication.
 *
 * @author Hugo Sadok <sadok@cmu.edu>
 */

#ifndef ENSO_SOFTWARE_INCLUDE_ENSO_QUEUE_H_
#define ENSO_SOFTWARE_INCLUDE_ENSO_QUEUE_H_

#include <enso/consts.h>
#include <enso/helpers.h>
#include <sys/mman.h>
#include <unistd.h>

#include <cstdint>
#include <cstring>
#include <filesystem>
#include <iostream>
#include <memory>
#include <optional>
#include <string>

namespace enso {

// This implementation assumes AVX512.
#ifndef __AVX512F__
#error "Need support for AVX512F to use Queue."
#endif  // __AVX512F__

template <typename T>
static constexpr T align_cache_power_two(T value) {
  T cache_aligned = (value + kCacheLineSize - 1) & ~(kCacheLineSize - 1);
  T power_two = 1;
  while (power_two < cache_aligned) {
    power_two <<= 1;
  }
  return power_two;
}

/**
 * @brief Queue parent class.
 *
 * Use this queue to communicate between different threads. It should be
 * instantiated using either the QueueConsumer or QueueProducer classes through
 * the Create method.
 *
 * Example:
 *   // Producer.
 *   std::unique_ptr<QueueProducer<int>> queue_producer =
 *     QueueProducer<int>::Create("queue_name");
 *
 *   // Consumer.
 *   std::unique_ptr<QueueConsumer<int>> queue_consumer =
 *      QueueConsumer<int>::Create("queue_name");
 *
 *   queue_producer->Push(42);
 *
 *   int data = queue_consumer->Pop().value_or(-1);
 *   std::cout << data << std::endl;  // Should print 42.
 *
 *   data = queue_consumer->Pop().value_or(-1);
 *   std::cout << data << std::endl;  // Should print -1.
 */
template <typename T, typename Subclass>
class Queue {
 public:
  static constexpr size_t kElementMetaSize = sizeof(T) + 8;
  static constexpr size_t kElementPadding =
      align_cache_power_two(kElementMetaSize) - kElementMetaSize;

  struct alignas(kCacheLineSize) Element {
    uint64_t signal;
    T data;
  };

  static_assert(sizeof(Element) == kCacheLineSize,
                "Element must fit in a cache line");

  static_assert((sizeof(Element) & (sizeof(Element) - 1)) == 0,
                "Element size must be a power of two");

  ~Queue() noexcept {
    if (buf_addr_ != nullptr) {
      munmap(buf_addr_, size_);
      if (created_queue_) {
        unlink(huge_page_path_.c_str());
      }
    }
  }

  Queue(Queue&& other) = default;
  Queue& operator=(Queue&& other) = default;

  /**
   * @brief Factory method to create a Queue object.
   *
   * @param queue_name Global queue name.
   * @param size Size of the queue (in bytes). If zero (default), the size will
   *        be inferred if the queue already exists and will be set to
   *        kBufPageSize otherwise.
   * @param join_if_exists If true (default), the queue will be joined if it
   *       already exists. If false, the creation will fail if the queue already
   *       exists.
   * @param huge_page_prefix Prefix to use when creating the shared memory
   *       file. If empty (default), the default prefix will be used.
   * @return A unique pointer to the object or nullptr if the creation fails.
   */
  static std::unique_ptr<Subclass> Create(
      const std::string& queue_name, uint32_t core_id = 0, size_t size = 0,
      bool join_if_exists = true, std::string huge_page_prefix = "") noexcept {
    if (huge_page_prefix == "") {
      huge_page_prefix = kHugePageDefaultPrefix;
    }

    std::unique_ptr<Subclass> queue(new (std::nothrow) Subclass(
        queue_name, core_id, size, huge_page_prefix));

    if (queue == nullptr) {
      return std::unique_ptr<Subclass>{};
    }

    if (queue->Init(join_if_exists)) {
      return std::unique_ptr<Subclass>{};
    }

    return queue;
  }

  /**
   * @brief Returns the address of the internal buffer.
   * @return The address of the internal buffer.
   */
  inline Element* buf_addr() const noexcept { return buf_addr_; }

  /**
   * @brief Returns the size of the internal buffer.
   * @return The size of the internal buffer.
   */
  inline size_t size() const noexcept { return size_; }

  /**
   * @brief Returns the capacity of the queue.
   * @return The capacity of the queue in number of elements.
   */
  inline uint32_t capacity() const noexcept { return capacity_; }

  static_assert(std::is_trivially_copyable<T>::value,
                "T must be trivially copyable");

 protected:
  explicit Queue(const std::string& queue_name, size_t size,
                 const std::string& huge_page_prefix) noexcept
      : size_(size),
        queue_name_(queue_name),
        huge_page_prefix_(huge_page_prefix) {}

  /**
   * @brief Initializes the Queue object.
   *
   * @param join_if_exists If true, the queue will be joined if it already
   *        exists. If false, the creation will fail if the queue already
   *        exists.
   * @return 0 on success and a non-zero error code on failure.
   */
  int Init(bool join_if_exists) noexcept {
    if (size_ == 0) {
      size_ = kBufPageSize;
    }

    if ((size_ & (size_ - 1)) != 0) {
      std::cerr << "Queue size must be a power of two" << std::endl;
      return -1;
    }

    if (size_ < sizeof(struct Element)) {
      std::cerr << "Queue size must be at least " << sizeof(struct Element)
                << " bytes" << std::endl;
      return -1;
    }

    capacity_ = size_ / sizeof(struct Element);
    index_mask_ = capacity_ - 1;

    // Keep path so that we can unlink it later if needed.
    huge_page_path_ =
        huge_page_prefix_ + std::string(kHugePageQueuePathPrefix) + queue_name_;

    // Check if a file starting with huge_page_path_ exists.
    std::filesystem::path path = std::filesystem::path(huge_page_path_);
    std::filesystem::path dir_path = path.parent_path();
    std::string file_name = path.filename();

    bool create_queue = true;
    for (const auto& entry : std::filesystem::directory_iterator(dir_path)) {
      if (!entry.is_regular_file()) {
        continue;
      }

      std::string entry_name = entry.path().filename().string();

      // File starting with file_name exists.
      if (entry_name.find(file_name) == 0) {
        std::string size_str = entry_name.substr(file_name.size());

        // Check if the string is a number.
        if (size_str.find_first_not_of("0123456789") != std::string::npos) {
          std::cerr << "Found existing queue with invalid size: " << size_str
                    << std::endl;
          return -1;
        }

        size_t existing_size = std::stoul(size_str);

        if (existing_size != size_) {
          std::cerr << "Found existing queue with different size: "
                    << existing_size << std::endl;
          return -1;
        }

        create_queue = false;
      }
    }

    if (!join_if_exists && !create_queue) {
      std::cerr << "Queue already exists!!" << std::endl;
      return -1;
    }

    created_queue_ = create_queue;
    huge_page_path_ += std::to_string(size_);

    void* addr = get_huge_page(huge_page_path_, size_);
    if (addr == nullptr) {
      std::cerr << "Failed to allocate shared memory" << std::endl;
      return -1;
    }
    buf_addr_ = reinterpret_cast<Element*>(addr);

    if (create_queue) {
      memset(buf_addr_, 0, size_);
    }

    return 0;
  }

  inline bool created_queue() const noexcept { return created_queue_; }

  inline uint32_t index_mask() const noexcept { return index_mask_; }

 private:
  Queue(const Queue& other) = delete;
  Queue& operator=(const Queue& other) = delete;

  size_t size_;
  uint32_t capacity_;  // In number of elements.
  uint32_t index_mask_;
  Element* buf_addr_ = nullptr;
  std::string huge_page_path_;
  bool created_queue_ = false;
  std::string queue_name_;
  std::string huge_page_prefix_;
};

template <typename T>
class QueueProducer : public Queue<T, QueueProducer<T>> {
 public:
  /**
   * @brief Access the tail from the huge page storing this information.
   *
   */
  inline void AccessTailFromHugePage() { tail_ = *tail_addr_; }

  /**
   * @brief Updates the tail of this queue in case it has been updated.
   *
   */
  inline void UpdateTailInHugePage() { *tail_addr_ = tail_; }

  /**
   * @brief Pushes data to the queue.
   *
   * @param data data to push.
   * @return 0 on success and a non-zero error code on failure.
   */
  inline int Push(const T& data) {
    struct Parent::Element* current_element = &(Parent::buf_addr()[tail_]);
    if (unlikely(current_element->signal)) {
      return -1;  // Queue is full.
    }

    __m512i tmp_element_raw;
    struct Parent::Element* tmp_element =
        (struct Parent::Element*)(&tmp_element_raw);
    tmp_element->signal = 1;
    tmp_element->data = data;

    _mm512_storeu_si512((__m512i*)current_element, tmp_element_raw);

    tail_ = (tail_ + 1) & Parent::index_mask();

    return 0;
  }

 protected:
  explicit QueueProducer(const std::string& queue_name, uint32_t core_id,
                         size_t size,
                         const std::string& huge_page_prefix) noexcept
      : Queue<T, QueueProducer<T>>(queue_name, size, huge_page_prefix),
        core_id_(core_id),
        huge_page_prefix_(huge_page_prefix) {}

  /**
   * @brief Initializes the Queue object.
   *
   * @param join_if_exists If true, the queue will be joined if it already
   *        exists. If false, the creation will fail if the queue already
   *        exists.
   * @return 0 on success and a non-zero error code on failure.
   */
  int Init(bool join_if_exists) noexcept {
    if (Parent::Init(join_if_exists)) {
      return -1;
    }

    if (Parent::created_queue()) {
      return 0;
    }

    // Synchronize the pointer in case the queue is not empty.
    std::string huge_page_path =
        huge_page_prefix_ + std::string(kHugePageQueueTailPathPrefix);
    void* addr = get_huge_page(huge_page_path, 0);
    if (addr == nullptr) {
      std::cerr << "Failed to allocate shared memory for tail" << std::endl;
      return -1;
    }

    tail_addr_ = &reinterpret_cast<uint32_t*>(addr)[core_id_];

    // Synchronize the pointer in case the queue is not empty.
    AccessTailFromHugePage();

    return 0;
  }

 private:
  using Parent = Queue<T, QueueProducer<T>>;
  friend Parent;

  uint32_t tail_ = 0;
  uint32_t* tail_addr_ = nullptr;
  uint32_t core_id_;
  std::string huge_page_prefix_;
};

template <typename T>
class QueueConsumer : public Queue<T, QueueConsumer<T>> {
 public:
  ~QueueConsumer() noexcept {}

  /**
   * @brief Access the head from the huge page storing this information.
   *
   */
  inline void AccessHeadFromHugePage() { head_ = *head_addr_; }

  /**
   * @brief Updates the head of this queue in case it has been updated.
   *
   */
  inline void UpdateHeadInHugePage() { *head_addr_ = head_; }

  /**
   * @brief Returns the data at the front of the queue without popping it.
   *
   * @return the data at the front of the queue on success and nullptr if the
   * queue is empty.
   */
  inline T* Front() {
    struct Parent::Element* current_element = &(Parent::buf_addr()[head_]);
    if (!current_element->signal) {
      return nullptr;  // Queue is empty.
    }
    return &(current_element->data);
  }

  /**
   * @brief Pops data from the queue.
   *
   * @return the data on success and an empty optional if the queue is empty.
   */
  inline std::optional<T> Pop() {
    struct Parent::Element* current_element = &(Parent::buf_addr()[head_]);
    if (!current_element->signal) {
      return {};  // Queue is empty.
    }

    T data = current_element->data;
    current_element->signal = 0;

    head_ = (head_ + 1) & Parent::index_mask();

    return data;
  }

 protected:
  explicit QueueConsumer(const std::string& queue_name, uint32_t core_id,
                         size_t size,
                         const std::string& huge_page_prefix) noexcept
      : Queue<T, QueueConsumer<T>>(queue_name, size, huge_page_prefix),
        core_id_(core_id),
        huge_page_prefix_(huge_page_prefix) {}

  /**
   * @brief Initializes the Queue object.
   *
   * @param join_if_exists If true, the queue will be joined if it already
   *        exists. If false, the creation will fail if the queue already
   *        exists.
   * @return 0 on success and a non-zero error code on failure.
   */
  int Init(bool join_if_exists) noexcept {
    if (Parent::Init(join_if_exists)) {
      return -1;
    }

    if (Parent::created_queue()) {
      return 0;
    }

    // Synchronize the pointer in case the queue is not empty.
    std::string huge_page_path =
        huge_page_prefix_ + std::string(kHugePageQueueHeadPathPrefix);
    void* addr = get_huge_page(huge_page_path, 0);
    if (addr == nullptr) {
      std::cerr << "Failed to allocate shared memory for head" << std::endl;
      return -1;
    }
    head_addr_ = &reinterpret_cast<uint32_t*>(addr)[core_id_];

    // Synchronize the pointer in case the queue is not empty.
    AccessHeadFromHugePage();

    return 0;
  }

 private:
  using Parent = Queue<T, QueueConsumer<T>>;
  friend Parent;

  uint32_t head_ = 0;
  uint32_t* head_addr_ = nullptr;
  uint32_t core_id_;
  std::string huge_page_prefix_;
};

}  // namespace enso

#endif  // ENSO_SOFTWARE_INCLUDE_ENSO_QUEUE_H_
