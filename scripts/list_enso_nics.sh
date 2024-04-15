#!/usr/bin/env bash
# This script lists the available Enso NICs. It scans both PCIe devices as well
# as USB devices to be used with JTAG.

YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "PCIe devices"
DEVICE_ID="0000"
VENDOR_ID="1172"

nb_pcie_devices=0

while read -r line; do
  device=$(echo "$line" | awk '{print $1}')
  nb_pcie_devices=$((nb_pcie_devices+1))
  echo "  PCIe Address:" $device
done < <(lspci -nn | grep ${VENDOR_ID}:${DEVICE_ID})

echo
echo "USB devices"
DEVICE_ID="6010"
VENDOR_ID="09fb"

nb_usb_devices=0

while read -r line; do
  # Get the device number from each line
  device=$(echo "$line" | awk '{print $4}' | cut -d: -f1)
  device=$((10#$device))

  bus=$(echo "$line" | cut -d " " -f 2)
  bus=$((10#$bus))

  # capture the right bus
  bus_line=$(lsusb -t | grep "Bus .*${bus}\." -n | cut -d ":" -f 1)
  fpga_bus="$(lsusb -t | tail -n +${bus_line} -)"

  # Get the port number from lsusb -t using the device number
  port=$(echo "${fpga_bus}" | grep -m 1 "Dev $device" | awk '{print $3}')
  port=${port%?}

  # Combine bus and port to get the ID
  bus=$(echo "$line" | awk '{print $2}')
  bus=$((10#$bus))

  id="$bus-$port"

  nb_usb_devices=$((nb_usb_devices+1))

  echo "  FPGA ID:" $id
done < <(lsusb -d ${VENDOR_ID}:${DEVICE_ID})

if [ $nb_pcie_devices -ne $nb_usb_devices ]; then
  echo
  echo -e "${YELLOW}WARNING: The number of PCIe and USB devices is different."\
          "Make sure to load the bitstream using scripts/load_bitstream.sh and"\
          "to reboot the machine.${NC}"
fi
