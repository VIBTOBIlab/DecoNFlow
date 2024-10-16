/*
 * celfie subworkflow
 */
include { MERGE_SAMPLES as MERGE_CELFIE_REF; MERGE_SAMPLES as MERGE_CELFIE_TEST   } from '../modules/merge_samples/main'
include { METDECODE_DECONV                                                        } from '../modules/metdecode/main'
include { INTERSECT                                                               } from '../modules/intersect/main'


workflow METDECODE {
    take:
    ref_metdecode
    test_metdecode

    main:

    /*
     * Merge the samples in a unique matrix compatible with MetDecode
     */
    MERGE_CELFIE_REF( // reference samples
        'ref_celfie', 
        ref_metdecode
    )    
    MERGE_CELFIE_TEST( // test samples
        'test_celfie',
        test_metdecode
    )

    /*
     * Intersect the matrices
     */  
    INTERSECT(
        MERGE_CELFIE_REF.out.celfie_fin_matrix, 
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