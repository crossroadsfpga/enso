#!/usr/bin/env bash
# Usage: ./synthesize.sh [seed1] [seed2] ...
# Launches as many workers as seeds that you specify.

SEEDS=${@:-1}

QUARTUS_PROJECT_ROOT_DEFAULT="$HOME/norman_production"

CUR_DIR=$(pwd)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Exit when error occurs.
set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command exited with code $?."' EXIT

if [[ -z "${FD_QUARTUS_PROJECT_ROOT}" ]]; then
  echo "FD_QUARTUS_PROJECT_ROOT is undefined, using default value:"\
       "$QUARTUS_PROJECT_ROOT_DEFAULT"
  quartus_project_root="${QUARTUS_PROJECT_ROOT_DEFAULT}"
else
  quartus_project_root="${FD_QUARTUS_PROJECT_ROOT}"
fi

if [[ -z "${FD_QUARTUS_PROJECT_DESTINATION}" ]]; then
  echo "FD_QUARTUS_PROJECT_DESTINATION is undefined, saving to current "\
       "directory: $CUR_DIR"
  bitstream_destination="${CUR_DIR}"
else
  bitstream_destination="${FD_QUARTUS_PROJECT_DESTINATION}"
fi

# Copy newest source.
cp $SCRIPT_DIR/../hardware/alt_ehipc2_hw.* \
  $quartus_project_root/hardware_test_design/
rm -rf $quartus_project_root/hardware_test_design/src
cp -r $SCRIPT_DIR/../hardware/src $quartus_project_root/hardware_test_design/

# Run synthesis.
cd $quartus_project_root/hardware_test_design

# Enable/disable signal tap.
# quartus_stp alt_ehipc2_hw --stp_file stp1.stp --enable
quartus_stp alt_ehipc2_hw --stp_file stp1.stp --disable
quartus_syn --read_settings_files=on --write_settings_files=off alt_ehipc2_hw \
  -c alt_ehipc2_hw

parallel --tmux \
  "${SCRIPT_DIR}/quartus_fit_save.sh {} ${bitstream_destination}" ::: $SEEDS
