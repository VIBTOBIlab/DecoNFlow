#!/usr/bin/env nextflow

process METHYL_RESOLVER {
    conda "${moduleDir}/environment.yml"
    container 'egiuili/methylresolver:v1'

    label 'process_low'

    input:
    path reference
    path samples

    output:
    path '*_deconv_output*.csv', emit: output

    script:
    """
    run_methylresolver.R -s ${reference} -m ${samples} -a ${params.alpha}
    """

}
