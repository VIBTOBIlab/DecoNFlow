#!/usr/bin/env nextflow

process INTERSECT {

    container 'egiuili/intersect:v1'

    label 'process_low'    
    
    input:
    path atlas
    path samples

    output:
    path 'atlas.csv', emit: atlas
    path 'samples.csv', emit: samples

    script:
    """
    python3 /source/intersect.py \
    -i $atlas \
    -t $samples \
    """
}
