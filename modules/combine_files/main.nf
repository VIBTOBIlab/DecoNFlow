#!/usr/bin/env nextflow

// Define mounting option
def args = workflow.containerEngine == 'docker' ? '--volume' : '--bind'

process COMBINE_FILES {
    container 'egiuili/combine_files:v1'

    containerOptions "$args ${projectDir}:${projectDir}"

    label 'process_low'

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