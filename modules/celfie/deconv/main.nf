#!/usr/bin/env nextflow

process RUN_DECONV {
    container 'egiuili/celfie:v1.0'

    label 'process_low'    
    
    input:
    path merged_table
    val nsamples

    output:
    path '*tissue_proportions.txt', emit: res

    script:
    """
    python3 /source/celfie.py \
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

