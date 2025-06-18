#!/usr/bin/env nextflow

process INTERSECT {

    container 'egiuili/python3-3.9.16:v1'

    label 'process_low'    
    
    input:
    path atlas
    path samples

    output:
    path 'atlas.csv', emit: atlas
    path 'samples.csv', emit: samples

    script:
    """
    intersect.py \
    -i $atlas \
    -t $samples \
    """
}
