#!/usr/bin/env nextflow

process REFREE_PREPROCESSING {

    container 'egiuili/bedtools_preprocessing:v1'

    input:
    tuple val(meta), path(covs)
    path reference

    output:
    tuple val(meta), path("${meta}_sample_mix.csv") , emit: preprocessed_refree

    script:
    """
    zcat $covs | awk -v OFS='\\t' '\$5 + \$6 >= ${params.refree_min_counts}' | gzip > ${meta}_filtered.cov.gz 

    bedtools intersect \\
    -a $reference \\
    -b ${meta}_filtered.cov.gz \\
    -wa -wb > ${meta}.bed \\

    bedtools groupby \\
    -i ${meta}.bed \\
    -g 1,2,3 \\
    -c 8 \\
    -o count | awk -v OFS='\\t' '\$4 >= ${params.refree_min_cpgs} {print \$1, \$2, \$3, \$4}' > ${meta}_counts.bed \\

    bedtools groupby \\
    -i ${meta}.bed \\
    -g 1,2,3 \\
    -c 8,9 > ${meta}_sum.bed \\

    bedtools intersect \\
    -a ${meta}_sum.bed \\
    -b ${meta}_counts.bed \\
    -wa -wb | awk -v OFS='\\t' '{print \$1, \$2, \$3, \$4, \$5}'> ${meta}_final.bed \\

    echo "chr,start,end,${meta}" > "${meta}_sample_mix.csv"
    awk 'BEGIN {OFS=","}
        {
            chr=\$1 
            start=\$2 
            end=\$3 
            methylation=\$4 / (\$4 + \$5)
            print NR, chr, start, end, methylation

        }' ${meta}_final.bed >> ${meta}_sample_mix.csv
    """
    
}