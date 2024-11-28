#!/usr/bin/env nextflow

process DMRFINDER_SELECTION {

    container 'egiuili/dmrfinder_r:v2'

    label 'process_medium'

    input:
    path(combined_file)
    val(sampleid)
    val(condition)

    output:
    path("reference_matrix_dmrfinder*.tsv"), emit: reference_tsv
    path("reference_matrix_dmrfinder*.csv"), emit: reference_csv
    path("DMRfinder_analysis.out"), emit: dmr_logfile

    script:
    def args = ''
    if (params.direction) {
        args += "-dir ${params.direction}"
        if (params.top) {
        args += " -top ${params.top}"
        }
    }
    """
    Rscript /source/findDMRs.r \
    -i $combined_file \
    $sampleid \
    -o reference_matrix_dmrfinder.csv \
    -n "${condition}" \
    -col ${params.collapse_method} \
    -d ${params.delta} \
    -p ${params.dmrfinder_pvalue} \
    -q ${params.dmrfinder_qvalue} \
    -c ${params.min_cpgs} \
    $args

    """

}