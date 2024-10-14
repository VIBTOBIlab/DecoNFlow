#!/usr/bin/env nextflow

process METDECODE_DECONV {
    container 'egiuili/metdecode:v1'

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
    python3 /source/run.py \
    $atlas \
    $samples \
    output.csv \
    $args
    """
}

