#!/usr/bin/env nextflow

process EPIDISH {
    container 'egiuili/epidish:v1'

    label 'process_medium'

    input:
    path ref_path
    path samples_path

    output:
    path 'epidish_res_*.csv', emit: output

    script:
    """
    Rscript /source/EpiDISH.R -s ${ref_path} -m ${samples_path} -d ${params.mod}
    """

}