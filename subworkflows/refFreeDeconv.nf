#!/usr/bin/env nextflow


include { REFREE_PREPROCESSING                              } from "../modules/refree_preprocessing/main"
include { PRMETH_RF                                         } from "../modules/refree_tools/prmeth_rf/main"
include { MEDECOM                                           } from "../modules/refree_tools/medecom/main"
include { MERGE_SAMPLES                                     } from "../modules/merge_samples/main"


workflow refFreeDeconv {

    take:
    test
    regions

    main:
    test
    // Preprocess testing samples for reference-free deconvolution tools
    REFREE_PREPROCESSING(test, regions)

    // Collect the different preprocessed samples
    refree_procTest = REFREE_PREPROCESSING
        .out
        .preprocessed_refree
        .map{_sample,cov -> [cov]}
        .collect( sort: true )
    
    // Merge the samples in a unique matrix with inner join
    MERGE_SAMPLES('atlas',refree_procTest)

    // List to collect output channels
    refree_outputChannels = Channel.empty()
    
    // Run deconvolution tool(s)
    if (params.medecom || params.benchmark) {
        MEDECOM(MERGE_SAMPLES.out.fin_matrix)
        refree_outputChannels = refree_outputChannels.mix( MEDECOM.out.output.map { file -> tuple('MeDeCom', file) } )
    }  
    if (params.prmeth_rf || params.benchmark) {
        PRMETH_RF(MERGE_SAMPLES.out.fin_matrix)
        refree_outputChannels = refree_outputChannels.mix( PRMETH_RF.out.output.map { file -> tuple('PRMeth_RF', file) } )
    }   

    emit:
    refree_proportions         = refree_outputChannels
    
}