#!/usr/bin/env nextflow

process PREPROCESSING {
    container 'egiuili/preprocessing:v1.0'

    publishDir "${params.output_dir}/preprocessing", mode: 'copy'

    input:
    path file
    path regions

    output:
    path '*.csv', emit: clusters
    path '*.out'

    script:
    """
    python3 /source/preprocessing.py \
    -i ${file} \
    -r ${regions} \
    -c ${params.min_cpgs} \
    -g ${params.min_counts} \
    -f ${params.merging_approach} \
    -k ${params.chunk_size}
    """
    
}