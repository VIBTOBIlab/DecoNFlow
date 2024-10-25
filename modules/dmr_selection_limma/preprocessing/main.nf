#!/usr/bin/env nextflow

process PREPROCESSING {
    container 'egiuili/bedtools_preprocessing:v2'

    label 'process_medium'

    input:
    tuple val(meta),val(entity),path(cov) 
    path regions

    output:
    path "*sample_mix.csv", emit: filt_sample
    
    script:
    def args = ""
    if (params.big_covs) {
        args += "-sorted -g /bedtools2/genomes2/${params.genome_order}.genome"
    }
    """
    zcat $cov | awk -v OFS='\\t' '\$5 + \$6 >= ${params.min_counts}' | gzip > ${entity}_filtered.cov.gz 
    cut -f1-3 ${regions} | sort -k1,1 -k2,2n > regions.bed

    bedtools intersect \\
    -a regions.bed \\
    -b ${entity}_filtered.cov.gz \\
    -wa -wb $args > ${entity}.bed \\

    bedtools groupby \\
    -i ${entity}.bed \\
    -g 1,2,3 \\
    -c 8 \\
    -o count | awk -v OFS='\\t' '\$4 >= ${params.refree_min_cpgs} {print \$1, \$2, \$3, \$4}' > ${entity}_counts.bed \\

    bedtools groupby \\
    -i ${entity}.bed \\
    -g 1,2,3 \\
    -c 8,9 > ${entity}_sum.bed \\

    bedtools intersect \\
    -a ${entity}_sum.bed \\
    -b ${entity}_counts.bed \\
    -wa -wb | awk -v OFS='\\t' '{print \$1, \$2, \$3, \$4, \$5}'> ${entity}_final.bed \\

    echo ",chr,start,end,${entity}-V" > "${entity}_sample_mix.csv"
    awk 'BEGIN {OFS=","}
        {
            chr=\$1 
            start=\$2 
            end=\$3 
            methylation=\$4 / (\$4 + \$5)
            print NR, chr, start, end, methylation

        }' ${entity}_final.bed >> ${entity}_sample_mix.csv    
    """

}