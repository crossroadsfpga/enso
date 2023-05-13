#!/usr/bin/env bash
# Usage: ./synthesize.sh [seed1] [seed2] ...
# Syntheizes hardware. Launches as many workers as seeds that you specify.

PROJECT_NAME="enso"

SEEDS=${@:-0}
NUMBER_SEEDS=$#

CUR_DIR=$(pwd)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
SCRIPTS_DIR=$SCRIPT_DIR/scripts
PROJECT_DIR=$SCRIPT_DIR/hardware

# Exit when error occurs.
set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command exited with code $?."' EXIT

if [[ $NUMBER_SEEDS -gt 1 ]]; then
  if ! command -v parallel &> /dev/null; then
    echo "Error: GNU Parallel is not installed."
    echo "You need GNU Parallel to run multiple seeds."
    exit 1
  fi
fi

# Run synthesis.
cd $PROJECT_DIR/quartus

# Generate IPs if necessary.
quartus_ipgenerate $PROJECT_NAME

# We must copy the pcie_generic_component_0.v.template to the correct location.
cp $PROJECT_DIR/ip/pcie_generic_component_0.v.template \
    $PROJECT_DIR/ip/pcie_ed/generic_component_0/synth/generic_component_0.v

# Enable/disable signal tap.
# quartus_stp alt_ehipc2_hw --stp_file stp1.stp --enable
# quartus_stp alt_ehipc2_hw --stp_file stp1.stp --disable

quartus_syn --read_settings_files=on --write_settings_files=off $PROJECT_NAME \
  -c $PROJECT_NAME

# We need to go back to original directory to make sure we save the bitstream
# to the correct directory.
cd -

# Check number of SEEDS. If more than one, run in parallel.
if [[ $NUMBER_SEEDS -gt 1 ]]; then
  parallel --tmux \
    "${SCRIPTS_DIR}/quartus_fit_save.sh {} ${bitstream_destination}" ::: $SEEDS
else
  source ${SCRIPTS_DIR}/quartus_fit_save.sh $SEEDS $bitstream_destination
fi
