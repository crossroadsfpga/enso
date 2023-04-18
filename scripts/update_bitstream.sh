#!/usr/bin/env bash

# exit when error occurs
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

if [ $# -ne 1 ]; then
    echo "Must specify bitstream file or '--download'."
    echo
    echo "Usage: $0 BITSTREAM_FILE | --download"
    echo "  BITSTREAM_FILE: Path to bitstream file to use."
    echo "  --download: Automatically download bitstream for the current version."
    exit 1
fi

cd $SCRIPT_DIR/..

python3 -m pip install -r requirements.txt

if [ "$1" == "--download" ]; then
    echo "Downloading bitstream file."
    # Get latest tag.
    LATEST_TAG=$(git describe --abbrev=0)
    echo "Latest tag: $LATEST_TAG"

    GH_RELEASE_URL="https://github.com/crossroadsfpga/enso/releases/download"
    BITSTREAM_NAME="intel_stratix10mx_bitstream.sof"
    BITSTREAM_URL="$GH_RELEASE_URL/$LATEST_TAG/$BITSTREAM_NAME"
    echo "Downloading bitstream file from: $BITSTREAM_URL"

    wget $BITSTREAM_URL
    mv $BITSTREAM_NAME scripts/alt_ehipc2_hw.sof
else 
    BITSTREAM_FILE=$1

    # Check if bitstream file exists.
    if [ ! -f "$BITSTREAM_FILE" ]; then
        echo -e "${RED}Bitstream file $BITSTREAM_FILE does not exist.${NC}"
        exit 1
    fi

    # Copy bitstream file to the scripts directory.
    cp $BITSTREAM_FILE scripts/alt_ehipc2_hw.sof
fi
