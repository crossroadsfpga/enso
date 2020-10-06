#!/usr/bin/env bash
# Usage ./run_vsim_afs.sh [input.pkt]
# Usage ./run_vsim_afs.sh nb_pkts pkt_size nb_dest

# exit when error occurs
set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command exited with code $?."' EXIT

if [ "$#" -eq 3 ]; then
    PKT_FILE="./input_gen/$1_$2_$3.pkt"
    if [[ -f "$PKT_FILE" ]]; then
        echo "$PKT_FILE exists, using cache"
    else
        echo "Generating $PKT_FILE"
        cd "./input_gen"
        ./generate_synthetic_trace.py $1 $2 $3 "$1_$2_$3.pcap"
        ./run.sh "$1_$2_$3.pcap" "$1_$2_$3.pkt"
        cd -
    fi
    NB_QUEUES=$3
else
    # if pkt file not specified, use the default
    PKT_FILE=${1:-"./input_gen/small_pkt_100.pkt"}
    NB_QUEUES=${2:-"1"}
fi

echo "Using $NB_QUEUES queues"

pwd
PKT_FILE_NB_LINES=$(wc -l < $PKT_FILE)

rm -rf work
rm -f vsim.wlf

vlib work
vlog +define+SIM +define+PKT_FILE=\"$PKT_FILE\" \
     +define+PKT_FILE_NB_LINES=$PKT_FILE_NB_LINES \
     +define+NB_QUEUES=$NB_QUEUES \
     ./src/*.sv -sv 
#vlog *.v
vlog +define+SIM ./src/common/*.sv -sv
vlog +define+SIM ./src/common/*.v
#vlog ./src/common/esram/synth/esram.v  
#vlog ./src/common/esram/esram_1913/synth/iopll.v  
#vlog ./src/common/esram/esram_1913/synth/esram_esram_1913_a3ainji.sv -sv
#vlog ./src/common/esram/altera_iopll_1930/synth/stratix10_altera_iopll.v
#vlog ./src/common/esram/altera_iopll_1930/synth/esram_altera_iopll_1930_rnqonzq.v

#GUI full debug
# vsim tb -L altera_mf_ver -L altera_lnsim_ver -L altera_ver -L lpm_ver -L sgate_ver -L fourteennm_ver -L fourteennm_ct1_ver -voptargs="+acc"

#NO GUI
vsim -L altera_mf_ver -L altera_lnsim_ver -L altera_ver -L lpm_ver -L sgate_ver -L fourteennm_ver -L fourteennm_ct1_ver -voptargs="+acc" -c -do "run -all" tb

#NO GUI, Optimized, but the stats may not match
#vsim -L altera_mf_ver -L altera_lnsim_ver -L altera_ver -L lpm_ver -L sgate_ver -L fourteennm_ver -L fourteennm_ct1_ver -c -do "run -all" tb
