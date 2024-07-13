#!/usr/bin/env nextflow

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


// include processes and subworkflows to make them available for use in this script 
include { inHousePrep                                       } from "../subworkflows/inHousePrep"
include { refBasedDeconv                                    } from "../subworkflows/refBasedDeconv"
include { refFreeDeconv                                     } from "../subworkflows/refFreeDeconv"
include { CELFIE                                            } from "../subworkflows/celfie"
include { TEST_PREPROCESSING                                } from "../modules/test_preprocessing/main"
include { COMBINE_FILES                                     } from "../modules/combine_files/main"


workflow DNAmDeconv{

    // List to collect cellular proportion channels
    proportion_ch = Channel.empty()

    // Set the testing samples channel
    test_ch = Channel.fromPath(params.test_set)

    if (params.input) {
        samples_ch = Channel.fromPath(params.input)

        /*
         * SUBWORKFLOW:
         *     - inHousePrep if regions specified
         *     - Other DMRselection tools else
         */
        if (params.DMRselection=="custom") {
            regions_ch = Channel.fromPath(params.regions)
            inHousePrep(samples_ch, regions_ch)
            dmrs = inHousePrep.out.dmrs
        } 
        
        //else if (params.regions=="DMRfinder"){ 
        //    println "No regions: specify them (or wait for modules reference = DMRfinder, DSS, etc)"
            // dmrs = DMRfinder()
        //}

        // Preprocess test samples
        TEST_PREPROCESSING(test_ch, dmrs)
        test = TEST_PREPROCESSING.out.preprocessed_test


        /*
         * SUBWORKFLOW: Reference-based cellular deconvolution using CelFiE
         */
        if (params.celfie || params.benchmark) {
            test_celfie = TEST_PREPROCESSING.out.celfie_test
            CELFIE(inHousePrep.out.celfie_ref, test_celfie)
            proportion_ch = proportion_ch.concat( Channel.of( 'CelFiE' ).combine( CELFIE.out.output ) )
        }   


        /*
         * SUBWORKFLOW: Reference-based cellular deconvolution 
         */
        refBasedDeconv(dmrs, test)
        proportion_ch = proportion_ch.concat(refBasedDeconv.out.refbased_proportions)
            
    }



    /*
     * SUBWORKFLOW: Reference-free cellular deconvolution 
     */
    if (!(params.input) || (params.benchmark)) {
        if (params.regions) {
            regions_ch = Channel.fromPath(params.regions)
            refFreeDeconv(test_ch, regions_ch)
            proportion_ch = proportion_ch.concat(refFreeDeconv.out.refree_proportions)
        } else {
            println "Region file is required for ref-free deconvolution"
        }
    }


    /*
     * PROCESS: Combine results in a unique table 
     */
    COMBINE_FILES( proportion_ch.collect { t -> t[0] + ':' + t[1] } )
}