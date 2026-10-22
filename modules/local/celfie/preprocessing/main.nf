#!/usr/bin/env nextflow

process CELFIE_PREPROCESSING {
    conda "bioconda::bedtools==2.31.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bedtools:2.31.1--hf5e1c6e_0' :
        'quay.io/biocontainers/bedtools:2.31.1--hf5e1c6e_0' }"

    label 'process_high'

    input:
    tuple val(meta),val(entity),path(cov)
    path regions

    output:
    path "*sample_celfie_mix.csv", emit: filt_celfie_sample

    script:
    """
    tail -n +2 ${regions} | cut -f1-3 | awk '\$2 ~ /^[0-9]+\$/' > ${entity}_regions.bed

    # The coverage file is streamed (-a) and only the regions (-b) are kept in memory,
    # so that big coverage files (e.g. WGBS) do not need to be sorted or loaded in memory.
    # Columns of ${entity}_sum.bed: chr, start, end, methylated and unmethylated counts, CpGs
    gzip -dc $cov | \\
    awk '\$1 ~ /^(chr)?(1[0-9]|2[0-2]|[1-9]|X|Y|MT|M)\$/ {print}' | \\
    bedtools intersect -a stdin -b ${entity}_regions.bed -wa -wb | \\
    awk -v OFS='\\t' '
        { region = \$7 OFS \$8 OFS \$9; meth[region] += \$5; unmeth[region] += \$6; cpgs[region]++ }
        END { for (region in meth) print region, meth[region], unmeth[region], cpgs[region] }' | \\
    sort -T /tmp/ -k1,1 -k2,2n > ${entity}_sum.bed

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
