#!/usr/bin/env bash
# Usage: ./synthesize.sh [bistream_destination]
# If you do not specify the bitstream destination it will be saved to the
# current directory.

QUARTUS_PROJECT_ROOT_DEFAULT="$HOME/enso_production"

CUR_DIR=$(pwd)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BITSTREAM_DESTINATION=${1:-$CUR_DIR}

echo "BITSTREAM_DESTINATION: $BITSTREAM_DESTINATION"
QUARTUS_STA_LOG_FILE="quartus_sta.log"

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

# Copy newest source.
cp $SCRIPT_DIR/hardware/alt_ehipc2_hw.* \
  $quartus_project_root/hardware_test_design/
rm -rf $quartus_project_root/hardware_test_design/src
cp -r $SCRIPT_DIR/hardware/src $quartus_project_root/hardware_test_design/

# run synthesis
cd $quartus_project_root/hardware_test_design
start=$(date +%s.%N)

# Enable/disable signal tap.
quartus_stp alt_ehipc2_hw --stp_file stp1.stp --enable
# quartus_stp alt_ehipc2_hw --stp_file stp1.stp --disable
quartus_syn --read_settings_files=on --write_settings_files=off alt_ehipc2_hw \
  -c alt_ehipc2_hw
quartus_fit --read_settings_files=on --write_settings_files=off alt_ehipc2_hw \
  -c alt_ehipc2_hw

# We use script instead of tee to capture the output and display it while
# preserving colors.
script --flush --quiet --return $QUARTUS_STA_LOG_FILE \
  --command "quartus_sta alt_ehipc2_hw -c alt_ehipc2_hw --mode=finalize"
quartus_asm --read_settings_files=on --write_settings_files=off alt_ehipc2_hw \
  -c alt_ehipc2_hw

dur=$(echo "$(date +%s.%N) - $start" | bc)
printf "Synthesis completed in %.6f seconds\n" $dur

if grep -q "Timing requirements not met" $QUARTUS_STA_LOG_FILE; then
  # Show slack.
  grep -C 10 "Timing requirements not met" quartus_sta.log
  RED='\033[0;31m'
  NC='\033[0m' # No Color.
  echo -e "${RED}===========================${NC}"
  echo -e "${RED}Timing requirements not met${NC}"
  echo -e "${RED}===========================${NC}"
fi

cd $CUR_DIR
cp "$quartus_project_root/hardware_test_design/output_files/alt_ehipc2_hw.sof" \
    "$BITSTREAM_DESTINATION"

# Announce that it is over.
tput bel
