#include "userlib.h"
#include "pcie.h"

#include <assert.h>
#include <iostream>

#include <rte_ethdev.h>

namespace norman {

// From pcie.cpp. TODO(natre): De-duplicate.
static int get_hugepage_fd(const std::string path, size_t size) {
    int fd = open(path.c_str(), O_RDWR, S_IRWXU);
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
 * PacketBufferGroup implementation.
 */
size_t PacketBufferGroup::append(PacketBuffer* buffer) {
    assert(!is_full()); // Sanity check

    size_t eth_size = round_to_cache_line_size(buffer->get_length());
    buffers_[num_valid_++] = buffer;
    total_bytes_ += eth_size;
    return eth_size;
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
    commit_alloc(); // Commit the outstanding alloc (if any)

    free_capacity_ += size;
    assert(free_capacity_ <= kMaxBufferSize); // Sanity check
    dealloc_offset_ = (dealloc_offset_ + size) % kMaxBufferSize;
}

uint64_t SpeculativeRingBufferMemoryAllocator::to_phys_addr(void* vaddr) const {
    // Compute offset relative to the base vaddr
    uint64_t offset = ((static_cast<char*>(vaddr) -
                        static_cast<char*>(buffer_vaddr_)) % kMaxBufferSize);

    return buffer_paddr_ + offset;
}

/**
 * RXPacketQueueManager implementation.
 */
void RXPacketQueueManager::initialize(
    const int pb_ring_fd, const uint64_t pb_ring_size) {
    pb_allocator_.initialize(pb_ring_fd, pb_ring_size);
}

uint16_t RXPacketQueueManager::consume_packetized(PacketBufferGroup& group) {
    assert(group.is_empty()); // Sanity check
    assert(last_consume_bytes_ == 0);

    // Satisfy as much of the request as possible using previously-read bytes
    while (!group.is_full() && read_bytes_left_ > 0) {
        auto pb = static_cast<PacketBuffer*>(
            pb_allocator_.allocate(sizeof(PacketBuffer)));

        if (unlikely(pb == nullptr)) { break; } // OOM, return immediately
        const rte_ipv4_hdr* hdr = (reinterpret_cast<const rte_ipv4_hdr*>(
                                   read_addr_ + sizeof(rte_ether_hdr)));

        uint16_t eth_size = static_cast<uint16_t>(
            rte_be_to_cpu_16(hdr->total_length) +
            static_cast<uint16_t>(sizeof(rte_ether_hdr)));

        eth_size = group.append(new (pb) PacketBuffer(eth_size, read_addr_));
        assert(read_bytes_left_ >= eth_size);
        last_consume_bytes_ += eth_size;
        read_bytes_left_ -= eth_size;
        read_addr_ += eth_size;
    }
    // Return the number of packets parsed
    return group.get_num_valid_buffers();
}

void RXPacketQueueManager::release(const PacketBufferGroup& group) {
    pb_allocator_.deallocate(group.get_num_valid_buffers() *
                             sizeof(PacketBuffer));

    assert(group.get_byte_count() == last_consume_bytes_);
    last_consume_bytes_ = 0;
}

void RXPacketQueueManager::on_recv(char* read_addr, size_t read_bytes) {
    // Update the read address and the last ready bytes
    assert(read_bytes_left_ == 0); // Sanity check
    read_bytes_left_ = read_bytes;
    read_addr_ = read_addr;
}

/**
 * TXPacketQueueManager implementation.
 */
void TXPacketQueueManager::initialize(
    const int pb_ring_fd, const uint64_t pb_ring_size,
    const int pd_ring_fd, const uint64_t pd_ring_size) {
    // Initialize both ringbuffer memory allocators
    pb_allocator_.initialize(pb_ring_fd, pb_ring_size);
    pd_allocator_.initialize(pd_ring_fd, pd_ring_size);
}

PacketBuffer* TXPacketQueueManager::alloc(const uint64_t size) {
    auto pb = static_cast<PacketBuffer*>(
        pb_allocator_.allocate(sizeof(PacketBuffer)));
    if (unlikely(pb == nullptr)) { return nullptr; } // OOM

    auto data = pd_allocator_.allocate(size);
    if (unlikely(data == nullptr)) { // OOM on data alloc
        pb_allocator_.deallocate(sizeof(PacketBuffer));
        return nullptr;
    }
    pb->set_length(size);
    pb->set_data(data);
    return pb;
}

void TXPacketQueueManager::alloc_shrink(
    PacketBuffer* buffer, const uint64_t to_size) {
    pd_allocator_.allocate_shrink(to_size);
    // buffer->set_length(to_size);
}

void TXPacketQueueManager::alloc_squash() {
    pb_allocator_.allocate_shrink(0);
    pd_allocator_.allocate_shrink(0);
}

void TXPacketQueueManager::dealloc(const uint64_t num_pktbufs,
                                   const uint64_t num_bytes) {
    pb_allocator_.deallocate(num_pktbufs * sizeof(PacketBuffer));
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
    hp_prefix += ":" + std::to_string(sg_idx);
    const auto rxpb_hp_path = hp_prefix + "_rxpb";
    const auto txpb_hp_path = hp_prefix + "_txpb";
    const auto txpd_hp_path = hp_prefix + "_txpd";

    const size_t rxpb_size = kHugePageSize;
    const size_t txpb_size = kHugePageSize;
    const size_t txpd_size = (1 << 24);

    int rxpb_fd = get_hugepage_fd(rxpb_hp_path, rxpb_size);
    int txpb_fd = get_hugepage_fd(txpb_hp_path, txpb_size);
    int txpd_fd = get_hugepage_fd(txpd_hp_path, txpd_size);

    // Initialize the RX and TX queue managers
    rx_manager_.initialize(rxpb_fd, rxpb_size);
    tx_manager_.initialize(txpb_fd, txpb_size, txpd_fd, txpd_size);

    // Clean up
    unlink(rxpb_hp_path.c_str());
    unlink(txpb_hp_path.c_str());
    unlink(txpd_hp_path.c_str());

    return socket_fd_;
}

bool Socket::bind(const struct sockaddr *addr, socklen_t addrlen) {
    return norman::bind(socket_fd_, addr, addrlen);
}

void Socket::send_zc(const PacketBufferGroup& group,
    TxCompletionQueueManager& txcq_manager) {
    if (unlikely(group.is_empty())) { return; }

    // Fetch the paddr corresponding to this group
    auto& txpd_allocator = tx_manager_.pd_allocator_;
    uint64_t start_paddr = (txpd_allocator.to_phys_addr(
        group.get_buffers()[0]->get_data()));

    norman::send(socket_fd_, (void*) start_paddr,
                 group.get_byte_count(), 0);

    // Enque an event into the TXCQ
    txcq_manager.enque_event(
        TxCompletionEvent(sg_idx_, group.get_byte_count(),
                          group.get_num_valid_buffers()));
}

uint16_t Socket::recv_zc(PacketBufferGroup& group) {
    // If required, read new data from the NIC
    if (rx_manager_.get_bytes_left() == 0) {
        void* read_addr = nullptr;
        size_t read_size = norman::recv_zc(
            socket_fd_, &read_addr, kRecvSize, 0);

        rx_manager_.on_recv(
            static_cast<char*>(read_addr), read_size);
    }
    // Use previously-read bytes to satisfy the request
    return rx_manager_.consume_packetized(group);
}

void Socket::done_recv(const PacketBufferGroup& group) {
    rx_manager_.release(group); // Release packet buffers
    if (likely(!group.is_empty())) { // Advance tail pointer
        norman::free_pkt_buf(socket_fd_, group.get_byte_count());
    }
}

/**
 * TxCompletionQueueManager implementation.
 */
TxCompletionEvent TxCompletionQueueManager::deque_event() {
    assert(num_outstanding_ > 0); // Sanity check
    num_outstanding_--;
    free_capacity_++;

    return events_[dealloc_idx_++];
}

void TxCompletionQueueManager::enque_event(TxCompletionEvent event) {
    assert(free_capacity_ > 0); // Sanity check
    events_[alloc_idx_++] = event;
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

void SocketGroup::send_zc(uint8_t sg_idx, const PacketBufferGroup& group) {
    assert(sg_idx < num_active_sockets_); // Sanity check
    sockets_[sg_idx].send_zc(group, txcq_manager_);

    // Fetch TX completions
    uint32_t tx_completions = (
        norman::get_completions(sockets_[sg_idx].get_fd()));

    uint32_t count = 0;
    while (count < tx_completions) {
        auto event = txcq_manager_.deque_event();
        Socket& socket = sockets_[event.get_sg_idx()];
        socket.get_tx_manager().dealloc(event.get_num_pktbufs(),
                                        event.get_num_bytes());
        count++;
    }
}

void SocketGroup::done_recv(uint8_t sg_idx, const PacketBufferGroup& group) {
    assert(sg_idx < num_active_sockets_); // Sanity check
    return sockets_[sg_idx].done_recv(group);
}

uint16_t SocketGroup::recv_zc(uint8_t sg_idx, PacketBufferGroup& group) {
    assert(sg_idx < num_active_sockets_); // Sanity check
    return sockets_[sg_idx].recv_zc(group);
}

Socket& SocketGroup::get_socket(const uint8_t sg_idx) {
    assert(sg_idx < num_active_sockets_); // Sanity check
    return sockets_[sg_idx];
}

} // namespace norman
