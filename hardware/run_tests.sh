#!/usr/bin/env bash
# Usage ./run_tests.sh

# exit when error occurs
set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command exited with code $?."' EXIT

declare -a tests=(
    # 'test_pcie_top'
    # 'test_cpu_to_fpga'
    # 'test_queue_manager'
    # 'test_prefetch_rb'
    'test_timestamp'
    # 'test_rate_limiter'
    # 'sketch'
)

sim_lib_path="$HOME/sim_lib/verilog_libs"
altera_ver="$sim_lib_path/altera_ver"
lpm_ver="$sim_lib_path/lpm_ver"
sgate_ver="$sim_lib_path/sgate_ver"
altera_mf_ver="$sim_lib_path/altera_mf_ver"
altera_lnsim_ver="$sim_lib_path/altera_lnsim_ver"
fourteennm_ver="$sim_lib_path/fourteennm_ver"
fourteennm_ct1_ver="$sim_lib_path/fourteennm_ct1_ver"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

rm -rf work
rm -f vsim.wlf

shopt -s globstar  # make sure we match all subdirs

vlib work
vlog ./src/**/*.sv -sv
for t in ${tests[@]}; do
    echo "Compiling $t"
    vlog "./tests/$t.sv" -sv -lint -source | grep --color -e 'Error' -e '^'
done
vlog ./src/common/*.v

# avoid trap
output_if_error() {
    if grep -q -e "Errors: [^0]" out.txt; then
        grep --color -e 'Error' -e '^' out.txt
        printf "${RED}$1 failed!${NC}\n"
        return 1
    fi
    return 0
}

touch out.txt
for t in ${tests[@]}; do
    echo "Running test: $t"
    if [ "$1" = "--gui" ]; then
        # Use the following to activate the modelsim GUI.
        vsim -L $altera_mf_ver -L $altera_lnsim_ver -L $altera_ver -L $lpm_ver \
            -L $sgate_ver -L $fourteennm_ver -L $fourteennm_ct1_ver \
            -voptargs="+acc" $t
    else
        vsim -L $altera_mf_ver -L $altera_lnsim_ver -L $altera_ver -L $lpm_ver \
            -L $sgate_ver -L $fourteennm_ver -L $fourteennm_ct1_ver \
            -voptargs="+acc" -c -do "run -all" $t #> out.txt
    fi
    #output_if_error $t
done

printf "${GREEN}All tests passed${NC}\n"
