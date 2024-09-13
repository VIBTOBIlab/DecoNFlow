#!/usr/bin/env nextflow

process DSS_SELECTION {

    container 'egiuili/dss_dmr_analysis:v1'

    label 'process_high'

    input:
    path(covs)
    val(entity)

    output:
    path("reference_matrix_dss.tsv"), emit: reference_tsv
    path("reference_matrix_dss.csv"), emit: reference_csv

    script:
    def args = ''
    if (params.direction) {
        args += "-dir ${params.direction}"
        if (params.top) {
        args += " -t ${params.top}"
        }
    }
    """
    Rscript /source/DSS.R \
    -i "${covs}" \
    -en "${entity}" \
    -p ${params.adjp} \
    -col ${params.collapse_method} \
    -s ${params.smoothing} \
    -ss ${params.smoothing_span} \
    -d ${params.delta} \
    -c 4 \
    -l ${params.min_len} \
    -cg ${params.min_cpgs} \
    -dm ${params.dis_merge} \
    -pct ${params.pct_sign} \
    $args
    """

}