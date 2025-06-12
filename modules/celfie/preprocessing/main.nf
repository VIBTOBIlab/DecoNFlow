#!/usr/bin/env nextflow

process CELFIE_PREPROCESSING {
    container 'egiuili/bedtools_preprocessing:v2'

    label 'process_high'

    input:
    tuple val(meta),val(entity),path(cov) 
    path regions

    output:
    path "*sample_celfie_mix.csv", emit: filt_celfie_sample
    
    script:
    def args = ""
    if (params.big_covs) {
        args += "-sorted -g /bedtools2/genomes2/${params.genome_order}.genome"
    }
    """
    cat ${regions} | tail -n +2 | awk '{print \$1 "\t" \$2 "\t" \$3}' | sort -T /tmp/ -k1,1 -k2,2n > reference.tsv

    zcat $cov | \\
    awk '\$1 ~ /^(chr)?(1[0-9]|2[0-2]|[1-9]|X|Y|MT|M)\$/ {print}' | \\
    gzip > ${meta}_filtered.cov.gz

    bedtools intersect \\
    -a reference.tsv \\
    -b ${meta}_filtered.cov.gz \\
    -wa -wb $args > ${entity}.bed \\

    bedtools groupby \\
    -i ${entity}.bed \\
    -g 1,2,3 \\
    -c 8,9 > ${entity}_sum.bed \\

    echo ",chr,start,end,${entity}_meth,${entity}_depth" > "${entity}_sample_celfie_mix.csv"
    awk 'BEGIN {OFS=","}
        {
            chr=\$1 
            start=\$2 
            end=\$3 
            methylation=\$4 
            depth= (\$4 + \$5)
            print NR, chr, start, end, methylation, depth

        }' ${entity}_sum.bed >> ${entity}_sample_celfie_mix.csv  
    """

}