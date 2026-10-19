/*
 * celfie subworkflow
 */

include { MERGE_TABLES                         } from '../../../modules/local/celfie/merge_tables/main'
include { RUN_DECONV                           } from '../../../modules/local/celfie/deconv/main'
include { MERGE_SAMPLES as MERGE_CELFIE_TEST   } from '../../../modules/local/merge_samples/main'


// combine the two processes into a subworkflow
workflow CELFIE {
    take:
    atlas         // reference atlas in the CelFiE format
    test_celfie   // bulk samples in the CelFiE format, one file per sample

    main:

    /*
     * Merge the bulk samples in a unique matrix compatible with CelFiE
     */
    MERGE_CELFIE_TEST('test_celfie',test_celfie)


    /*
     * merge data to match celfie format
     */
    MERGE_TABLES(
        atlas,
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
