/*
 * celfie subworkflow
 */
include { MERGE_SAMPLES as MERGE_CELFIE_REF; MERGE_SAMPLES as MERGE_CELFIE_TEST   } from '../modules/merge_samples/main'
include { METDECODE_DECONV                                                         } from '../modules/metdecode/main'

// combine the two processes into a subworkflow
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
     * run deconvolution
     */
    METDECODE_DECONV(
        MERGE_CELFIE_REF.out.celfie_fin_matrix, 
        MERGE_CELFIE_TEST.out.fin_matrix
    )

    emit:
    output             = METDECODE_DECONV.out.res

}