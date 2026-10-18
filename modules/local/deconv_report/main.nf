#!/usr/bin/env nextflow

process DECONV_REPORT {
    container 'egiuili/python3-3.9.16:v1'

    label 'process_low'

    input:
    path results
    path ground_truth   // optional: [] when --ground_truth is not provided

    output:
    path 'deconvolution_report.html', emit: report
    path 'evaluation_metrics.csv',    emit: metrics, optional: true

    script:
    def evaluation = ground_truth ? "--ground_truth ${ground_truth} --metrics evaluation_metrics.csv" : ''
    """
    deconv_report.py \
    --results ${results} \
    --pipeline_version ${workflow.manifest.version} \
    ${evaluation} \
    -o deconvolution_report.html
    """

}
