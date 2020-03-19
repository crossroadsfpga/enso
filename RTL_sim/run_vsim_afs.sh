#!/bin/sh
rm -r work
rm vsim.wlf

vlib work
vlog ./src/*.sv -sv 
#vlog *.v
vlog ./src/common/*.sv -sv
vlog ./src/common/*.v
#vlog ./src/common/esram/synth/esram.v  
#vlog ./src/common/esram/esram_1913/synth/iopll.v  
#vlog ./src/common/esram/esram_1913/synth/esram_esram_1913_a3ainji.sv -sv
#vlog ./src/common/esram/altera_iopll_1930/synth/stratix10_altera_iopll.v
#vlog ./src/common/esram/altera_iopll_1930/synth/esram_altera_iopll_1930_rnqonzq.v

#GUI full debug
vsim tb -L altera_mf_ver -L altera_lnsim_ver -L altera_ver -L lpm_ver -L sgate_ver -L fourteennm_ver -L fourteennm_ct1_ver -voptargs="+acc"

#NO GUI
#vsim -L altera_mf_ver -L altera_lnsim_ver -L altera_ver -L lpm_ver -L sgate_ver -L fourteennm_ver -L fourteennm_ct1_ver -voptargs="+acc" -c -do "run -all" tb

#NO GUI, Optimized, but the stats may not match
#vsim -L altera_mf_ver -L altera_lnsim_ver -L altera_ver -L lpm_ver -L sgate_ver -L fourteennm_ver -L fourteennm_ct1_ver -c -do "run -all" tb
