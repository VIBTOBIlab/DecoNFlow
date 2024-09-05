#!/usr/bin/env nextflow

process MERGE_TABLES {
    container 'egiuili/celfie:v3.0'

    label 'process_low'

    input:
    path ref_matrix
    path test_matrix

    output:
    path 'celfie_matrix.txt', emit: merged_table

    script:
    """
    python3 /source/merge_tables.py \
    -i ${ref_matrix} \
    -t ${test_matrix} \
    """

}