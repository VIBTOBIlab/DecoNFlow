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

process BAM2PAT {
    container 'egiuili/uxm:v1'

    label 'process_medium'

    containerOptions "$cmd /tmp:/opt/wgbstools/references"

    input:
    tuple val(meta),val(entity),path(bam),path(bai)
    path ref 
    
    output:
    path "*.pat.gz", emit: pat
    path "*.pat.gz.csi", emit: pat_index
    path "*.beta", emit: beta_file

    script:
    """
    wgbstools bam2pat $bam
    """
}