#!/usr/bin/env bash

# exit when error occurs
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [[ "$#" -ne 4 ]]; then
    echo "Syntax: ./setup.sh NOTIFICATION_BUF_SIZE ENSO_PIPE_SIZE BATCH_SIZE LATENCY_OPT"
    exit 1
fi

cd $SCRIPT_DIR/kernel/linux/
sudo ./install
cd $SCRIPT_DIR

# Using GCC
meson setup --native-file gcc.ini build-gcc
ln -sfn build-gcc build

# Using Clang
# meson setup --native-file llvm.ini build-clang
# ln -sfn build-clang build

cd build
meson configure -Dnotification_buf_size=$1 -Denso_pipe_size=$2 -Dbatch_size=$3 \
    -Dlatency_opt=$4
ninja -v
sudo ninja install
