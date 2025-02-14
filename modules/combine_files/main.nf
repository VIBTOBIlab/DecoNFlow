#!/usr/bin/env nextflow

// Define mounting option
def args = workflow.containerEngine == 'docker' ? '--volume' : '--bind'

process COMBINE_FILES {
    container 'egiuili/python3-3.9.16:v1'

    containerOptions "$args ${projectDir}:${projectDir}"

    label 'process_low'

    input:
    val files

    output:
    path '*.csv', emit: clusters
    
    script:
    """
    combine_files.py \
    "${files}" \
    -o combined_results
    """
    
}