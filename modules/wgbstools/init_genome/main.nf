#!/usr/bin/env nextflow

process INIT_GENOME {
    container 'egiuili/uxm:v1'

    label 'process_high'

    containerOptions "${workflow.containerEngine == 'docker' ? '--volume' : '--bind'} ${workflow.workDir}:/opt/wgbstools/references"

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