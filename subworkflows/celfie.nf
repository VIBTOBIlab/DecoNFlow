/*
 * celfie subworkflow
 */

include { MERGE_TABLES                                                            } from '../modules/celfie/merge_tables/main'
include { RUN_DECONV                                                              } from '../modules/celfie/deconv/main'
include { MERGE_SAMPLES as MERGE_CELFIE_REF; MERGE_SAMPLES as MERGE_CELFIE_TEST   } from '../modules/merge_samples/main'


// combine the two processes into a subworkflow
workflow CELFIE {
    take:
    ref_celfie
    test_celfie

    main:

    /*
     * Merge the samples in a unique matrix compatible with CelFiE
     */
    MERGE_CELFIE_REF('celfie_atlas',ref_celfie)    // reference samples
    MERGE_CELFIE_TEST('test_celfie',test_celfie)  // test samples


    /*
     * merge data to match celfie format
     */
    MERGE_TABLES( 
        MERGE_CELFIE_REF.out.celfie_fin_matrix, 
        MERGE_CELFIE_TEST.out.fin_matrix
    )


    /*
     * run deconvolution
     */
    nsamples = test_celfie.map { collectedItems -> collectedItems.size() }
    RUN_DECONV(MERGE_TABLES.out.merged_table, nsamples)

    emit:
    output             = RUN_DECONV.out.res

}