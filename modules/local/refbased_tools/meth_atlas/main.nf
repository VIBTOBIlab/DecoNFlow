#!/usr/bin/env nextflow

process METH_ATLAS {
    conda "${moduleDir}/environment.yml"
    container 'egiuili/methyl_atlas:v1.0'

    label 'process_medium'

    input:
    path reference
    path samples

    output:
    path '*_deconv_output.csv', emit: output
    path '*_residuals.csv'

    script:
    """
    run_deconv.py -a ${reference} ${samples} --residuals
    """

}
