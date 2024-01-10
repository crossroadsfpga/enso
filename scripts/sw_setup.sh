#!/usr/bin/env bash

# exit when error occurs
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_DIR=$SCRIPT_DIR/..

if [[ "$#" -ne 3 ]]; then
    echo "Syntax: ./sw_setup.sh NOTIFICATION_BUF_SIZE ENSO_PIPE_SIZE LATENCY_OPT"
    exit 1
fi


sudo mkdir -p /mnt/huge
(sudo mount | grep /mnt/huge) > /dev/null || sudo mount -t hugetlbfs hugetlbfs /mnt/huge
for i in /sys/devices/system/node/node[0-9]*; do
    echo 4096 | sudo tee "$i"/hugepages/hugepages-2048kB/nr_hugepages
done

cd $REPO_DIR/software/kernel/linux/
make
./install
cd $REPO_DIR

which python3
which meson

# Using GCC
meson setup --native-file gcc.ini build-gcc
ln -sfn build-gcc build

# Using Clang
# meson setup --native-file llvm.ini build-clang
# ln -sfn build-clang build

cd build
meson configure -Dnotification_buf_size=$1 -Denso_pipe_size=$2 -Dlatency_opt=$3
ninja -v
sudo ninja install
