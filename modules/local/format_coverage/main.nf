#!/usr/bin/env nextflow

/*
 * Convert a coverage file into the CpG format used by the preprocessing modules:
 * a gzipped, tab-separated file with 1-based coordinates, start and end included
 * (as in the Bismark coverage files and the regions file), and the read counts
 *
 *     chr  start  end  methylation_%  n_methylated  n_unmethylated
 *
 * Accepted inputs:
 *  - Bismark coverage files (.cov / .cov.gz): already in this format
 *  - MethylDackel bedGraph files (.bedGraph / .bedGraph.gz): 0-based, end excluded,
 *    converted to 1-based (start + 1, end), and the 'track' header line is removed.
 *    Per-strand CpGs ('25114 25115') become '25115 25115' as in Bismark, and CpGs
 *    merged across strands (--mergeContext, '25114 25116') become '25115 25116'
 * A bedGraph without read counts (e.g. from bismark2bedGraph) is rejected.
 */
process FORMAT_COVERAGE {
    conda "bioconda::bedtools==2.29.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bedtools:2.29.2--hc088bd4_0' :
        'quay.io/biocontainers/bedtools:2.29.2--hc088bd4_0' }"

    label 'process_low'

    input:
    tuple val(meta), path(coverage)

    output:
    tuple val(meta), path("*.cpg.cov.gz"), emit: coverage

    script:
    def is_bismark = coverage.name ==~ /.*\.cov(\.gz)?$/
    def prefix = coverage.name.replaceAll(/\.(cov|bedGraph)(\.gz)?$/, '')
    """
    zcat -f ${coverage} | awk -v OFS='\\t' -v bismark=${is_bismark} '
        /^(track|#)/ { next }
        NF < 6 {
            print "Error: ${coverage} has " NF " columns instead of 6 (chr, start, end, methylation %, methylated and unmethylated read counts). A bedGraph without read counts (e.g. from bismark2bedGraph) cannot be used." > "/dev/stderr"
            exit 1
        }
        bismark == "true" { print \$1, \$2, \$3, \$4, \$5, \$6; next }
        { print \$1, \$2 + 1, \$3, \$4, \$5, \$6 }
    ' | gzip > ${prefix}.cpg.cov.gz
    """

}
