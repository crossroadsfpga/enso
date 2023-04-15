#!/usr/bin/env bash
# This script lists the available Enso NICs. It scans both PCIe devices as well
# as USB devices to be used with JTAG.

echo "PCIe devices"
DEVICE_ID="0000"
VENDOR_ID="1172"
while read -r line; do
  device=$(echo "$line" | awk '{print $1}')
  echo "  PCIe Address:" $device
done < <(lspci -nn | grep ${VENDOR_ID}:${DEVICE_ID})

echo
echo "USB devices"
DEVICE_ID="6010"
VENDOR_ID="09fb"

while read -r line; do
  # Get the device number from each line
  device=$(echo "$line" | awk '{print $4}' | cut -d: -f1)
  device=$((10#$device))

  # Get the port number from lsusb -t using the device number
  port=$(lsusb -t | grep -m 1 "Dev $device" | awk '{print $3}')
  port=${port%?}

  # Combine bus and port to get the ID
  bus=$(echo "$line" | awk '{print $2}')
  bus=$((10#$bus))

  id="$bus-$port"

  echo "  FPGA ID:" $id
done < <(lsusb -d ${VENDOR_ID}:${DEVICE_ID})

echo
echo "If the device you are looking for is not listed, make sure to load the"\
     "bitstream using load_bitstream.sh and to reboot the machine."
