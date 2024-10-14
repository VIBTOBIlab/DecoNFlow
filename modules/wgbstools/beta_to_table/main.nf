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

process BETA_TO_TABLE {
    container 'egiuili/uxm:v1'

    label 'process_low'

    containerOptions "$cmd /tmp:/opt/wgbstools/references"

    input:
    path regions
    path betas
    path groups 
    
    output:
    path "regions_table.tsv", emit: beta_table

    script:
    """
    awk 'BEGIN{FS=OFS="\\t"} NR>1 {\$1="chr"\$1; print}' $regions > regions_chr.bed
    
    wgbstools convert \
    -L regions_chr.bed \
    -o blocks.bed \

    wgbstools beta_to_table \
    --groups_file $groups \
    --betas $betas \
    --output regions_table.tsv \
    blocks.bed \
    """
}