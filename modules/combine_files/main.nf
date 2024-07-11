#!/usr/bin/env nextflow

process COMBINE_FILES {
    container 'egiuili/combine_files:v1'

    label 'process_low'

    containerOptions "--volume ${projectDir}:${projectDir}"

    input:
    val files

    output:
    path '*.csv', emit: clusters
    
    script:
    """
    python3 /source/combine_files.py \
    "${files}" \
    -o combined_results
    """
    
}