#!/usr/bin/env nextflow

process MERGE_TABLES {
    container 'egiuili/celfie:v1.0'

    publishDir "${params.output_dir}/celfie", mode: 'copy'

    input:
    path ref_matrix
    path test_matrix

    output:
    path 'celfie_matrix.txt', emit: merged_table

    script:
    """
    python3 /source/merge_tables.py \
    -i ${ref_matrix} \
    -t ${test_matrix} \
    """

}


process RUN_DECONV {
    container 'egiuili/celfie:v1.0'

    publishDir "${params.output_dir}/celfie", mode: 'copy'

    input:
    path merged_table

    output:
    path 'results/*tissue_proportions.txt', emit: output

    script:
    """
    python3 /source/celfie.py \
    ${merged_table} \
    ${params.output_dir} \
    ${params.nsamples} \
    -m ${params.celfie_maxiter} \
    -u ${params.unknown} \
    -c ${params.converg} \
    -r ${params.celfie_randrest} \
    -p ${params.parall_job} \
    """
}

// combine the two processes into a subworkflow
workflow CELFIE {
    take:
        ref_matrix
        test_matrix

    main:
        MERGE_TABLES(ref_matrix, test_matrix)

        RUN_DECONV(MERGE_TABLES.out.merged_table)
}