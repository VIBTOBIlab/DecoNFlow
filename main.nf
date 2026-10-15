#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VIBTOBIlab/DecoNFlow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/VIBTOBIlab/DecoNFlow
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { DECONFLOW              } from './workflows/deconflow'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_deconflow_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_deconflow_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PIPELINE PARAMETERS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

params {

    // Input/output options
    // Path to comma-separated file containing information about the reference samples.
    input: String?
    // The path of the reference matrix that you want to use for ref-based deconvolution.
    ref_matrix: String?
    // The output directory where the results will be saved. You have to use absolute paths to storage on Cloud infrastructure.
    outdir: String?
    // Path to comma-separated file containing information about the reference bam samples.
    ref_bams: String?
    // Path to the genome fasta file used to align samples.
    fasta: String?
    // File (.csv) of the groups.
    groups_file: String?
    // Path to the uxm-like atlas.
    uxm_atlas: String?
    // Path to comma-separated file containing information about the samples to deconvolve.
    bulk_samples: String?

    // Intermediate files options
    // Save intermediate files.
    save_intermeds: Boolean

    // Deconvolution tools
    // If True, it runs all the tools present in the pipeline
    benchmark: Boolean
    // Run the corresponding tool
    epidish: Boolean
    // Run the corresponding tool
    houseman_eq: Boolean
    // Run the corresponding tool
    houseman_ineq: Boolean
    // Run the corresponding tool
    methyl_resolver: Boolean
    // Run the corresponding tool
    episcore: Boolean
    // Run the corresponding tool
    prmeth: Boolean
    // Run the corresponding tool
    ref_freecell_mix: Boolean
    // Run the corresponding tool
    medecom: Boolean
    // Run the corresponding tool
    celfie: Boolean
    // Run the corresponding tool
    meth_atlas: Boolean
    // Run the corresponding tool
    cibersort: Boolean
    // Run the corresponding tool
    metdecode: Boolean

    // Options for the preprocessing of the reference samples
    // Minimum number of counts to keep a CpG position
    min_counts: Integer = 10
    // Minimum number of CpGs per region
    min_cpgs: Integer = 3
    // If specified, it makes the preprocessing running with a memory-efficient algorithm. Suggested to activate it when using whole-genome coverage files.
    big_covs: Boolean
    // If "--big_cov" flag is specified, the genome order needs to be specified as well.
    genome_order: String?

    // Options for the preprocessing for bulk samples.
    // Minimum number of counts to keep a CpG position for the bulk samples.
    bulk_min_cpgs: Integer = 0
    // Minimum number of CpGs per region for the bulk samples.
    bulk_min_counts: Integer = 0

    // DMR analysis general options
    // DMR selection approach adopted
    DMRselection: String?
    // Adjusted p-value threshold
    adjp: Float = 0.001
    // Method to collapse the sample values for each region
    collapse_method: String = 'mean'
    // Direction of methylation.
    direction: String = 'both'
    // Take the top x number of DMRs per cell state.
    top: Integer = 250
    // Threshold for calling DMRs
    delta: Float = 0.1

    // Limma options
    // Path to region file if DMRselection == "custom"
    regions: String?
    // Multiple testing correction method among the ones available in limma R package
    adj_method: String = 'BH'
    // When merging samples for limma DMR analysis, include the regions even if some samples have missing values
    include_na: Boolean

    // Reference-free deconvolution options.
    // Number of cell types expected (necessary for ref-free modality)
    clusters: Integer = 2

    // MeDeCom parameters
    // Number of random initializations
    ninit: Integer = 10
    // Number of folds for CV
    nfold: Integer = 10
    // Max number of iterations
    itermax: Integer = 300

    // EpiSCORE parameters
    // Weight parameter used for deconvolution (can go from 0.05 to 0.9)
    weight: Float = 0.4

    // MethylResolver parameters
    // Alpha parameter used by the model (can go from 0.5 to 0.9)
    alpha: Float = 0.5

    // PRMeth parameters
    // PRMeth deconv modality
    prmeth_mod: String = 'QP'
    // PRMeth number of entities when using NMF
    prmeth_NMF_entities: Integer = 3

    // CelFiE parameters
    // How long the EM should iterate before stopping, unless convergence criteria is met
    celfie_maxiter: Integer = 1000
    // Number of unknown categories to be estimated along with the reference data
    unknown: Integer = 0
    // Replicate number in a simulation experiment
    parall_job: Integer = 1
    // Convergence criteria for EM
    converg: Float = 0.0001
    // CelFiE will perform several random restarts and select the one with the highest log-likelihood
    celfie_randrest: Integer = 10

    // MetDecode parameters
    // Number of unknown entities.
    unknown_tissues: Integer?
    // If specified, it makes the sum of the proportions to 1.
    sum1: Boolean
    // Disable CpG coverage factor.
    no_coverage: Boolean
    // Disable the unsupervised refinment of the proportions.
    supervised: Boolean

    // Bismark parameters
    // If true, bismark will run under 'single_end' option
    single_end: Boolean

    // Generic options
    // Display version and exit.
    version: Boolean
    // Do not use coloured log outputs.
    monochrome_logs: Boolean
    // Boolean whether to validate parameters against the schema at runtime
    validate_params: Boolean = true
    // Display the help message.
    help: String?
    // Display the full detailed help message.
    help_full: Boolean
    // Display hidden parameters in the help message (only works when --help or --help_full are provided).
    show_hidden: Boolean
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main DecoNFlow analysis pipeline
//
workflow RUN_DECONFLOW {

    main:
    DECONFLOW ()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        args,
        params.outdir,
        params.help,
        params.help_full,
        params.show_hidden
    )

    //
    // WORKFLOW: Run main workflow
    //
    RUN_DECONFLOW ()

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.monochrome_logs,
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
