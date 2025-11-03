#!/usr/bin/env nextflow

process FINDMARKERS {
    container 'egiuili/uxm:v1'

    label 'process_high'

    input:
    path blocks
    path groups
    path betas

    output:
    path "MarkersAll.bed", emit: markers

    script:
    def args = ""
    args += "-@ ${(task.cpus) as int}"
    def delta = params.delta
    def pval = params.adjp
    if (params.only_hypo) {
        args += ' --only_hypo'
    }
    if (params.DMRselection!="wgbstools"){
        pval = 1
        delta = 0
    }
    if (params.top) {
        args += " --top ${params.top}"
    }
    
    """
    wgbstools find_markers \
    --blocks_path $blocks \
    --groups_file $groups \
    --betas $betas \
    --delta_means $delta \
    --pval $pval \
    --min_cov ${params.min_counts} \
    --min_cpg ${params.min_cpgs} \
    --sort_by delta_means \
    $args
    
    awk 'FNR==1 && NR!=1 { next; } { print }' Markers*.bed > MarkersAll.bed
    """
}