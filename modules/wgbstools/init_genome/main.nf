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

process INIT_GENOME {
    container 'egiuili/uxm:v1'

    label 'process_high'

    containerOptions "$cmd /tmp:/opt/wgbstools/references"

    input:
    path fasta, stageAs: "default/*"

    output:
    path "default", emit: ref

    script:
    def args = ""
    if (params.fasta) {
        args += "--fasta_path ${fasta}"
    }
    """
    wgbstools init_genome ${params.genome} $args -f
    """
}