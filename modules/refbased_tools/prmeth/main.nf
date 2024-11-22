#!/usr/bin/env nextflow

process PRMETH {
    container 'egiuili/prmeth:v2'

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
    -k ${params.prmeth_NMF_entities} \
    -d ${params.prmeth_mod}
    """
    
}