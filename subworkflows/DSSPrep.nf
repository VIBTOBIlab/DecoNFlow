#!/usr/bin/env nextflow

include { DSS_PREPROCESSING                         } from "../modules/dmr_selection_dss/preprocessing/main"
include { DSS_SELECTION                             } from "../modules/dmr_selection_dss/dss/main"

workflow DSSPrep {
        take:
        samples         // channel: [ val(meta), val(entity), path(cov) ]

        main:

        // Pass the input data and region file to the preprocessing module
        DSS_PREPROCESSING(samples)
        
        // Merge the samples in a unique matrix
        dssSamples = DSS_PREPROCESSING
                        .out
                        .dss_format_sample
                        .collect()
        dssEntity = DSS_PREPROCESSING
                        .out
                        .entity
                        .collect()
        
        // Pass the samples for the DMR analysis
        DSS_SELECTION(dssSamples,dssEntity)

        emit:
        atlas_csv                 = DSS_SELECTION.out.reference_csv
        atlas_tsv                 = DSS_SELECTION.out.reference_tsv
}
