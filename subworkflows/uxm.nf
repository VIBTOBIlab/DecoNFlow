/*
 * UXM subworkflow
 */
import nextflow.Nextflow
include { samplesheetToList                                       } from 'plugin/nf-schema'
include { BAM2PAT as BAM2PAT_TEST; BAM2PAT as BAM2PAT_REF         } from '../modules/wgbstools/bam2pat/main'
include { UXM_DECONV                                              } from '../modules/uxm/uxm_deconv/main'
include { SELECT_REGIONS                                          } from "../modules/wgbstools/select_regions/main"
include { BETA_TO_TABLE                                           } from "../modules/wgbstools/beta_to_table/main"
include { BUILD                                                   } from '../modules/uxm/build/main'
include { FINDMARKERS                                             } from '../modules/wgbstools/findmarkers/main'
include { INIT_GENOME                                             } from '../modules/wgbstools/init_genome/main'

workflow UXM {
    take:
    test_bam
    atlas

    main:
    
    fasta = params.fasta ? Channel.value(file(params.fasta)) : Channel.value(file("${params.outdir}/no_file"))


    /*
     * If a DMR selection different than wgbstools has been specified
     * convert the atlas into a wgbstools-like atlas
     */
    if (params.DMRselection!="wgbstools") {
        if (!params.ref_bams) {
            Nextflow.error "\n----> ERROR: With UXM deconvolution tool you must specify the --ref_bams flag. <---- \n"
        }
        if (!params.groups_file) {
            Nextflow.error "\n----> ERROR: A group file (--groups_file) needs to be specified when using UXM deconvolution. <---- \n"
        }

        group_ch = Channel.fromPath(params.groups_file)
        samples_ch_original = Channel.fromList(
            samplesheetToList(params.ref_bams, "assets/schema_refbams.json"))
            .map { 
            meta, entity, bam, bai ->
            meta_entity = meta.clone()
            meta_entity.id = meta.id
            tuple(meta_entity.id, entity, bam, bai) }

        // Add index to the second (entity) column
        def counterMap = [:]
        ref_bam = samples_ch_original
            .map { entry -> 

                def label = entry[1]
            
                if (!counterMap.containsKey(label)) {
                    counterMap[label] = 0
                }
                counterMap[label]++

                def newLabel = "${label}${counterMap[label]}"

                def newEntry = [
                    entry[0],           // Original first column
                    newLabel,           // Modified second column with index
                    entry[2],           // Original third column
                    entry[3]            // Original fourth column
                ]

                return newEntry
            }

        /*
        * Initialize the genome
        */
        INIT_GENOME(
            fasta
        )

        /*
         * Convert ref bam files to pat files 
         */
        BAM2PAT_REF(
            ref_bam, 
            INIT_GENOME.out.ref
        )

        // Select only chr, start and end columns
        SELECT_REGIONS(atlas)

        // Convert the regions into a wgbstools-like table
        BETA_TO_TABLE(
            SELECT_REGIONS.out.regions,
            BAM2PAT_REF.out.beta_file.collect(),
            group_ch
        )

        // Extract entity markers
        FINDMARKERS(
            BETA_TO_TABLE.out.beta_table,
            group_ch,
            BAM2PAT_REF.out.beta_file.collect()
        )

        // Build the atlas
        BUILD(
            FINDMARKERS.out.markers, 
            group_ch, 
            BAM2PAT_REF.out.pat.collect(), 
            BAM2PAT_REF.out.pat_index.collect()
        )
        atlas = BUILD.out.atlas
    }


    /*
     * Convert test bam files to pat files 
     */
    BAM2PAT_TEST(test_bam, atlas.first())
    pats = BAM2PAT_TEST
        .out
        .pat
        .collect()
    pat_indeces = BAM2PAT_TEST
        .out
        .pat_index
        .collect()


    /*
     * Run deconvolution
     */
    UXM_DECONV(pats, pat_indeces, atlas)
    

    emit:
    uxm_proportions             = Channel.of( 'UXM' ).combine( UXM_DECONV.out.res )
}