#!/usr/bin/env nextflow

process MEDECOM {
    container 'egiuili/medecom:v1'

    publishDir "${params.outdir}/medecom", mode: 'copy'

    input:
    path samples_path

    output:
    path '*deconv_output*.csv', emit: output

    script:
    """
    Rscript /source/run_medecom.R \
    -m ${samples_path} \
    -k ${params.clusters} \
    -n ${params.ninit} \
    -f ${params.nfold} \
    -r ${params.itermax} \
    """

}