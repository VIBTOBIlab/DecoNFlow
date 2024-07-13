#!/bin/bash -euo pipefail
Rscript /source/run_cibersort.R -s reference_matrix_0.001_BH_mean.csv -m test_samples.csv
