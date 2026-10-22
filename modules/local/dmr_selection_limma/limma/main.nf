#!/usr/bin/env nextflow

process LIMMA {
    conda "bioconda::bioconductor-limma==3.62.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bioconductor-limma:3.62.1--r44h15a9599_1' :
        'quay.io/biocontainers/bioconductor-limma:3.62.1--r44h15a9599_1' }"

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
    -m ${params.min_delta_beta} \
    -j ${params.adj_method} \
    -c ${params.collapse_method} \
    $args
    """

}
