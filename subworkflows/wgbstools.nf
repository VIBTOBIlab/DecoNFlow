/*
 * wgbstools subworkflow
 */
import nextflow.Nextflow
include { INIT_GENOME                               } from '../modules/wgbstools/init_genome/main'
include { BAM2PAT                                   } from '../modules/wgbstools/bam2pat/main'
include { SEGMENT                                   } from '../modules/wgbstools/segment/main'
include { FINDMARKERS                               } from '../modules/wgbstools/findmarkers/main'
include { BUILD                                     } from '../modules/uxm/build/main'
include { BISMARK_METHYLATIONEXTRACTOR              } from '../modules/bismark_methylation_extractor/main'
include { PREPROCESSING                             } from "../modules/dmr_selection_limma/preprocessing/main" 
include { MERGE_SAMPLES                             } from "../modules/merge_samples/main"
include { CONVERT_ATLAS                             } from "../modules/convert_atlas/main"
include { SELECT_REGIONS                            } from "../modules/wgbstools/select_regions/main"
include { paramsSummaryLog;samplesheetToList        } from 'plugin/nf-schema'


workflow WGBSTOOLS {
    take:
    atlas_tsv

    main:

    if (!params.ref_bams & !params.uxm_atlas) {
        Nextflow.error "\n----> ERROR: With wgbstools you must specify the --ref_bams flag or the --uxm_atlas. <---- \n"
    }
    if (!params.groups_file & !params.uxm_atlas) {
        Nextflow.error "\n----> ERROR: A group file (--groups_file) needs to be specified when using wgbstools. <---- \n"
    }

    /*
     * Initialize the channels
     */
    fasta = params.fasta ? Channel.value(file(params.fasta)) : Channel.value(file("${params.outdir}/no_file"))
    reference_csv = Channel.empty()
    reference_tsv = Channel.empty()

    if (params.ref_bams) {
        samples_ch_original = Channel.fromList(
            samplesheetToList(params.ref_bams, "assets/schema_refbams.json"))
            .map { 
            meta, entity, bam, bai ->
            def meta_entity = meta + [entity:entity]
            meta_entity.id = meta.id
            tuple(meta_entity.id, meta_entity.entity, bam, bai) }

        def counterMap = [:]
        ref_bams = samples_ch_original
            .map { entry -> 

                def label = entry[1]
                
                if (!counterMap.containsKey(label)) {
                    counterMap[label] = 0
                }
                counterMap[label]++

                def newLabel = "${label}_${counterMap[label]}"

                def newEntry = [
                    entry[0],           // Original first column
                    newLabel,           // Modified second column with index
                    entry[2],           // Original third column
                    entry[3]            // Original fourth column
                ]

                return newEntry
            }
    }

        
    /*
     * If an uxm-like atlas has been specified, skip the the processing step
     */
    if (params.uxm_atlas) {
        wgbstools_atlas = Channel.fromPath( params.uxm_atlas )
    }
    else {

        /*
         * Initialize the genome
         */
        INIT_GENOME(
            fasta
        )

        /*
         * Convert ref bam files to pat files 
         */
        BAM2PAT(
            ref_bams, 
            INIT_GENOME.out.ref
        )

        /*
         * Segment the bam files into homogenously methylated blocks 
         */
        betas = BAM2PAT
            .out
            .beta_file
            .collect( sort: true )
        SEGMENT(betas)

        /*
         * Find markers 
         */
        group_ch = Channel.fromPath(params.groups_file)
        FINDMARKERS(
            SEGMENT.out.blocks,
            group_ch,
            betas
        )

        /*
         * Build atlas
         */
        pats = BAM2PAT
            .out
            .pat
            .collect( sort: true )
        pat_indeces = BAM2PAT
            .out
            .pat_index
            .collect( sort: true )
        BUILD(
            FINDMARKERS.out.markers, 
            group_ch, 
            pats, 
            pat_indeces
        )

        wgbstools_atlas = BUILD.out.atlas
    }


    /*
     * If other deconvolution tools have been specified, 
     * generate an atlas that can be used with these tools
     */
    if (params.meth_atlas || params.metdecode || params.celfie || params.epidish || params.prmeth || params.methyl_resolver || params.episcore || params.cibersort || params.benchmark) {

        if (!params.ref_bams) {
            Nextflow.error "\n----> ERROR: If you want to use a UXM-like atlas in combination with another more classical deconvolution tool you must specifiy the --ref_bams flag <---- \n"
        }
        
        SELECT_REGIONS(wgbstools_atlas)
        regions = SELECT_REGIONS.out.regions

        BISMARK_METHYLATIONEXTRACTOR ( // Generate cov files from bam files
            ref_bams
        )
    
        PREPROCESSING( // Pass the input data and region file to the preprocessing module
            BISMARK_METHYLATIONEXTRACTOR.out.coverage,
            regions.first()
        )

        procSamples = PREPROCESSING     // Merge the samples in a unique matrix
                        .out
                        .filt_sample
                        .collect( sort: true )
        MERGE_SAMPLES(
            'atlas', 
            procSamples
        )

        CONVERT_ATLAS(     // Create the atlas in tsv and csv format
            MERGE_SAMPLES.out.fin_matrix
        )

        reference_csv = CONVERT_ATLAS.out.atlas_csv
        reference_tsv = CONVERT_ATLAS.out.atlas_tsv
    }


    
    emit:
    output                    = wgbstools_atlas
    atlas_csv                 = reference_csv
    atlas_tsv                 = reference_tsv

}