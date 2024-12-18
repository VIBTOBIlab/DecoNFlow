#!/usr/bin/env nextflow

process PROCESS_REF_MATRIX {
    container 'egiuili/process_ref_matrix:v1'

    label 'process_low'

    input:
    path reference_tsv

    output:
    path 'reference.csv', emit: reference_csv

    script:
    """
    python3 /source/check_file.py $reference_tsv
    """

}