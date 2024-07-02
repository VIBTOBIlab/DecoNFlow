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
        - output_dir                    : ${params.output_dir}
        - regions_file                  : ${params.regions_file}
        - test_samples                  : ${params.test_samples}

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
        - ncells                        : ${params.ncells}
        - prmeth_mod                    : ${params.prmeth_mod}
        
    ==============================================================================================
    """.stripIndent()


// include processes and subworkflows to make them available for use in this script 
include { PREPROCESSING                                     } from "./modules/preprocessing/main" 
include { DMR_ANALYSIS                                      } from "./modules/dmr_analysis/main"
include { TEST_PREPROCESSING                                } from "./modules/test_preprocessing/main"
include { METHYL_ATLAS                                      } from "./modules/methyl_atlas/main"
include { CIBERSORT                                         } from "./modules/cibersort/main"
include { EPIDISH                                           } from "./modules/epidish/main"
include { METHYL_RESOLVER                                   } from "./modules/methyl_resolver/main"
include { EPISCORE                                          } from "./modules/episcore/main"
include { REFREE_PREPROCESSING                              } from "./modules/refree_preprocessing/main"
include { PRMETH                                            } from "./modules/prmeth/main"


workflow {
    // set input data
    samples_ch = Channel.fromPath(params.input, checkIfExists:true)
    // set region file
    regions_ch = Channel.fromPath(params.regions_file, checkIfExists:true)
    // set test samples
    test_ch = Channel.fromPath(params.test_samples, checkIfExists:true)

    // Pass the input data and region file to the preprocessing module
    PREPROCESSING(samples_ch, regions_ch)

    // Pass the regions for the DMR analysis
    DMR_ANALYSIS(PREPROCESSING.out.clusters)

    // Pass the DMRs to the samples to deconvolve to preprocess them
    TEST_PREPROCESSING(test_ch, DMR_ANALYSIS.out.reference)
    // Preprocess testing samples for reference-free deconvolution tools
    REFREE_PREPROCESSING(test_ch, regions_ch)

    // Run Deconvolution for the testing samples
    METHYL_ATLAS(DMR_ANALYSIS.out.reference, TEST_PREPROCESSING.out.preprocessed_test)

    CIBERSORT(DMR_ANALYSIS.out.reference, TEST_PREPROCESSING.out.preprocessed_test)

    EPIDISH(DMR_ANALYSIS.out.reference, TEST_PREPROCESSING.out.preprocessed_test)

    METHYL_RESOLVER(DMR_ANALYSIS.out.reference, TEST_PREPROCESSING.out.preprocessed_test)

    EPISCORE(DMR_ANALYSIS.out.reference, TEST_PREPROCESSING.out.preprocessed_test)

    PRMETH(DMR_ANALYSIS.out.reference, REFREE_PREPROCESSING.out.preprocessed_refree)
}