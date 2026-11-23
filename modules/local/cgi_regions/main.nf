#!/usr/bin/env nextflow

/*
 * Build a regions file from the CpG islands of a genome (UCSC cpgIslandExt table).
 *
 * The UCSC table has the chromosome, start and end in columns 2-4, with 0-based
 * starts. The regions file uses 1-based coordinates with start and end included
 * (as the Bismark coverage files), so 1 is added to the start. Only the primary
 * chromosomes are kept (no alt, random or unplaced contigs), and the regions are
 * sorted by chromosome and start.
 */
process CGI_REGIONS {
    conda "bioconda::bedtools==2.31.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bedtools:2.31.1--hf5e1c6e_0' :
        'quay.io/biocontainers/bedtools:2.31.1--hf5e1c6e_0' }"

    label 'process_low'

    input:
    tuple val(genome), path(cpg_islands)

    output:
    path "cgi_${genome}.bed", emit: regions

    script:
    // gzip -dc rather than zcat, which only reads .Z files on macOS (e.g. with -profile conda)
    def reader = cpg_islands.name.endsWith('.gz') ? 'gzip -dc' : 'cat'
    """
    ${reader} ${cpg_islands} \\
        | awk -v OFS='\\t' '\$2 ~ /^chr([0-9]+|X|Y|M)\$/ { print \$2, \$3 + 1, \$4 }' \\
        | sort -T /tmp/ -k1,1 -k2,2n > cgi_${genome}.bed
    """

}
