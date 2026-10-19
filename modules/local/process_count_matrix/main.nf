#!/usr/bin/env nextflow

process PROCESS_COUNT_MATRIX {
    container 'egiuili/python3-3.9.16:v1'

    label 'process_low'

    input:
    path matrix_tsv

    output:
    path 'count_matrix.csv', emit: atlas

    script:
    """
    check_count_matrix.py $matrix_tsv
    """

}
