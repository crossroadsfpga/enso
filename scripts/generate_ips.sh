#!/usr/bin/env bash

# exit when error occurs
set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command exited with code $?."' EXIT

PROJECT_NAME="enso"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_DIR=$SCRIPT_DIR/..

cd $REPO_DIR/hardware/ip

generate_ip () {
    rm -rf $1
    rm -rf $1.ip
    qsys-script --script=$1.tcl --quartus-project=../quartus/enso.qsf
}

generate_ip alt_ehipc2_jtag_avalon
generate_ip alt_ehipc2_sys_pll
generate_ip ex_100G
generate_ip my_pll
generate_ip probe8
generate_ip reset_ip

rm -rf ip
rm -rf pcie_ed.qsys
rm -rf pcie_ed
qsys-script --script=pcie_ed.tcl --quartus-project=../quartus/enso.qsf

PROJECT_DIR=$REPO_DIR/hardware

cd $PROJECT_DIR/quartus

# Generate IPs.
quartus_ipgenerate $PROJECT_NAME

# We must copy the pcie_generic_component_0.v.template to the correct location.
cp $PROJECT_DIR/ip/pcie_generic_component_0.v.template \
    $PROJECT_DIR/ip/pcie_ed/generic_component_0/synth/generic_component_0.v
