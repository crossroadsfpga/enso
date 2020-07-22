#!/usr/bin/env bash
# usage: ./synthesize.sh [bistream_destination]
# If you do not specify the bitstream destination it will be saved to the
# current directory

QUARTUS_PROJECT_ROOT_DEFAULT="$HOME/front_door_consumer"

CUR_DIR=$(pwd)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BITSTREAM_DESTINATION=${1:-$CUR_DIR}

# exit when error occurs
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

# copy newest source
cp $SCRIPT_DIR/RTL_sim/alt_ehipc2_hw.* $quartus_project_root/hardware_test_design/
cp -r $SCRIPT_DIR/RTL_sim/src/* $quartus_project_root/hardware_test_design/src/

# run synthesis
cd $quartus_project_root/hardware_test_design
quartus_syn --read_settings_files=on --write_settings_files=off alt_ehipc2_hw -c alt_ehipc2_hw
quartus_fit --read_settings_files=on --write_settings_files=off alt_ehipc2_hw -c alt_ehipc2_hw
quartus_sta alt_ehipc2_hw -c alt_ehipc2_hw --mode=finalize
quartus_asm --read_settings_files=on --write_settings_files=off alt_ehipc2_hw -c alt_ehipc2_hw
cd $CUR_DIR
cp "$quartus_project_root/hardware_test_design/output_files/alt_ehipc2_hw.sof" \
    "$BITSTREAM_DESTINATION"
