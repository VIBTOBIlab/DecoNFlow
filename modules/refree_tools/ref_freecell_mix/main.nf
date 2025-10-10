#!/usr/bin/env nextflow

process REF_FREECELL_MIX {
    container 'egiuili/prmeth:v1'

    label 'process_medium'

    input:
    path(matrix)

    output:
    path "*deconv_output*.csv", emit: output

    script:
    """
    Rscript /source/run_prmeth.R \
    -s ${matrix} \
    -m ${matrix} \
    -k ${params.clusters} \
    -d RF
    """
    
}