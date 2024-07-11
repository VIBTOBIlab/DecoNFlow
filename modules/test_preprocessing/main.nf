#!/usr/bin/env nextflow

process TEST_PREPROCESSING {
    container 'egiuili/test_preprocessing:v1.0'

    label 'process_high_memory'

    input:
    path test
    path reference

    output:
    path 'test_samples.csv', emit: preprocessed_test
    path 'celfie*.csv', emit: celfie_test, optional: true
    path '*.out'

    script:
    def args = "-n ${task.cpus}"
    if (params.celfie || params.benchmark) {
        args += ' --celfie'
    }
    """
    python3 /source/test_preprocessing.py \
    -i ${test} \
    -r ${reference} \
    -k ${params.chunk_size} \
    $args
    """
    
}