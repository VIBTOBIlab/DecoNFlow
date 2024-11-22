#!/usr/bin/env nextflow

// Define mounting option
def cmd = workflow.containerEngine == 'docker' ? '--volume' : '--bind'

process BUILD {
    container 'egiuili/uxm:v1'

    label 'process_medium'

    containerOptions "$cmd /tmp:/opt/UXM_deconv/tmp_dir"

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