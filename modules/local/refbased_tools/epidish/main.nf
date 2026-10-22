#!/usr/bin/env nextflow

process EPIDISH {
    conda "bioconda::bioconductor-epidish==2.22.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bioconductor-epidish:2.22.0--r44hdfd78af_0' :
        'quay.io/biocontainers/bioconductor-epidish:2.22.0--r44hdfd78af_0' }"

    label 'process_low'

    input:
    path ref_path
    path samples_path

    output:
    path 'epidish_res_*.csv', emit: output

    script:
    """
    EpiDISH.R -s ${ref_path} -m ${samples_path} -d "RPC"
    """

}
