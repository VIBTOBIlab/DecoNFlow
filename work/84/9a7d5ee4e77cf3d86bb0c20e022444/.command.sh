#!/bin/bash -euo pipefail
python3 /source/test_preprocessing.py     -i test.csv     -r reference_matrix_0.001_BH_mean.csv     -k 100     -n 1 --celfie
