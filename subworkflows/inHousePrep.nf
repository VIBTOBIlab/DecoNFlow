#!/usr/bin/env nextflow

include { PREPROCESSING                                     } from "../modules/dmr_selection_limma/preprocessing/main" 
include { LIMMA                                             } from "../modules/dmr_selection_limma/limma/main"
include { MERGE_SAMPLES                                     } from "../modules/merge_samples/main"


workflow inHousePrep {
        take:
        samples         // channel: [ val(meta), val(entity), path(cov) ]

        main:


        /*
         * If only the merged matrix has been specified, skip the preprocessing step
         */
        if (params.merged_matrix) {
                fin_matrix = Channel.fromPath(params.merged_matrix)
                LIMMA(fin_matrix)
                atlas_tsv = LIMMA.out.reference_tsv.first()
                atlas_csv = LIMMA.out.reference_csv.first()
        }


        /*
         * Otherwise run everything
         */
        else {
                
                // Read the cluster file
                regions_ch = Channel.fromPath(params.regions).first()

                // Pass the input data and region file to the preprocessing module
                PREPROCESSING(samples, regions_ch) 
                
                // Merge the samples in a unique matrix
                procSamples = PREPROCESSING
                                .out
                                .filt_sample
                                .collect()                              
                MERGE_SAMPLES('ref_based', procSamples)

                // Pass the regions for the DMR analysis
                LIMMA(MERGE_SAMPLES.out.fin_matrix)
                atlas_csv = LIMMA.out.reference_csv
                atlas_tsv = LIMMA.out.reference_tsv
        }

        emit:
        atlas_csv                 = atlas_csv
        atlas_tsv                 = atlas_tsv
}
