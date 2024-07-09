#!/usr/bin/env nextflow

process MERGE_TABLES {
    container 'egiuili/celfie:v1.0'

    publishDir "${params.outdir}/celfie", mode: 'copy'

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