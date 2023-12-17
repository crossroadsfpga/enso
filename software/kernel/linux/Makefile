INTEL_MODULE_NAME := intel_fpga_pcie_drv
obj-m += $(INTEL_MODULE_NAME).o
$(INTEL_MODULE_NAME)-y := intel_fpga_pcie_chr.o intel_fpga_pcie_dma.o \
        intel_fpga_pcie_setup.o intel_fpga_pcie_ioctl.o event_queue.o \
        event_handler.o
USE_AVX ?= 0

ENSO_MODULE_NAME := enso
obj-m += $(ENSO_MODULE_NAME).o
$(ENSO_MODULE_NAME)-y := enso_setup.o enso_chr.o enso_ioctl.o

PWD       := $(shell pwd)
KDIR ?= /lib/modules/$(shell uname -r)/build
CPPFLAGS += -include $(KDIR)/include/generated/autoconf.h
EXTRA_CFLAGS += -Wall -Werror

ifeq ($(USE_AVX), 1)
	# Enable wide accesses up to 32B
	EXTRA_CFLAGS += -mavx -mpreferred-stack-boundary=4
endif

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
