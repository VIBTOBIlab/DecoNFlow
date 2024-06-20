![Presentation1](https://github.com/edogiuili/DNAm_deconvolution_benchmarking/assets/85080683/09d33d07-c9a1-4102-b246-6b5970174fa6)

# Table of Contents
1. [Introduction](#Introduction)
2. [Installation](#Installation)
3. [Usage](#Usage)
4. [Contributing](#Contributing)
5. [License](#License)

# Introduction
DNAmDeconv is a bioinformatics analysis pipeline used for computational deconvolution of DNA methylation data. It pre-processes the coverage files of the reference dataset, it performs a clustering of the single CpGs in regions and then it runs a differential methylated regions (DMRs) analysis to extract cell type specific DNAm signatures (markers). Finally, it builds a reference matrix and deconvolves the bulks samples for which the cellular proportions are unknown.

The pipeline is built using [Nextfklow](https://www.nextflow.io/) a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker / Singularity containers making installation trivial and results highly reproducible.