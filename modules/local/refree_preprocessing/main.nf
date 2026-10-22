#!/usr/bin/env nextflow

process REFREE_PREPROCESSING {
    conda "bioconda::bedtools==2.29.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bedtools:2.29.2--hc088bd4_0' :
        'quay.io/biocontainers/bedtools:2.29.2--hc088bd4_0' }"

    label 'process_medium'

    input:
    tuple val(meta), path(covs)
    path reference

    output:
    tuple val(meta), path("${meta}_sample_mix.csv") , emit: preprocessed_refree

    script:
    """
    cut -f1-3 ${reference} | awk '\$2 ~ /^[0-9]+\$/' > ${meta}_regions.bed

    # The coverage file is streamed (-a) and only the regions (-b) are kept in memory,
    # so that big coverage files (e.g. WGBS) do not need to be sorted or loaded in memory.
    # Columns of ${meta}_sum.bed: chr, start, end, methylated and unmethylated counts, CpGs
    zcat $covs | awk -v OFS='\\t' '\$5 + \$6 >= ${params.bulk_min_counts}' | \\
    awk '\$1 ~ /^(chr)?(1[0-9]|2[0-2]|[1-9]|X|Y|MT|M)\$/ {print}' | \\
    bedtools intersect -a stdin -b ${meta}_regions.bed -wa -wb | \\
    awk -v OFS='\\t' '
        { region = \$7 OFS \$8 OFS \$9; meth[region] += \$5; unmeth[region] += \$6; cpgs[region]++ }
        END { for (region in meth) print region, meth[region], unmeth[region], cpgs[region] }' | \\
    sort -T /tmp/ -k1,1 -k2,2n > ${meta}_sum.bed

    echo "chr,start,end,${meta}" > "${meta}_sample_mix.csv"
    awk 'BEGIN {OFS=","}
        \$6 >= ${params.bulk_min_cpgs} {
            chr=\$1
            start=\$2
            end=\$3
            methylation=\$4 / (\$4 + \$5)
            print ++n, chr, start, end, methylation

        }' ${meta}_sum.bed >> ${meta}_sample_mix.csv
    """

}
