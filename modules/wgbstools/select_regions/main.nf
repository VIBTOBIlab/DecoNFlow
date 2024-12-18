#!/usr/bin/env nextflow

process SELECT_REGIONS {
    container 'egiuili/uxm:v1'

    label 'process_low'

    input:
    path atlas

    output:
    path "*.bed", emit: regions

    script:
    """
    cut -f1-3 $atlas > RegionsAtlas.bed
    """
}