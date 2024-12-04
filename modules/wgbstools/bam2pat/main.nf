#!/usr/bin/env nextflow

// Define mounting option
def cmd = workflow.containerEngine == 'docker' ? '--volume' : '--bind'

process BAM2PAT {
    container 'egiuili/uxm:v1'

    label 'process_medium'

    containerOptions "$cmd ${workflow.workDir}:/opt/wgbstools/references"

    input:
    tuple val(meta),val(entity),path(bam),path(bai)
    val ready 
    
    output:
    path "*.pat.gz", emit: pat
    path "*.pat.gz.csi", emit: pat_index
    path "*.beta", emit: beta_file

    script:
    """
    wgbstools bam2pat $bam
    """
}