#!/usr/bin/env nextflow

process COMBINE_FILES {
    container 'egiuili/combine_files:v1'

    containerOptions "--volume ${projectDir}:${projectDir}"

    publishDir "${params.outdir}/final_outputs", mode: 'copy'

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