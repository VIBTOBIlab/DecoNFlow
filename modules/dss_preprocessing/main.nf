#!/usr/bin/env nextflow

process DSS_PREPROCESSING {

    container 'ubuntu:rolling'

    label 'process_low'

    input:
    tuple val(meta),val(entity),path(cov) 

    output:
    val(entity), emit: entity
    path("${meta}_dss_format.cov.gz"), emit: dss_format_sample
    
    script:
    """
    zcat $cov | awk '{print \$1 "\t" \$2 "\t" \$5 + \$6 "\t" \$6}' | gzip > ${meta}_dss_format.cov.gz 
    """

}