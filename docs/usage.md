# DNAmDeconv: Usage

## Table of Contents
- [Introduction](#Introduction)
- [Reference-based deconvolution](#reference-based)
- [Reference-free deconvolution](#reference-free)
- [Running the pipeline](#pipeline-run)
    - [Default behaviours](#default-behaviours)
- [Core Nextflow arguments](#core-nextflow-arguments)
- [Custom configuration](#custom-configuration)
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

### Default behaviours
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

## Custom configuration

### `--DMRselection`
Default is 'DSS'. Alternative is 'custom'. If using 'custom' DMR selection, a region file must be specified using the flag `--regions` (read below).

### `--regions`
> **NOTE** The chromosome name must be consistent among coverage and region files. Always use the same format (in the example below the chromosome name is represented just by the number, without the "chr" string).

If _custom_ `--DMRselection` or a reference-free tool have been specified, you must provide also a regions file using this paramater. It has to be a tab-separated file with three columns, and no header as shown in the example below.

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

### `--save_intermeds`
If the flag is specified, all the output files will be saved.

### `--benchmark`
If specified, all the tools and modalities in the pipeline are run.

### `--epidish`, `--methyl_resolver`, `--episcore`, `--prmeth`,`--prmeth_rf`,`--medecom`, `--celfie`,`--methyl_atlas`,`--cibersort`
If specified, they run the corresponding tool. By default, `--methyl_atlas` and `--prmeth_rf` are set for respectively ref-based and ref-free decovolution.

### `--min_counts`
Minimum number of counts to keep a CpG position. Default 10.

### `--min_cpgs`
Minimum number of CpGs per region. Default 3.

### `--chunk_size`
Size of the chunks that are used to reduce the memory required. Default is 100.

### `--refree_min_cpgs`, `--refree_min_counts`
Same as min_cpgs and min_counts but for reference-free deconvolution.

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

### `--mod`
EpiDISH modality to be used. Default is 'RPC'. Alternatives are [CBS, CP_ineq, CP_eq].

### `--alpha`
MethylResolver alpha parameter. Default is 0.5, can go from 0.5 to 0.9.

### `--weight`
EpiSCORE weight parameter. Default is 0.4, can go from 0.05 to 0.9.

### `--clusters`
Number of expected cell types required by the reference-free deconvolution tools. Default is 2.

### `--prmeth_mod`
Modality to be used for the PRMeth tool. Default is 'QP' (reference-based), alternative is 'NMF' (partial reference-based). PRMeth_RF runs always with 'RF' (reference-free) modality.

### `--ninit`
MeDeCom number of random initializations (def. 10).

### `--nfold`
MeDeCom number of folds for cross-validation (def. 10).

### `--itermax`
MeDeCom max number of iterations (def. 300).

### `--celfie_maxiter`
How long the EM should iterate before stopping, unless convergence criteria is met (def. 1000).

### `--unknown`
Number of unknown categories to be estimated along with the reference data (def. 0).

### `--parallel_job`
CelFiE: Replicate number in a simulation experiment (def. 1).

### `--converg`
CelFiE: Convergence criteria for EM (def. 0.0001)

### `--celfie_randrest`
CelFiE will perform several random restarts and select the one with the highest log-likelihood (def. 10).

## Resource requests
Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher requests (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/usage/configuration#max-resources) and [tuning workflow resources](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources) section of the nf-core website.

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).
