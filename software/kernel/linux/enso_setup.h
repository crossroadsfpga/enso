#ifndef SOFTWARE_KERNEL_LINUX_ENSO_SETUP_H_
#define SOFTWARE_KERNEL_LINUX_ENSO_SETUP_H_

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/printk.h>
#include <linux/cdev.h>
#include <linux/slab.h>
#include <linux/fs.h>

#define ENSO_DRIVER_NAME        "enso"

struct enso_intel_pcie {
    uint64_t bar2_pcie_start;
    uint64_t bar2_pcie_len;
};

struct enso_global_bookkeep {
  struct cdev cdev;
  struct class *chr_class;
  struct enso_intel_pcie *intel_enso;
  int chr_major;
  int chr_minor;
};

extern struct enso_global_bookkeep global_bk;

#endif // SOFTWARE_KERNEL_LINUX_ENSO_SETUP_H_
