# DecoNFlow Pipeline

## [v2.2.0](https://github.com/VIBTOBIlab/DecoNFlow/releases/tag/v2.2.0) - 2025-07-02

- Added the test profile to test the pipeline on public, test data.
- Removed unnecessary files from assets/ directory and updated the documentation.

## [v2.1.0](https://github.ugent.be/DePreterLab/DecoNFlow/releases/tag/v2.1.0) - 2025-06-18

### 🐛 Bug Fixes

- **Limma module**:
  Modified container and module to prevent errors when `--top` exceeds the available number of DMRs.

- **FINDMARKERS module**:
  Added the `--sort_by delta_means` flag. Previously, when using `--only_hyper`, markers were incorrectly sorted by chromosome location instead of delta means as intended.
  \_Note: a GitHub issue should be opened in the `wgbs_tools` repository regarding this behavior.

- **convert_atlas container**:
  Updated to properly handle the new **entity** structure (with `_`) introduced in version 2.0.0.

- **wgbstools subworkflow**:
  Adjusted to include `_` in the entity structure to avoid processing errors.

- **UXM subworkflow**:
  Added `params.ref_matrix` to the conditional (`if`) gate, ensuring that the workflow proceeds when no DMR selection method is specified but a reference matrix is provided.

- **Preprocessing modules**:
  Added `sort -T /tmp/` to prevent `sort` from using unavailable directories.
  See [related discussion](https://github.com/nf-core/chipseq/issues/123).

- **CelFiE preprocessing**:
  Included missing `params.big_covs` parameter.

### 🚀 Minor Improvements

- **MERGE_SAMPLES module**:
  Renamed the `step` parameter for clarity and consistency with the latest container version.

- **Container cleanup**:
  Removed unnecessary containers and added a `/bin` directory for utility scripts.

- **test_DMR.R script optimization**:
  Reduced container size by removing `tidyverse` from `test_DMR.R`, keeping only `tibble` and `dplyr`.

- **Limma DMR selection**:
  Introduced `params.include_na` parameter to allow merging of reference samples even when values are missing.
  This prevents excessive region filtering when the number of samples or entities is high.

- **FINDMARKERS module**:
  Moved `top` parameter outside the main script, now passed to the function only when explicitly defined (not `null` or `false`).

- **COMBINE_FILES module**:
  Changed the way output files are combined: now files are linked directly using Nextflow, eliminating the need for volume bindings.

- **Reference coverage option**:
  Added support to use reference coverage files (`--input`) instead of rerunning the `bismark_methylationextraction` module.
  Applies when using `wgbstools` for DMR selection and `meth_atlas` (or other tools except UXM) for deconvolution.

- **Bulk sample filtering parameters**:
  Replaced `refree_min_counts` and `refree_min_cpgs` with `bulk_min_counts` and `bulk_min_cpgs` for more flexible CpG and region filtering on bulk samples. By default they are both set to 0 (meaning, no filtering on the bulk samples).

### 🔄 Updates to MetDecode & CelFiE Subworkflows

- Previously, only atlas markers present in **all** bulk samples were used for deconvolution.
- Now, if a marker is missing in any bulk sample, a value of **0** is assigned (instead of `NA`) for both methylation and depth, ensuring smoother downstream processing.

## [v2.0.0](https://github.ugent.be/DePreterLab/DecoNFlow/releases/tag/v2.0.0) - 2024-12-26

### Bugs fixed

- Thanks to [@kaschoof](https://github.ugent.be/kaschoof), major bug has been fixed
  in the TEST_PROCESSING module that was grouping according to wrong columns when more than 2 cell types are specified in the atlas.
- Fixed problems with _check_max_ function and _base.config_ file not properly imported in _nextflow.config_
- Updated _bedtools_ container version to the version 2.29.2 to fix a bug present in the previous version (see [#643](https://github.com/arq5x/bedtools2/issues/643)).
- Updated CelFiE container adding random seeds to make it generating reproducible results.
- Updated the PRMeth container to solve a bug on the number of cells (ncells) parameters when using the NMF modality.
- Updated nf-core schema plugin to version 2.2.0
- Changed the function to read the input file (from meta.clone() to def meta)

### New features

- Added _lib_ directory with two functions for parameters checking, string citations, string version, for dumping parameters .json file and for nfcore logo.
- Added DSS as an alternative DMR selection tool.
- Added UXM deconvolution tool, wgbs_tools as DMR selection tool and other modules to convert the structure from uxm-like to standard ref-based structure
- Added MetDecode tool
- Added possibility to start from a reference matrix already built.
- Added possibility to start from a merged matrix with reference samples on columns and regions on rows.
- In the entity column of the reference samples is now possible to include numbers.

### Minor changes

- Restructuring of the pipeline structure
- Removed `merging_approach` and `chunk_size` flags from the documentation (not used anymore).
- Changed parameter _custom_ of the flag `DMRselection` into _limma_.
- Added possibility of specifying "-sorted" and "-g" to the bedtools intersect in the preprocessing to keep the memory usage low when using big coverage files (e.g. WGBS covs).
- Sort the columns of the matrices in MERGE_SAMPLES module to make the files always the same
- Updated MERGE_SAMPLES container to always output sorted samples for reproducibility
- Added gitignore, pre-commit and CODEOWNERS for PR
- Added metromap to the README
- Added instituional config options
- Changed methyl_atlas into meth_atlas
- Added prefix chr check between region file and coverage files in limma preprocessing

## [v1.0.1](https://github.ugent.be/DePreterLab/DecoNFlow/releases/tag/v1.0.1) - 2024-07-26

### Parameters changes

- `nsamples` parameter has been removed (it's now automatically computed)

### Speed of the preprocessing

- The preprocessing of the reference and testing samples, including the preprocessing adopted in the reference-free tools, has been modified. It now uses bedtools and runs in bash. The preprocessing is now much faster (10x) and less computationally intensive (20x).
- `merge_samples` container and module has been added to merge all the files together once they have been preprocessed in order to give to the deconv tools the entire reference and testing matrix.

### Input files validation

- The validation of the `input` and `test_set` files has been moved in the DNAmDeconv workflow. Moreover, the samples are now being passed one by one to the preprocessing step: this allows parallelization of these steps, reduces the amount of memory needed and ultimately avoid run out of memory issues.

### limma DMRs

Version two of the container has been released. With this version, it's now possible to perform DMR selection with even only one sample per group.

## [v1.0.0](https://github.ugent.be/DePreterLab/DecoNFlow/releases/tag/v1.0.0) - 2024-07-16

The DNAmDeconv pipeline is designed to perform DNA methylation deconvolution on bulk DNA samples. This pipeline uses a Nextflow framework to streamline and automate the analysis process, ensuring reproducible and efficient results.
