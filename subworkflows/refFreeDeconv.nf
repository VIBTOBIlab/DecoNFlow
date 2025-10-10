#!/usr/bin/env nextflow


include { REFREE_PREPROCESSING                              } from "../modules/refree_preprocessing/main"
include { REF_FREECELL_MIX                                  } from "../modules/refree_tools/ref_freecell_mix/main"
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
    if (params.ref_freecell_mix || params.benchmark) {
        REF_FREECELL_MIX(MERGE_SAMPLES.out.fin_matrix)
        refree_outputChannels = refree_outputChannels.mix( REF_FREECELL_MIX.out.output.map { file -> tuple('RefFreeCellMix', file) } )
    }   

    emit:
    refree_proportions         = refree_outputChannels
    
}