#!/usr/bin/env bash
set -e

VENDOR_ID="1172"
DEVICE_ID="0000"

FPGA_NB=${1:-"1-13"}

quartus_pgm -c "Intel Stratix 10 MX FPGA Development Kit [$FPGA_NB]" ./load.cdf

# remove device and force rescan, this will trigger the driver's probe function
DEVICE_ADDR=$(lspci -nn | grep ${VENDOR_ID}:${DEVICE_ID} | awk '{print $1}')
if [ -n "$DEVICE_ADDR" ]; then
    echo "1" | sudo tee -a /sys/bus/pci/devices/0000\:${DEVICE_ADDR}/remove > /dev/null
fi
echo "1" | sudo tee -a /sys/bus/pci/rescan > /dev/null
