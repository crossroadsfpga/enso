#!/usr/bin/env bash

# exit when error occurs
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_DIR=$SCRIPT_DIR/..

if [[ "$#" -ne 3 ]]; then
    echo "Syntax: ./sw_setup.sh NOTIFICATION_BUF_SIZE ENSO_PIPE_SIZE LATENCY_OPT"
    exit 1
fi

# Check if hugepages are enabled, and if not, automatically enable them.
if [ ! -f /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages ]; then
    # Hugepages are not enabled. Enable them.
    mkdir -p /mnt/huge
    (mount | grep /mnt/huge) > /dev/null || mount -t hugetlbfs hugetlbfs /mnt/huge
    for i in /sys/devices/system/node/node[0-9]*; do
        echo 4096 > "$i"/hugepages/hugepages-2048kB/nr_hugepages
    done
    echo "Hugepages enabled."
else
    nb_hugepages=$(cat /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages)
    echo "Currently there are $nb_hugepages hugepages allocated."
fi

cd $REPO_DIR/software/kernel/linux/
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
