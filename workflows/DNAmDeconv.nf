#!/usr/bin/env nextflow

// Set a header made using https://patorjk.com/software/taag (but be sure to escape characters such as dollar signs and backslashes, e.g., '$'=> '\$' and '\' =>'\\')
log.info """
    ================================================================================================    

                                                                                                            
 ____   _____  ____  ___   _   _ __     __  ____   _____  _   _   ____  _   _  __  __     _     ____   _  __
|  _ \\ | ____|/ ___|/ _ \\ | \\ | |\\ \\   / / | __ ) | ____|| \\ | | / ___|| | | ||  \\/  |   / \\   |  _ \\ | |/ /
| | | ||  _| | |   | | | ||  \\| | \\ \\ / /  |  _ \\ |  _|  |  \\| || |    | |_| || |\\/| |  / _ \\  | |_) || ' / 
| |_| || |___| |___| |_| || |\\  |  \\ V /   | |_) || |___ | |\\  || |___ |  _  || |  | | / ___ \\ |  _ < | . \\ 
|____/ |_____|\\____|\\___/ |_| \\_|   \\_/    |____/ |_____||_| \\_| \\____||_| |_||_|  |_|/_/   \\_\\|_| \\_\\|_|\\_\\
                                                                                                            

    ================================================================================================

    POSITIONAL PARAMETERS:
        - input                         : ${params.input}
        - output_dir                    : ${params.outdir}
        - regions_file                  : ${params.regions}
        - test_samples                  : ${params.test}

    OPTIONAL PARAMETERS:
        - min_counts                    : ${params.min_counts}
        - min_cpgs                      : ${params.min_cpgs}
        - merging_approach              : ${params.merging_approach}
        - chunk_size                    : ${params.chunk_size}
        - ncores                        : ${params.ncores}   // still need to include it in the modules so not working now
        - adjp                          : ${params.adjp}
        - adj_method                    : ${params.adj_method}
        - collapse_method               : ${params.collapse_method}
        - direction                     : ${params.direction}
        - top                           : ${params.top}
        - refree_min_cpgs               : ${params.refree_min_cpgs}
        - refree_min_counts             : ${params.refree_min_counts}

    EPIDISH PARAMETERS:
        - mod                           : ${params.mod}
    
    MethylResolver PARAMETERS:
        - alpha                         : ${params.alpha}
    
    EpiSCORE PARAMETERS:
        - weight                        : ${params.weight}
    
    PRMeth PARAMETERS:
        - prmeth_mod                    : ${params.prmeth_mod}

    MeDeCom PARAMETERS:
        - clusters                      : ${params.clusters}
        - ninit                         : ${params.ninit}
        - nfold                         : ${params.nfold}
        - itermax                       : ${params.itermax}
        - ncores                        : ${params.ncores_medecom} // not yet implemented

    CelFiE PARAMETERS:
        - nsamples                      : ${params.nsamples}
        - celfie_maxiter                : ${params.celfie_maxiter}
        - unknown                       : ${params.unknown}
        - parall_job                    : ${params.parall_job}
        - converg                       : ${params.converg}
        - celfie_randrest               : ${params.celfie_randrest}
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
    test_ch = Channel.fromPath(params.test)

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