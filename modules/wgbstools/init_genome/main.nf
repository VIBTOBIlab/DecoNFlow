#!/usr/bin/env nextflow

// Define mounting option
def cmd = workflow.containerEngine == 'docker' ? '--volume' : '--bind'

process INIT_GENOME {
    container 'egiuili/uxm:v1'

    label 'process_high'

    containerOptions "$cmd ${workflow.workDir}:/opt/wgbstools/references"

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