# DNAmDeconv: Output

## Introduction

This document describes the output produced by the pipeline.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/).

## Results structure

If `--save_intermeds` flag is not specified, the pipeline will produce two folders inside the outdir specified using the `--outdir` flag:

**Pipeline info directory: `results/pipeline_info`**

- Contains the information regarding the pipeline (timeline, dag, report).

**Final output directory: `results/deconvolution_results`**

- Contains a .csv file with the cell type proportions estimated. Each row contains the information on the cell type proportion estimated by one single tool (specified in the column tool) for a single sample.

`combined_results.csv`

```plaintext:
sample,proportion_entity1,proportion_entity2,proportion_entity3,tool
bulk_sample_1,0.68,0.02,0.06,CelFiE
bulk_sample_2,0.68,0.15,0.10,CelFiE
bulk_sample_3,0.68,0.05,0.25,CelFiE
bulk_sample_4,0.68,0.24,0.01,CelFiE
```

## Other output data

If `--save_intermeds` flag is specified, then also the intermediate files are saved. So, the preprocessing of the reference and bulk samples, the DMR analyses results and all other intermediates files will be saved in the corresponding folders. Moreover, for each tool specified with the corresponding flag, a results .csv file containing the cell type proportions for the bulk samples will be generated within the `results/deconvolution_results` folder.
