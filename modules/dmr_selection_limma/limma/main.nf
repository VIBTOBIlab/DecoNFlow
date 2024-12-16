#!/usr/bin/env nextflow

process LIMMA {
    container 'egiuili/dmr_analysis:v3.0'

    label 'process_low'

    input:
    path clusters

    output:
    path 'reference_matrix*.csv', emit: reference_csv
    path 'reference_matrix*.tsv', emit: reference_tsv
    path 'dmrs*.csv'
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
    Rscript /source/test_DMR.R \
    -i ${clusters} \
    -p ${params.adjp} \
    -j ${params.adj_method} \
    -c ${params.collapse_method} \
    $args
    """
    
}