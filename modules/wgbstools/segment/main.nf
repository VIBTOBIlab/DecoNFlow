#!/usr/bin/env nextflow

process SEGMENT {
    container 'egiuili/uxm:v1'

    label 'process_high'

    containerOptions "${workflow.containerEngine == 'docker' ? '--volume' : '--bind'} ${workflow.workDir}:/opt/wgbstools/references"

    input:
    path betas

    output:
    path "blocks.bed", emit: blocks

    script:
    def args = ''
    args += "-@ ${task.cpus as int}"
    """
    wgbstools segment \
    --betas $betas \
    --min_cpg ${params.min_cpg_uxm} \
    --max_bp ${params.max_bp} \
    -o blocks.bed \
    $args
    """
}