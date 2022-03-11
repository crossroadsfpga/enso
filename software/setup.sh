#!/usr/bin/env bash

# exit when error occurs
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ "$#" -ne 3 ]; then
    echo "Syntax: ./setup.sh DSC_BUF_SIZE PKT_BUF_SIZE BATCH_SIZE"
fi

cd $SCRIPT_DIR/norman/kernel/linux/
sudo ./install
cd $SCRIPT_DIR
make clean
make DSC_BUF_SIZE=$1 PKT_BUF_SIZE=$2 BATCH_SIZE=$3
