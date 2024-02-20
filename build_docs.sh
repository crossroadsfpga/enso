#!/usr/bin/env bash

# print commands
set -o xtrace

# exit when error occurs
# set -e

ORIGINAL_PWD=$(pwd)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_DIR="$SCRIPT_DIR/.."

cd $REPO_DIR
# ./docs/build_hw_docs.sh
mkdocs build -f mkdocs.yml
