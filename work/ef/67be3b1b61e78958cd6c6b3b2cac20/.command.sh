#!/bin/bash -euo pipefail
python3 /source/preprocessing.py     -i test.csv     -r RRBS_regions20-200.bed     -c 3     -g 10     -k 100
