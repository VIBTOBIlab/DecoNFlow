#!/usr/bin/env nextflow

process DMRFINDER_PREPROCESSING {

    container 'ubuntu:rolling'

    label 'process_low'

    input:
    tuple val(meta),val(entity),path(cov) 

    output:
    tuple val(meta),val(entity), emit: metadata
    path("${meta}_dmrfinder_format.cov.gz"), emit: dmrfinder_format_sample
 
    
    script:
    """
    zcat $cov | awk -v OFS='\\t' '\$5 + \$6 >= ${params.min_counts}' | \\
    awk '\$1 ~ /^(chr)?(1[0-9]|2[0-2]|[1-9]|X|Y|MT|M)\$/ {print}' | \\
    awk '{print \$1 "\t" \$2 "\t" \$3 "\t" \$4 "\t" \$5 "\t" \$6}' | \\
    gzip > ${meta}_dmrfinder_format.cov.gz 
    """

}