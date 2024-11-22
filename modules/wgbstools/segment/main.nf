#!/usr/bin/env nextflow

// Define mounting option
def cmd = workflow.containerEngine == 'docker' ? '--volume' : '--bind'

process SEGMENT {
    container 'egiuili/uxm:v1'

    label 'process_medium'

    containerOptions "$cmd ${workflow.workDir}:/opt/wgbstools/references"

    input:
    path betas

    output:
    path "blocks.bed", emit: blocks

    script:
    """
    wgbstools segment \
    --betas $betas \
    --min_cpg ${params.min_cpg_uxm} \
    --max_bp ${params.max_bp} \
    -o blocks.bed
    """
}