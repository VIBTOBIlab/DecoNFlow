# DecoNFlow Pipeline

## [v3.0.0](https://github.ugent.be/DePreterLab/DecoNFlow/releases/tag/v3.0.0) - 2026-10-16

### ⚠️ Breaking changes

- **Minimum Nextflow version** raised to **26.04.0**. The pipeline is migrated to the Nextflow strict syntax and rebuilt on the nf-core template (nf-core/tools 4.1.0), with parameter validation through the `nf-schema` plugin.
- **Removed DMR selection methods**: DMRfinder and wgbstools, together with the UXM deconvolution tool (`DMRfinderPrep`, `wgbstools` and `uxm` subworkflows and their modules, plus the bundled hg19 genome files in `assets/genome/`). Limma is now the only DMR selection method and the `--DMRselection` parameter has been removed.
- **Removed parameters** tied to the dropped tools: `--DMRselection`, `--merged_matrix`, `--ref_bams`, `--test_bams`, `--fasta`, `--groups_file`, `--uxm`, `--uxm_atlas`, `--dmrfinder_pvalue`, `--dmrfinder_qvalue`, `--max_bp`, `--min_cpg_uxm`, `--rlen` and `--only_hypo`.
- **Renamed `--test_set` to `--bulk_samples`** for the samplesheet of the bulk samples to deconvolve.
- **Stricter parameter validation** at launch: `--bulk_samples` is now required, `--regions`, `--ref_matrix` and `--bulk_samples` must point to existing files, and `--direction`, `--collapse_method`, `--adj_method`, `--prmeth_mod` and `--genome_order` only accept their documented values. `--clusters` must be at least 2 and `--top` at least 1. Values that used to fail midway through a run (e.g. a typo in `--direction`, which only failed at the limma step) are now rejected before anything runs.
- **limma DMR selection fits the model on M-values** instead of beta values (`test_DMR.R`). DMRs are still ranked and split into hyper/hypo by their delta beta, but the p-values, and therefore the DMRs passing `--adjp`, can differ from previous versions.

### 🚀 Improvements

- Renamed the main workflow from `DNAmDeconv` to `DECONFLOW` and the limma DMR selection subworkflow from `inHousePrep` to `markerSelection`. Local modules and subworkflows now live in `modules/local/` and `subworkflows/local/`.
- Limma marker selection now only runs when a reference-based tool needs the reference atlas. Reference-free runs (MeDeCom, RefFreeCellMix) no longer preprocess the reference samples or run limma.
- Updated the documentation, citations and README.
- **New HTML report** (`deconvolution_report.html`, `DECONV_REPORT` module) with a per-sample comparison of all reference-based tools (stacked bars plus the mean, SD and range of each cell type across tools) and the results of each tool (stacked bars per sample and tables).
- **Reference-based and reference-free results are now saved separately**, in `combined_results_refbased.csv` and `combined_results_reffree.csv`, instead of a single `combined_results.csv`. Reference-free tools estimate unlabelled components (e.g. `LMC1`, `V1`) rather than the cell types of the reference, so combining them in one table mixed unrelated columns.

### 🐛 Bug fixes

- **Reference matrix (`--ref_matrix`) runs were always rejected** by a faulty parameter check, which also required `--regions` although the reference matrix route does not use it. Both now work as intended.
- **Reference-free runs without reference samples were rejected** unless both MeDeCom and RefFreeCellMix were selected. A single reference-free tool can now be run with only `--bulk_samples` and `--regions`.
- **CelFiE and MetDecode with a reference matrix**: they need the reference samples (`--input`), so with `--ref_matrix` (including through `--benchmark`) they are now skipped with a warning instead of being silently dropped. The run fails with a clear error if no other tool is left.
- **`--big_covs` without `--genome_order`** is now caught at launch, instead of failing in the preprocessing with a missing `null.genome` file.
- **Unused inputs**: a warning is printed when `--input` or `--ref_matrix` is given but no reference-based tool is selected, and the reference matrix is no longer processed in that case.
- **Reference matrix check (`check_file.py`)**: an invalid matrix now stops the run with the reason (it used to exit successfully and fail later with a missing `reference.csv`), and duplicated cell type names are now detected.

### 🔧 Maintenance

- Parameter checks are grouped in `validateInputParameters()` (combinations of parameters) and `nextflow_schema.json` (single parameters), with the selected tools defined once and shared with the `DECONFLOW` workflow.
- Cleaned up and documented the helper scripts (`build_matrix.py`, `check_file.py`, `combine_files.py`, `intersect.py`, `merge_tables.py`), with identical outputs.
- Fixed the config type warnings in `nextflow.config` and `conf/base.config`.

### 🧪 Tests and CI

- End-to-end tests now use bulk samples (`--bulk_samples`), and the snapshots have been updated.
- New end-to-end tests for the reference matrix route (`tests/refmatrix.nf.test`), including the CelFiE warning and error cases, and a module test for `DECONV_REPORT`.
- The nf-test GitHub action now also runs on pushes to `main`, `master` and `dev-refactoring` (the previous `branch:` trigger was invalid), and tests against Nextflow 26.04.0 and `latest-everything`.

## [v2.5.0](https://github.ugent.be/DePreterLab/DecoNFlow/releases/tag/v2.5.0) - 2026-09-26

- Update the RefFreeCellMix module to also output the methylation components for downstream latent component analysis.

## [v2.4.0](https://github.ugent.be/DePreterLab/DecoNFlow/releases/tag/v2.4.0) - 2026-07-21

- Update the MeDeCom module to also output the entire object generated by MeDeCom package for latent component analysis.

## [v2.3.0](https://github.ugent.be/DePreterLab/DecoNFlow/releases/tag/v2.3.0) - 2025-11-03

- Changed the name from PRMeth_RF to the actual name RefFreeCellMix and added the corresponding citation.
- Added 2 new modules, being Houseman's CP equality and inequality. Before, to run these modalities you had to specify the **--mod** EpiDISH parameter. Now this parameter is deprecated and to run the above two tools you just have to specify the corresponding new flag **--houseman_eq** and **--houseman_ineq**.
- Changed the Docker container of CIBERSORT module with the EpiDISH container since EpiDISH package contains the CIBERSORT modality.
- Readapted the output directories and files in the modules/conf to have a more clear structure.
- Added tests on each individual module in the **tests/modules/** folder.
- Added pipeline end-to-end tests and nf-test actions on PR and new release.

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
