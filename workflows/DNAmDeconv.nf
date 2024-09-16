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
                 _____  _   _                      _____                            
                |  __ \\| \\ | |   /\\               |  __ \\                           
                | |  | |  \\| |  /  \\   _ __ ___   | |  | | ___  ___ ___  _ ____   __
                | |  | | . ` | / /\\ \\ | '_ ` _ \\  | |  | |/ _ \\/ __/ _ \\| '_ \\ \\ / /
                | |__| | |\\  |/ ____ \\| | | | | | | |__| |  __/ (_| (_) | | | \\ V / 
                |_____/|_| \\_/_/    \\_\\_| |_| |_| |_____/ \\___|\\___\\___/|_| |_|\\_/  

    ==============================================================================================
    """.stripIndent()


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { samplesheetToList                      } from 'plugin/nf-schema'
include { inHousePrep                            } from "../subworkflows/inHousePrep"
include { DSSPrep                                } from "../subworkflows/DSSPrep"
include { refBasedDeconv                         } from "../subworkflows/refBasedDeconv"
include { refFreeDeconv                          } from "../subworkflows/refFreeDeconv"
include { CELFIE                                 } from "../subworkflows/celfie"
include { CELFIE_PREPROCESSING                   } from "../modules/celfie/preprocessing/main"
include { TEST_PREPROCESSING                     } from "../modules/test_preprocessing/main"
include { COMBINE_FILES                          } from "../modules/combine_files/main"
include { MERGE_SAMPLES                          } from "../modules/merge_samples/main"
include { PROCESS_REF_MATRIX                     } from "../modules/process_ref_matrix/main"


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow DNAmDeconv{

    // List to collect cellular proportion channels
    proportion_ch = Channel.empty()

    // Set the testing samples channel
    test_ch = Channel.fromList(
        samplesheetToList(params.test_set, "assets/schema_testset.json"))
        .map { meta, cov -> tuple(meta.id, cov) }

    if (params.input) {
        Channel.fromList(
            samplesheetToList(params.input, "assets/schema_input.json"))
            .map { 
                meta, entity, cov ->
                meta_entity = meta.clone()
                meta_entity.entity = entity
                meta_entity.id = meta.id
                tuple(meta_entity.id, meta_entity.entity, cov) }
            .set{ samples_ch_original }


        // Add index to the second (entity) column
        def counterMap = [:]
        def samples_ch = samples_ch_original
            .map { entry -> 

                def label = entry[1]
            
                if (!counterMap.containsKey(label)) {
                    counterMap[label] = 0
                }
                counterMap[label]++

                def newLabel = "${label}${counterMap[label]}"

                def newEntry = [
                    entry[0],           // Original first column
                    newLabel,           // Modified second column with index
                    entry[2]            // Original third column
                ]

                return newEntry
            }

        /*
         * If reference matrix has been specified, skip the preprocessing step
         */
        if (params.ref_matrix) {
            atlas_tsv = Channel.fromPath(params.ref_matrix)
            PROCESS_REF_MATRIX(atlas_tsv)
            atlas_csv = PROCESS_REF_MATRIX.out.reference_csv
        }
        else {
            /*
             * SUBWORKFLOW:
             *     - inHousePrep if regions specified
             *     - Other DMRselection tools else
             */
            if (params.DMRselection=="custom") {
                regions_ch = Channel.fromPath(params.regions).first()
                inHousePrep(samples_ch, regions_ch)
                atlas_tsv = inHousePrep.out.atlas_tsv
                atlas_csv = inHousePrep.out.atlas_csv
            } 
            else if (params.DMRselection=="DSS"){ 
                DSSPrep(samples_ch)
                atlas_tsv = DSSPrep.out.atlas_tsv
                atlas_csv = DSSPrep.out.atlas_csv
            }
        }
    

        // Preprocess test samples
        TEST_PREPROCESSING(test_ch, atlas_tsv)
        test = TEST_PREPROCESSING
                .out
                .preprocessed_test
                .collect()
    
        // Merge the samples in a unique matrix
        MERGE_SAMPLES('test',test)


        /*
         * SUBWORKFLOW: Reference-based cellular deconvolution using CelFiE
         */
        if ((params.celfie || params.benchmark) & !(params.ref_matrix)) {
            // Merge the samples in a unique matrix compatible with CelFiE
            test_celfie = TEST_PREPROCESSING.out.preprocessed_celfie_test.collect()
            CELFIE_PREPROCESSING(samples_ch, atlas_tsv)
            ref_celfie = CELFIE_PREPROCESSING.out.filt_celfie_sample.collect()
            CELFIE(ref_celfie, test_celfie)
            proportion_ch = proportion_ch.concat( Channel.of( 'CelFiE' ).combine( CELFIE.out.output ) )
        }   


        /*
         * SUBWORKFLOW: Reference-based cellular deconvolution 
         */
        refBasedDeconv(atlas_csv, MERGE_SAMPLES.out.fin_matrix)
        proportion_ch = proportion_ch.concat(refBasedDeconv.out.refbased_proportions)
            
    }



    /*
     * SUBWORKFLOW: Reference-free cellular deconvolution 
     */
    if (!(params.input) || (params.benchmark)) {
        regions_ch = Channel.fromPath(params.regions).first()
        refFreeDeconv(test_ch, regions_ch)
        proportion_ch = proportion_ch.concat(refFreeDeconv.out.refree_proportions)    
    }


    /*
     * PROCESS: Combine results in a unique table 
     */
    COMBINE_FILES( proportion_ch.collect { t -> t[0] + ':' + t[1] } )
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