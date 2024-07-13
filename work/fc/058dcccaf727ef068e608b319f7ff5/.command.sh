#!/bin/bash -euo pipefail
Rscript /source/run_prmeth.R     -s reference_matrix_0.001_BH_mean.csv     -m test_samples.csv     -k 2     -d QP
