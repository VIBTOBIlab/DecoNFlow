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

    def command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samplesheet.csv --test_set test_set.csv --regions regions.bed --outdir <OUTDIR>"

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
// Check and validate pipeline parameters
//
def validateInputParameters() {
    if (!params.medecom && !params.ref_freecell_mix && !params.uxm && !params.houseman_eq && !params.houseman_ineq && !params.meth_atlas && !params.celfie && !params.metdecode && !params.epidish && !params.prmeth && !params.methyl_resolver && !params.episcore && !params.cibersort && !params.benchmark) {
        error("\n----> ERROR: specify at least one deconvolution tool. <----\n")
    }
    if ((params.celfie || params.metdecode) && !params.input) {
        error("\n----> ERROR: you need to specify the reference samples (--input) when using CelFiE or MetDecode. <----\n")
    }
    if (params.DMRselection != "wgbstools" && params.DMRselection != "DMRfinder" && params.DMRselection != "limma" && !params.ref_matrix && !params.uxm_atlas && !params.ref_freecell_mix && !params.medecom) {
        error("\n----> ERROR: you need to specify one DMR selection approach (--DMRselection). <----\n")
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
