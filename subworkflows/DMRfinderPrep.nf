#!/usr/bin/env nextflow

include { DMRFINDER_PREPROCESSING                         } from "../modules/dmr_selection_dmrfinder/preprocessing/main"
include { DMRFINDER_COMBINE                               } from "../modules/dmr_selection_dmrfinder/combine/main"
include { DMRFINDER_SELECTION                             } from "../modules/dmr_selection_dmrfinder/dmrfinder/main"


workflow DMRfinderPrep {
        take:
        samples         // channel: [ val(meta), val(entity), path(cov) ]

        main:
        // Create the correct sample names format for DMRfinder
        samples_new = samples
            .map { sample_id, condition, file_path ->
                    [condition, sample_id]}
            .groupTuple()

        condition = samples_new
            .map{ condition,sample_id -> condition }
            .collect()
            .map { it.join(',')}
 
        sampleid = samples_new
            .map{ condition,sample_id -> sample_id.collect{ it + "_dmrfinder_format" }.join(',') }
            .collect()
            .map { it.join(' ')}

        // Pass the input data to the preprocessing module
        DMRFINDER_PREPROCESSING(samples)
        
        // Merge the samples in a unique matrix
        dmrfindersamples = DMRFINDER_PREPROCESSING
                .out
                .dmrfinder_format_sample
                .collect( sort: true )
        
	DMRFINDER_COMBINE(dmrfindersamples)
        
        		
        // Pass the samples for the DMR analysis
        DMRFINDER_SELECTION(
                DMRFINDER_COMBINE.out,
                sampleid,
                condition)

        emit:
        atlas_csv                 = DMRFINDER_SELECTION.out.reference_csv
        atlas_tsv                 = DMRFINDER_SELECTION.out.reference_tsv
}
