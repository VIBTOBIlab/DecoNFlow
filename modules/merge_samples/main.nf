#!/usr/bin/env nextflow

process MERGE_SAMPLES {
    container 'egiuili/python3-3.9.16:v1'

    label 'process_medium'

    input:
    val(step)
    path(files)

    output:
    path "${step}*.csv", emit: fin_matrix
    path "celfie_${step}*.csv", emit: celfie_fin_matrix, optional: true

    script:
    def args = ''
    if (step=='test') { 
        // if normal test samples, outer join
        args += '--how outer'
    } else if (step=='test_celfie') {
        // if test samples with Celfie structure outer_fillna with 0
        args += '--how outer_fillna'
    } else if (step == 'celfie_atlas') {
        args += '--how inner --celfie_atlas'
    } else if (step == 'atlas') { 
        args += '--how inner'
    }
    """
    build_matrix.py \
    --file_paths "${files}" \
    --outfile "${step}_matrix.csv" \
    $args
    """
    
}