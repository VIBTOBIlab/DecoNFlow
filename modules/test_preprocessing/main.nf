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
    cut -f1-3 ${reference} | sort -T /tmp/ -k1,1 -k2,2n > regions.bed
    
    zcat $covs | awk -v OFS='\\t' '\$5 + \$6 >= ${params.bulk_min_counts}' | \\
    awk '\$1 ~ /^(chr)?(1[0-9]|2[0-2]|[1-9]|X|Y|MT|M)\$/ {print}' | \\
    gzip > ${meta}_filtered.cov.gz

    bedtools intersect \\
    -a regions.bed \\
    -b ${meta}_filtered.cov.gz \\
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