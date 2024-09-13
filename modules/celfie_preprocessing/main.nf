#!/usr/bin/env nextflow

process CELFIE_PREPROCESSING {
    container 'egiuili/bedtools_preprocessing:v2'

    label 'process_medium'

    input:
    tuple val(meta),val(entity),path(cov) 
    path regions

    output:
    path "*sample_celfie_mix.csv", emit: filt_celfie_sample
    
    script:
    """
    cat ${regions} | tail -n +2 | awk '{print \$1 "\t" \$2 "\t" \$3}' > reference.tsv

    bedtools intersect \\
    -a reference.tsv \\
    -b $cov \\
    -wa -wb > ${entity}.bed \\

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