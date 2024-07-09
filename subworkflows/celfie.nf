/*
 * celfie subworkflow
 */

include { MERGE_TABLES            } from '../modules/celfie/merge_tables/main'
include { RUN_DECONV              } from '../modules/celfie/deconv/main'


// combine the two processes into a subworkflow
workflow CELFIE {
    take:
    ref_matrix
    test_matrix

    main:

    /*
     * merge data to match celfie format
     */
    MERGE_TABLES(ref_matrix, test_matrix)


    /*
     * run deconvolution
     */
    RUN_DECONV(MERGE_TABLES.out.merged_table)

    emit:
    output             = RUN_DECONV.out.res

}