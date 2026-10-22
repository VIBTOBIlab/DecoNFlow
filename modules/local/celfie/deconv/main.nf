#!/usr/bin/env nextflow

process RUN_DECONV {
    conda "conda-forge::pandas==1.5.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:1.5.2' :
        'quay.io/biocontainers/pandas:1.5.2' }"

    label 'process_low'

    input:
    path merged_table
    val nsamples

    output:
    path '*tissue_proportions.txt', emit: res

    script:
    """
    celfie.py \
    ${merged_table} \
    ${params.outdir} \
    ${nsamples} \
    -m ${params.celfie_maxiter} \
    -u ${params.unknown} \
    -c ${params.converg} \
    -r ${params.celfie_randrest} \
    -p ${params.parall_job} \
    """
}
