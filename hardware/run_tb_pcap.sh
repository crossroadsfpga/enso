#!/usr/bin/env bash
# Usage ./run_tb_pcap.sh rate pcap nb_fb_queues nb_dsc_queues nb_pkt_queues
# Optionally append --gui to the command to run graphical interface.

# exit when error occurs
set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command exited with code $?."' EXIT

sim_lib_path="$HOME/sim_lib/verilog_libs"
altera_ver="$sim_lib_path/altera_ver"
lpm_ver="$sim_lib_path/lpm_ver"
sgate_ver="$sim_lib_path/sgate_ver"
altera_mf_ver="$sim_lib_path/altera_mf_ver"
altera_lnsim_ver="$sim_lib_path/altera_lnsim_ver"
fourteennm_ver="$sim_lib_path/fourteennm_ver"
fourteennm_ct1_ver="$sim_lib_path/fourteennm_ct1_ver"

RATE=$1
PCAP_FILE=$2
NB_FALLBACK_QS=$3
NB_DSC_QS=$4
NB_PKT_QS=$5

PCAP_FILE=$(readlink -f $PCAP_FILE)
PKT_FILE_BASE_NAME=$(basename $PCAP_FILE)
PKT_FILE="./input_gen/${PKT_FILE_BASE_NAME}.pkt"
if [[ -f "$PKT_FILE" ]]; then
    echo "$PKT_FILE exists, using cache"
else
    echo "Generating $PKT_FILE"
    cd "./input_gen"
    ./run.sh ${PCAP_FILE} "${PKT_FILE_BASE_NAME}.pkt"
    cd -
fi

echo "Using:"
echo "$NB_FALLBACK_QS fallback queues"
echo "$NB_DSC_QS dsc queues"
echo "$NB_PKT_QS pkt queues"

pwd
PKT_FILE_NB_LINES=$(wc -l < $PKT_FILE)

rm -rf work
rm -f vsim.wlf

shopt -s globstar  # make sure we match all subdirs

vlib work
vlog +define+SIM ./src/**/*.sv -sv
vlog +define+SIM ./src/**/*.v
vlog +define+SIM \
     +define+RATE=$RATE \
     +define+PKT_FILE=\"$PKT_FILE\" \
     +define+PKT_FILE_NB_LINES=$PKT_FILE_NB_LINES \
     +define+NB_FALLBACK_QUEUES=$NB_FALLBACK_QS \
     +define+NB_DSC_QUEUES=$NB_DSC_QS \
     +define+NB_PKT_QUEUES=$NB_PKT_QS \
     ./tests/tb.sv -sv

VSIM_CMD="run -all"
# VSIM_CMD="set BreakOnAssertion 2; run -all"

if [ "$6" = "--gui" ]; then
    # Use the following to activate the modelsim GUI.
    vsim -L $altera_mf_ver -L $altera_lnsim_ver -L $altera_ver -L $lpm_ver \
        -L $sgate_ver -L $fourteennm_ver -L $fourteennm_ct1_ver \
        -voptargs="+acc" tb
else
    vsim -L $altera_mf_ver -L $altera_lnsim_ver -L $altera_ver -L $lpm_ver \
        -L $sgate_ver -L $fourteennm_ver -L $fourteennm_ct1_ver \
        -voptargs="+acc" -c -do "$VSIM_CMD" tb | grep --color -e 'Error' -e '^'
fi
