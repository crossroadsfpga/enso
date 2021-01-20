all: kernel_modules

obj-m := mmap_zcopy.o

KDIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

%.ko: %.o
	$(MAKE) -C $(KDIR) SUBDIRS=$(PWD) $@

kernel_modules:
	$(MAKE) -C $(KDIR) SUBDIRS=$(PWD) modules
	gcc test.c -o test

clean:
	$(MAKE) -C $(KDIR) SUBDIRS=$(PWD) clean
	rm -f test
