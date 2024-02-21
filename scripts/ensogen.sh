#!/usr/bin/env bash
# Helper script to run ensogen with the correct arguments for numerator and
# denominator depending on a given rate and pcap file.

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

ENSOGEN_PATH="${SCRIPT_DIR}/../build/software/examples/ensogen"
ENSOGEN_PATH=$(realpath $ENSOGEN_PATH)

GET_PCAP_SIZE_CMD_PATH="${SCRIPT_DIR}/../build/scripts/get_pcap_pkt_size"
GET_PCAP_SIZE_CMD_PATH=$(realpath $GET_PCAP_SIZE_CMD_PATH)

if [ $# -lt 2 ]; then
    echo "Usage: ./ensogen.sh PCAP_FILE RATE_GBPS [OPTIONS]"
    echo "Example: ./ensogen.sh /tmp/pcap_file.pcap 100 --pcie-addr 65:00.0"
    exit 1
fi

if [ ! -f $ENSOGEN_PATH ]; then
    echo "Error: Could not find ensogen binary at $ENSOGEN_PATH"
    echo "Make sure you have built the enso project."
    exit 2
fi

if [ ! -f $GET_PCAP_SIZE_CMD_PATH ]; then
    echo "Error: Could not find binary at $GET_PCAP_SIZE_CMD_PATH"
    echo "Make sure you have built the enso project."
    exit 3
fi

rate=$1
extra_args=${@:2}

pattern="Average packet size:"
mean_pkt_size=60

num_den=$(python3 <<EOF
import math
from fractions import Fraction
pkt_size = $mean_pkt_size
rate = $rate * 1e9
mac_overhead = 24
clock = 200e6

rate_pps = rate / ((pkt_size + mac_overhead) * 8)
flits_per_pkt = math.ceil(pkt_size / 64)
rate_flits_per_second = rate_pps * flits_per_pkt
clock_fraction = Fraction(rate_flits_per_second / clock).limit_denominator(1000)

print(clock_fraction.numerator, clock_fraction.denominator)

EOF
)

sudo $ENSOGEN_PATH $num_den $extra_args
