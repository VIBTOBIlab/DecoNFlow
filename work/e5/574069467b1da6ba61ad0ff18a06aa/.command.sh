#!/bin/bash -euo pipefail
Rscript /source/test_DMR.R     -i regions.csv     -p 0.001     -j BH     -c mean
