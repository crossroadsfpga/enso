#!/usr/bin/env bash
# This script is used to check if the FPGA is enumerated as an Ethernet
# controller. If it is not, make sure to load the bitstream using
# load_bitstream.sh and to reboot the machine.

DEVICE_ID="0000"
VENDOR_ID="1172"
lspci -nn | grep ${VENDOR_ID}:${DEVICE_ID}
