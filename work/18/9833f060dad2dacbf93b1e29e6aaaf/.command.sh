#!/bin/bash -euo pipefail
Rscript /source/run_episcore.R -s reference_matrix_None_None_0.001_BH_mean.csv -m test_samples.csv -w 0.4
