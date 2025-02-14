#!/usr/bin/env nextflow

process DMRFINDER_COMBINE {

    container 'egiuili/python3-3.9.16:v1'

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
    combine_CpG_sites.py \
    -i $cov \
    -o combine_CpG_sites_output.csv \
    $args
    """

}


