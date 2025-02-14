process MERGE_TABLES {
    container 'egiuili/python3-3.9.16:v1'

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