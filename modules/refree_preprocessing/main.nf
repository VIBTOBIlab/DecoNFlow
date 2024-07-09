#!/usr/bin/env nextflow

process REFREE_PREPROCESSING {
    container 'egiuili/refree_preprocessing:v1'

    publishDir "${params.outdir}/refree_preprocessing", mode: 'copy'

    input:
    path test
    path reference

    output:
    path '*.csv', emit: preprocessed_refree
    path '*.out'

    script:
    """
    python3 /source/preprocessing.py \
    -i ${test} \
    -r ${reference} \
    -c ${params.refree_min_cpgs} \
    -g ${params.refree_min_counts} \
    -k ${params.chunk_size}
    """
    
}