#!/usr/bin/env nextflow

process PRMETH {
    container 'egiuili/prmeth:v1'

    publishDir "${params.output_dir}/prmeth", mode: 'copy'

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
    -k ${params.ncells} \
    -d ${params.prmeth_mod}
    """
    
}