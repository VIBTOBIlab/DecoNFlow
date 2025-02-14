#!/usr/bin/env nextflow

process BISMARK_METHYLATIONEXTRACTOR {

    label 'process_high'

    container "quay.io/biocontainers/bismark:0.24.0--hdfd78af_0"

    input:
    tuple val(meta), val(entity), path(bam), path(bai)

    output:
    tuple val(meta), val(entity), path("*.cov.gz")              , emit: coverage

    script:
    def args = ''
    // Assign sensible numbers for multicore and buffer_size based on bismark docs
    if (params.bismark_multicore && task.cpus >= 6){
        args += "--multicore ${(task.cpus / 3) as int}"
    }
    // Only set buffer_size when there are more than 6.GB of memory available
    if (params.bismark_buffer_size && task.memory?.giga > 6){
        args += " --buffer_size ${task.memory.giga - 2}G"
    }
    def seqtype  = params.single_end ? '-s' : '-p'
    """
    samtools sort -@ $task.cpus -n $bam > "${meta}_sorted.bam"
    bismark_methylation_extractor \\
        ${meta}_sorted.bam \\
        --bedGraph \\
        --counts \\
        --gzip \\
        $seqtype \\
        $args
    """
}