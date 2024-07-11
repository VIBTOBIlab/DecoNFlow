#!/usr/bin/env nextflow

process MEDECOM {
    container 'egiuili/medecom:v1'

    label 'process_high'

    input:
    path samples_path

    output:
    path '*deconv_output*.csv', emit: output

    script:
    def args = "-c ${task.cpus}"
    """
    Rscript /source/run_medecom.R \
    -m ${samples_path} \
    -k ${params.clusters} \
    -n ${params.ninit} \
    -f ${params.nfold} \
    -r ${params.itermax} \
    $args
    """

}