// TODO: Is there a common file that we can use here for these MACROS
#define NOTIFICATION_BUF_SIZE   16384
#define ENSO_PIPE_SIZE          32768
#define MAX_TRANSFER_LEN        131072
#define HUGE_PAGE_SIZE          (0x1ULL << 21)
#define MEM_PER_QUEUE           (0x1ULL << 12)
#define BATCH_SIZE              64


int ext_free_rx_enso_pipe(struct chr_dev_bookkeep *chr_dev_bk);
