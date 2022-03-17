#!/usr/bin/env bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

SEED=$1
BITSTREAM_DESTINATION=$2

QUARTUS_STA_LOG_FILE="quartus_sta.log"

echo "Starting fit with seed=$SEED"
start=$(date +%s.%N)

mkdir -p ../hardware_test_design_$SEED/db
cp -r * ../hardware_test_design_$SEED
cp -r db/* ../hardware_test_design_$SEED/db

cd ../hardware_test_design_$SEED

quartus_fit --read_settings_files=on --write_settings_files=off alt_ehipc2_hw \
  -c alt_ehipc2_hw --seed=$SEED

# We use script instead of tee to capture the output and display it while
# preserving colors.
script --flush --quiet --return $QUARTUS_STA_LOG_FILE \
  --command "quartus_sta alt_ehipc2_hw -c alt_ehipc2_hw --mode=finalize"
quartus_asm --read_settings_files=on --write_settings_files=off alt_ehipc2_hw \
  -c alt_ehipc2_hw

dur=$(echo "$(date +%s.%N) - $start" | bc)
printf "Fitting completed in %.6f seconds\n" $dur

if grep -q "Timing requirements not met" $QUARTUS_STA_LOG_FILE; then
  # Show slack.
  grep -C 10 "Timing requirements not met" quartus_sta.log
  RED='\033[0;31m'
  NC='\033[0m' # No Color.
  echo -e "${RED}===========================${NC}"
  echo -e "${RED}Timing requirements not met${NC}"
  echo -e "${RED}===========================${NC}"
  BITSTREAM_NAME="slack_alt_ehipc2_hw_${SEED}.sof"
else
  BITSTREAM_NAME="alt_ehipc2_hw_${SEED}.sof"
fi

# Copy sof.
cp "output_files/alt_ehipc2_hw.sof" "$BITSTREAM_DESTINATION/$BITSTREAM_NAME"
echo "Bitstream saved to: $BITSTREAM_DESTINATION/$BITSTREAM_NAME"
md5sum "$BITSTREAM_DESTINATION/$BITSTREAM_NAME"

# Announce that it is over.
tput bel

echo "Done synthesis with seed=$SEED"

read -p "Press press enter to continue"
