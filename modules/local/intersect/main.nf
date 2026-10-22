#!/usr/bin/env nextflow

process INTERSECT {

    conda "conda-forge::pandas==1.5.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:1.5.2' :
        'quay.io/biocontainers/pandas:1.5.2' }"

    label 'process_low'

    input:
    path atlas
    path samples

    output:
    path 'atlas.csv', emit: atlas
    path 'samples.csv', emit: samples

    script:
    """
    intersect.py \
    -i $atlas \
    -t $samples \
    """
}
