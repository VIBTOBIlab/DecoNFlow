# DNAmDeconv Pipeline
## [v1.0.2](https://github.ugent.be/DePreterLab/DNAmDeconv/releases/tag/v1.0.2) -
### Bugs fixed
- Fixed problems with _check_max_ function and _base.config_ file not properly imported in _nextflow.config_
- Removed _merging_approach_ flag from the documentation.
- Updated *bedtools* container version to the version 2.29.2 to fix a bug present in the previous version (see [#643](https://github.com/arq5x/bedtools2/issues/643)).
- Updated CelFiE container adding random seeds to make it generating reproducible results.
- Minor restructuring of the pipeline structure
### Small new features
Added _lib_ directory with two functions for parameters checking, string citations, string version, for dumping parameters .json file and for nfcore logo.
Added DSS as an alternative DMR selection tool. (add docu)
Added possibility to start from a reference matrix already built (add docu)
Added possibility to start from a merged matrix with reference samples on columns and regions on rows (and methylation values). (add docu)

## [v1.0.1](https://github.ugent.be/DePreterLab/DNAmDeconv/releases/tag/v1.0.1) - 2024-07-26
### Parameters changes
- `nsamples` parameter has been removed (it's now automatically computed)
### Speed of the preprocessing
- The preprocessing of the reference and testing samples, including the preprocessing adopted in the reference-free tools, has been modified. It now uses bedtools and runs in bash. The preprocessing is now much faster (10x) and less computationally intensive (20x).
- `merge_samples` container and module has been added to merge all the files together once they have been preprocessed in order to give to the deconv tools the entire reference and testing matrix.
### Input files validation 
- The validation of the `input` and `test_set` files has been moved in the DNAmDeconv workflow. Moreover, the samples are now being passed one by one to the preprocessing step: this allows parallelization of these steps, reduces the amount of memory needed and ultimately avoid run out of memory issues.
### limma DMRs
Version two of the container has been released. With this version, it's now possible to perform DMR selection with even only one sample per group.

## [v1.0.0](https://github.ugent.be/DePreterLab/DNAmDeconv/releases/tag/v1.0.0) - 2024-07-16 
The DNAmDeconv pipeline is designed to perform DNA methylation deconvolution on bulk DNA samples. This pipeline uses a Nextflow framework to streamline and automate the analysis process, ensuring reproducible and efficient results.