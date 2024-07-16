#!/usr/bin/env nextflow

process BAM2PAT {
    //def dir_path = params.fasta_path.lastIndexOf('/') >= 0 ? params.fasta_path.substring(0, params.fasta_path.lastIndexOf('/')) : ""

    container 'wgbstools:v1'
    debug true

    containerOptions { "--volume /Users/edoardogiuili/Library/CloudStorage/OneDrive-UGent/Projects/Maisa_deconv_benchmark/DNAmDeconv:/Users/edoardogiuili/Library/CloudStorage/OneDrive-UGent/Projects/Maisa_deconv_benchmark/DNAmDeconv --volume ./resources/:/opt/wgbstools/references" }

    publishDir "${params.output_dir}/uxm/pat", mode: 'copy'

    output:
    "*pat.gz"

    script:
    """
    wgbstools bam2pat /Users/edoardogiuili/Library/CloudStorage/OneDrive-UGent/Projects/Maisa_deconv_benchmark/DNAmDeconv/resources/samples/bams/sorted_reads/*_new.bam --out_dir ${params.output_dir}
    """
}
