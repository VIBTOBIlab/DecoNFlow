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
include { COMBINE_FILES                          } from "../modules/local/combine_files/main"
include { MERGE_SAMPLES                          } from "../modules/local/merge_samples/main"
include { LIMMA                                  } from "../modules/local/dmr_selection_limma/limma/main"
include { PROCESS_REF_MATRIX                     } from "../modules/local/process_ref_matrix/main"
include { METDECODE                              } from "../subworkflows/local/metdecode"


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow DECONFLOW{

    /*
     * Initiliaze the channels
     */
    proportion_ch = channel.empty()
    samples_ch = channel.empty()
    atlas_tsv = channel.empty()

    /*
     * If no bulk_samples samplesheet has been specified, throw an error
     */
    if (!params.bulk_samples) {
        nextflow.Nextflow.error "\n----> ERROR: Please provide bulk samples to the pipeline e.g. '--bulk_samples bulksamples.csv' <----\n"
    }

    /*
     * If both reference matrix and reference samples have been specified, throw an error
     */
    if (params.ref_matrix && params.input) {
        nextflow.Nextflow.error "\n----> ERROR: Please provide either a reference matrix (--ref_matrix) or reference samples (--input), but not both.<----\n"
    }

    /*
     * If neither reference matrix nor reference samples have been specified, throw an error
     */
    if (!params.regions || !params.input && (!params.medecom || !params.ref_freecell_mix)) {
        nextflow.Nextflow.error "\n----> ERROR: With limma DMR selection you need both a cluster file (--regions) and reference samples (--input). Or run a reference-free deconvolution. (MeDeCom or RefFreeCellMix). <----\n"
    }

    /*
     * If reference matrix has been specified, and neither
     * CelFiE or MetDecode have been specified, then:
     * skip the preprocessing and DMR selection steps
     */
    if (params.ref_matrix) {
        atlas_tsv = channel.fromPath(params.ref_matrix).first()
        PROCESS_REF_MATRIX(atlas_tsv)
        atlas_csv = PROCESS_REF_MATRIX.out.reference_csv
    }

    /*
     * If reference samples have been specified, then:
     * run the preprocessing and DMR selection steps
     */
    else if (params.input) {
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

        /*
         *  Run limma DMR selection
         */
        markerSelection(samples_ch)
        atlas_tsv = markerSelection.out.atlas_tsv
        atlas_csv = markerSelection.out.atlas_csv
    }


    /*
     * SUBWORKFLOW: Reference-based cellular deconvolution using classical deconvolution tools
     */
    if (params.meth_atlas || params.epidish || params.houseman_eq || params.houseman_ineq ||
        params.prmeth || params.methyl_resolver || params.episcore || params.cibersort || params.benchmark) {

        // Set the testing samples channel
        test_ch = channel.fromList(
            samplesheetToList(params.bulk_samples, "assets/schema_bulk_samples.json"))
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
        if (params.meth_atlas || params.epidish || params.houseman_eq || params.houseman_ineq ||
            params.prmeth || params.methyl_resolver || params.episcore || params.cibersort || params.benchmark) {
            refBasedDeconv(atlas_csv, MERGE_SAMPLES.out.fin_matrix)
            proportion_ch = proportion_ch.concat(refBasedDeconv.out.refbased_proportions)
        }
    }


    /*
     * SUBWORKFLOW: If reference-free deconvolution tools
     * have been specified, run ref-free deconvolution
     */
    if (params.medecom || params.ref_freecell_mix || params.benchmark) {
        if (!params.regions) {
            nextflow.Nextflow.error "\n----> ERROR: Please provide an cluster file (--regions) for reference-free deconvolution. <----\n"
        }
        if (!params.test_set) {
            nextflow.Nextflow.error "\n----> ERROR: Please provide an test_set samplesheet to the pipeline e.g. '--test_set samplesheet.csv' <----\n"
        }
        // Set the testing samples channel
        test_ch = channel.fromList(
            samplesheetToList(params.test_set, "assets/schema_testset.json"))
            .map { meta, cov -> tuple(meta.id, cov) }
        regions_ch = channel.fromPath(params.regions)
        refFreeDeconv(test_ch, regions_ch.first())
        proportion_ch = proportion_ch.concat(refFreeDeconv.out.refree_proportions)
    }


    /*
     * PROCESS: Combine results in a unique table
     */
    proportion_ch = proportion_ch
                        .toSortedList{ a, b -> a[0] <=> b[0] }
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
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
