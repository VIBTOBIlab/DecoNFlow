#!/usr/bin/env nextflow

process COMBINE_FILES {
    conda "conda-forge::pandas==1.5.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:1.5.2' :
        'quay.io/biocontainers/pandas:1.5.2' }"

    label 'process_low'

    input:
    tuple val(names), path(proportions, stageAs: "?/*")

    output:
    path '*.csv', emit: clusters

    script:
    def prefix = task.ext.prefix ?: 'combined_results'
    """
    combine_files.py \
    --tool_names ${names.join(' ')} \
    --results $proportions \
    -o ${prefix}
    """

}
