#!/usr/bin/env nextflow


include { REFREE_PREPROCESSING                              } from "../modules/refree_preprocessing/main"
include { PRMETH_RF                                         } from "../modules/prmeth_rf/main"
include { MEDECOM                                           } from "../modules/medecom/main"


workflow refFreeDeconv {

    take:
    test
    regions

    main:

    // Preprocess testing samples for reference-free deconvolution tools
    REFREE_PREPROCESSING(test, regions)
    refree_procTest = REFREE_PREPROCESSING.out.preprocessed_refree
    
    // List to collect output channels
    refree_outputChannels = Channel.empty()
    
    // Run deconvolution tool(s)
    if (params.medecom || params.benchmark) {
        MEDECOM(refree_procTest)
        refree_outputChannels = refree_outputChannels.concat( Channel.of( 'MeDeCom' ).combine( MEDECOM.out.output) )
    }  
    if (params.prmeth_rf || params.benchmark) {
        PRMETH_RF(refree_procTest)
        refree_outputChannels = refree_outputChannels.concat( Channel.of( 'PRMeth_RF' ).combine( PRMETH_RF.out.output ) )
    }   

    emit:
    refree_proportions         = refree_outputChannels
    
}