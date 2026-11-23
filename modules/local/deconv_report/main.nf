#!/usr/bin/env nextflow

process DECONV_REPORT {
    conda "conda-forge::pandas==1.5.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:1.5.2' :
        'quay.io/biocontainers/pandas:1.5.2' }"

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
