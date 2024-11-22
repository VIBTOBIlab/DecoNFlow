#!/usr/bin/env nextflow

// Define mounting option
def cmd = workflow.containerEngine == 'docker' ? '--volume' : '--bind'

process BETA_TO_TABLE {
    container 'egiuili/uxm:v1'

    label 'process_low'

    containerOptions "$cmd ${workflow.workDir}:/opt/wgbstools/references"

    input:
    path regions
    path betas
    path groups 
    
    output:
    path "regions_table.tsv", emit: beta_table

    script:
    """    
    wgbstools convert \
    -L $regions \
    -o blocks.bed \

    wgbstools beta_to_table \
    --groups_file $groups \
    --betas $betas \
    --output regions_table.tsv \
    blocks.bed \
    """
}