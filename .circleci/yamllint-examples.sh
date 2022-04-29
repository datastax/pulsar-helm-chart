#!/usr/bin/env bash

set -o errexit

mkdir -p yamllint/examples/
rm -f yamllint/examples/*.yaml

for FILE in examples/*.yaml; do
  helm template pulsar-test -f $FILE helm-chart-sources/pulsar > yamllint/$FILE
done

# Lint all files in output directory
yamllint yamllint/