//
// Subworkflow with functionality specific to the VIBTOBIlab/DecoNFlow pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFSCHEMA_PLUGIN     } from '../../nf-core/utils_nfschema_plugin'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    validate_params   // boolean: Boolean whether to validate parameters against the schema at runtime
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir            //  string: The output directory where the results will be saved
    help              // boolean: Display help message and exit
    help_full         // boolean: Show the full help message
    show_hidden       // boolean: Show hidden parameters in the help message

    main:

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    def before_text = ""
    def after_text = '\n' + citationText() + '\n' + bannerText()

    def command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samplesheet.csv --bulk_samples bulk_samples.csv --regions regions.bed --outdir <OUTDIR>"

    UTILS_NFSCHEMA_PLUGIN (
        workflow,
        validate_params,
        null,
        help,
        help_full,
        show_hidden,
        before_text,
        after_text,
        command,
        false
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )

    //
    // Custom validation for pipeline parameters
    //
    validateInputParameters()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {

    take:
    monochrome_logs // boolean: Disable ANSI colour codes in log output

    main:

    //
    // Completion summary
    //
    workflow.onComplete {

        completionSummary(monochrome_logs)

    }

    workflow.onError {
        log.error "Pipeline failed. Please refer to troubleshooting docs for common issues: https://nf-co.re/docs/running/troubleshooting"
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Deconvolution tools selected with the pipeline parameters. Also used by the
// DECONFLOW workflow, so that the tool lists are defined in one place only.
//

// "Classical" reference-based tools, which only need a reference matrix
def classicToolsSelected() {
    return params.meth_atlas || params.epidish || params.houseman_eq || params.houseman_ineq ||
        params.prmeth || params.methyl_resolver || params.episcore || params.cibersort || params.benchmark
}

// CelFiE and MetDecode, which also need the reference samples (--input)
def celfieLikeToolsRequested() {
    return params.celfie || params.metdecode || params.benchmark
}

// CelFiE and MetDecode are skipped when a reference matrix replaces the reference samples
def celfieLikeToolsSelected() {
    return celfieLikeToolsRequested() && !params.ref_matrix
}

def refBasedToolsSelected() {
    return classicToolsSelected() || celfieLikeToolsSelected()
}

def refFreeToolsSelected() {
    return params.medecom || params.ref_freecell_mix || params.benchmark
}

//
// Check the combinations of pipeline parameters. Single parameters (types,
// allowed values, existing files, required ones) are validated against nextflow_schema.json.
//
def validateInputParameters() {
    if (!classicToolsSelected() && !celfieLikeToolsRequested() && !refFreeToolsSelected()) {
        error("\n----> ERROR: specify at least one deconvolution tool. <----\n")
    }
    if (params.ref_matrix && params.input) {
        error("\n----> ERROR: Please provide either a reference matrix (--ref_matrix) or reference samples (--input), but not both. <----\n")
    }
    if (params.big_covs && !params.genome_order) {
        error("\n----> ERROR: Please provide the genome order (--genome_order) when using --big_covs. <----\n")
    }
    if (celfieLikeToolsRequested() && params.ref_matrix) {
        if (!classicToolsSelected() && !refFreeToolsSelected()) {
            error("\n----> ERROR: CelFiE and MetDecode need the reference samples (--input) and cannot be used with a reference matrix (--ref_matrix). <----\n")
        }
        log.warn "CelFiE and MetDecode need the reference samples (--input) and are skipped when using a reference matrix (--ref_matrix)."
    }
    if (refBasedToolsSelected() && !params.ref_matrix && !params.input) {
        error("\n----> ERROR: Please provide either a reference matrix (--ref_matrix) or reference samples (--input) for reference-based deconvolution. <----\n")
    }
    if (refBasedToolsSelected() && params.input && !params.regions) {
        error("\n----> ERROR: Please provide a regions file (--regions) for the limma DMR selection on the reference samples (--input). <----\n")
    }
    if (refFreeToolsSelected() && !params.regions) {
        error("\n----> ERROR: Please provide a regions file (--regions) for reference-free deconvolution. <----\n")
    }
    if (!refBasedToolsSelected() && params.input) {
        log.warn "No reference-based tool selected: the reference samples (--input) are ignored."
    }
    if (!refBasedToolsSelected() && params.ref_matrix) {
        log.warn "No reference-based tool selected: the reference matrix (--ref_matrix) is ignored."
    }
}

//
// Citation string for pipeline
//
def citationText() {
    return "If you use ${workflow.manifest.name} for your analysis please cite:\n\n" +
        "* The pipeline\n" +
        "  " +
        "* The nf-core framework\n" +
        "  https://doi.org/10.1038/s41587-020-0439-x\n\n" +
        "* Software dependencies\n" +
        "  ../CITATIONS.md"
}

//
// Pipeline banner, made using https://patorjk.com/software/taag
//
def bannerText() {
    return """
        ==============================================================================================

            ██████╗*███████╗*██████╗*██████╗*███╗***██╗███████╗██╗******██████╗*██╗****██╗
            ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗**██║██╔════╝██║*****██╔═══██╗██║****██║
            ██║**██║█████╗**██║*****██║***██║██╔██╗*██║█████╗**██║*****██║***██║██║*█╗*██║
            ██║**██║██╔══╝**██║*****██║***██║██║╚██╗██║██╔══╝**██║*****██║***██║██║███╗██║
            ██████╔╝███████╗╚██████╗╚██████╔╝██║*╚████║██║*****███████╗╚██████╔╝╚███╔███╔╝
            ╚═════╝*╚══════╝*╚═════╝*╚═════╝*╚═╝**╚═══╝╚═╝*****╚══════╝*╚═════╝**╚══╝╚══╝*

        ==============================================================================================
        """.stripIndent()
}
