#include "enso_setup.h"
#include "enso_chr.h"

struct enso_global_bookkeep global_bk __read_mostly;

// function defined in Intel's FPGA to get the BAR information
extern struct enso_intel_pcie* get_intel_fpga_pcie_addr(void);

/******************************************************************************
 * Kernel Resgitration
 *****************************************************************************/
/*
 * enso_init(void): Registers the Enso driver.
 *
 * @returns: 0 if successful.
 *
 * */
static __init int enso_init(void) {
    int ret;
    global_bk.intel_enso = NULL;
    global_bk.intel_enso = get_intel_fpga_pcie_addr();
    if(global_bk.intel_enso == NULL) {
        printk("Failed to receive BAR info\n");
        return -1;
    }
    printk("PCIE ADDR = %llx\n", global_bk.intel_enso->bar2_pcie_start);
    printk("PCIE LEN = %llx\n", global_bk.intel_enso->bar2_pcie_len);
    // initialize a character device
    ret = enso_chr_init();
    if(ret != 0) {
        printk("Failed to initialize character device\n");
        return ret;
    }
	return 0;
}
module_init(enso_init);

/*
 * enso_init(void): Unregisters the Enso driver.
 *
 * */
static void enso_exit(void) {
    // unregister the character device
    enso_chr_exit();
    global_bk.intel_enso = NULL;
}
module_exit(enso_exit);

MODULE_LICENSE("GPL");
