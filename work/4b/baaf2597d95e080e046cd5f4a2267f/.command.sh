#!/bin/bash -euo pipefail
Rscript /source/EpiDISH.R -s reference_matrix_None_None_0.001_BH_mean.csv -m test_samples.csv -d RPC
