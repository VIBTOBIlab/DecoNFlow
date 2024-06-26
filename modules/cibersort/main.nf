#!/usr/bin/env nextflow

process CIBERSORT {
    container 'egiuili/cibersort:v1.0'

    publishDir "${params.output_dir}/cibersort", mode: 'copy'

    input:
    path reference
    path samples

    output:
    path '*_deconv_output.csv', emit: output

    script:
    """
    Rscript /source/run_cibersort.R -s ${reference} -m ${samples}
    """
    
}