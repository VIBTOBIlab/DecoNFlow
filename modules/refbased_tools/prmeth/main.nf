#!/usr/bin/env nextflow

process PRMETH {
    container 'egiuili/prmeth:v1'

    label 'process_medium'

    input:
    path reference
    path samples

    output:
    path '*_deconv_output*.csv', emit: output

    script:
    """
    Rscript /source/run_prmeth.R \
    -s ${reference} \
    -m ${samples} \
    -k ${params.clusters} \
    -d ${params.prmeth_mod}
    """
    
}