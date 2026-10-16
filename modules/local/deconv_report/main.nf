#!/usr/bin/env nextflow

process DECONV_REPORT {
    container 'egiuili/python3-3.9.16:v1'

    label 'process_low'

    input:
    path results

    output:
    path 'deconvolution_report.html', emit: report

    script:
    """
    deconv_report.py \
    --results ${results} \
    --pipeline_version ${workflow.manifest.version} \
    -o deconvolution_report.html
    """

}
