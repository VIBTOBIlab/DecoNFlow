#!/usr/bin/env nextflow

process METDECODE_DECONV {
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/metdecode:1.0.1--pyhdfd78af_0' :
        'quay.io/biocontainers/metdecode:1.0.1--pyhdfd78af_0' }"

    label 'process_low'

    input:
    path atlas
    path samples

    output:
    path 'output.csv', emit: res

    script:
    def args = ""
    if (params.unknown_tissues) {
        args += "-n-unknown-tissues ${params.unknown_tissues}"
    }
    if (params.sum1) {
        args += " --sum1"
    }
    if (params.no_coverage) {
        args += " --no-coverage"
    }
    if (params.supervised) {
        args += " --supervised"
    }
    """
    run_metdecode.py \
    $atlas \
    $samples \
    output.csv \
    $args
    """
}
