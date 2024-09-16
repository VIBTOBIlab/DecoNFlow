#!/usr/bin/env nextflow

include { METHYL_ATLAS                                      } from "../modules/refbased_tools/methyl_atlas/main"
include { CIBERSORT                                         } from "../modules/refbased_tools/cibersort/main"
include { EPIDISH                                           } from "../modules/refbased_tools/epidish/main"
include { METHYL_RESOLVER                                   } from "../modules/refbased_tools/methyl_resolver/main"
include { EPISCORE                                          } from "../modules/refbased_tools/episcore/main"
include { PRMETH                                            } from "../modules/refbased_tools/prmeth/main"


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