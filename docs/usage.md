# DNAmDeconv: Usage

## Table of Contents
- [Introduction](#Introduction)
- [Reference-based deconvolution](#reference-based)
- [Reference-free deconvolution](#reference-free)
- [Running the pipeline](#pipeline-run)
    - [Default behaviours](#default-behaviours)
- [Core Nextflow arguments](#core-nextflow-arguments)
- [DMR selection arguments](#dmr-selection-arguments)
  - [DSS arguments](#dss-arguments)
  - [limma arguments](#limma-arguments)
- [Deconvolution parameters](#deconvolution-parameters)
  - [EpiDISH params](#epidish-params)
  - [MethylResolver params](#methylresolver-params)
  - [ EpiSCORE params](#episcore-params)
  - [PRMeth params](#prmeth-params)
  - [MeDeCom params](#medecom-params)
  - [CelFiE params](#celfie-params)
- [Resource requests](#resource-requests)
- [Running in the background](#running-in-the-background)

## Introduction

DNAmDeconv is a bioinformatics analysis pipeline used for computational deconvolution of DNA methylation data. It allows deconvolution of samples using both reference-based and reference-free deconvolution tools. It also allows benchmarking of the different tools included in the pipeline.

The pipeline is built using [Nextflow](https://www.nextflow.io/) (>= 23.04.0) a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker / Singularity containers making installation trivial and results highly reproducible.

## Reference-based deconvolution
If you want to deconvolve the samples using reference-based deconvolution tools, you will need to create a samplesheet (`reference.csv`) with information about the samples that will build your reference matrix and a samplesheet (`test.csv`) with information about the samples you would like to deconvolve.

### Input file 
Use this parameter to specify its location. It has to be a comma-separated file with 3 columns, and a header row as shown in the examples below.

```bash
--input '[path to samplesheet file]'
```

where the samplesheet file looks like the following:

`reference.csv`
```plaintext:
name,type,file
DNA097385,healthy,DNA097385_S10.cov.gz
DNA097389,healthy,DNA097389_S14.cov.gz
DNA097393,healthy,DNA097393_S18.cov.gz
DNA041087,nbl,DNA041087_S27.cov.gz
DNA044133,nbl,DNA044133_S31.cov.gz
DNA044134,nbl,DNA044134_S32.cov.gz
```
| Column      | Description |
| ----------- | ----------- |
| `name`  | Custom sample name. Spaces in sample names are automatically converted to underscores (`_`). |
| `type` | Cell type name |
| `file` | Full path to .cov file. File has to be gzipped and have the extension ".cov.gz". |

An [example samplesheet](../assets/reference.csv) has been provided with the pipeline.

### Test file
Use this parameter to specify its location. It has to be a comma-separated file with 2 columns, and a header row as shown in the example below.

```bash
--test_set '[path to samplesheet file]'
```
where the samplesheet file looks like the following:

`test.csv`
```plaintext:
name,sample
20M_mix_Bmap_CLBGA_0_rep1,20M_mix_Bmap_CLBGA_0_rep1.cov.gz
20M_mix_Bmap_CLBGA_10_rep1,20M_mix_Bmap_CLBGA_10_rep1.cov.gz
20M_mix_Bmap_CLBGA_25_rep1,20M_mix_Bmap_CLBGA_25_rep1.cov.gz
20M_mix_Bmap_CLBGA_50_rep1,20M_mix_Bmap_CLBGA_50_rep1.cov.gz
20M_mix_Bmap_CLBGA_100_rep1,20M_mix_Bmap_CLBGA_100_rep1.cov.gz
```
An [example samplesheet](../assets/test.csv) has been provided with the pipeline.

## Reference-free deconvolution
For the reference-free deconvolution tools, the required files are the [regions file](../assets/RRBS_regions20-200.bed) and the [test samplesheet](../assets/test.csv).

## Running the pipeline
The typical command for running the pipeline is the following:

```bash
nextflow run main.nf --input assets/reference.csv --test_set assets/test.csv --outdir ./results  -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.


The above pipeline run specified with a params file in yaml format:

```bash
nextflow run main.nf -profile docker -params-file params.yaml
```
with `params.yaml` containing:

```yaml
input: 'assets/reference.csv'
test_set: 'assets/test.csv'
outdir: './results/'
<...>
```

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

## Default behaviours
By default, when the `--input` is specified, the pipeline will run the reference-based deconvolution workflow and deconvolve the samples given with the `--test_set` parameter using `meth_atlas`. If the `--input` file is not specified, the pipeline will deconvolve the samples using the `PRMeth` tool with the reference-free modality.

## Core Nextflow arguments

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Apptainer) - see below.

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer enviroment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## DMR selection arguments

### `--DMRselection`
Default is 'DSS'. Alternative is 'limma'. If using 'limma' DMR selection, a region file must be specified using the flag `--regions` (read below).

### `--adjp`
Adjusted p-value threshold for the DMR selection. Default 0.001.

### `--adj_method`
Multiple testing correction method. Default is 'BH'. Look at limma documentation for other methods.

### `--collapse_method`
Method adopted to collapse the samples values for each region. Default is 'mean', alternative is 'median'.

### `--direction`
Direction of methylation: can be either "hypo","hyper","both" or "random" (def. null, takes all the regions).

### `--top`
Take the top x number (integer) of DMRs per cell state (def. null): it can be used only if direction flag is specified.

### DSS arguments

#### `--smoothing`
Apply smoothing (default: TRUE).

#### `--smoothing_span`
Size of smoothing window in base pairs (default: 500).

#### `--delta`
Threshold for calling DMRs (default: 0.1).

#### `--min_len`
Minimum length in base pairs for DMR (default: 50).

#### `--dis_merge`
Maximum distance between DMRs to merge (default: 50).

#### `--pct_sign`
Minimum percentage of significant CpGs within a DMR (default: 0.5).

### limma arguments

#### `--regions`
> **NOTE** The chromosome name must be consistent among coverage and region files. Always use the same format (in the example below the chromosome name is represented just by the number, without the "chr" string).

If _limma_ `--DMRselection`, you must provide also a regions file using this paramater. It has to be a tab-separated file with three columns, and no header as shown in the example below.

```bash
--regions '[path to regions file]'
```
where the samplesheet file looks like the following:

`RRBS_regions20-200.bed`
```plaintext:
1   10497       10588
1   10589       10640
1   10641       10669
... ...         ...
22  50064015    50064037
22  50064064    50064084
22  50064090    50064112
```
An [example regions file](../assets/RRBS_regions20-200.bed) has been provided with the pipeline.

#### `--min_counts`
Minimum number of counts to keep a CpG position. Default 10.

#### `--min_cpgs`
Minimum number of CpGs per region. Default 3.

## Deconvolution parameters

### `--save_intermeds`
If the flag is specified, all the output files will be saved.

### `--benchmark`
If specified, all the tools and modalities in the pipeline are run.

### `--epidish`, `--methyl_resolver`, `--episcore`, `--prmeth`,`--prmeth_rf`,`--medecom`, `--celfie`,`--methyl_atlas`,`--cibersort`
If specified, they run the corresponding tool. By default, `--methyl_atlas` and `--prmeth_rf` are set for respectively ref-based and ref-free decovolution.

### `--refree_min_cpgs`, `--refree_min_counts`
Same as min_cpgs and min_counts but for reference-free deconvolution.

### `--clusters`
Number of expected cell types required by the reference-free deconvolution tools. Default is 2.

### EpiDISH params
#### `--mod`
EpiDISH modality to be used. Default is 'RPC'. Alternatives are [CBS, CP_ineq, CP_eq].

### MethylResolver params
#### `--alpha`
MethylResolver alpha parameter. Default is 0.5, can go from 0.5 to 0.9.

### EpiSCORE params
#### `--weight`
EpiSCORE weight parameter. Default is 0.4, can go from 0.05 to 0.9.

### PRMeth params
#### `--prmeth_mod`
Modality to be used for the PRMeth tool. Default is 'QP' (reference-based), alternative is 'NMF' (partial reference-based). PRMeth_RF runs always with 'RF' (reference-free) modality.

### MeDeCom params
#### `--ninit`
MeDeCom number of random initializations (def. 10).

#### `--nfold`
MeDeCom number of folds for cross-validation (def. 10).

#### `--itermax`
MeDeCom max number of iterations (def. 300).

### CelFiE params
#### `--celfie_maxiter`
How long the EM should iterate before stopping, unless convergence criteria is met (def. 1000).

#### `--unknown`
Number of unknown categories to be estimated along with the reference data (def. 0).

#### `--parallel_job`
CelFiE: Replicate number in a simulation experiment (def. 1).

#### `--converg`
CelFiE: Convergence criteria for EM (def. 0.0001)

#### `--celfie_randrest`
CelFiE will perform several random restarts and select the one with the highest log-likelihood (def. 10).

## Other parameters

### `--ref_matrix`
> **NOTE** The chromosome name must be consistent among coverage files to deconvolve and reference matrix. Always use the same format (in the example below the chromosome name is represented just by the number, without the "chr" string).

If this parameter is specified, the pipeline skips the preprocessing and DMR selection steps, and immediately deconvolves the samples given the reference matrix provided. Below you can find an example of the structure of the reference matrix:

`reference_matrix.tsv`
```plaintext:
chr   start     end         entity1 entity2     entity3
14	89493501	89493545	0       0.9897      0
15	89922039	89922098	0.0021  0.9898      0
17	27945066	27945109	0       0.9861      0.0012
2	96811100	96811138	0       0           0.9857
15	28352514	28352560	0       0.0013      0.9843
10	73846983	73847022	0       0.9840      0
3	48693689	48693754	0.9838  0           0.0021
14	89493868	89493895    0.9833  0           0
```
The file needs to be a tab separated (.tsv/.bed) file. The values in the matrix are methylation beta values.

### `--merged_matrix`
If this parameter is specified, the pipeline skips the preprocessing step and immediately performs limma DMR selection step. The merged matrix corresponds to a matrix composed of one column corresponding to the DMR coordinates collapsed and the remaining columns to the individual samples containing methylation beta values. These columns need to have column names that end with "-V". Below you can find an example of the structure of the merged matrix:

`merged_matrix.csv`
```plaintext:
,chr,start,end,healthy3-V,nbl2-V,nbl3-V,healthy1-V,healthy2-V,nbl1-V
0,1,10497,10588,0.902439,0.968421,0.946197,0.938053,0.820513,0.972149
1,1,136876,136924,0.959184,0.972678,0.989583,0.884181,0.934272,0.926941
2,1,661865,661927,1.0,1.0,0.972222,0.986111,0.927536,0.885965
3,1,662657,662705,0.936508,0.97037,0.977778,0.961905,0.979798,0.922705
4,1,714254,714299,0.0,0.0162162,0.0252101,0.00319489,0.0,0.0240964
```
The file needs to be a comma separated (.csv) file. The values in the matrix are methylation beta values.

## Resource requests
Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher requests (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/usage/configuration#max-resources) and [tuning workflow resources](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources) section of the nf-core website.

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).