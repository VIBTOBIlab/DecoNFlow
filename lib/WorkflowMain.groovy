//
// This file holds several functions specific to the main.nf workflow in the DNAmDeconv pipeline
//

import nextflow.Nextflow

class WorkflowMain {

    //
    // Citation string for pipeline
    //
    public static String citation(workflow) {
        return "If you use ${workflow.manifest.name} for your analysis please cite:\n\n" +
            "* The pipeline\n" +
            "  " +
            "* The nf-core framework\n" +
            "  https://doi.org/10.1038/s41587-020-0439-x\n\n" +
            "* Software dependencies\n" +
            "  ../CITATIONS.md"
    }


    //
    // Validate parameters and print summary to screen
    //
    public static void initialise(workflow, params, log) {

        // Print workflow version and exit on --version
        if (params.version) {
            String workflow_version = NfcoreTemplate.version(workflow)
            log.info "${workflow.manifest.name} ${workflow_version}"
            System.exit(0)
        }

        // Check that a -profile or Nextflow config has been provided to run the pipeline
        NfcoreTemplate.checkConfigProvided(workflow, log)

        if (!params.medecom & !params.prmeth_rf & !params.uxm & !params.methyl_atlas & !params.celfie & !params.metdecode & !params.epidish & !params.prmeth & !params.methyl_resolver & !params.episcore & !params.cibersort & !params.benchmark) {
            Nextflow.error "\n----> ERROR: specify at least one deconvolution tool. <----\n"
        }
        if ((params.celfie || params.metdecode) & !params.input) {
            Nextflow.error "\n----> ERROR: you need to specify the reference samples (--input) when using CelFiE. <----\n"
        }
        if (params.DMRselection!="wgbstools" & params.DMRselection!="DSS" & params.DMRselection!="limma" & !params.ref_matrix & !params.uxm_atlas) {
            Nextflow.error "\n----> ERROR: you need to specify one DMR selection approach (--DMRselection). <----\n"
        }
    }
}
