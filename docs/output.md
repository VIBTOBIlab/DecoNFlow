# DNAmDeconv: Output

## Introduction

This document describes the output produced by the pipeline.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/).

## Results structure

If `--save_intermeds` flag is not specified, the pipeline will produce two folders inside the outdir specified using the `--outdir` flag:

**Pipeline info directory: `results/pipeline_info`**

- Contains the information regarding the pipeline (timeline, dag, report).

**Final output directory: `results/deconvolution`**

- Contains a .csv file with the cell type proportions estimated. Each row contains the information on the cell type proportion estimated by one single tool (specified in the column tool) for a single sample.

`combined_results.csv`

```plaintext:
sample,healthy,nbl,tool,LMC1,LMC2,V1,V2
20M_mix_Bmap_CLBGA_0_rep1,0.9977785149894458,0.0022214850105542,CelFiE,,,,
20M_mix_Bmap_CLBGA_10_rep1,0.877813686675229,0.122186313324771,CelFiE,,,,
20M_mix_Bmap_CLBGA_25_rep1,0.6992687532002937,0.3007312467997062,CelFiE,,,,
20M_mix_Bmap_CLBGA_50_rep1,0.4317048134137805,0.5682951865862195,CelFiE,,,,
```

## Other output data

If `--save_intermeds` flag is specified, then also the intermediate files are saved. So, the preprocessing, test preprocessing, reference-free preprocessing and DMR analyses results will be saved in the corresponding folders. Moreover, for each tool specified with the corresponding flag, a results .csv file containing the cell type proportions for the bulk samples will be generated.
