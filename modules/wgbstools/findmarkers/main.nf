#!/usr/bin/env nextflow

process FINDMARKERS {
    container 'egiuili/uxm:v1'

    label 'process_medium'

    input:
    path blocks
    path groups
    path betas

    output:
    path "MarkersAll.bed", emit: markers

    script:
    def args = ''
    def delta = params.delta
    def pval = params.adjp
    if (params.only_hypo) {
        args += '--only_hypo'
    }
    if (params.DMRselection!="wgbstools"){
        pval = 1
        delta = 0
    }
    """
    wgbstools find_markers \
    --blocks_path $blocks \
    --groups_file $groups \
    --betas $betas \
    --delta_means $delta \
    --pval $pval \
    $args
    
    awk 'FNR==1 && NR!=1 { next; } { print }' Markers*.bed > MarkersAll.bed
    """
}