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