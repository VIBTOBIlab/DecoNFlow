#!/usr/bin/env nextflow


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { samplesheetToList                      } from 'plugin/nf-schema'
include { markerSelection                        } from "../subworkflows/local/markerSelection"
include { refBasedDeconv                         } from "../subworkflows/local/refBasedDeconv"
include { refFreeDeconv                          } from "../subworkflows/local/refFreeDeconv"
include { CELFIE                                 } from "../subworkflows/local/celfie"
include { CELFIE_PREPROCESSING                   } from "../modules/local/celfie/preprocessing/main"
include { TEST_PREPROCESSING                     } from "../modules/local/test_preprocessing/main"
include { COMBINE_FILES as COMBINE_REFBASED      } from "../modules/local/combine_files/main"
include { COMBINE_FILES as COMBINE_REFFREE       } from "../modules/local/combine_files/main"
include { DECONV_REPORT                          } from "../modules/local/deconv_report/main"
include { FORMAT_COVERAGE as FORMAT_REF_COVERAGE  } from "../modules/local/format_coverage/main"
include { CGI_REGIONS                            } from "../modules/local/cgi_regions/main"
include { FORMAT_COVERAGE as FORMAT_BULK_COVERAGE } from "../modules/local/format_coverage/main"
include { MERGE_SAMPLES                          } from "../modules/local/merge_samples/main"
include { LIMMA                                  } from "../modules/local/dmr_selection_limma/limma/main"
include { PROCESS_REF_MATRIX                     } from "../modules/local/process_ref_matrix/main"
include { METDECODE                              } from "../subworkflows/local/metdecode"
include { classicToolsSelected                   } from "../subworkflows/local/utils_nfcore_deconflow_pipeline"
include { celfieLikeToolsSelected                } from "../subworkflows/local/utils_nfcore_deconflow_pipeline"
include { refBasedToolsSelected                  } from "../subworkflows/local/utils_nfcore_deconflow_pipeline"
include { refFreeToolsSelected                   } from "../subworkflows/local/utils_nfcore_deconflow_pipeline"


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow DECONFLOW{

    /*
     * Initiliaze the channels
     */
    refbased_proportions = channel.empty()
    reffree_proportions = channel.empty()
    samples_ch = channel.empty()
    atlas_tsv = channel.empty()

    /*
     * Deconvolution tools to run. The combinations of parameters have already
     * been checked by validateInputParameters() in PIPELINE_INITIALISATION.
     */
    def run_classic = classicToolsSelected()
    def run_celfie_like = celfieLikeToolsSelected()
    def run_ref_based = refBasedToolsSelected()
    def run_ref_free = refFreeToolsSelected()

    /*
     * Regions used by the limma DMR selection and the reference-free deconvolution:
     * the regions file (--regions) or, if not given, the CpG islands of a genome
     * downloaded from UCSC (--cgi_genome)
     */
    def needs_regions = (run_ref_based && !params.ref_matrix) || run_ref_free
    regions_ch = channel.empty()
    if (needs_regions && params.regions) {
        regions_ch = channel.fromPath(params.regions).first()
    }
    else if (needs_regions) {
        def cgi_url = "https://hgdownload.soe.ucsc.edu/goldenPath/${params.cgi_genome}/database/cpgIslandExt.txt.gz"
        CGI_REGIONS(channel.of([params.cgi_genome, file(cgi_url)]))
        regions_ch = CGI_REGIONS.out.regions.first()
    }

    /*
     * Read the bulk samples to deconvolve and convert their coverage files
     * (Bismark .cov or MethylDackel .bedGraph) into the common CpG format
     */
    bulk_samples_ch = channel.fromList(
        samplesheetToList(params.bulk_samples, "assets/schema_bulk_samples.json"))
        .map { meta, cov -> tuple(meta.id, cov) }
    FORMAT_BULK_COVERAGE(bulk_samples_ch)
    test_ch = FORMAT_BULK_COVERAGE.out.coverage

    /*
     * If a reference matrix has been specified, skip the
     * preprocessing and DMR selection steps
     */
    if (run_ref_based && params.ref_matrix) {
        atlas_tsv = channel.fromPath(params.ref_matrix).first()
        PROCESS_REF_MATRIX(atlas_tsv)
        atlas_csv = PROCESS_REF_MATRIX.out.reference_csv
    }

    /*
     * Otherwise build the atlas from the reference samples:
     * run the preprocessing and DMR selection steps
     */
    else if (run_ref_based) {
        channel.fromList(
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

        // Convert the coverage files of the reference samples into the common CpG format
        FORMAT_REF_COVERAGE(samples_ch.map { id, label, cov -> tuple([id, label], cov) })
        samples_ch = FORMAT_REF_COVERAGE.out.coverage.map { key, cov -> [key[0], key[1], cov] }

        /*
         *  Run limma DMR selection
         */
        markerSelection(samples_ch, regions_ch)
        atlas_tsv = markerSelection.out.atlas_tsv
        atlas_csv = markerSelection.out.atlas_csv
    }


    /*
     * SUBWORKFLOW: Reference-based cellular deconvolution using classical deconvolution tools
     */
    if (run_ref_based) {

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
        if (run_celfie_like) {

            // Generate CelFiE (or MetDecode) like matrices
            test_celfie_format = TEST_PREPROCESSING.out.preprocessed_celfie_test.collect()
            CELFIE_PREPROCESSING(samples_ch, atlas_tsv)
            ref_celfie_format = CELFIE_PREPROCESSING.out.filt_celfie_sample.collect()

            // Run the subworkflows based on the parameters specified
            if (params.celfie || params.benchmark) {
                CELFIE(ref_celfie_format, test_celfie_format)
                refbased_proportions = refbased_proportions.mix( CELFIE.out.output.map { file -> tuple('CelFiE', file) } )
            }
            if (params.metdecode || params.benchmark) {
                METDECODE(ref_celfie_format, test_celfie_format)
                refbased_proportions = refbased_proportions.mix( METDECODE.out.output.map { file -> tuple('MetDecode', file) } )
            }
        }

        /*
         * If not MetDecode or CelFiE, run "classical" deconvolution tools
         */
        if (run_classic) {
            refBasedDeconv(atlas_csv, MERGE_SAMPLES.out.fin_matrix)
            refbased_proportions = refbased_proportions.concat(refBasedDeconv.out.refbased_proportions)
        }
    }


    /*
     * SUBWORKFLOW: If reference-free deconvolution tools
     * have been specified, run ref-free deconvolution
     */
    if (run_ref_free) {
        refFreeDeconv(test_ch, regions_ch)
        reffree_proportions = reffree_proportions.concat(refFreeDeconv.out.refree_proportions)
    }


    /*
     * PROCESS: Combine the results of each type of deconvolution in a table.
     * Reference-based and reference-free results are kept separate, since
     * reference-free tools estimate unlabelled components (e.g. LMC1, V1)
     * instead of the cell types of the reference.
     */
    COMBINE_REFBASED( collectResults(refbased_proportions) )
    COMBINE_REFFREE( collectResults(reffree_proportions) )


    /*
     * PROCESS: Generate an HTML report with the results of each tool and,
     * if a ground truth is provided, the evaluation of the reference-based tools
     */
    def ground_truth = params.ground_truth && run_ref_based ? file(params.ground_truth) : []
    DECONV_REPORT(
        COMBINE_REFBASED.out.clusters
            .mix(COMBINE_REFFREE.out.clusters)
            .collect(),
        ground_truth
    )

}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
 * Gather the (tool, result) tuples of a channel into a single [tools, results]
 * pair, sorted by tool name. Emits nothing when no tool of that type was run.
 */
def collectResults(results) {
    return results
        .toSortedList { a, b -> a[0] <=> b[0] }
        .filter { list -> !list.isEmpty() }
        .map { list -> [list.collect { item -> item[0] }, list.collect { item -> item[1] }] }
}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
