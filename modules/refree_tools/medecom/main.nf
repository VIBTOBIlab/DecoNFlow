#!/usr/bin/env nextflow

process MEDECOM {
    container 'egiuili/medecom:v1'

    label 'process_high'

    input:
    path(matrix)

    output:
    path '*deconv_output*.csv', emit: output

    script:
    """
    Rscript /source/run_medecom.R \
    -m ${matrix} \
    -k ${params.clusters} \
    -n ${params.ninit} \
    -f ${params.nfold} \
    -r ${params.itermax} \
    -c 8 \
    """

}