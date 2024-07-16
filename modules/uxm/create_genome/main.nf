#!/usr/bin/env nextflow

process CREATE_GENOME {
    container 'egiuili/uxm:v1'

    containerOptions { "--volume ${params.output_dir}:/opt/wgbstools/references/" }

    publishDir "${params.output_dir}", mode: 'copy'

    script:
    """
	wgbstools init_genome ${params.genome}
	wgbstools set_default_ref --name ${params.genome}
    """
}
