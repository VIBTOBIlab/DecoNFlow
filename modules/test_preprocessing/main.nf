#!/usr/bin/env nextflow

process TEST_PREPROCESSING {
    container 'egiuili/test_preprocessing:v1.0'

    publishDir "${params.output_dir}/test_preprocessing", mode: 'copy'

    input:
    path test
    path reference

    output:
    path '*.csv', emit: preprocessed_test
    path '*.out'

    script:
    """
    python3 /source/test_preprocessing.py \
    -i ${test} \
    -r ${reference} \
    -k ${params.chunk_size} \
    """
    
}