#!/usr/bin/env nextflow

include { METH_ATLAS                                        } from "../modules/refbased_tools/meth_atlas/main"
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
    if (params.meth_atlas || params.benchmark) {
        METH_ATLAS(reference, test)
        outputChannels = outputChannels.mix( METH_ATLAS.out.output.map { file -> tuple('meth_atlas', file) } )
    }
    if (params.cibersort || params.benchmark) {
        CIBERSORT(reference, test)
        outputChannels = outputChannels.mix( CIBERSORT.out.output.map { file -> tuple('CIBERSORT', file) } )
    }
    if (params.epidish || params.benchmark) {
        EPIDISH(reference, test)
        outputChannels = outputChannels.mix( EPIDISH.out.output.map { file -> tuple("EpiDISH_${params.mod}", file) } )
    }   
    if (params.methyl_resolver || params.benchmark) {
        METHYL_RESOLVER(reference, test)
        outputChannels = outputChannels.mix( METHYL_RESOLVER.out.output.map { file -> tuple('Methyl_Resolver', file) } )
    }
    if (params.episcore || params.benchmark) {
        EPISCORE(reference, test)
        outputChannels = outputChannels.mix( EPISCORE.out.output.map { file -> tuple('EpiSCORE', file) } )
    }
    if (params.prmeth || params.benchmark) {
        PRMETH(reference, test)
        outputChannels = outputChannels.mix( PRMETH.out.output.map { file -> tuple('PRMeth', file) } )
    }   
    
    emit:
    refbased_proportions         = outputChannels
}