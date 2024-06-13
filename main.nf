#!/usr/bin/env nextflow

// Set a header made using https://patorjk.com/software/taag (but be sure to escape characters such as dollar signs and backslashes, e.g., '$'=> '\$' and '\' =>'\\')
log.info """
    ================================================================================================    

                                                                                                            
 ____   _____  ____  ___   _   _ __     __  ____   _____  _   _   ____  _   _  __  __     _     ____   _  __
|  _ \\ | ____|/ ___|/ _ \\ | \\ | |\\ \\   / / | __ ) | ____|| \\ | | / ___|| | | ||  \\/  |   / \\   |  _ \\ | |/ /
| | | ||  _| | |   | | | ||  \\| | \\ \\ / /  |  _ \\ |  _|  |  \\| || |    | |_| || |\\/| |  / _ \\  | |_) || ' / 
| |_| || |___| |___| |_| || |\\  |  \\ V /   | |_) || |___ | |\\  || |___ |  _  || |  | | / ___ \\ |  _ < | . \\ 
|____/ |_____|\\____|\\___/ |_| \\_|   \\_/    |____/ |_____||_| \\_| \\____||_| |_||_|  |_|/_/   \\_\\|_| \\_\\|_|\\_\\
                                                                                                            

    ================================================================================================

    INPUT PARAMETERS:
        - reference samples             : ${params.input}
        - output directory              : ${params.output_dir}
        - minimum number of CpGs        : ${params.cpg_filter_number}
        - version of the genome         : ${params.genome_version}

    ==============================================================================================
    """.stripIndent()


// include processes and subworkflows to make them available for use in this script 
include { PREPROCESSING                                     } from "./modules/preprocessing/main" 

workflow {
    PREPROCESSING()
}