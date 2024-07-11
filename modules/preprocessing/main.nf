#!/usr/bin/env nextflow

process PREPROCESSING {
    container 'egiuili/preprocessing:v1.0'

    label 'process_high_memory'

    input:
    path file
    path regions

    output:
    path 'regions.csv', emit: clusters
    path 'celfie_regions.csv', emit: celfie_ref, optional: true
    path '*.out'
    
    script:
    def args = "-n ${task.cpus}"
    if (params.celfie || params.benchmark) {
        args += ' --celfie'
    }
    """
    python3 /source/preprocessing.py \
    -i ${file} \
    -r ${regions} \
    -c ${params.min_cpgs} \
    -g ${params.min_counts} \
    -f ${params.merging_approach} \
    -k ${params.chunk_size} \
    $args
    """
    
}