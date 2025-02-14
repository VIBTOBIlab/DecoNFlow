#!/usr/bin/env nextflow

process PROCESS_REF_MATRIX {
    container 'egiuili/python3-3.9.16:v1'

    label 'process_low'

    input:
    path reference_tsv

    output:
    path 'reference.csv', emit: reference_csv

    script:
    """
    check_file.py $reference_tsv
    """

}