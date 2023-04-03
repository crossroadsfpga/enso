#!/usr/bin/env bash

# print commands
set -o xtrace

# exit when error occurs
set -e

ORIGINAL_PWD=$(pwd)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_DIR="$SCRIPT_DIR/.."

HARDWARE_PATH="$REPO_DIR/hardware/src"
HDL_DOC_PATH="$REPO_DIR/docs/hardware/modules"

TEROS_HDL_COMMON_OPTS="\
    --dep \
    --fsm \
    --signals only_commented \
    --constants only_commented \
    --process only_commented \
    --functions only_commented \
    --symbol_verilog / \
    --out markdown \
"

rm -rf $HDL_DOC_PATH

ls -al

# Build hardware docs.
teroshdl-hdl-documenter $TEROS_HDL_COMMON_OPTS \
    --input $HARDWARE_PATH \
    --outpath "$REPO_DIR/docs/out" \
    # --recursive

# Build hardware PCIe docs.
teroshdl-hdl-documenter $TEROS_HDL_COMMON_OPTS \
    --input "$HARDWARE_PATH/pcie" \
    --outpath "$REPO_DIR/docs/out/pcie"

mv "$REPO_DIR/docs/out/doc_internal" "$REPO_DIR/docs/hardware/modules"
mv "$REPO_DIR/docs/out/pcie/doc_internal" "$REPO_DIR/docs/hardware/modules/pcie"

cd $REPO_DIR
mkdocs build -f mkdocs.yml
