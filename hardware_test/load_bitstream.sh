#!/usr/bin/env bash

VENDOR_ID="1172"
DEVICE_ID="0000"

quartus_pgm -c Intel\ Stratix\ 10\ MX\ FPGA\ Development\ Kit\ [1-12] ./load.cdf 

# remove device and force rescan, this will trigger the driver's probe function
DEVICE_ADDR=$(lspci -nn | grep ${VENDOR_ID}:${DEVICE_ID} | awk '{print $1}')
echo "1" | sudo tee -a /sys/bus/pci/devices/0000\:${DEVICE_ADDR}/remove > /dev/null
echo "1" | sudo tee -a /sys/bus/pci/rescan > /dev/null
