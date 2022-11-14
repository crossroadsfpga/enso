#!/usr/bin/env bash

# exit when error occurs
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [[ "$#" -ne 4 ]]; then
    echo "Syntax: ./setup.sh DSC_BUF_SIZE PKT_BUF_SIZE BATCH_SIZE LATENCY_OPT"
    exit 1
fi

cd $SCRIPT_DIR/kernel/linux/
sudo ./install
cd $SCRIPT_DIR

# Using GCC
# CC=gcc-9 CXX=g++-9 meson build-gcc
# ln -sfn build-gcc build

# Using Clang
CC=clang-8 CXX=clang++-8 meson build-clang
ln -sfn build-clang build

cd build
meson configure -Ddsc_buf_size=$1 -Dpkt_buf_size=$2 -Dbatch_size=$3 \
    -Dlatency_opt=$4
ninja
