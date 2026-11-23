#!/usr/bin/env nextflow

process PROCESS_REF_MATRIX {
    conda "conda-forge::pandas==1.5.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:1.5.2' :
        'quay.io/biocontainers/pandas:1.5.2' }"

    label 'process_low'

    input:
    path reference_tsv

    output:
    path 'reference.csv', emit: reference_csv

    script:
    """
    check_file.py $reference_tsv
    """

}
