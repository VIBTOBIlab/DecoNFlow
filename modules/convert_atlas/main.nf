#!/usr/bin/env nextflow

process CONVERT_ATLAS {
    container 'egiuili/python3-3.9.16:v1'

    label 'process_low'    
    
    input:
    path fin_matrix

    output:
    path '*.csv', emit: atlas_csv
    path '*.tsv', emit: atlas_tsv

    script:
    """
    convert_atlas.py \
    -m $fin_matrix \
    -c ${params.collapse_method} \
    """
}