#!/bin/bash -euo pipefail
python3 /source/test_preprocessing.py     -i test.csv     -r reference_matrix_None_None_0.001_BH_mean.csv     -k 100     --celfie
