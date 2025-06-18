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
    first_column_regions=\$(awk -F'\t' 'NR==2 {print \$1}' $regions)
    if [[ \$first_column_regions == chr* ]]; then
        chr_present_regions="true"
    else
        chr_present_regions="false"
    fi
    first_column_cov=\$(zcat $cov | awk -F'\t' 'NR==2 {print \$1}')
    if [[ \$first_column_cov == chr* ]]; then
        chr_present_cov="true"
    else
        chr_present_cov="false"
    fi
    if [[ \$chr_present_cov != \$chr_present_regions ]]; then
        echo "Error: chr suffix does not match between the files!" >&2
        exit 1
    fi

    zcat $cov | awk -v OFS='\\t' '\$5 + \$6 >= ${params.min_counts}' | \\
    awk '\$1 ~ /^(chr)?(1[0-9]|2[0-2]|[1-9])\$/ {print}' | \\
    gzip > ${meta}_filtered.cov.gz
     
    cut -f1-3 ${regions} | sort -T /tmp/ -k1,1 -k2,2n > regions.bed

    bedtools intersect \\
    -a regions.bed \\
    -b ${meta}_filtered.cov.gz \\
    -wa -wb $args > ${meta}.bed \\

    bedtools groupby \\
    -i ${meta}.bed \\
    -g 1,2,3 \\
    -c 8 \\
    -o count | awk -v OFS='\\t' '\$4 >= ${params.min_cpgs} {print \$1, \$2, \$3, \$4}' > ${meta}_counts.bed \\

    bedtools groupby \\
    -i ${meta}.bed \\
    -g 1,2,3 \\
    -c 8,9 > ${meta}_sum.bed \\

    bedtools intersect \\
    -a ${meta}_sum.bed \\
    -b ${meta}_counts.bed \\
    -wa -wb | awk -v OFS='\\t' '{print \$1, \$2, \$3, \$4, \$5}'> ${meta}_final.bed \\

    echo ",chr,start,end,${entity}-V" > "${meta}_sample_mix.csv"
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