#!/usr/bin/env nextflow


process INIT_GENOME {
    def dir_path = params.fasta_path.lastIndexOf('/') >= 0 ? params.fasta_path.substring(0, params.fasta_path.lastIndexOf('/')) : ""

    container 'wgbstools:v1'

    containerOptions { "--volume ${dir_path}:/opt/wgbstools/references/" }

    input:
    path genome

    publishDir "${params.output_dir}", mode: 'copy'

    script:
    """
	wgbstools init_genome ${params.genome} --fasta_path ${genome}
	wgbstools set_default_ref --name ${params.genome}
    """
}
