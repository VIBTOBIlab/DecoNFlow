#!/usr/bin/env nextflow

process CONVERT_ATLAS {
    container 'egiuili/convert_atlas:v2'

    label 'process_low'    
    
    input:
    path fin_matrix

    output:
    path '*.csv', emit: atlas_csv
    path '*.tsv', emit: atlas_tsv

    script:
    """
    python3 /source/convert_atlas.py \
    -m $fin_matrix \
    -c ${params.collapse_method} \
    """
}