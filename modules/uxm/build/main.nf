#!/usr/bin/env nextflow

process BUILD {
    container 'egiuili/uxm:v1'

    label 'process_high'

    containerOptions "${workflow.containerEngine == 'docker' ? '--volume' : '--bind'} ${workflow.workDir}:/opt/wgbstools/references"

    input:
    path markers
    path groups
    path pats
    path indeces 

    output:
    path "*.tsv", emit: atlas

    script:
    """
    uxm build \
    --markers $markers \
    --pats $pats \
    --groups $groups \
    --tmp_dir /opt/UXM_deconv/tmp_dir \
    --threads $task.cpus \
    --rlen ${params.rlen} \
    -o Atlas.l${params.rlen}.tsv
    """
}