#!/bin/bash -euo pipefail
Rscript /source/EpiDISH.R -s reference_matrix_0.001_BH_mean.csv -m test_samples.csv -d RPC
