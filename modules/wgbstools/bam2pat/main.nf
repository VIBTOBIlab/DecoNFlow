#!/usr/bin/env nextflow

process BAM2PAT {
    container 'egiuili/uxm:v1'
    
    containerOptions "${workflow.containerEngine == 'docker' ? '--volume' : '--bind'} ${workflow.workDir}:/opt/wgbstools/references"

    label 'process_high'

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