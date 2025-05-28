#!/usr/bin/env bash

# print commands
set -o xtrace

# exit when error occurs
set -e

ORIGINAL_PWD=$(pwd)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

DOXYBOOK2_PATH="$PWD/doxybook2"
DOXYBOOK2_BIN="$DOXYBOOK2_PATH/bin/doxybook2"

# Check if doxybook2 is already downloaded
if [ -d $DOXYBOOK2_PATH ]; then
    echo "doxybook2 is already downloaded skipping download"
else
    # Download doxybook2.
    mkdir -p $DOXYBOOK2_PATH
    cd $DOXYBOOK2_PATH
    wget https://github.com/matusnovak/doxybook2/releases/download/v1.5.0/doxybook2-linux-amd64-v1.5.0.zip
    unzip doxybook2-linux-amd64-v1.5.0.zip
    rm doxybook2-linux-amd64-v1.5.0.zip
fi

cd $ORIGINAL_PWD
ls -al

rm -rf docs/software
mkdir -p docs/software
$DOXYBOOK2_BIN --input docs/xml --output docs/software \
    --config $SCRIPT_DIR/config-doxybook2.json

# Not ideal but mkdocs can only work with all the files in the same directory.
rm -rf $SCRIPT_DIR/software
cp -r docs/software $SCRIPT_DIR/software
