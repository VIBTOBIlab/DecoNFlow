#!/usr/bin/env nextflow

process METHYL_ATLAS {
    container 'egiuili/methyl_atlas:v1.0'

    publishDir "${params.outdir}/methyl_atlas", mode: 'copy'

    input:
    path reference
    path samples

    output:
    path '*_deconv_output.csv', emit: output
    path '*_residuals.csv'

    script:
    """
    python3 /source/run_deconv.py -a ${reference} ${samples} --residuals
    """
    
}