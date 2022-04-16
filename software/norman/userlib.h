#ifndef USERLIB_H
#define USERLIB_H

#include <cstdint>
#include <cstddef>
#include <string>

#include "socket.h"

namespace norman {

// Macro to generate default methods
#define DEFAULT_CTOR_AND_DTOR(TypeName)     \
  TypeName() = default;                     \
  ~TypeName() = default

// Macro to disallow copy/assignment
#define DISALLOW_COPY_AND_ASSIGN(TypeName)  \
  TypeName(const TypeName&) = delete;       \
  void operator=(const TypeName&) = delete

// Forward declarations
class PacketBuffer;
class SpeculativeRingBufferMemoryAllocator;
class RXPacketQueueManager;
class TXPacketQueueManager;
class Socket;
class TxCompletionEvent;
class TxCompletionQueueManager;
class SocketGroup;

// TODO(natre): Don't hardcode these parameters
static constexpr uint16_t kLogCacheLineSize = 6;
static constexpr size_t kHugePageSize = (2048 * 1024);
static constexpr uint16_t kCacheLineAlignmentMask = (
    ((0xffff) >> kLogCacheLineSize) << kLogCacheLineSize);
static constexpr uint16_t kCacheLineSize = (1 << kLogCacheLineSize);

template<typename T>
T round_to_cache_line_size(const T req_size) {
  return (T) ((req_size + kCacheLineSize - 1) &
               kCacheLineAlignmentMask);
}

/**
 * Implementation of a packet buffer in Norman (modeled on
 * the DPDK `rte_mbuf` struct). Depending on context, this
 * can be used to represent either a single Ethernet frame
 * or a stream of bytes encapsulating multiple frames.
 */
class __attribute__ ((__packed__)) PacketBuffer final {
private:
    size_t len_ = 0; // Length (in bytes) of packet data
    void* data_ = nullptr; // Virtual address of packet data

    // Housekeeping
    uint16_t num_pkts_ = 0; // Number of packets

public:
    DEFAULT_CTOR_AND_DTOR(PacketBuffer);
    explicit PacketBuffer(const size_t len, void* data) :
                          len_(len), data_(data) {}
    // Mutators
    inline void set_length(size_t len) { len_ = len; }
    inline void clear() { num_pkts_ = 0; len_ = 0; data_ = nullptr; }
    inline void append(const size_t len) { num_pkts_ += 1; len_ += len; }
    inline void set(void* data, const size_t len) { num_pkts_ = 1; data_ = data; len_ = len; }

    // Accessors
    inline size_t get_length() const { return len_; }
    inline uint16_t get_num_packets() const { return num_pkts_; }
    inline char* get_data() { return static_cast<char*>(data_); }
    inline const char* get_data() const { return static_cast<const char*>(data_); }
};
static_assert(sizeof(PacketBuffer) == 18,
              "Error: PacketBuffer layout is incorrect");

/**
 * Implementation of a speculative memory allocator that uses a fixed-
 * size ringbuffer as the underlying memory resource. Requires memory
 * to be free'd in the order that it is allocated. Not thread-safe.
 */
class SpeculativeRingBufferMemoryAllocator {
private:
    void* buffer_vaddr_ = nullptr; // Double-mapped virtual addrspace
    uint64_t buffer_paddr_ = 0; // Base paddr of the ringbuffer
    uint64_t kMaxBufferSize = 0; // Physical ringbuffer size

    // Housekeeping
    uint64_t alloc_offset_ = 0; // Allocation offset
    uint64_t free_capacity_ = 0; // Available memory
    uint64_t dealloc_offset_ = 0; // Deallocation offset
    uint64_t spec_alloc_size_ = 0; // Speculatively-allocated memory

    /**
     * Internal helper function to commit outstanding allocs.
     */
    inline void commit_alloc();

public:
    DEFAULT_CTOR_AND_DTOR(SpeculativeRingBufferMemoryAllocator);
    DISALLOW_COPY_AND_ASSIGN(SpeculativeRingBufferMemoryAllocator);

    /**
     * Initialize the memory allocator.
     */
    void initialize(const int buffer_fd, const uint64_t buffer_size);

    /**
     * Speculatively allocates a contiguous region in memory. If the
     * request cannot be satisfied, returns nullptr. Post this point,
     * subsequent calls to allocate_shrink() can be used to truncate
     * (but NOT extend) the allocated memory region. It is also safe
     * to skip this step; a subsequent invocation of deallocate() or
     * allocate() commits the earlier alloc operation.
     */
    void* allocate(const uint64_t size);
    void  allocate_shrink(const uint64_t to_size);

    /**
     * Deallocates blocks of memory. Memory MUST be dealloc'd
     * in the same order that it was originally allocated.
     */
    void deallocate(const uint64_t size);

    /**
     * Given a virtual address in the allocator's addrspace, returns
     * the corresponding physical address.
     */
    uint64_t to_phys_addr(const void* vaddr) const;
};

/**
 * Helper class to manage a socket's RX queue.
 */
class RXPacketQueueManager final {
private:
    // Housekeeping
    char* read_addr_ = nullptr;     // Current address of the read pointer. This
                                    // is the position at which the application
                                    // left off consuming data.
    size_t read_bytes_left_ = 0;    // Number of bytes that can be read from the
                                    // RX buffer without polling the NIC again.
    size_t advanced_bytes_ = 0;     // Number of bytes advanced since the last
                                    // invocation of done().
public:
    DEFAULT_CTOR_AND_DTOR(RXPacketQueueManager);
    DISALLOW_COPY_AND_ASSIGN(RXPacketQueueManager);

    /**
     * Returns a packet buffer containing a single Ethernet frame.
     */
    size_t done();
    PacketBuffer next();
    void prefetch_next() const;

    /**
     * Updates the packet queue state on receiving new RX data
     * from the NIC. Should be invoked whenever recv is called
     * on the corresponding socket.
     */
    void on_recv(char* read_addr, size_t read_bytes);

    // Accessors
    inline char* get_read_addr() const { return read_addr_; }
    inline size_t get_bytes_left() const { return read_bytes_left_; }
};

/**
 * Helper class to manage a socket's TX queue.
 */
class TXPacketQueueManager final {
private:
    SpeculativeRingBufferMemoryAllocator pd_allocator_{};

    /**
     * Initialize the TX packet queue.
     */
    void initialize(const int pd_ring_fd,
                    const uint64_t pd_ring_size);
public:
    DEFAULT_CTOR_AND_DTOR(TXPacketQueueManager);
    DISALLOW_COPY_AND_ASSIGN(TXPacketQueueManager);

    /**
     * Construct a PacketBuffer with the given size.
     */
    void* alloc(const uint64_t size);
    void alloc_shrink(const uint64_t to_size);
    inline void alloc_squash() { return alloc_shrink(0); }

    /**
     * Updates the packet queue state on TX events.
     */
    void dealloc(const uint64_t num_bytes);

    friend Socket;
};

/**
 * Represents a Norman socket.
 */
class Socket final {
public:
    // TODO(natre): Don't hardcode this
    static constexpr size_t kRecvSize = 10000000;

private:
    uint8_t sg_idx_ = 0; // SocketGroup idx
    int socket_fd_ = -1; // This socket's FD
    RXPacketQueueManager rx_manager_{}; // RX queue manager
    TXPacketQueueManager tx_manager_{}; // TX queue manager

    /**
     * Network interface.
     */
    void send_zc(const PacketBuffer* buffer,
                 TxCompletionQueueManager& txcq_manager);

    size_t read();
    void done_read();

public:
    DEFAULT_CTOR_AND_DTOR(Socket);
    DISALLOW_COPY_AND_ASSIGN(Socket);

    /**
     * Initializes the socket and returns its FD.
     */
    int initialize(const std::string hp_prefix,
                   const int num_queues,
                   const uint8_t sg_idx);

    /**
     * Bind the socket to the given network address.
     */
    bool bind(const struct sockaddr *addr, socklen_t addrlen);

    // Accessors
    inline int get_fd() const { return socket_fd_; }
    inline uint8_t get_sg_idx() const { return sg_idx_; }
    inline RXPacketQueueManager& get_rx_manager() { return rx_manager_; }
    inline TXPacketQueueManager& get_tx_manager() { return tx_manager_; }

    friend SocketGroup;
};


/**
 * Represents a TX completion event.
 */
class __attribute__ ((__packed__)) TxCompletionEvent final {
private:
    size_t num_bytes_ = 0; // Length (in bytes) of the packet data
    uint8_t sg_idx_ = 0; // Socket's index in its SocketGroup
    uint8_t pad[7]{}; // Padding for alignment

public:
    TxCompletionEvent() = default;
    explicit TxCompletionEvent(uint8_t sg_idx, size_t num_bytes) :
                               num_bytes_(num_bytes), sg_idx_(sg_idx) {}
    // Accessors
    inline uint8_t get_sg_idx() const { return sg_idx_; }
    inline size_t get_num_bytes() const { return num_bytes_; }

    // Mutators
    inline void set_sg_idx(uint8_t sg_idx) { sg_idx_ = sg_idx; }
    inline void set_num_bytes(size_t num_bytes) { num_bytes_ = num_bytes; }
};
static_assert(sizeof(TxCompletionEvent) == 16,
              "Error: TxCompletionEvent layout is incorrect");

/**
 * Helper class to manage a SocketGroup's TX completion queue.
 */
class TxCompletionQueueManager final {
private:
    static constexpr size_t kMaxNumEvents = (
        MAX_PENDING_TX_REQUESTS + 1);

    // Housekeeping
    size_t alloc_idx_ = 0;
    size_t dealloc_idx_ = 0;
    size_t num_outstanding_ = 0;
    size_t free_capacity_ = kMaxNumEvents;
    TxCompletionEvent events_[kMaxNumEvents]{};

public:
    DEFAULT_CTOR_AND_DTOR(TxCompletionQueueManager);
    DISALLOW_COPY_AND_ASSIGN(TxCompletionQueueManager);

    /**
     * Deques the next completion event.
     */
    TxCompletionEvent deque_event();

    /**
     * Enques a new completion event.
     */
    void enque_event(TxCompletionEvent event);

    // Accessors
    inline bool is_event_queue_full() const { return (free_capacity_ == 0); }
    inline bool is_event_queue_empty() const { return (num_outstanding_ == 0); }
};

/**
 * Represents a (per-core) group of Norman sockets.
 */
class SocketGroup final {
private:
    static constexpr uint8_t kMaxNumSockets = 255;

    // Housekeeping
    const std::string hp_prefix_;
    uint8_t num_active_sockets_ = 0;
    Socket sockets_[kMaxNumSockets]{};
    TxCompletionQueueManager txcq_manager_{};

public:
    DISALLOW_COPY_AND_ASSIGN(SocketGroup);
    explicit SocketGroup(const std::string hp_prefix) :
                         hp_prefix_(hp_prefix) {}
    /**
     * Adds a new socket to this group.
     */
    uint8_t add_socket(const int num_queues);

    /**
     * Network interface.
     */
    size_t read(uint8_t sg_idx);
    void done_read(uint8_t sg_idx);
    void send_zc(uint8_t sg_idx, const PacketBuffer* buffer);

    // Accessors
    Socket& get_socket(const uint8_t sg_idx);
    uint8_t get_num_active_sockets() const { return num_active_sockets_; }
};

#undef DISALLOW_COPY_AND_ASSIGN
#undef DEFAULT_CTOR_AND_DTOR
} // namespace norman

#endif // USERLIB_H
