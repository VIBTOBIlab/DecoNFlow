#!/usr/bin/env nextflow

process DMRFINDER_COMBINE {

    container 'sofvdvel/dmrfinder_python:v1'

    label 'process_medium'

    input:
    path(cov)

    output:
    path("combine_CpG_sites_output.csv"), emit: combined_cpgs
    
    script:
    def args = ""
    if (params.big_covs) {
        args += "-b"
    }
    """
    python /source/combine_CpG_sites.py \
    -i $cov \
    -o combine_CpG_sites_output.csv \
    $args
    """

}


