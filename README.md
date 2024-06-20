![Presentation1](https://github.com/edogiuili/DNAm_deconvolution_benchmarking/assets/85080683/09d33d07-c9a1-4102-b246-6b5970174fa6)

# Table of Contents
1. [Introduction](#Introduction)
2. [Usage](#Usage)
3. [Contributing](#Contributing)
4. [License](#License)

# Introduction
DNAmDeconv is a bioinformatics analysis pipeline used for computational deconvolution of DNA methylation data. It pre-processes the coverage files of the reference dataset, it performs a clustering of the single CpGs in regions and then it runs a differential methylated regions (DMRs) analysis to extract cell type specific DNAm signatures (markers). Finally, it builds a reference matrix and deconvolves the bulks samples for which the cellular proportions are unknown.

The pipeline is built using [Nextflow](https://www.nextflow.io/) a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker / Singularity containers making installation trivial and results highly reproducible.

# Usage
> **NOTE**
If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/getting_started/installation) on how to set-up Nextflow.

## Reference dataset
First, prepare a samplesheet with your input data (reference dataset) data looks as follows:

<span style="background-color: #808080; padding: 2px 4px; border-radius: 4px;">reference.csv</span>
```plaintext:
name,type,file
file1,healthy,/path/to/the/file/file1.cov.gz
file2,healthy,/path/to/the/file/file2.cov.gz
file3,healthy,/path/to/the/file/file3.cov.gz
file4,nbl,/path/to/the/file/file4.cov.gz
file5,nbl,/path/to/the/file/file5.cov.gz
file6,nbl,/path/to/the/file/file6.cov.gz
```
Each row represents a coverage file, with the first column representing the name, the second column representing the name of the cell type and the last column representing the path where the coverage file is stored.

## Region file

## Testing samples