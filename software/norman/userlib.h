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
class PacketBufferGroup;
class SpeculativeRingBufferMemoryAllocator;
class RXPacketQueueManager;
class TXPacketQueueManager;
class Socket;
class TxCompletionEvent;
class TxCompletionQueueManager;
class SocketGroup;

// TODO(natre): Don't hardcode these parameters
static constexpr uint16_t kLogCacheLineSize = 6;
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

public:
    DISALLOW_COPY_AND_ASSIGN(PacketBuffer);
    explicit PacketBuffer(const size_t len, void* data) :
                          len_(len), data_(data) {}
    // Mutators
    inline void set_data(void* const data) { data_ = data; }
    inline void set_length(const size_t len) { len_ = len; }

    // Accessors
    inline size_t get_length() const { return len_; }
    inline char* get_data() { return static_cast<char*>(data_); }
    inline const char* get_data() const { return static_cast<const char*>(data_); }
};
static_assert(sizeof(PacketBuffer) == 16,
              "Error: PacketBuffer layout is incorrect");

/**
 * Represents a collection of packet buffers. As per Norman
 * semantics, buffers must only be bundled this way if they
 * are: (a) in-order, (b) contiguous, and (c) allocated by
 * either the NIC or the same MemoryAllocator instance.
 */
struct PacketBufferGroup final {
    size_t num_valid_buffers = 0;       // Valid buffer count
    size_t num_total_buffers = 0;       // Maximum buffer count
    PacketBuffer** buffers = nullptr;   // Array of packet buffers
    size_t total_buffer_size_bytes = 0; // Cumulative size of the group
};

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
    uint64_t to_phys_addr(void* vaddr) const;
};

/**
 * Helper class to manage a socket's RX queue.
 */
class RXPacketQueueManager final {
private:
    // PacketBuffer* memory allocator
    SpeculativeRingBufferMemoryAllocator pb_allocator_{};

    // Housekeeping
    char* read_addr_ = nullptr;     // Current address of the read pointer. This
                                    // is the position at which the application
                                    // left off consuming data.
    size_t read_bytes_left_ = 0;    // Number of bytes that can be read from the
                                    // RX buffer without polling the NIC again.
    size_t last_consume_bytes_ = 0; // Number of bytes read by the application
                                    // on the previous invocation of consume()
                                    // (incl padding for cache-line alignment).

    DEFAULT_CTOR_AND_DTOR(RXPacketQueueManager);
    DISALLOW_COPY_AND_ASSIGN(RXPacketQueueManager);

    /**
     * Initialize the RX packet queue.
     */
    void initialize(const int pb_ring_fd, const uint64_t pb_ring_size);

    /**
     * Parses one or more Ethernet frames from the previously-
     * read bytes, and populates the parametrized buffer group
     * with packet data. Returns the number of frames parsed.
     */
    uint16_t consume_packetized(PacketBufferGroup& group);

    /**
     * Constructs and populates a packet buffer from the previously-
     * read bytes. Returns true if the buffer is valid (i.e., filled
     * at least one byte), else false.
     */
    bool consume(PacketBuffer** buffer); // TODO(natre): Impl.

    /**
     * Releases resources associated with the parameterized packet-
     * buffer or group. Every consume() invocation must be followed
     * (immediately) by a release().
     *
     * TODO(natre): This condition (atomic consume+release) is stronger
     * than what the interface requires. For instance, it is sufficient
     * to have multiple consecutive consumes as long as releases happen
     * in-order. However, in this version of the library, we're intent-
     * ionally limiting the abstraction to prevent the programmer from
     * inadvertently shooting themselves in the foot.
     */
    void release(PacketBufferGroup& group);
    void release(PacketBuffer** buffer); // TODO(natre): Impl.

    /**
     * Updates the packet queue state on receiving new RX data
     * from the NIC. Should be invoked whenever recv is called
     * on the corresponding socket.
     */
    void on_recv(char* read_addr, size_t read_bytes);

    // Accessors
    inline size_t get_bytes_left() const { return read_bytes_left_; }

    friend Socket;
};

/**
 * Helper class to manage a socket's TX queue.
 */
class TXPacketQueueManager final {
private:
    SpeculativeRingBufferMemoryAllocator pb_allocator_{}; // PacketBuffer* allocator
    SpeculativeRingBufferMemoryAllocator pd_allocator_{}; // PacketBuffer data allocator

    /**
     * Initialize the TX packet queue.
     */
    void initialize(const int pb_ring_fd, const uint64_t pb_ring_size,
                    const int pd_ring_fd, const uint64_t pd_ring_size);

public:
    DEFAULT_CTOR_AND_DTOR(TXPacketQueueManager);
    DISALLOW_COPY_AND_ASSIGN(TXPacketQueueManager);

    /**
     * Construct a PacketBuffer with the given size.
     */
    PacketBuffer* alloc(const uint64_t size);
    void alloc_shrink(PacketBuffer* buffer,
                      const uint64_t to_size);

    /**
     * Updates the packet queue state on TX events.
     */
    void dealloc(const uint64_t num_pktbufs,
                 const uint64_t num_bytes);

    friend Socket;
};

/**
 * Represents a Norman socket.
 */
class Socket final {
private:
    static constexpr size_t kRecvSize = 10000000;

    uint8_t sg_idx_ = 0; // SocketGroup idx
    int socket_fd_ = -1; // This socket's FD
    RXPacketQueueManager rx_manager_{}; // RX queue manager
    TXPacketQueueManager tx_manager_{}; // TX queue manager

    /**
     * Network interface.
     */
    void send_zc(PacketBufferGroup& group,
                 TxCompletionQueueManager& txcq_manager);

    uint16_t recv_zc(PacketBufferGroup& group);
    void done_recv(PacketBufferGroup& group);

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
    inline TXPacketQueueManager& get_tx_manager() { return tx_manager_; }

    friend SocketGroup;
};


/**
 * Represents a TX completion event.
 */
class __attribute__ ((__packed__)) TxCompletionEvent final {
private:
    size_t num_bytes_ = 0; // Length (in bytes) of the packet data
    size_t num_pktbufs_ = 0; // Number of pktbufs in this event
    uint8_t sg_idx_ = 0; // Socket's index in its SocketGroup

public:
    TxCompletionEvent() = default;
    explicit TxCompletionEvent(uint8_t sg_idx, size_t num_bytes,
                               size_t num_pktbufs) : num_bytes_(num_bytes),
                               num_pktbufs_(num_pktbufs), sg_idx_(sg_idx) {}
    // Accessors
    inline uint8_t get_sg_idx() const { return sg_idx_; }
    inline size_t get_num_bytes() const { return num_bytes_; }
    inline size_t get_num_pktbufs() const { return num_pktbufs_; }

    // Mutators
    inline void set_sg_idx(uint8_t sg_idx) { sg_idx_ = sg_idx; }
    inline void set_num_bytes(size_t num_bytes) { num_bytes_ = num_bytes; }
    inline void set_num_pktbufs(size_t num_pktbufs) { num_pktbufs_ = num_pktbufs; }
};
static_assert(sizeof(TxCompletionEvent) == 17,
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
    uint8_t num_active_sockets_ = 0;
    Socket sockets_[kMaxNumSockets]{};
    TxCompletionQueueManager txcq_manager_{};

public:
    DEFAULT_CTOR_AND_DTOR(SocketGroup);
    DISALLOW_COPY_AND_ASSIGN(SocketGroup);

    /**
     * Adds a new socket to this group.
     */
    uint8_t add_socket(const std::string hp_prefix,
                       const int num_queues);
    /**
     * Network interface.
     */
    void send_zc(uint8_t sg_idx, PacketBufferGroup& group);
    void done_recv(uint8_t sg_idx, PacketBufferGroup& group);
    uint16_t recv_zc(uint8_t sg_idx, PacketBufferGroup& group);

    // Accessors
    uint8_t get_num_active_sockets() const;
    Socket& get_socket(const uint8_t sg_idx);
};

#undef DISALLOW_COPY_AND_ASSIGN
#undef DEFAULT_CTOR_AND_DTOR
} // namespace norman

#endif // USERLIB_H
