# DecoNFlow: Output

## Introduction

This document describes the output produced by the pipeline.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/).

## Results structure

If `--save_intermeds` flag is not specified, the pipeline will produce two folders inside the outdir specified using the `--outdir` flag:

**Pipeline info directory: `results/pipeline_info`**

- Contains the information regarding the pipeline (timeline, dag, report).

**Final output directory: `results/deconvolution_results`**

Reference-based and reference-free results are saved in separate tables, since reference-free tools do not estimate the cell types of a reference but unlabelled latent components (e.g. `LMC1`, `LMC2` for MeDeCom and `V1`, `V2` for RefFreeCellMix). Each table is only produced if at least one tool of that type was run.

`combined_results_refbased.csv`

Cell type proportions estimated by the reference-based tools. Each row contains the proportions estimated by one tool (column `tool`) for one bulk sample.

```plaintext
sample,proportion_entity1,proportion_entity2,proportion_entity3,tool
bulk_sample_1,0.68,0.02,0.30,CelFiE
bulk_sample_2,0.68,0.15,0.17,CelFiE
bulk_sample_3,0.68,0.05,0.27,CelFiE
bulk_sample_4,0.68,0.24,0.08,CelFiE
```

`combined_results_reffree.csv`

Proportions of the latent components estimated by the reference-free tools, with the same structure. Each tool has its own component columns, which are empty (`NaN`) for the rows of the other tools.

```plaintext
sample,LMC1,LMC2,tool,V1,V2
bulk_sample_1,1.0,0.0,MeDeCom,,
bulk_sample_2,0.18,0.82,MeDeCom,,
bulk_sample_1,,,RefFreeCellMix,1.0,0.0
bulk_sample_2,,,RefFreeCellMix,0.18,0.82
```

`deconvolution_report.html`

Self-contained HTML report (it can be opened offline in any browser) with:

- **Per-sample comparison**: one card per bulk sample comparing the cell type proportions estimated by every reference-based tool, with a stacked bar per tool, the mean, standard deviation (SD), minimum and maximum of each cell type across tools, and the cell type the tools disagree on the most. Reference-free tools are not included, since their components are not labelled with cell types and cannot be compared between tools.
- **Per-tool results**: one card per tool (reference-based and reference-free sections) with a stacked bar per bulk sample and a table with the exact values.

Negative estimates (possible for some tools) are drawn as 0 in the charts but kept in the tables.

If a ground truth is provided (`--ground_truth`), the report starts with an **Evaluation against ground truth** section: the MSE, RMSE and Spearman correlation of each reference-based tool (sorted by RMSE, with the best values highlighted), and an interactive plot of the estimated vs expected proportions. In the plot you can choose which tools and cell types to show (one, several or all), colour the points by tool or by cell type, and see the MSE, RMSE and Spearman correlation of the selected points only.

`evaluation_metrics.csv`

Only produced when a ground truth is provided. Evaluation metrics of each reference-based tool, computed over all the cell types of the samples present in both the results and the ground truth, sorted by RMSE.

```plaintext
tool,samples,MSE,RMSE,Spearman
EpiDISH,3,0.0016,0.0401,0.9660
meth_atlas,3,0.0023,0.0481,0.9660
CelFiE,3,0.0983,0.3136,0.8768
```

## Other output data

If `--save_intermeds` flag is specified, then also the intermediate files are saved. So, the preprocessing of the reference and bulk samples, the DMR analyses results and all other intermediates files will be saved in the corresponding folders. Moreover, for each tool specified with the corresponding flag, a results .csv file containing the cell type proportions for the bulk samples will be generated within the `results/deconvolution_results` folder.
