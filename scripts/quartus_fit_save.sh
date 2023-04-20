#!/usr/bin/env bash

PROJECT_NAME="enso"

CUR_DIR=$(pwd)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PROJECT_DIR=$SCRIPT_DIR/../hardware

SEED=${1:-"0"}

BITSTREAM_DESTINATION=$CUR_DIR

echo "SEED=$SEED"

PROJECT_OUTPUT_DIRECTORY="output_files"
QUARTUS_STA_LOG_FILE="quartus_sta_${SEED}.log"

start=$(date +%s.%N)

compilation_dir="/tmp/${PROJECT_NAME}_$SEED"

rm -rf $compilation_dir
mkdir -p $compilation_dir/db

cp -r $PROJECT_DIR/* $compilation_dir/

cd $compilation_dir/quartus

quartus_fit --read_settings_files=on --write_settings_files=off $PROJECT_NAME \
  -c $PROJECT_NAME --seed=$SEED

# We use script instead of tee to capture the output and display it while
# preserving colors.
script --flush --quiet --return $QUARTUS_STA_LOG_FILE \
  --command "quartus_sta $PROJECT_NAME -c $PROJECT_NAME --mode=finalize"
quartus_asm --read_settings_files=on --write_settings_files=off $PROJECT_NAME \
  -c $PROJECT_NAME

dur=$(echo "$(date +%s.%N) - $start" | bc)
printf "Fitting completed in %.6f seconds\n" $dur

# Show Fmax.
grep -A20 "; Fmax" "$PROJECT_OUTPUT_DIRECTORY/$PROJECT_NAME.sta.rpt"


# Show resource utilization.
cat "$PROJECT_OUTPUT_DIRECTORY/$PROJECT_NAME.fit.summary"

if grep -q "Timing requirements not met" $QUARTUS_STA_LOG_FILE; then
  # Show slack.
  grep -C 10 "Timing requirements not met" quartus_sta.log
  RED='\033[0;31m'
  NC='\033[0m' # No Color.
  echo -e "${RED}===========================${NC}"
  echo -e "${RED}Timing requirements not met${NC}"
  echo -e "${RED}===========================${NC}"
  BITSTREAM_NAME="neg_slack_${PROJECT_NAME}_${SEED}.sof"
else
  BITSTREAM_NAME="${PROJECT_NAME}_${SEED}.sof"
fi

BITSTREAM_DST_NAME="$BITSTREAM_DESTINATION/$BITSTREAM_NAME"

# Copy sof.
cp "$PROJECT_OUTPUT_DIRECTORY/$PROJECT_NAME.sof" $BITSTREAM_DST_NAME
echo "Bitstream saved to: $BITSTREAM_DST_NAME"
sha256sum $BITSTREAM_DST_NAME

echo "Done (seed=$SEED)"

# Announce that it is over.
tput bel

read -p "Press press enter to continue"
