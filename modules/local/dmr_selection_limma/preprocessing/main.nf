#!/usr/bin/env nextflow

process PREPROCESSING {
    conda "bioconda::bedtools==2.29.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bedtools:2.29.2--hc088bd4_0' :
        'quay.io/biocontainers/bedtools:2.29.2--hc088bd4_0' }"

    label 'process_medium'

    input:
    tuple val(meta),val(entity),path(cov)
    path regions

    output:
    path "*sample_mix.csv", emit: filt_sample

    script:
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

    cut -f1-3 ${regions} | awk '\$2 ~ /^[0-9]+\$/' > ${meta}_regions.bed

    # The coverage file is streamed (-a) and only the regions (-b) are kept in memory,
    # so that big coverage files (e.g. WGBS) do not need to be sorted or loaded in memory.
    # Columns of ${meta}_sum.bed: chr, start, end, methylated and unmethylated counts, CpGs
    zcat $cov | awk -v OFS='\\t' '\$5 + \$6 >= ${params.min_counts}' | \\
    awk '\$1 ~ /^(chr)?(1[0-9]|2[0-2]|[1-9])\$/ {print}' | \\
    bedtools intersect -a stdin -b ${meta}_regions.bed -wa -wb | \\
    awk -v OFS='\\t' '
        { region = \$7 OFS \$8 OFS \$9; meth[region] += \$5; unmeth[region] += \$6; cpgs[region]++ }
        END { for (region in meth) print region, meth[region], unmeth[region], cpgs[region] }' | \\
    sort -T /tmp/ -k1,1 -k2,2n > ${meta}_sum.bed

    echo ",chr,start,end,${entity}-V" > "${meta}_sample_mix.csv"
    awk 'BEGIN {OFS=","}
        \$6 >= ${params.min_cpgs} {
            chr=\$1
            start=\$2
            end=\$3
            methylation=\$4 / (\$4 + \$5)
            print ++n, chr, start, end, methylation

        }' ${meta}_sum.bed >> ${meta}_sample_mix.csv
    """

}
