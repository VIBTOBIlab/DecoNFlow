#!/usr/bin/env nextflow

process TEST_PREPROCESSING {
    container 'egiuili/bedtools_preprocessing:v2'

    label 'process_medium'

    input:
    tuple val(meta), path(covs)
    path reference

    output:
    path("${meta}_sample_mix.csv") , emit: preprocessed_test
    path("${meta}_sample_celfie_mix.csv") , emit: preprocessed_celfie_test

    script:
    def args = ""
    if (params.big_covs) {
        args += "-sorted -g /bedtools2/genomes2/${params.genome_order}.genome"
    }
    """
    cut -f1-3 ${reference} | sort -V > regions.bed

    bedtools intersect \\
    -a regions.bed \\
    -b ${covs} \\
    -wa -wb $args > ${meta}.bed \\

    bedtools groupby \\
    -i ${meta}.bed \\
    -g 1,2,3 \\
    -c 8,9 > ${meta}_sum.bed \\

    echo "chr,start,end,${meta}" > "${meta}_sample_mix.csv"
    awk 'BEGIN {OFS=","}
        {
            chr=\$1 
            start=\$2 
            end=\$3 
            methylation=\$4 / (\$4 + \$5)
            print NR, chr, start, end, methylation

        }' ${meta}_sum.bed >> ${meta}_sample_mix.csv
    
    echo ",chr,start,end,${meta}_meth,${meta}_depth" > "${meta}_sample_celfie_mix.csv"
    awk 'BEGIN {OFS=","}
        {
            chr=\$1 
            start=\$2 
            end=\$3 
            methylation=\$4 
            depth= (\$4 + \$5)
            print NR, chr, start, end, methylation, depth

        }' ${meta}_sum.bed >> ${meta}_sample_celfie_mix.csv
    """
    
}