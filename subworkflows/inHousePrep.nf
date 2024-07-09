#!/usr/bin/env nextflow

include { PREPROCESSING                                     } from "../modules/preprocessing/main" 
include { LIMMA                                             } from "../modules/limma/main"

workflow inHousePrep {
        take:
        samples
        regions

        main:
        // Pass the input data and region file to the preprocessing module
        PREPROCESSING(samples, regions)
        // Pass the regions for the DMR analysis
        LIMMA(PREPROCESSING.out.clusters)

        emit:
        dmrs                    = LIMMA.out.reference
        celfie_ref              = PREPROCESSING.out.celfie_ref
}
