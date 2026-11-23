#!/usr/bin/env nextflow

process EPISCORE {
    conda "${moduleDir}/environment.yml"
    container 'egiuili/episcore:v1'

    label 'process_low'

    input:
    path reference
    path samples

    output:
    path '*_deconv_output*.csv', emit: output

    script:
    """
    run_episcore.R -s ${reference} -m ${samples} -w ${params.weight}
    """

}
