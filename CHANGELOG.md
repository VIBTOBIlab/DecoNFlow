# DNAmDeconv Pipeline
## [v1.0.2](https://github.ugent.be/DePreterLab/DNAmDeconv/releases/tag/v1.0.2) -
### Bugs fixed
- Thanks to [@kaschoof](https://github.ugent.be/kaschoof), major bug has been fixed
 in the TEST_PROCESSING module that was grouping according to wrong columns when more than 2 cell types are specified in the atlas. 
- Fixed problems with _check_max_ function and _base.config_ file not properly imported in _nextflow.config_
- Updated *bedtools* container version to the version 2.29.2 to fix a bug present in the previous version (see [#643](https://github.com/arq5x/bedtools2/issues/643)).
- Updated CelFiE container adding random seeds to make it generating reproducible results.
- Updated the PRMeth container to solve a bug on the number of cells (ncells) parameters when using the NMF modality.
### New features
- Added _lib_ directory with two functions for parameters checking, string citations, string version, for dumping parameters .json file and for nfcore logo.
- Added DSS as an alternative DMR selection tool.
- Added UXM deconvolution tool, wgbs_tools as DMR selection tool and other modules to convert the structure from uxm-like to standard ref-based structure
- Added MetDecode tool
- Added possibility to start from a reference matrix already built.
- Added possibility to start from a merged matrix with reference samples on columns and regions on rows.
### Minor changes
- Restructuring of the pipeline structure
- Removed `merging_approach` and `chunk_size` flags from the documentation (not used anymore).
- Changed parameter *custom* of the flag `DMRselection` into *limma*.
- Added possibility of specifying "-sorted" and "-g" to the bedtools intersect in the preprocessing to keep the memory usage low when using big coverage files (e.g. WGBS covs).
- Sort the columns of the matrices in MERGE_SAMPLES module to make the files always the same
- Updated MERGE_SAMPLES container to always output sorted samples for reproducibility

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