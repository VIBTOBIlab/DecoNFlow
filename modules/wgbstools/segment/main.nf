#!/usr/bin/env nextflow

// Define mounting option
def cmd = ''
if (workflow.profile=='docker'||
    workflow.profile=='debug,docker' ||
    workflow.profile=='docker,debug' ||
    workflow.profile=='test,docker' ||
    workflow.profile=='docker,test') {
    cmd += '--volume'
} else { cmd += '--bind'}

process SEGMENT {
    container 'egiuili/uxm:v1'

    label 'process_medium'

    containerOptions "$cmd /tmp:/opt/wgbstools/references"

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