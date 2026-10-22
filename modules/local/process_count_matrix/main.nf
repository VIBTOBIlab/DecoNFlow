#!/usr/bin/env nextflow

process PROCESS_COUNT_MATRIX {
    conda "conda-forge::pandas==1.5.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:1.5.2' :
        'quay.io/biocontainers/pandas:1.5.2' }"

    label 'process_low'

    input:
    path matrix_tsv

    output:
    path 'count_matrix.csv', emit: atlas

    script:
    """
    check_count_matrix.py $matrix_tsv
    """

}
