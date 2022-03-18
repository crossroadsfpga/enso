#!/usr/bin/env bash

set -e

python3 setup.py sdist bdist_wheel
twine check dist/*
twine upload dist/*
