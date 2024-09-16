#!/usr/bin/env nextflow

include { PREPROCESSING                                     } from "../modules/dmr_selection_limma/preprocessing/main" 
include { LIMMA                                             } from "../modules/dmr_selection_limma/limma/main"
include { MERGE_SAMPLES                                     } from "../modules/merge_samples/main"


workflow inHousePrep {
        take:
        samples         // channel: [ val(meta), val(entity), path(cov) ]
        regions         // channel: path(regions)

        main:

        // Pass the input data and region file to the preprocessing module
        PREPROCESSING(samples, regions.first())
        
        // Merge the samples in a unique matrix
        procSamples = PREPROCESSING
                        .out
                        .filt_sample
                        .collect()
        MERGE_SAMPLES('ref_based', procSamples)

        // Pass the regions for the DMR analysis
        LIMMA(MERGE_SAMPLES.out.fin_matrix)

        emit:
        atlas_csv                 = LIMMA.out.reference_csv
        atlas_tsv                 = LIMMA.out.reference_tsv
}
