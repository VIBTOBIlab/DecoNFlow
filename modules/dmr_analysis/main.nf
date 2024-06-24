#!/usr/bin/env nextflow

process DMR_ANALYSIS {
    container 'egiuili/dmr_analysis:v1.0'

    publishDir "${params.output_dir}/dmr_analysis", mode: 'copy'

    input:
    path clusters

    output:
    path 'reference_matrix*.csv', emit: reference
    path 'dmrs*.csv'
    path '*.out'

    script:
    """
    Rscript /source/test_DMR.R \
    -i ${clusters} \
    -p ${params.adjp} \
    -j ${params.adj_method} \
    -c ${params.collapse_method} \
    -d ${params.direction} \
    -t ${params.top} \
    """
    
}