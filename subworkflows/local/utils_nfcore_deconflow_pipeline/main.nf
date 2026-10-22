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

// CelFiE and MetDecode, which need read counts instead of beta values: their own
// count reference matrix (--celfie_ref_matrix, --metdecode_ref_matrix) or the reference samples (--input)
def celfieRequested() {
    return params.celfie || params.benchmark
}

def metdecodeRequested() {
    return params.metdecode || params.benchmark
}

def celfieLikeToolsRequested() {
    return celfieRequested() || metdecodeRequested()
}

// CelFiE and MetDecode are skipped when they have neither their own reference matrix
// nor the reference samples (e.g. when a beta-value reference matrix replaces the reference samples)
def celfieSelected() {
    return celfieRequested() && (params.celfie_ref_matrix || params.input)
}

def metdecodeSelected() {
    return metdecodeRequested() && (params.metdecode_ref_matrix || params.input)
}

def celfieLikeToolsSelected() {
    return celfieSelected() || metdecodeSelected()
}

// The atlas is built from the reference samples (--input) with the limma DMR selection
// only if a selected tool has no reference matrix of its own
def atlasFromReferenceSamples() {
    return (classicToolsSelected() && !params.ref_matrix) ||
        (celfieSelected() && !params.celfie_ref_matrix) ||
        (metdecodeSelected() && !params.metdecode_ref_matrix)
}

def refBasedToolsSelected() {
    return classicToolsSelected() || celfieLikeToolsSelected()
}

def refFreeToolsSelected() {
    return params.medecom || params.ref_freecell_mix || params.benchmark
}

// Regions are given as a file (--regions), or as the CpG islands of a genome (--cgi_genome)
def regionsProvided() {
    return params.regions || params.cgi_genome
}

//
// Check the combinations of pipeline parameters. Single parameters (types,
// allowed values, existing files, required ones) are validated against nextflow_schema.json.
//
def validateInputParameters() {
    if (!classicToolsSelected() && !celfieLikeToolsRequested() && !refFreeToolsSelected()) {
        error("\n----> ERROR: specify at least one deconvolution tool. <----\n")
    }
    def skipped_tools = [
        [name: 'CelFiE', requested: celfieRequested(), selected: celfieSelected(), matrix: 'celfie_ref_matrix'],
        [name: 'MetDecode', requested: metdecodeRequested(), selected: metdecodeSelected(), matrix: 'metdecode_ref_matrix']
    ].findAll { tool -> tool.requested && !tool.selected }
    skipped_tools.each { tool ->
        def reason = "${tool.name} needs read counts: provide its own reference matrix (--${tool.matrix}) or the reference samples (--input)"
        if (params.ref_matrix) {
            reason += ", since it cannot use the beta values of the reference matrix (--ref_matrix)"
        }
        if (!classicToolsSelected() && !celfieLikeToolsSelected() && !refFreeToolsSelected()) {
            error("\n----> ERROR: ${reason}. <----\n")
        }
        log.warn "${reason}. ${tool.name} is skipped."
    }
    if (classicToolsSelected() && !params.ref_matrix && !params.input) {
        error("\n----> ERROR: Please provide either a reference matrix (--ref_matrix) or reference samples (--input) for reference-based deconvolution. <----\n")
    }
    if (atlasFromReferenceSamples() && !regionsProvided()) {
        error("\n----> ERROR: Please provide a regions file (--regions) or a genome to use its CpG islands as regions (--cgi_genome) for the limma DMR selection on the reference samples (--input). <----\n")
    }
    if (refFreeToolsSelected() && !regionsProvided()) {
        error("\n----> ERROR: Please provide a regions file (--regions) or a genome to use its CpG islands as regions (--cgi_genome) for reference-free deconvolution. <----\n")
    }
    if (params.regions && params.cgi_genome) {
        log.warn "Both a regions file (--regions) and a genome (--cgi_genome) were given: the regions file is used and --cgi_genome is ignored."
    }
    if (!refBasedToolsSelected() && params.input) {
        log.warn "No reference-based tool selected: the reference samples (--input) are ignored."
    }
    else if (params.input && !atlasFromReferenceSamples()) {
        // Each tool uses one reference: fail instead of silently ignoring the reference samples
        def replaced_by = []
        if (classicToolsSelected() && params.ref_matrix) {
            replaced_by << "the reference-based tools other than CelFiE and MetDecode use the reference matrix (--ref_matrix)"
        }
        if (celfieSelected() && params.celfie_ref_matrix) {
            replaced_by << "CelFiE uses its own reference matrix (--celfie_ref_matrix)"
        }
        if (metdecodeSelected() && params.metdecode_ref_matrix) {
            replaced_by << "MetDecode uses its own reference matrix (--metdecode_ref_matrix)"
        }
        error("\n----> ERROR: The reference samples (--input) are not used by any selected tool: ${replaced_by.join(', ')}. Please remove --input, or the reference matrix that should not be used. <----\n")
    }
    if (!refBasedToolsSelected() && params.ref_matrix) {
        log.warn "No reference-based tool selected: the reference matrix (--ref_matrix) is ignored."
    }
    else if (!classicToolsSelected() && params.ref_matrix) {
        log.warn "The reference matrix (--ref_matrix) is only used by the reference-based tools other than CelFiE and MetDecode, and none is selected: it is ignored."
    }
    if (!celfieRequested() && params.celfie_ref_matrix) {
        log.warn "CelFiE is not selected: its reference matrix (--celfie_ref_matrix) is ignored."
    }
    if (!metdecodeRequested() && params.metdecode_ref_matrix) {
        log.warn "MetDecode is not selected: its reference matrix (--metdecode_ref_matrix) is ignored."
    }
    if (params.ground_truth) {
        if (refBasedToolsSelected()) {
            validateGroundTruth()
        } else {
            log.warn "No reference-based tool selected: the ground truth (--ground_truth) is ignored, since reference-free tools do not estimate the cell types of the reference."
        }
    }
}

//
// Check that the ground truth has a 'sample' column and the same cell types as each reference used
//
def validateGroundTruth() {
    def header = csvFields(firstLine(params.ground_truth), ',')
    if (header[0] != 'sample') {
        error("\n----> ERROR: The first column of the ground truth (--ground_truth) must be named 'sample', found '${header[0]}'. <----\n")
    }
    def truth_cell_types = header.drop(1).toSet()

    referencesCellTypes().each { reference, reference_cell_types ->
        def missing = reference_cell_types - truth_cell_types
        def extra = truth_cell_types - reference_cell_types
        if (missing || extra) {
            def details = []
            if (missing) {
                details << "missing in the ground truth: ${missing.sort().join(', ')}"
            }
            if (extra) {
                details << "not in the reference: ${extra.sort().join(', ')}"
            }
            error("\n----> ERROR: The cell types of the ground truth (--ground_truth) must be the same as in the ${reference} (${details.join('; ')}). <----\n")
        }
    }
}

//
// Cell types of each reference used by the selected tools, keyed by its description:
// the columns of the reference matrices, or the 'type' column of the reference samplesheet
//
def referencesCellTypes() {
    def references = [:]
    if (classicToolsSelected() && params.ref_matrix) {
        references['reference matrix (--ref_matrix)'] = csvFields(firstLine(params.ref_matrix), '\t').drop(3).toSet()
    }
    if (celfieSelected() && params.celfie_ref_matrix) {
        references['CelFiE reference matrix (--celfie_ref_matrix)'] = countMatrixCellTypes(params.celfie_ref_matrix)
    }
    if (metdecodeSelected() && params.metdecode_ref_matrix) {
        references['MetDecode reference matrix (--metdecode_ref_matrix)'] = countMatrixCellTypes(params.metdecode_ref_matrix)
    }
    if (atlasFromReferenceSamples()) {
        def lines = file(params.input).readLines().findAll { line -> line.trim() }
        def type_column = csvFields(lines[0], ',').indexOf('type')
        references['reference samples (--input)'] = lines.drop(1).collect { line -> csvFields(line, ',')[type_column] }.toSet()
    }
    return references
}

//
// Cell types of a count reference matrix, from its '<cell type>_meth' columns
//
def countMatrixCellTypes(String path) {
    return csvFields(firstLine(path), '\t')
        .drop(3)
        .findAll { column -> column.endsWith('_meth') }
        .collect { column -> column.substring(0, column.length() - '_meth'.length()) }
        .toSet()
}

//
// First line of a file, without reading the whole file
//
def firstLine(String path) {
    return file(path).withReader { reader -> reader.readLine() }
}

//
// Split a line of a delimited file, removing quotes and surrounding spaces
//
def csvFields(String line, String separator) {
    return line.split(separator, -1).collect { field -> field.trim().replaceAll('^"|"$', '') }
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
