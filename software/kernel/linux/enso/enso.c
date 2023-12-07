#include <linux/delay.h> /* usleep_range */
#include <linux/errno.h> /* EFAULT */
#include <linux/fs.h>
#include <linux/jiffies.h>
#include <linux/kernel.h> /* min */
#include <linux/kthread.h>
#include <linux/module.h>
#include <linux/poll.h>
#include <linux/printk.h> /* printk */
#include <linux/uaccess.h> /* copy_from_user, copy_to_user */
#include <linux/wait.h> /* wait_queue_head_t, wait_event_interruptible, wake_up_interruptible  */
#include <uapi/linux/stat.h> /* S_IRUSR */
#include <linux/cdev.h>

#define ENSO_DRIVER_NAME "enso"

static int ret0 = 0;
int major = 0;
int minor = 0;
struct cdev cdev;

module_param(ret0, int, S_IRUSR | S_IWUSR);
MODULE_PARM_DESC(i, "if 1, always return 0 from poll");

static char readbuf[1024];
static size_t readbuflen;
static struct task_struct *kthread;
static wait_queue_head_t waitqueue;

static ssize_t read(struct file *filp, char __user *buf, size_t len, loff_t *off) {
    ssize_t ret;
    if (copy_to_user(buf, readbuf, readbuflen)) {
        ret = -EFAULT;
    } else {
        ret = readbuflen;
    }
    /* This is normal pipe behaviour: data gets drained once a reader reads from it. */
    /* https://stackoverflow.com/questions/1634580/named-pipes-fifos-on-unix-with-multiple-readers */
    readbuflen = 0;
    return ret;
}

/* If you return 0 here, then the kernel will sleep until an event
 * happens in the queue. and then call this again, because of the call to poll_wait. */
unsigned int poll(struct file *filp, struct poll_table_struct *wait) {
    pr_info("poll\n");
    /* This doesn't sleep. It just makes the kernel call poll again if we return 0. */
    poll_wait(filp, &waitqueue, wait);
    if (readbuflen && !ret0) {
        pr_info("return POLLIN\n");
        return POLLIN;
    } else {
        pr_info("return 0\n");
        return 0;
    }
}

static int kthread_func(void *data) {
    while (!kthread_should_stop()) {
        readbuflen = snprintf(
        readbuf,
        sizeof(readbuf),
        "%llu",
        (unsigned long long)jiffies
        );
        usleep_range(1000000, 1000001);
        wake_up(&waitqueue);
    }
    return 0;
}

static int enso_open(struct inode *inode, struct file *filp) {
    return 0;
}

static int enso_release(struct inode *inode, struct file *filp) {
    return 0;
}

static const struct file_operations enso_fops = {
    .owner = THIS_MODULE,
    .read = read,
    .poll = poll,
    .open = enso_open,
    .release = enso_release
};

static int enso_init(void) {
    dev_t dev_id;
    int retval = alloc_chrdev_region(&dev_id, 0, 1, ENSO_DRIVER_NAME);
    if(retval) {
        printk("Failed to register char dev\n");
        return -1;
    }
    major = MAJOR(dev_id);
    minor = MINOR(dev_id);

    cdev_init(&cdev, &enso_fops);
    cdev.owner = THIS_MODULE;
    cdev.ops = &enso_fops;
    retval = cdev_add(&cdev, dev_id, 1);
    if(retval) {
        cdev_del(&cdev);
        printk("Failed to register device\n");
        return -1;
    }

	init_waitqueue_head(&waitqueue);
	kthread = kthread_create(get_rx_tails, NULL, "enso_rx");
	wake_up_process(kthread);

	return 0;
}

static void enso_exit(void) {
    unregister_chrdev_region(MKDEV(major, minor), 1);
    cdev_del(&cdev);
	kthread_stop(kthread);
}

module_init(enso_init);
module_exit(enso_exit);
MODULE_LICENSE("GPL");
