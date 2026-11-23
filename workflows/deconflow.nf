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
include { PROCESS_COUNT_MATRIX as PROCESS_CELFIE_MATRIX    } from "../modules/local/process_count_matrix/main"
include { PROCESS_COUNT_MATRIX as PROCESS_METDECODE_MATRIX } from "../modules/local/process_count_matrix/main"
include { TEST_PREPROCESSING as TEST_PREPROCESSING_CELFIE    } from "../modules/local/test_preprocessing/main"
include { TEST_PREPROCESSING as TEST_PREPROCESSING_METDECODE } from "../modules/local/test_preprocessing/main"
include { TEST_PREPROCESSING as TEST_PREPROCESSING_COUNTS    } from "../modules/local/test_preprocessing/main"
include { MERGE_SAMPLES as MERGE_CELFIE_ATLAS    } from "../modules/local/merge_samples/main"
include { METDECODE                              } from "../subworkflows/local/metdecode"
include { classicToolsSelected                   } from "../subworkflows/local/utils_nfcore_deconflow_pipeline"
include { celfieSelected                         } from "../subworkflows/local/utils_nfcore_deconflow_pipeline"
include { metdecodeSelected                      } from "../subworkflows/local/utils_nfcore_deconflow_pipeline"
include { atlasFromReferenceSamples              } from "../subworkflows/local/utils_nfcore_deconflow_pipeline"
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
    def run_celfie = celfieSelected()
    def run_metdecode = metdecodeSelected()
    def run_ref_based = refBasedToolsSelected()
    def run_ref_free = refFreeToolsSelected()

    /*
     * The atlas is built from the reference samples (--input) only if a selected
     * tool has no reference matrix of its own (--ref_matrix, --celfie_ref_matrix,
     * --metdecode_ref_matrix)
     */
    def run_atlas = atlasFromReferenceSamples()

    /*
     * Regions used by the limma DMR selection and the reference-free deconvolution:
     * the regions file (--regions) or, if not given, the CpG islands of a genome
     * downloaded from UCSC (--cgi_genome)
     */
    def needs_regions = run_atlas || run_ref_free
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
     * Build the atlas from the reference samples (--input):
     * run the preprocessing and DMR selection steps
     */
    if (run_atlas) {
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
        limma_atlas_tsv = markerSelection.out.atlas_tsv
        limma_atlas_csv = markerSelection.out.atlas_csv
    }


    /*
     * SUBWORKFLOW: Reference-based cellular deconvolution using classical deconvolution tools,
     * with the reference matrix (--ref_matrix) or the atlas of the reference samples.
     * The bulk samples are preprocessed on the regions of the atlas.
     */
    if (run_classic) {
        if (params.ref_matrix) {
            atlas_tsv = channel.fromPath(params.ref_matrix).first()
            PROCESS_REF_MATRIX(atlas_tsv)
            atlas_csv = PROCESS_REF_MATRIX.out.reference_csv
        }
        else {
            atlas_tsv = limma_atlas_tsv
            atlas_csv = limma_atlas_csv
        }
        TEST_PREPROCESSING(test_ch, atlas_tsv)
        MERGE_SAMPLES('test', TEST_PREPROCESSING.out.preprocessed_test.collect())
        refBasedDeconv(atlas_csv, MERGE_SAMPLES.out.fin_matrix)
        refbased_proportions = refbased_proportions.concat(refBasedDeconv.out.refbased_proportions)
    }


    /*
     * Atlas of read counts built from the reference samples, for CelFiE and
     * MetDecode when they have no reference matrix of their own
     */
    if ((run_celfie && !params.celfie_ref_matrix) || (run_metdecode && !params.metdecode_ref_matrix)) {
        CELFIE_PREPROCESSING(samples_ch, limma_atlas_tsv)
        MERGE_CELFIE_ATLAS('celfie_atlas', CELFIE_PREPROCESSING.out.filt_celfie_sample.collect())
        counts_atlas = MERGE_CELFIE_ATLAS.out.celfie_fin_matrix

        // Reuse the bulk samples preprocessed for the classical tools if they share the atlas
        if (run_classic && !params.ref_matrix) {
            counts_test = TEST_PREPROCESSING.out.preprocessed_celfie_test.collect()
        }
        else {
            TEST_PREPROCESSING_COUNTS(test_ch, limma_atlas_tsv)
            counts_test = TEST_PREPROCESSING_COUNTS.out.preprocessed_celfie_test.collect()
        }
    }


    /*
     * SUBWORKFLOW: Reference-based cellular deconvolution using CelFiE, with its
     * own reference matrix (--celfie_ref_matrix) or the atlas of the reference samples
     */
    if (run_celfie) {
        if (params.celfie_ref_matrix) {
            celfie_matrix = channel.fromPath(params.celfie_ref_matrix).first()
            PROCESS_CELFIE_MATRIX(celfie_matrix)
            TEST_PREPROCESSING_CELFIE(test_ch, celfie_matrix)
            celfie_atlas = PROCESS_CELFIE_MATRIX.out.atlas
            celfie_test = TEST_PREPROCESSING_CELFIE.out.preprocessed_celfie_test.collect()
        }
        else {
            celfie_atlas = counts_atlas
            celfie_test = counts_test
        }
        CELFIE(celfie_atlas, celfie_test)
        refbased_proportions = refbased_proportions.mix( CELFIE.out.output.map { file -> tuple('CelFiE', file) } )
    }


    /*
     * SUBWORKFLOW: Reference-based cellular deconvolution using MetDecode, with its
     * own reference matrix (--metdecode_ref_matrix) or the atlas of the reference samples
     */
    if (run_metdecode) {
        if (params.metdecode_ref_matrix) {
            metdecode_matrix = channel.fromPath(params.metdecode_ref_matrix).first()
            PROCESS_METDECODE_MATRIX(metdecode_matrix)
            TEST_PREPROCESSING_METDECODE(test_ch, metdecode_matrix)
            metdecode_atlas = PROCESS_METDECODE_MATRIX.out.atlas
            metdecode_test = TEST_PREPROCESSING_METDECODE.out.preprocessed_celfie_test.collect()
        }
        else {
            metdecode_atlas = counts_atlas
            metdecode_test = counts_test
        }
        METDECODE(metdecode_atlas, metdecode_test)
        refbased_proportions = refbased_proportions.mix( METDECODE.out.output.map { file -> tuple('MetDecode', file) } )
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
