#!/usr/bin/env nextflow

process UXM_DECONV {
    container 'egiuili/uxm:v1'

    label 'process_medium'

    input:
    path pats
    path pat_indeces
    path atlas 

    output:
    path "output.csv", emit: res

    script:
    """
    uxm deconv $pats -o output.csv --atlas $atlas --tmp_dir /tmp/
    """
}