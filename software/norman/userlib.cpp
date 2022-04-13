#include "userlib.h"
#include "pcie.h"

#include <assert.h>
#include <iostream>

#include <rte_ethdev.h>

namespace norman {

// From pcie.cpp. TODO(natre): De-duplicate.
static int get_hugepage_fd(const std::string path, size_t size) {
    int fd = open(path.c_str(), O_CREAT | O_RDWR, S_IRWXU);
    if (fd == -1) {
        std::cerr << "(" << errno
                  << ") Problem opening huge page file descriptor" << std::endl;
        assert(false);
    }
    if (ftruncate(fd, (off_t) size)) {
        std::cerr << "(" << errno << ") Could not truncate huge page to size: "
                  << size << std::endl;
        close(fd);
        unlink(path.c_str());
        assert(false);
    }
    return fd;
}

// From pcie.cpp. TODO(natre): De-duplicate.
static uint64_t virt_to_phys(void* virt) {
    long pagesize = sysconf(_SC_PAGESIZE);
    int fd = open("/proc/self/pagemap", O_RDONLY);
    if (fd < 0) {
        return 0;
    }
    // pagemap is an array of pointers for each normal-sized page
    if (lseek(fd, (uintptr_t) virt / pagesize * sizeof(uintptr_t),
            SEEK_SET) < 0) {
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
    // bits 0-54 are the page number
    return (uint64_t) ((phy & 0x7fffffffffffffULL) * pagesize
                       + ((uintptr_t) virt) % pagesize);
}

/**
 * SpeculativeRingBufferMemoryAllocator implementation.
 */
void SpeculativeRingBufferMemoryAllocator::initialize(
    const int buffer_fd, const uint64_t buffer_size) {
    assert(buffer_vaddr_ == nullptr); // Sanity check

    // Initialize the virtual addrspace
    buffer_vaddr_ = (void*) mmap(NULL, buffer_size * 2,
        PROT_READ | PROT_WRITE, MAP_SHARED | MAP_HUGETLB, buffer_fd, 0);

    if (buffer_vaddr_ == (void*) -1) {
        std::cerr << "(" << errno << ") Could not mmap huge page" << std::endl;
        close(buffer_fd);
        assert(false);
    }

    // Re-map the second half of the virtual addrspace onto the buffer
    void* ret = (void*) mmap((uint8_t*) buffer_vaddr_ + buffer_size, buffer_size,
        PROT_READ | PROT_WRITE, MAP_FIXED | MAP_SHARED | MAP_HUGETLB, buffer_fd, 0);

    if (ret == (void*) -1) {
        std::cerr << "(" << errno << ") Could not mmap second huge page" << std::endl;
        free(buffer_vaddr_);
        close(buffer_fd);
        assert(false);
    }

    if (mlock(buffer_vaddr_, buffer_size)) {
        std::cerr << "(" << errno << ") Could not lock huge page" << std::endl;
        munmap(buffer_vaddr_, buffer_size);
        close(buffer_fd);
        assert(false);
    }
    close(buffer_fd);

    // Initialize the other parameters
    kMaxBufferSize = buffer_size;
    free_capacity_ = buffer_size;
    buffer_paddr_ = virt_to_phys(buffer_vaddr_);
}

void SpeculativeRingBufferMemoryAllocator::commit_alloc() {
    if (likely(spec_alloc_size_ != 0)) {
        assert(free_capacity_ >= spec_alloc_size_);
        free_capacity_ -= spec_alloc_size_; // Update capacity
        alloc_offset_ = (alloc_offset_ + spec_alloc_size_) % kMaxBufferSize;
        spec_alloc_size_ = 0;
    }
}

void* SpeculativeRingBufferMemoryAllocator::allocate(const uint64_t size) {
    commit_alloc(); // Commit the outstanding alloc (if any)

    if (unlikely(free_capacity_ < size)) { return nullptr; } // OOM
    spec_alloc_size_ = size; // Update the speculative alloc size
    return static_cast<char*>(buffer_vaddr_) + alloc_offset_;
}

void SpeculativeRingBufferMemoryAllocator::
allocate_shrink(const uint64_t shrink_to) {
    assert(shrink_to <= spec_alloc_size_);
    spec_alloc_size_ = shrink_to;
}

void SpeculativeRingBufferMemoryAllocator::deallocate(const uint64_t size) {
    // If dealloc causes the free capacity to exceed the max buffer size, then
    // it must be the case that the last speculative alloc was never committed.
    // A special case arises when then the memory to be deallocated is exactly
    // equal to the total allocated memory (including speculation). Here, we
    // also need to quash the speculative alloc since it musn't be committed.
    const size_t spec_capacity = (free_capacity_ + size - spec_alloc_size_);
    if (unlikely(spec_capacity >= kMaxBufferSize)) {
        assert(spec_capacity == kMaxBufferSize);
        free_capacity_ = kMaxBufferSize;
        dealloc_offset_ = alloc_offset_;
        spec_alloc_size_ = 0;
    }
    else {
        free_capacity_ += size;
        assert(free_capacity_ <= kMaxBufferSize); // Sanity check
        dealloc_offset_ = (dealloc_offset_ + size) % kMaxBufferSize;
    }
}

uint64_t SpeculativeRingBufferMemoryAllocator::to_phys_addr(const void* vaddr) const {
    // Compute offset relative to the base vaddr
    uint64_t offset = ((static_cast<const char*>(vaddr) -
                        static_cast<const char*>(buffer_vaddr_)) % kMaxBufferSize);

    return buffer_paddr_ + offset;
}

/**
 * TXPacketQueueManager implementation.
 */
void TXPacketQueueManager::initialize(
    const int pd_ring_fd, const uint64_t pd_ring_size) {
    pd_allocator_.initialize(pd_ring_fd, pd_ring_size);
}

void* TXPacketQueueManager::alloc(const uint64_t size) {
    return pd_allocator_.allocate(size);
}

void TXPacketQueueManager::alloc_shrink(const uint64_t to_size) {
    pd_allocator_.allocate_shrink(to_size);
}

void TXPacketQueueManager::dealloc(const uint64_t num_bytes) {
    pd_allocator_.deallocate(num_bytes);
}

/**
 * Socket implementation.
 */
int Socket::initialize(std::string hp_prefix, const int num_queues,
                       const uint8_t sg_idx) {
    socket_fd_ = norman::socket(AF_INET, SOCK_DGRAM, num_queues);
    if (socket_fd_ == -1) { return -1; }
    sg_idx_ = sg_idx;

    // TODO(natre): Hack, figure out how to do this properly
    const size_t txpd_size = kHugePageSize;
    hp_prefix += ":" + std::to_string(sg_idx);
    const auto txpd_hp_path = hp_prefix + "_txpd";
    int txpd_fd = get_hugepage_fd(txpd_hp_path, txpd_size);

    // Initialize the TX queue manager
    tx_manager_.initialize(txpd_fd, txpd_size);

    // Clean up
    unlink(txpd_hp_path.c_str());

    return socket_fd_;
}

bool Socket::bind(const struct sockaddr *addr, socklen_t addrlen) {
    return norman::bind(socket_fd_, addr, addrlen);
}

void Socket::send_zc(const PacketBuffer* buffer,
    TxCompletionQueueManager& txcq_manager) {
    if (unlikely(buffer->get_length() == 0)) { return; }

    // Fetch the paddr corresponding to this group
    auto& txpd_allocator = tx_manager_.pd_allocator_;
    uint64_t start_paddr = (txpd_allocator.to_phys_addr(
        static_cast<const void*>(buffer->get_data())));

    norman::send(socket_fd_, (void*) start_paddr,
                 buffer->get_length(), 0);

    // Enque an event into the TXCQ
    txcq_manager.enque_event(
        TxCompletionEvent(sg_idx_, buffer->get_length()));
}

size_t Socket::recv_zc(PacketBuffer* buffer) {
    // Sanit checks
    assert(likely(buffer->get_length() == 0));
    assert(likely(buffer->get_data() == nullptr));
    assert(likely(buffer->get_num_packets() == 0));

    // Read data from the NIC
    void* read_addr = nullptr;
    size_t read_size = norman::recv_zc(
        socket_fd_, &read_addr, kRecvSize, 0);

    // Update the buffer state and return
    buffer->set(read_addr, read_size);
    return read_size;
}

void Socket::done_recv(const PacketBuffer* buffer) {
    if (likely(buffer->get_length() != 0)) { // Advance tail pointer
        norman::free_pkt_buf(socket_fd_, buffer->get_length());
    }
}

/**
 * TxCompletionQueueManager implementation.
 */
TxCompletionEvent TxCompletionQueueManager::deque_event() {
    assert(num_outstanding_ > 0); // Sanity check
    num_outstanding_--;
    free_capacity_++;

    TxCompletionEvent event = events_[dealloc_idx_++];
    if (dealloc_idx_ == kMaxNumEvents) {
        dealloc_idx_ = 0;
    }
    return event;
}

void TxCompletionQueueManager::enque_event(TxCompletionEvent event) {
    assert(free_capacity_ > 0); // Sanity check
    events_[alloc_idx_++] = event;
    if (alloc_idx_ == kMaxNumEvents) {
        alloc_idx_ = 0;
    }
    num_outstanding_++;
    free_capacity_--;
}

/**
 * SocketGroup implementation.
 */
uint8_t SocketGroup::add_socket(const int num_queues) {
    if (num_active_sockets_ == kMaxNumSockets) { // Sanity check
        std::cerr << "Max socket count exceeded" << std::endl;
        assert(false);
    }
    uint8_t sg_idx = num_active_sockets_++;
    int fd = sockets_[sg_idx].initialize(hp_prefix_, num_queues, sg_idx);
    if (fd == -1) {
        std::cerr << "Error creating socket" << std::endl;
        assert(false);
    }

    return sg_idx;
}

void SocketGroup::send_zc(uint8_t sg_idx, const PacketBuffer* buffer) {
    assert(sg_idx < num_active_sockets_); // Sanity check
    sockets_[sg_idx].send_zc(buffer, txcq_manager_);

    // Fetch TX completions
    uint32_t tx_completions = (
        norman::get_completions(sockets_[sg_idx].get_fd()));

    uint32_t count = 0;
    while (count < tx_completions) {
        auto event = txcq_manager_.deque_event();
        Socket& socket = sockets_[event.get_sg_idx()];
        socket.get_tx_manager().dealloc(event.get_num_bytes());
        count++;
    }
}

void SocketGroup::done_recv(uint8_t sg_idx, const PacketBuffer* buffer) {
    assert(sg_idx < num_active_sockets_); // Sanity check
    return sockets_[sg_idx].done_recv(buffer);
}

size_t SocketGroup::recv_zc(uint8_t sg_idx, PacketBuffer* buffer) {
    assert(sg_idx < num_active_sockets_); // Sanity check
    return sockets_[sg_idx].recv_zc(buffer);
}

Socket& SocketGroup::get_socket(const uint8_t sg_idx) {
    assert(sg_idx < num_active_sockets_); // Sanity check
    return sockets_[sg_idx];
}

} // namespace norman
