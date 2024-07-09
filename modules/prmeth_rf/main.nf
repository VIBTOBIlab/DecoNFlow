#!/usr/bin/env nextflow

process PRMETH_RF {
    container 'egiuili/prmeth:v1'

    publishDir "${params.outdir}/prmeth", mode: 'copy'

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