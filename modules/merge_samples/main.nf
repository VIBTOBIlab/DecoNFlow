#!/usr/bin/env nextflow

process MERGE_SAMPLES {
    container 'egiuili/merge_samples:v3'

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
        args += '--how outer'
    }
    if (step == 'ref_celfie') {
        args += ' --celfie'
    }
    """
    python3 /source/build_matrix.py \
    --file_paths "${files}" \
    --outfile "${step}_matrix.csv" \
    $args
    """
    
}