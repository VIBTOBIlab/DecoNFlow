#!/usr/bin/env nextflow

include { PREPROCESSING                                     } from "../../../modules/local/dmr_selection_limma/preprocessing/main"
include { LIMMA                                             } from "../../../modules/local/dmr_selection_limma/limma/main"
include { MERGE_SAMPLES                                     } from "../../../modules/local/merge_samples/main"


workflow markerSelection {
        take:
        samples         // channel: [ val(meta), val(entity), path(cov) ]

        main:


        /*
         * If no regions are specified, we cannot proceed with the DMR analysis
         */
        if (!params.regions) {
            nextflow.Nextflow.error "\n----> ERROR: Please provide a regions file (--regions) to the pipeline. <----\n"
        }

        /*
         * Otherwise run everything
         */
        regions_ch = channel.fromPath(params.regions).first()

        // Pass the input data and region file to the preprocessing module
        PREPROCESSING(samples, regions_ch)

        // Merge the samples in a unique matrix
        procSamples = PREPROCESSING
                        .out
                        .filt_sample
                        .collect()
        MERGE_SAMPLES('atlas', procSamples)

        // Pass the regions for the DMR analysis
        LIMMA(MERGE_SAMPLES.out.fin_matrix)
        atlas_csv = LIMMA.out.reference_csv
        atlas_tsv = LIMMA.out.reference_tsv

        emit:
        atlas_csv                 = atlas_csv
        atlas_tsv                 = atlas_tsv
}
