MODULE_NAME := enso
obj-m += $(MODULE_NAME).o

PWD       := $(shell pwd)
KDIR ?= /lib/modules/$(shell uname -r)/build
CPPFLAGS += -include $(KDIR)/include/generated/autoconf.h
EXTRA_CFLAGS += -Wall -Werror

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
