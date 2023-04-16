#!/usr/bin/env bash
set -e

VENDOR_ID="1172"
DEVICE_ID="0000"

FPGA_NB=${1:-"1-13"}

# We use taskset and chrt to benefit from multiple cores even when they are
# isolated from the linux scheduler. This significantly speeds up loading the
# bitstream. Note that we use all but the last core.
sudo taskset -c 0-$((`nproc --all` - 2)) chrt -r 1 $(which quartus_pgm) \
    -c "Intel Stratix 10 MX FPGA Development Kit [$FPGA_NB]" ./load.cdf

# remove device and force rescan, this will trigger the driver's probe function
DEVICE_ADDRS=$(lspci -nn | grep ${VENDOR_ID}:${DEVICE_ID} | grep Ethernet | \
    awk '{print $1}')

for device in $DEVICE_ADDRS; do
    if [ -n "$device" ]; then
        echo "1" | sudo tee -a /sys/bus/pci/devices/0000\:${device}/remove \
            > /dev/null
    fi
done
echo "1" | sudo tee -a /sys/bus/pci/rescan > /dev/null
