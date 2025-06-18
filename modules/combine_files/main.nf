#!/usr/bin/env nextflow

process COMBINE_FILES {
    container 'egiuili/python3-3.9.16:v1'

    label 'process_low'

    input:
    tuple val(names), path(proportions, stageAs: "?/*")

    output:
    path '*.csv', emit: clusters
    
    script:
    """
    combine_files.py \
    --tool_names ${names.join(' ')} \
    --results $proportions \
    -o combined_results
    """
    
}