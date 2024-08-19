#!/usr/bin/env bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

SETUP_DONE_PATH="$SCRIPT_DIR/.setup_done"

# If --no-quartus is passed, we don't check for quartus.
if [[ $1 == "--no-quartus" ]]; then
    echo "Skipping quartus check."
else
    # Check if quartus is in the PATH.
    if ! command -v quartus &> /dev/null; then
        echo -e "${RED}quartus not in PATH. Add it to PATH and try again.${NC}"
        exit 1
    fi

    # Check if quartus_pgm is in the PATH.
    if ! command -v quartus_pgm &> /dev/null; then
        echo-e  "${RED}quartus_pgm not in PATH. Add it to PATH and try again.${NC}"
        exit 1
    fi
fi

# if .setup_done exists, then setup has already been run.
if [ -f $SETUP_DONE_PATH ]; then
    echo "Setup has already been run. If you want to re-run the setup, delete" \
         "$SETUP_DONE_PATH and run this script again."
    exit 0
fi

# Check if apt-get is available. If yes, install dependencies.
if command -v apt-get &> /dev/null; then
    # Update if more than a month has passed since last update.
    last_update=$(stat -c %Y /var/cache/apt/pkgcache.bin)
    now=$(date +%s)
    if [ $((now - last_update)) -gt 2592000 ]; then
        sudo apt-get update -y
    fi
    sudo apt-get install -y \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    gcc-9 \
    g++-9 \
    libpcap-dev \
    wget
else
    echo "apt-get not found. Please install dependencies manually."
fi


sudo python3 -m pip install meson ninja

echo "Using python3 from $(which python3)"

cd $SCRIPT_DIR
python3 -m pip install -r requirements.txt

# If the bitstream file is not present, download it.
if [ ! -f "scripts/enso.sof" ]; then
    ./scripts/update_bitstream.sh --download
else
    echo "Using existing bitstream file."
fi

# Setup the software.
./scripts/sw_setup.sh 16384 32768 true
return_code=$?

if [ $return_code -ne 0 ]; then
    echo -e "${RED}Failed to setup software.${NC}"
    exit 1
fi

touch $SETUP_DONE_PATH
