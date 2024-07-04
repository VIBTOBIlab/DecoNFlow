#!/usr/bin/env nextflow

process PREPROCESSING {
    container 'egiuili/preprocessing:v1.0'

    publishDir "${params.output_dir}/preprocessing", mode: 'copy'

    input:
    path file
    path regions

    output:
    path 'regions.csv', emit: clusters
    path 'celfie_regions.csv', emit: celfie_ref
    path '*.out'
    
    script:
    def celfie_flag = params.celfie ? "--celfie" : ""
    """
    python3 /source/preprocessing.py \
    -i ${file} \
    -r ${regions} \
    -c ${params.min_cpgs} \
    -g ${params.min_counts} \
    -f ${params.merging_approach} \
    -k ${params.chunk_size} \
    ${celfie_flag}
    """
    
}