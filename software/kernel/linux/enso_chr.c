#include "enso_chr.h"

/******************************************************************************
 * Static function prototypes
 *****************************************************************************/
static int enso_chr_open(struct inode *inode, struct file *filp);
static int enso_chr_release(struct inode *inode, struct file *filp);

/******************************************************************************
 * File operation functions
 *****************************************************************************/
const struct file_operations enso_fops = {
    .owner = THIS_MODULE,
    .open = enso_chr_open,
    .release = enso_chr_release,
};

/**
 * enso_chr_open() - Responds to the system call open(2).
 *
 * @inode: Unused.
 * @filp:  Pointer to file struct.
 *
 * Return: 0 if successful, negative error code otherwise.
 */
static int enso_chr_open(struct inode *inode, struct file *filp) {
    return 0;
}

/**
 * enso_chr_release() - Responds to the system call close(2). Clean up character
 *                      device file structure.
 * @inode: Unused.
 * @filp:  Pointer to file struct.
 *
 * @return: 0 if successful, negative error code otherwise.
 */
static int enso_chr_release(struct inode *inode, struct file *filp) {
    return 0;
}

/******************************************************************************
 * Initialization functions
 *****************************************************************************/
/**
 * enso_chr_init() - Populates sysfs entry with a new device class
 *                   and creates a character device.
 *
 * @return: 0 if successful, negative error code otherwise.
 */
int __init enso_chr_init(void) {
    dev_t dev_id;
    struct device *dev;
    int ret;

    // allocate chrdev region for this device
    // we allocate minor numbers starting from 0
    // we need only one device
    ret = alloc_chrdev_region(&dev_id, 0, 1, ENSO_DRIVER_NAME);
    if(ret) {
        printk("Failed to register char dev\n");
        return -1;
    }
    // dev_id contains a unique identifier allocated by the kernel
    // get the major and minor device numbers from it
    global_bk.chr_major = MAJOR(dev_id);
    global_bk.chr_minor = MINOR(dev_id);

    // initilize and add the character device to the kernel
    cdev_init(&global_bk.cdev, &enso_fops);
    global_bk.cdev.owner = THIS_MODULE;
    global_bk.cdev.ops = &enso_fops;

    // link the major/minor numbers to the char dev
    ret = cdev_add(&global_bk.cdev, dev_id, 1);
    if(ret) {
        cdev_del(&global_bk.cdev);
        printk("Failed to add char device\n");
        return -1;
    }

    // add an entry under /dev/ for the enso device
    // same as running mknod
    global_bk.chr_class = class_create(THIS_MODULE, ENSO_DRIVER_NAME);
    if (IS_ERR(global_bk.chr_class)) {
        printk("Failed to create device class\n");
        return -1;
    }
    dev = device_create(global_bk.chr_class, NULL, dev_id, NULL,
                        ENSO_DRIVER_NAME);
    if (IS_ERR(dev)) {
        printk("Failed to create device under /dev/.");
        return -1;
    }
    return 0;
}

/**
 * enso_chr_exit() - Undo everything done by enso_chr_init().
 *
 * @return: Nothing
 */
void enso_chr_exit(void) {
    unregister_chrdev_region(MKDEV(global_bk.chr_major, global_bk.chr_minor), 1);
    cdev_del(&global_bk.cdev);
    device_destroy(global_bk.chr_class,
                   MKDEV(global_bk.chr_major, global_bk.chr_minor));
    global_bk.chr_major = 0;
    global_bk.chr_minor = 0;
    class_destroy(global_bk.chr_class);
    global_bk.chr_class = NULL;
}

/******************************************************************************
 * Helper functions
 *****************************************************************************/
