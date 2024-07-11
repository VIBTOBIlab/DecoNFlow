#!/usr/bin/env nextflow

process METHYL_RESOLVER {
    container 'egiuili/methylresolver:v1'

    label 'process_medium'

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