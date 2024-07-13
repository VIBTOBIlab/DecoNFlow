#!/usr/bin/env nextflow

// Define mounting option
def args = ''
if (workflow.profile=='docker'||
    workflow.profile=='debug,docker' ||
    workflow.profile=='docker,debug') {
    args += '--volume'
} else { args += '--bind'}

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