#!/usr/bin/env bash
# Usage ./run_tests.sh

# exit when error occurs
set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command exited with code $?."' EXIT

rm -rf work
rm -f vsim.wlf

vlib work
# vlog ./src/prefetch_rb.sv -sv -lint
# vlog ./src/pcie_top.sv -sv -lint
# vlog ./src/fpga2pcie_.sv -sv -lint
# vlog ./src/*.sv -sv -lint
vlog ./tests/*.sv -sv -lint
#vlog *.v
vlog ./src/common/*.sv -sv
vlog ./src/common/*.v
#vlog ./src/common/esram/synth/esram.v  
#vlog ./src/common/esram/esram_1913/synth/iopll.v  
#vlog ./src/common/esram/esram_1913/synth/esram_esram_1913_a3ainji.sv -sv
#vlog ./src/common/esram/altera_iopll_1930/synth/stratix10_altera_iopll.v
#vlog ./src/common/esram/altera_iopll_1930/synth/esram_altera_iopll_1930_rnqonzq.v

#GUI full debug
# vsim test_prefetch_rb -L altera_mf_ver -L altera_lnsim_ver -L altera_ver -L lpm_ver -L sgate_ver -L fourteennm_ver -L fourteennm_ct1_ver -voptargs="+acc"

#NO GUI
# vsim -L altera_mf_ver -L altera_lnsim_ver -L altera_ver -L lpm_ver -L sgate_ver -L fourteennm_ver -L fourteennm_ct1_ver -voptargs="+acc" -c -do "run -all" test_prefetch_rb
vsim -L altera_mf_ver -L altera_lnsim_ver -L altera_ver -L lpm_ver -L sgate_ver -L fourteennm_ver -L fourteennm_ct1_ver -voptargs="+acc" -c -do "run -all" test_pcie_top

#NO GUI, Optimized, but the stats may not match
#vsim -L altera_mf_ver -L altera_lnsim_ver -L altera_ver -L lpm_ver -L sgate_ver -L fourteennm_ver -L fourteennm_ct1_ver -c -do "run -all" test_prefetch_rb
