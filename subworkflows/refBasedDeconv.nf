#!/usr/bin/env nextflow

include { METHYL_ATLAS                                      } from "../modules/methyl_atlas/main"
include { CIBERSORT                                         } from "../modules/cibersort/main"
include { EPIDISH                                           } from "../modules/epidish/main"
include { METHYL_RESOLVER                                   } from "../modules/methyl_resolver/main"
include { EPISCORE                                          } from "../modules/episcore/main"
include { PRMETH                                            } from "../modules/prmeth/main"
include { CELFIE                                            } from "../subworkflows/celfie"


workflow refBasedDeconv {

    take:
    reference
    test

    main:

    // List to collect output channels
    outputChannels = Channel.empty()

    // Run deconvolution tool(s)
    if (params.methyl_atlas || params.benchmark) {
        METHYL_ATLAS(reference, test)
        outputChannels = outputChannels.concat( Channel.of( 'meth_atlas' ).combine( METHYL_ATLAS.out.output) )
    }
    if (params.cibersort || params.benchmark) {
        CIBERSORT(reference, test)
        outputChannels = outputChannels.concat( Channel.of( 'CIBERSORT' ).combine( CIBERSORT.out.output ) )
    }
    if (params.epidish || params.benchmark) {
        EPIDISH(reference, test)
        outputChannels = outputChannels.concat(Channel.of( 'EpiDISH' ).combine( EPIDISH.out.output) )
    }
    if (params.methyl_resolver || params.benchmark) {
        METHYL_RESOLVER(reference, test)
        outputChannels = outputChannels.concat( Channel.of( 'Methyl_Resolver' ).combine( METHYL_RESOLVER.out.output ) )
    }
    if (params.episcore || params.benchmark) {
        EPISCORE(reference, test)
        outputChannels = outputChannels.concat( Channel.of( 'EpiSCORE' ).combine( EPISCORE.out.output ) )
    }
    if (params.prmeth || params.benchmark) {
        PRMETH(reference, test)
        outputChannels = outputChannels.concat( Channel.of( 'PRMeth' ).combine( PRMETH.out.output ) )
    }   
    
    emit:
    refbased_proportions         = outputChannels
}