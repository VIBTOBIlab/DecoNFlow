#!/usr/bin/env nextflow

process METHYL_RESOLVER {
    container 'egiuili/methylresolver:v1'

    publishDir "${params.output_dir}/methyl_resolver", mode: 'copy'

    input:
    path reference
    path samples

    output:
    path '*_deconv_output*.csv', emit: output

    script:
    """
    Rscript /source/run_methylresolver.R -s ${reference} -m ${samples} -a ${params.alpha}
    """
    
}