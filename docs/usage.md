# DecoNFlow: Usage

## Introduction

DecoNFlow is a bioinformatics analysis pipeline used for computational deconvolution of DNA methylation data. It allows deconvolution of samples using both reference-based and reference-free deconvolution tools. It also allows benchmarking of the different tools included in the pipeline.

The pipeline is built using [Nextflow](https://www.nextflow.io/) (>= 26.04.0), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker / Singularity containers making installation trivial and results highly reproducible.

## Reference-based deconvolution

If you want to deconvolve the samples using reference-based deconvolution tools, you will need to create a samplesheet (`reference.csv`) with information about the samples that will build your reference matrix and a samplesheet (`test.csv`) with information about the samples you would like to deconvolve.

### Reference samples

Use this parameter to specify its location. It has to be a comma-separated file with 3 columns, and a header row as shown in the examples below.

```bash
--input '[path to samplesheet file]'
```

where the samplesheet file looks like the following:

`reference.csv`

```plaintext
name,type,file
DNAXX1,healthy,DNAXX1.cov.gz
DNAXX2,healthy,DNAXX2.cov.gz
DNAXX3,healthy,DNAXX3.cov.gz
DNAXX4,nbl,DNAXX4.cov.gz
DNAXX5,nbl,DNAXX5.cov.gz
DNAXX6,nbl,DNAXX6.cov.gz
```

| Column | Description                                                                                  |
| ------ | -------------------------------------------------------------------------------------------- |
| `name` | Custom sample name. Spaces in sample names are automatically converted to underscores (`_`). |
| `type` | Cell type name                                                                               |
| `file` | Full path to the coverage file of the sample (see [Coverage files](#coverage-files)).        |

An [example samplesheet](https://github.com/VIBTOBIlab/deconflow_testdata/blob/main/resources/ref_cov.csv) is available in the test data of the pipeline.

### Bulk samples

Use this parameter to specify its location. It has to be a comma-separated file with 2 columns, and a header row as shown in the example below.

```bash
--bulk_samples '[path to samplesheet file]'
```

where the samplesheet file looks like the following:

`bulk_samples.csv`

```plaintext
name,sample
bulk1,bulk1.cov.gz
bulk2,bulk2.cov.gz
bulk3,bulk3.cov.gz
bulk4,bulk4.cov.gz
bulk5,bulk5.cov.gz
```

| Column   | Description                                                                           |
| -------- | ------------------------------------------------------------------------------------- |
| `name`   | Custom sample name.                                                                   |
| `sample` | Full path to the coverage file of the sample (see [Coverage files](#coverage-files)). |

An [example samplesheet](https://github.com/VIBTOBIlab/deconflow_testdata/blob/main/resources/bulk_samples_cov.csv) is available in the test data of the pipeline.

### Coverage files

The reference and bulk samples can be provided in two formats. Both contain the methylated and unmethylated read counts of each CpG, which the pipeline needs to filter CpGs by coverage (`--min_counts`, `--bulk_min_counts`), to compute the methylation of each region and to run CelFiE and MetDecode.

- **Bismark coverage files** (`.cov` or `.cov.gz`), produced by `bismark_methylation_extractor` (or `coverage2cytosine`). Positions are 1-based:

  ```plaintext
  chr1	10469	10469	0	0	1
  chr1	10471	10471	100	1	0
  ```

- **MethylDackel bedGraph files** (`.bedGraph` or `.bedGraph.gz`), produced by `MethylDackel extract`, with or without `--mergeContext`. Positions are 0-based (`start` is one base before the cytosine), and the `track` header line is optional:

  ```plaintext
  track type="bedGraph" description="SRR1182519.sorted CpG methylation levels"
  1	25114	25115	66	2	1
  1	25115	25116	100	3	0
  ```

The columns are: chromosome, start, end, methylation percentage, number of methylated reads and number of unmethylated reads. At the start of the pipeline, the MethylDackel coordinates are converted to the 1-based coordinates of the Bismark coverage files by adding 1 to `start` (e.g. `1 25114 25115` becomes `1 25115 25115`, as Bismark reports it), so both formats give the same results. CpGs merged across strands (`--mergeContext`) keep their two bases (`1 25114 25116` becomes `1 25115 25116`).

**Mixing formats.** Bismark and MethylDackel files can be mixed, both within a samplesheet and between the reference and the bulk samplesheets (e.g. reference samples processed with Bismark and bulk samples processed with nf-core/methylseq and bwa-meth). Since all files are converted to the same positions, a CpG gets the same coordinates whichever format it comes from, and the results do not depend on the format.

> **NOTE** The [regions file](#--regions) must use the same 1-based coordinates as the Bismark coverage files. See [Coordinates of the regions file](#coordinates-of-the-regions-file).

> **NOTE** The bedGraph files produced by Bismark (`bismark2bedGraph`) only contain the methylation percentage, without the read counts, and cannot be used: use the Bismark coverage files (`.cov.gz`) instead.

### Ground truth (optional)

If the expected cell type proportions of the bulk samples are known (e.g. in silico mixtures or benchmarking datasets), they can be provided to evaluate the reference-based tools:

```bash
--ground_truth '[path to ground truth file]'
```

It has to be a comma-separated file with a header row: a `sample` column with the names of the bulk samples (as in the `name` column of the [bulk samplesheet](#bulk-samples)), followed by one column per cell type with the expected proportions (between 0 and 1, not percentages).

`ground_truth.csv`

```plaintext
sample,colon,lung,pancreas
bulk1,0.50,0.50,0.00
bulk2,0.05,0.05,0.90
bulk3,0.70,0.05,0.25
```

The cell types must be exactly the same as in the reference: the `type` column of the [reference samplesheet](#reference-samples), or the cell types of the reference matrices (`--ref_matrix`, `--celfie_ref_matrix`, `--metdecode_ref_matrix`). If the tools use different references, the ground truth is checked against each of them. This is checked when the pipeline starts. Samples that are not listed in the ground truth are not evaluated.

For each reference-based tool, the estimated proportions are compared with the expected ones over all the cell types of the evaluated samples, computing the mean squared error (MSE), the root mean squared error (RMSE) and the Spearman correlation. The metrics are added to the [HTML report](output.md), with a plot of the estimated vs expected proportions of each tool, and saved in `evaluation_metrics.csv`.

> **NOTE** Reference-free tools are not evaluated, since their components are not labelled with cell types. If only reference-free tools are selected, the ground truth is ignored.

## Reference-free deconvolution

For the reference-free deconvolution tools, the required files are the [regions file](#--regions) and the [bulk samplesheet](#bulk-samples).

## Running the pipeline

The typical command for running the pipeline is the following:

```bash
nextflow run main.nf --input assets/reference.csv --bulk_samples assets/bulk_samples.csv --outdir ./results -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`. The above pipeline run specified with a params file in yaml format:

```bash
nextflow run main.nf -profile docker -params-file params.yaml
```

with `params.yaml` containing:

```yaml
input: 'assets/reference.csv'
bulk_samples: 'assets/test.csv'
outdir: './results/'
<...>
```

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

## Default behaviours (depracated)

By default, when the `--input` is specified, the pipeline will run the reference-based deconvolution workflow and deconvolve the samples given with the `--bulk_samples` parameter using `meth_atlas`. If the `--input` file is not specified, the pipeline will deconvolve the samples using the `PRMeth` tool with the reference-free modality.

## Core Nextflow arguments

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Apptainer) - see below.

Note that multiple profiles can be loaded, for example: `-profile docker,test` - the order of arguments is important!
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

> **NOTE** The pipeline uses limma for DMR selection. It will filter out from the coverage files all those CpGs not mapping to chromosomes ((chr)1-22/X/Y/M/MT). Thus, all those CpGs located in unplaced or unlocalized genomic sequences (e.g. chr1_gl000192_random, chrUn_gl000215, etc) will be filtered out.

### `--adjp`

Adjusted p-value threshold for the DMR selection. Default 0.001.

### `--adj_method`

Multiple testing correction method. Default is 'BH'. Look at limma documentation for other methods.

### `--collapse_method`

Method adopted to collapse the samples values for each region. Default is 'mean', alternative is 'median'.

### `--direction`

Direction of methylation: can be either "hypo","hyper","both" or "random" (def. both).

### `--top`

Take the top x number (integer) of DMRs per cell state (def. null): it can be used only if direction flag is specified.

### limma arguments

#### `--regions`

> **NOTE** The chromosome name must be consistent among coverage and region files. Always use the same format (in the example below the chromosome name is represented by the "chr" string + the chromosome number).

For limma DMR selection and reference-free deconvolution, you must provide a regions file using this parameter, or use the CpG islands of a genome as regions with [`--cgi_genome`](#--cgi_genome). It has to be a tab-separated file with three columns, and no header as shown in the example below.

```bash
--regions '[path to regions file]'
```

where the samplesheet file looks like the following:

`RRBS_regions20-200_chr.bed`

```plaintext
chr1   10497       10588
chr1   10589       10640
chr1   10641       10669
...    ...         ...
chr22  50064015    50064037
chr22  50064064    50064084
chr22  50064090    50064112
```

An [example regions file](https://github.com/VIBTOBIlab/deconflow_testdata/blob/main/resources/RRBS_regions20-200_hg19_chr1_1M.bed) is available in the test data of the pipeline.

##### Coordinates of the regions file

The regions must use **1-based coordinates, with both `start` and `end` included**: `chr1 10497 10588` is the region from base 10497 to base 10588. This is the convention of the Bismark coverage files, to which all coverage files are converted (see [Coverage files](#coverage-files)), so that each CpG is assigned to the right region.

The RRBS regions files provided with the pipeline were generated from the in silico MspI digestion of the genome (`mkrrgenome`), by copying its `start..end` fragment coordinates (1-based, both ends included) into the `start` and `end` columns. A region therefore starts at the CpG of the MspI site (`C^CGG`) and ends right before the next one.

> **WARNING** Standard BED files (e.g. from UCSC, ENCODE or `bedtools`) use 0-based coordinates, where `start` is one base before the first base of the region. They are not detected by the pipeline and would shift every region by one base, so CpGs at the edges of the regions could be assigned to the wrong region. Convert them first by adding 1 to `start`:
>
> ```bash
> awk -v OFS='\t' '{ print $1, $2 + 1, $3 }' regions_0based.bed > regions.bed
> ```

#### `--cgi_genome`

Instead of a regions file, the CpG islands (CGIs) of a genome can be used as regions, by giving the genome assembly: `hg19`, `hg38`, `mm10` or `mm39`.

```bash
--cgi_genome hg38
```

The CpG islands are downloaded from UCSC (`https://hgdownload.soe.ucsc.edu/goldenPath/<genome>/database/cpgIslandExt.txt.gz`), and converted into a regions file with the same coordinates as described above: the UCSC starts are 0-based, so 1 is added to them. Only the primary chromosomes are kept (alt, random and unplaced contigs are removed). If a regions file (`--regions`) is also given, the regions file is used and `--cgi_genome` is ignored.

> **NOTE** The UCSC chromosome names start with `chr` (e.g. `chr1`). The chromosome names of the coverage files must use the same format.

#### `--min_counts`

Minimum number of counts to keep a CpG position. Default 10.

#### `--min_cpgs`

Minimum number of CpGs per region. Default 3.

#### `--include_na`

Activate this parameter to allow missing values when merging the reference samples before performing limma DMR selection (def. false).

#### `--big_covs`

If you are including big coverage files, such as WGBS around 200 MB, specify this flag to make the preprocessing of the files (before using limma) running with a memory-efficient algorithm. When specifying this flag within `limma` workflow, it's necessary to specify the `--genome_order` flag as well.

#### `--genome_order`

> **NOTE** The coverage files are expected to be sorted by chromosome position (chr1, chr11, chr12) instead of natural order (chr1, chr2, chr3). You can achieve this using the UNIX sort utility to sort cov files by chromosome and then by position. That is, _sort -k1,1 -k2,2n in.cov > in.sorted.cov_ .

When `--big_covs` is specified, you need to specify the genome version of the files and if the chromosome name is represented just by the number (e.g. human.hg38.nochr) or with the "chr" string (e.g. human.38). You can choose among the following parameters: [`human.hg19`, `human.hg38`, `human.hg19.nochr`, `human.hg38.nochr`, `mouse.mm9`, `mouse.mm10`, `mouse.mm9.nochr`, `mouse.mm10.nochr`].

## Deconvolution parameters

### `--save_intermeds`

If the flag is specified, all the output files will be saved.

### `--benchmark`

If specified, all the tools and modalities in the pipeline are run.

### `--epidish`, `houseman_eq`, `houseman_ineq`, `--methyl_resolver`, `--episcore`, `--prmeth`,`--ref_freecell_mix`,`--medecom`, `--celfie`,`--meth_atlas`,`--cibersort`,`--metdecode`

If specified, they run the corresponding tool.

### `--bulk_min_cpgs`, `--bulk_min_counts`

Same filtering as min_cpgs and min_counts but applied on the bulk samples.

### `--clusters`

Number of expected cell types required by the reference-free deconvolution tools. Default is 2.

### MethylResolver params

#### `--alpha`

MethylResolver alpha parameter. Default is 0.5, can go from 0.5 to 0.9.

### EpiSCORE params

#### `--weight`

EpiSCORE weight parameter. Default is 0.4, can go from 0.05 to 0.9.

### PRMeth params

#### `--prmeth_mod`

Modality to be used for the PRMeth tool. Default is 'QP' (reference-based), alternative is 'NMF' (partial reference-based).

#### `--prmeth_NMF_entities`

Expected number of entities when using PRMeth with NMF modality (def. 3).

### MeDeCom params

#### `--ninit`

MeDeCom number of random initializations (def. 10).

#### `--nfold`

MeDeCom number of folds for cross-validation (def. 10).

#### `--itermax`

MeDeCom max number of iterations (def. 300).

### CelFiE params

CelFiE uses the reference samples (`--input`) or its own reference matrix of read counts ([`--celfie_ref_matrix`](#--celfie_ref_matrix-and---metdecode_ref_matrix)).

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

### MetDecode params

MetDecode uses the reference samples (`--input`) or its own reference matrix of read counts ([`--metdecode_ref_matrix`](#--celfie_ref_matrix-and---metdecode_ref_matrix)).

#### `--unknown_tissues`

Number of unknown entities (def. null, it must be an integer)

#### `--sum1`

If specified, it makes the sum of the proportions to 1 (def. false).

#### `--no_coverage`

If specified, it disables CpG coverage factor (def. false).

#### `--supervised`

If specified, it disables the unsupervised refinment of the proportions (def. false).

## Other parameters

### `--ref_matrix`

> **NOTE** The chromosome name must be consistent among coverage files to deconvolve and reference matrix. Always use the same format (in the example below the chromosome name is represented just by the number, without the "chr" string).

If this parameter is specified, the pipeline skips the preprocessing and DMR selection steps, and immediately deconvolves the samples given the reference matrix provided. Below you can find an example of the structure of the reference matrix:

`reference_matrix.tsv`

```plaintext
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

The file needs to be a tab separated (.tsv/.bed) file. The values in the matrix are methylation beta values. You can find an example [here](https://github.com/VIBTOBIlab/deconflow_testdata/blob/main/modules/limma/reference_matrix_limma.tsv).

CelFiE and MetDecode cannot use this matrix, since they need read counts instead of beta values: give them their own reference matrix (`--celfie_ref_matrix`, `--metdecode_ref_matrix`) or the reference samples (`--input`). Otherwise they are skipped with a warning.

Each selected tool uses one reference: the reference-based tools other than CelFiE and MetDecode use `--ref_matrix` if given, otherwise the reference samples (`--input`), while CelFiE and MetDecode use their own reference matrix if given, otherwise the reference samples. So `--ref_matrix` and `--input` can be combined, e.g. `--ref_matrix` for `--meth_atlas` and `--input` for `--celfie`. If `--input` is given but every selected tool uses a reference matrix instead, the pipeline stops with an error, so that a reference is never silently ignored.

### `--celfie_ref_matrix` and `--metdecode_ref_matrix`

> **NOTE** As for `--ref_matrix`, the chromosome names and the coordinates (1-based, as in the Bismark coverage files) must be consistent with the coverage files to deconvolve.

Reference matrices of read counts used by CelFiE (`--celfie_ref_matrix`) and MetDecode (`--metdecode_ref_matrix`) instead of the atlas built from the reference samples (`--input`). They are independent: each tool can use its own matrix, or one tool its own matrix and the other the reference samples. The bulk samples are preprocessed on the regions of each matrix, and a tool with its own matrix does not need the reference samples, the limma DMR selection or the regions (`--regions`, `--cgi_genome`).

The matrix is the atlas format of MetDecode: a tab separated (.tsv/.bed/.txt) file with the columns `chr`, `start` and `end`, followed by two columns per cell type, `<cell type>_meth` with the number of methylated reads (or methylated CpG calls) of the region and `<cell type>_depth` with the total number of reads (methylated and unmethylated):

`celfie_ref_matrix.tsv`

```plaintext
chr     start   end     colon_meth  colon_depth lung_meth   lung_depth  pancreas_meth   pancreas_depth
chr1    10497   10588   549         617         241         271         46              51
chr1    15089   15188   12          15          15          19          2               3
```

The matrix is checked when the pipeline runs: each `_meth` column must be followed by the `_depth` column of the same cell type, there must be at least two cell types, and the counts must be numeric, not missing and with `_meth` not larger than `_depth`. You can find an example [here](https://github.com/VIBTOBIlab/deconflow_testdata/blob/main/resources/count_ref_matrix.tsv), and how to build one from your own reference samples [below](#building-your-own-reference-matrices).

### Building your own reference matrices

The pipeline can build the reference matrices from your reference samples, so that you can reuse them in later runs without the reference samples, the limma DMR selection and the regions. Run the pipeline once with the [reference samples](#reference-samples) (`--input`), the regions (`--regions` or `--cgi_genome`), a beta-value tool (e.g. `--meth_atlas`), CelFiE or MetDecode (e.g. `--celfie`) and `--save_intermeds`:

```bash
nextflow run VIBTOBIlab/DecoNFlow \
  --input reference.csv \
  --bulk_samples bulk_samples.csv \
  --regions regions.bed \
  --meth_atlas --celfie \
  --save_intermeds \
  --outdir results \
  -profile docker
```

The matrices are saved in `results/preprocessing/reference_samples_preprocessing/`:

- `limma/reference_matrix_limma.tsv`: the beta values of the DMRs selected by limma, which can be used as is with `--ref_matrix`.
- `filtered_samples/final_celfie_atlas_matrix.csv`: the read counts of the DMRs selected by limma. It is comma separated and its first column is an index, so convert it to the format of `--celfie_ref_matrix` and `--metdecode_ref_matrix` with:

  ```bash
  cut -d, -f2- final_celfie_atlas_matrix.csv | tr ',' '\t' > count_ref_matrix.tsv
  ```

The reference matrices can also be built outside the pipeline, e.g. from a published methylation atlas, as long as they follow the formats described above ([`--ref_matrix`](#--ref_matrix), [`--celfie_ref_matrix` and `--metdecode_ref_matrix`](#--celfie_ref_matrix-and---metdecode_ref_matrix)).

## Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher requests (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/usage/configuration#max-resources) and [tuning workflow resources](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources) section of the nf-core website.

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).
