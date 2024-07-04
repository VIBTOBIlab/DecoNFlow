#!/usr/bin/env nextflow

process TEST_PREPROCESSING {
    container 'egiuili/test_preprocessing:v1.0'

    publishDir "${params.output_dir}/test_preprocessing", mode: 'copy'

    input:
    path test
    path reference

    output:
    path 'test_samples.csv', emit: preprocessed_test
    path 'celfie*.csv', emit: celfie_test
    path '*.out'

    script:
    def celfie_flag = params.celfie ? "--celfie" : ""
    """
    python3 /source/test_preprocessing.py \
    -i ${test} \
    -r ${reference} \
    -k ${params.chunk_size} \
    ${celfie_flag}
    """
    
}