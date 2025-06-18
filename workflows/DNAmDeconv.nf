#!/usr/bin/env nextflow


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include {paramsSummaryLog} from 'plugin/nf-schema'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryLog(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

// Set a header made using https://patorjk.com/software/taag (but be sure to escape characters such as dollar signs and backslashes, e.g., '$'=> '\\$' and '\' =>'\\')
log.info """
    ==============================================================================================

        ██████╗*███████╗*██████╗*██████╗*███╗***██╗███████╗██╗******██████╗*██╗****██╗
        ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗**██║██╔════╝██║*****██╔═══██╗██║****██║
        ██║**██║█████╗**██║*****██║***██║██╔██╗*██║█████╗**██║*****██║***██║██║*█╗*██║
        ██║**██║██╔══╝**██║*****██║***██║██║╚██╗██║██╔══╝**██║*****██║***██║██║███╗██║
        ██████╔╝███████╗╚██████╗╚██████╔╝██║*╚████║██║*****███████╗╚██████╔╝╚███╔███╔╝
        ╚═════╝*╚══════╝*╚═════╝*╚═════╝*╚═╝**╚═══╝╚═╝*****╚══════╝*╚═════╝**╚══╝╚══╝*

    ==============================================================================================
    """.stripIndent()

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { samplesheetToList                      } from 'plugin/nf-schema'
include { inHousePrep                            } from "../subworkflows/inHousePrep"
include { DMRfinderPrep                          } from "../subworkflows/DMRfinderPrep"
include { refBasedDeconv                         } from "../subworkflows/refBasedDeconv"
include { refFreeDeconv                          } from "../subworkflows/refFreeDeconv"
include { CELFIE                                 } from "../subworkflows/celfie"
include { CELFIE_PREPROCESSING                   } from "../modules/celfie/preprocessing/main"
include { TEST_PREPROCESSING                     } from "../modules/test_preprocessing/main"
include { COMBINE_FILES                          } from "../modules/combine_files/main"
include { MERGE_SAMPLES                          } from "../modules/merge_samples/main"
include { LIMMA                                  } from "../modules/dmr_selection_limma/limma/main"
include { UXM                                    } from "../subworkflows/uxm"
include { WGBSTOOLS                              } from "../subworkflows/wgbstools"
include { PROCESS_REF_MATRIX                     } from "../modules/process_ref_matrix/main"
include { METDECODE                              } from "../subworkflows/metdecode"


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow DNAmDeconv{

    /*
     * Initiliaze the channels
     */
    proportion_ch = Channel.empty()
    samples_ch = Channel.empty()
    atlas_tsv = Channel.empty()


    /*
     * If reference matrix has been specified, and neither
     * CelFiE or MetDecode have been specified, then:
     * skip the preprocessing and DMR selection steps
     */
    if (params.ref_matrix) {
        atlas_tsv = Channel.fromPath(params.ref_matrix).first()
        PROCESS_REF_MATRIX(atlas_tsv)
        atlas_csv = PROCESS_REF_MATRIX.out.reference_csv
    }


    if (params.input) {

        Channel.fromList(
            samplesheetToList(params.input, "assets/schema_input.json"))
            .map {
                meta, entity, cov ->
                def meta_entity = meta + [entity:entity]
                tuple(meta_entity.id, meta_entity.entity, cov) }
            .set{ samples_ch_original }

        // Add index to the second (entity) column
        def counterMap = [:]
        samples_ch = samples_ch_original
            .map { entry ->

                def label = entry[1]

                if (!counterMap.containsKey(label)) {
                    counterMap[label] = 0
                }
                counterMap[label] = counterMap[label] + 1

                def newLabel = "${label}_${counterMap[label]}"

                def newEntry = [
                    entry[0],           // Original first column
                    newLabel,           // Modified second column with index
                    entry[2]            // Original third column
                ]

                return newEntry
            }
    }


    /*
     *  Run limma DMR selection
     */
    if (params.DMRselection=="limma") {

        if (!params.merged_matrix & (!params.regions || !params.input)) {
            nextflow.Nextflow.error "\n----> ERROR: With limma DMR selection either a cluster file (--regions) + reference samples (--input) or a merged matrix (--merged_matrix) is required  <----\n"
        }

        inHousePrep(samples_ch)
        atlas_tsv = inHousePrep.out.atlas_tsv
        atlas_csv = inHousePrep.out.atlas_csv
    }

    /*
     *  Run DMRfinder DMR selection
     */

    else if (params.DMRselection=="DMRfinder"){
        DMRfinderPrep(samples_ch_original)
        atlas_tsv = DMRfinderPrep.out.atlas_tsv
        atlas_csv = DMRfinderPrep.out.atlas_csv
    }

    /*
     * Run wgbstools DMR selection
     */
    else if (params.DMRselection=="wgbstools" || params.uxm_atlas) {
        WGBSTOOLS(atlas_tsv)
        wgbstools_atlas = WGBSTOOLS.out.output
        atlas_csv = WGBSTOOLS.out.atlas_csv
        atlas_tsv = WGBSTOOLS.out.atlas_tsv
    }


    /*
     * SUBWORKFLOW: Reference-based cellular deconvolution using UXM
     */
    if (params.uxm || params.benchmark) {

        if (!params.test_bams) {
            nextflow.Nextflow.error "\n----> ERROR: The flag --test_bams (.csv file) is required for UXM tool. <----\n"
        }
        test_bams = Channel.fromList(
        samplesheetToList(params.test_bams, "assets/schema_testbams.json"))
            .map {
            meta, bam, bai ->
            def meta_entity = meta
            meta_entity.id = meta.id
            def entity = null
            tuple(meta_entity.id, entity, bam, bai) }

        /*
         * If wgbstools DMR selection, use the atlas generated
         * Otherwise, convert the DMRfinder or limma atlas
         * and convert it into a UXM-like format
         */
        if (params.DMRselection=="wgbstools" || params.uxm_atlas) {
            UXM(test_bams, wgbstools_atlas)
        }
        else {
            UXM(test_bams, atlas_tsv)
        }

        proportion_ch = proportion_ch.mix( UXM.out.uxm_proportions )
    }


    /*
     * SUBWORKFLOW: Reference-based cellular deconvolution using classical deconvolution tools
     */
    if (params.meth_atlas || params.celfie || params.metdecode || params.epidish || params.prmeth || params.methyl_resolver || params.episcore || params.cibersort || params.benchmark) {

        if (!params.test_set) {
            nextflow.Nextflow.error "\n----> ERROR: Please provide an test_set samplesheet to the pipeline e.g. '--test_set samplesheet.csv' <----\n"
        }

        // Set the testing samples channel
        test_ch = Channel.fromList(
            samplesheetToList(params.test_set, "assets/schema_testset.json"))
            .map { meta, cov -> tuple(meta.id, cov) }

        /*
         * Preprocess test samples
         * And merge them in a unique matrix
         */
        TEST_PREPROCESSING(test_ch, atlas_tsv)
        test = TEST_PREPROCESSING
                .out
                .preprocessed_test
                .collect()
        MERGE_SAMPLES('test',test)

        /*
         * SUBWORKFLOW: Reference-based cellular deconvolution using CelFiE or MetDecode
         * Note that CELFIE_PREPROCESSING performs the preprocessing that can be used by
         * both CelFiE and MetDecode (similar structure)
         */
        if (params.celfie || params.metdecode || params.benchmark) {

            // Generate CelFiE (or MetDecode) like matrices
            test_celfie_format = TEST_PREPROCESSING.out.preprocessed_celfie_test.collect()
            CELFIE_PREPROCESSING(samples_ch, atlas_tsv)
            ref_celfie_format = CELFIE_PREPROCESSING.out.filt_celfie_sample.collect()

            // Run the subworkflows based on the parameters specified
            if (params.celfie || params.benchmark) {
                CELFIE(ref_celfie_format, test_celfie_format)
                proportion_ch = proportion_ch.mix( CELFIE.out.output.map { file -> tuple('CelFiE', file) } )
            }
            if (params.metdecode || params.benchmark) {
                METDECODE(ref_celfie_format, test_celfie_format)
                proportion_ch = proportion_ch.mix( METDECODE.out.output.map { file -> tuple('MetDecode', file) } )
            }
        }

        /*
         * If not MetDecode or CelFiE, run "classical" deconvolution tools
         */
        if (params.meth_atlas || params.epidish || params.prmeth || params.methyl_resolver || params.episcore || params.cibersort || params.benchmark) {
            refBasedDeconv(atlas_csv, MERGE_SAMPLES.out.fin_matrix)
            proportion_ch = proportion_ch.concat(refBasedDeconv.out.refbased_proportions)
        }
    }


    /*
     * SUBWORKFLOW: If reference-free deconvolution tools
     * have been specified, run ref-free deconvolution
     */
    if (params.medecom || params.prmeth_rf || params.benchmark) {
        if (!params.regions) {
            nextflow.Nextflow.error "\n----> ERROR: Please provide an cluster file (--regions) for reference-free deconvolution. <----\n"
        }
        if (!params.test_set) {
            nextflow.Nextflow.error "\n----> ERROR: Please provide an test_set samplesheet to the pipeline e.g. '--test_set samplesheet.csv' <----\n"
        }
        // Set the testing samples channel
        test_ch = Channel.fromList(
            samplesheetToList(params.test_set, "assets/schema_testset.json"))
            .map { meta, cov -> tuple(meta.id, cov) }
        regions_ch = Channel.fromPath(params.regions)
        refFreeDeconv(test_ch, regions_ch.first())
        proportion_ch = proportion_ch.concat(refFreeDeconv.out.refree_proportions)
    }


    /*
     * PROCESS: Combine results in a unique table
     */
    proportion_ch = proportion_ch
                        .toList()
                        .map { list ->
                            def methods = []
                            def files = []
                            list.each { item ->
                                methods.add(item[0])
                                files.add(item[1])
                            }
                            [methods, files]
                        }
    COMBINE_FILES( proportion_ch )

}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    NfcoreTemplate.dump_parameters(workflow, params)
    NfcoreTemplate.summary(workflow, params, log)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
