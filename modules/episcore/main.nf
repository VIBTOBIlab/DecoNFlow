#!/usr/bin/env nextflow

process EPISCORE {
    container 'egiuili/episcore:v1'

    label 'process_medium'

    input:
    path reference
    path samples

    output:
    path '*_deconv_output*.csv', emit: output

    script:
    """
    Rscript /source/run_episcore.R -s ${reference} -m ${samples} -w ${params.weight}
    """
    
}