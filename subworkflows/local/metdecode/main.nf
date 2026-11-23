/*
 * metdecode subworkflow
 */
include { MERGE_SAMPLES as MERGE_CELFIE_TEST   } from '../../../modules/local/merge_samples/main'
include { METDECODE_DECONV                     } from '../../../modules/local/metdecode/main'
include { INTERSECT                            } from '../../../modules/local/intersect/main'


workflow METDECODE {
    take:
    atlas            // reference atlas in the CelFiE format
    test_metdecode   // bulk samples in the CelFiE format, one file per sample

    main:

    /*
     * Merge the bulk samples in a unique matrix compatible with MetDecode
     */
    MERGE_CELFIE_TEST( // test samples
        'test_celfie',
        test_metdecode
    )

    /*
     * Intersect the matrices
     */
    INTERSECT(
        atlas,
        MERGE_CELFIE_TEST.out.fin_matrix
    )

    /*
     * run deconvolution
     */
    METDECODE_DECONV(
        INTERSECT.out.atlas,
        INTERSECT.out.samples
    )

    emit:
    output             = METDECODE_DECONV.out.res

}
