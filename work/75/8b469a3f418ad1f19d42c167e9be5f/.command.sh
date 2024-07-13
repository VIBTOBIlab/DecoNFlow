#!/bin/bash -euo pipefail
Rscript /source/run_prmeth.R     -s regions.csv     -m regions.csv     -k 2     -d RF
