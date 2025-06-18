#!/usr/bin/env nextflow

process LIMMA {
    container 'egiuili/r-v4.4.1:v1'

    label 'process_low'

    input:
    path clusters

    output:
    path 'reference_matrix_limma.csv', emit: reference_csv
    path 'reference_matrix_limma.tsv', emit: reference_tsv
    path '*.out'

    script:
    def args = ''
    if (params.direction) {
        args += "-d ${params.direction}"
        if (params.top) {
        args += " -t ${params.top}"
    }
    }
    """
    test_DMR.R \
    -i ${clusters} \
    -p ${params.adjp} \
    -j ${params.adj_method} \
    -c ${params.collapse_method} \
    $args
    """
    
}