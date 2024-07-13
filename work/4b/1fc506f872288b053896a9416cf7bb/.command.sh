#!/bin/bash -euo pipefail
python3 /source/run_deconv.py -a reference_matrix_0.001_BH_mean.csv test_samples.csv --residuals
