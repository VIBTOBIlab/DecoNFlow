#!/usr/bin/env nextflow

process EPIDISH {
    container 'egiuili/epidish:v1.0'

    publishDir "${params.output_dir}/epidish", mode: 'copy'

    input:
    path ref_path
    path samples_path

    output:
    path 'epidish_res_*.csv', emit: output
    path 'epidish_test_matrix*.csv'

    script:
    """
    Rscript /source/EpiDISH.R ${ref_path} ${samples_path} ${params.mod}
    """

}