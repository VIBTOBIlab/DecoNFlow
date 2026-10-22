#!/usr/bin/env nextflow

process REF_FREECELL_MIX {
    conda "${moduleDir}/environment.yml"
    container 'egiuili/prmeth:v3'

    label 'process_medium'

    input:
    path(matrix)

    output:
    path "test_samples_deconv_output*.csv", emit: output_samples
    path "test_samples_deconv_W_mod*.csv", emit: output_components

    script:
    """
    run_prmeth.R \
    -s ${matrix} \
    -m ${matrix} \
    -k ${params.clusters} \
    -d RF
    """

}
