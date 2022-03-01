#!/usr/bin/env bash
# Run testbench generating packets in a way that we send packets to the same
# queue `batch_size` at a time.
# Usage: ./run_tb_batch.sh rate nb_pkts pkt_size nb_dsc_queues nb_pkt_queues \
#        batch_size
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

RATE=${1:-"100"}

NB_PKTS=$2
PKT_SIZE=$3
NB_DSC_QS=$4
NB_PKT_QS=$5
BATCH_SIZE=${6:-"64"}
PKT_FILE_BASE_NAME="batch_${NB_PKTS}_${PKT_SIZE}_${NB_DSC_QS}_${NB_PKT_QS}_${BATCH_SIZE}"
PKT_FILE="./input_gen/${PKT_FILE_BASE_NAME}.pkt"
if [[ -f "$PKT_FILE" ]]; then
    echo "$PKT_FILE exists, using cache"
else
    echo "Generating $PKT_FILE"
    cd "./input_gen"
    ./generate_synthetic_trace.py ${NB_PKTS} ${PKT_SIZE} ${NB_DSC_QS} \
        ${NB_PKT_QS} "${PKT_FILE_BASE_NAME}.pcap" ${BATCH_SIZE}
    ./run.sh "${PKT_FILE_BASE_NAME}.pcap" "${PKT_FILE_BASE_NAME}.pkt"
    cd -
fi

echo "Using $NB_DSC_QS descriptor queues and $NB_PKT_QS packet queues."

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
     +define+NB_DSC_QUEUES=$NB_DSC_QS \
     +define+NB_PKT_QUEUES=$NB_PKT_QS \
     +define+PKT_SIZE=$PKT_SIZE \
     ./tests/tb.sv -sv

if [ "$7" = "--gui" ]; then
    # Use the following to activate the modelsim GUI.
    vsim -L $altera_mf_ver -L $altera_lnsim_ver -L $altera_ver -L $lpm_ver \
        -L $sgate_ver -L $fourteennm_ver -L $fourteennm_ct1_ver \
        -voptargs="+acc" tb
else
    vsim -L $altera_mf_ver -L $altera_lnsim_ver -L $altera_ver -L $lpm_ver \
        -L $sgate_ver -L $fourteennm_ver -L $fourteennm_ct1_ver \
        -voptargs="+acc" -c -do "run -all" tb | grep --color -e 'Error' -e '^'
fi
