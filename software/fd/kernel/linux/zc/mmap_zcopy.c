/* adapted from https://gist.github.com/laoar/4a7110dcd65dbf2aefb3231146458b39 */

#include <linux/module.h>
#include <linux/uaccess.h>
#include <linux/slab.h>
#include <linux/kernel.h>
#include <linux/device.h>
#include <linux/init.h>
#include <linux/fs.h>
#include <linux/mm.h>
#include <asm/uaccess.h>
#include "mmap_zcopy.h"

#define MAX_SIZE (PAGE_SIZE * 2)   /* max size mmaped to userspace */
#define DEVICE_NAME "mchar"
#define  CLASS_NAME "mogu"

static struct class*  class;
static struct device*  device;
static int major;

static DEFINE_MUTEX(mchar_mutex);

/*  executed once the device is closed or releaseed by userspace
 *  @param inodep: pointer to struct inode
 *  @param filep: pointer to struct file
 */
static int mchar_release(struct inode *inodep, struct file *filep)
{
    mutex_unlock(&mchar_mutex);
    pr_info("mchar: Device successfully closed\n");

    return 0;
}

/* executed once the device is opened.
 *
 */
static int mchar_open(struct inode *inodep, struct file *filep)
{
    int ret = 0;

    if(!mutex_trylock(&mchar_mutex)) {
        pr_alert("mchar: device busy!\n");
        ret = -EBUSY;
        goto out;
    }

    pr_info("mchar: Device opened\n");

out:
    return ret;
}

/*  mmap handler to map kernel space to user space
 *
 */
static int mchar_mmap(struct file *filp, struct vm_area_struct *vma)
{
    int ret = 0;
    struct page *page = NULL;
    unsigned long size = (unsigned long)(vma->vm_end - vma->vm_start);

    if (size > MAX_SIZE) {
        ret = -EINVAL;
        goto out;
    }

    page = virt_to_page((unsigned long)sh_mem + (vma->vm_pgoff << PAGE_SHIFT));
    ret = remap_pfn_range(vma, vma->vm_start, page_to_pfn(page), size, vma->vm_page_prot);
    if (ret != 0) {
        goto out;
    }

out:
    return ret;
}

static ssize_t mchar_read(struct file *filep, char *buffer, size_t len, loff_t *offset)
{
    int ret;

    if (len > MAX_SIZE) {
        pr_info("read overflow!\n");
        ret = -EFAULT;
        goto out;
    }

    if (copy_to_user(buffer, sh_mem, len) == 0) {
        pr_info("mchar: copy %u char to the user\n", len);
        ret = len;
    } else {
        ret =  -EFAULT;
    }

    sh_mem[0] = 0;

out:
    return ret;
}

static ssize_t mchar_write(struct file *filep, const char *buffer, size_t len, loff_t *offset)
{
    int ret;

    if (copy_from_user(sh_mem, buffer, len)) {
        pr_err("mchar: write fault!\n");
        ret = -EFAULT;
        goto out;
    }
    pr_info("mchar: copy %d char from the user\n", len);
    ret = len;

out:
    return ret;
}

static const struct file_operations mchar_fops = {
    .open = mchar_open,
    .read = mchar_read,
    .write = mchar_write,
    .release = mchar_release,
    .mmap = mchar_mmap,
    /*.unlocked_ioctl = mchar_ioctl,*/
    .owner = THIS_MODULE,
};

static int __init mchar_init(void)
{
    int ret = 0;
    major = register_chrdev(0, DEVICE_NAME, &mchar_fops);

    if (major < 0) {
        pr_info("mchar: fail to register major number!");
        ret = major;
        goto out;
    }

    class = class_create(THIS_MODULE, CLASS_NAME);
    if (IS_ERR(class)){
        unregister_chrdev(major, DEVICE_NAME);
        pr_info("mchar: failed to register device class");
        ret = PTR_ERR(class);
        goto out;
    }

    device = device_create(class, NULL, MKDEV(major, 0), NULL, DEVICE_NAME);
    if (IS_ERR(device)) {
        class_destroy(class);
        unregister_chrdev(major, DEVICE_NAME);
        ret = PTR_ERR(device);
        goto out;
    }


    /* init this mmap area */
    sh_mem = kmalloc(MAX_SIZE, GFP_KERNEL);
    if (sh_mem == NULL) {
        ret = -ENOMEM;
        goto out;
    }

    sprintf(sh_mem, "xyz\n");

    mutex_init(&mchar_mutex);
out:
    return ret;
}

static void __exit mchar_exit(void)
{
    mutex_destroy(&mchar_mutex);
    device_destroy(class, MKDEV(major, 0));
    class_unregister(class);
    class_destroy(class);
    unregister_chrdev(major, DEVICE_NAME);

    pr_info("mchar: unregistered!");
}

module_init(mchar_init);
module_exit(mchar_exit);
MODULE_LICENSE("GPL");
