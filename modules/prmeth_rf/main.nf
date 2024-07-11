#!/usr/bin/env nextflow

process PRMETH_RF {
    container 'egiuili/prmeth:v1'

    label 'process_medium'

    input:
    path samples

    output:
    path '*_deconv_output*.csv', emit: output

    script:
    """
    Rscript /source/run_prmeth.R \
    -s ${samples} \
    -m ${samples} \
    -k ${params.clusters} \
    -d RF
    """
    
}