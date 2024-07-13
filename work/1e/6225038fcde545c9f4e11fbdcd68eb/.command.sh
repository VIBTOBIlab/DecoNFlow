#!/bin/bash -euo pipefail
Rscript /source/run_medecom.R     -m regions.csv     -k 2     -n 10     -f 10     -r 300     -c 1
