#!/bin/bash -euo pipefail
python3 /source/run_deconv.py -a reference_matrix_None_None_0.001_BH_mean.csv test_samples.csv --residuals
