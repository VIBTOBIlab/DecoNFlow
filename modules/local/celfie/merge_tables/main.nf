process MERGE_TABLES {
    conda "conda-forge::pandas==1.5.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:1.5.2' :
        'quay.io/biocontainers/pandas:1.5.2' }"

    label 'process_low'

    input:
    path ref_matrix
    path test_matrix

    output:
    path 'celfie_matrix.txt', emit: merged_table

    script:
    """
    merge_tables.py -i ${ref_matrix} -t ${test_matrix}
    """
}
