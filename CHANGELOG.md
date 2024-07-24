# DNAmDeconv Pipeline
[v1.0.1] - 
-nsamples parameter has been removed (it's now automatically computed)
-the preprocessing of the reference and testing samples, including the preprocessing adopted in the reference-free tools, has been modified. It now uses bedtools and runs in bash. The preprocessing is now much faster (10x) and less computationally intensive (1000 less).
-the validation of the input and test_set files has been moved in the DNAmDeconv workflow. Moreover, the samples are now being passed one by one to the preprocessing step: this allows parallelization of these steps, reduces the amount of memory needed ultimately avoiding run out of memory issues.
-merge_samples container and module has been added: it's necessary to merge all the files together once they have been filtered in order to give to the deconv tools the entire reference and testing matrix.
-major changes to the structure of the pipeline have been made.

[v1.0.0] - 2024-07-16 
The DNAmDeconv pipeline is designed to perform DNA methylation deconvolution on bulk DNA samples. This pipeline uses a Nextflow framework to streamline and automate the analysis process, ensuring reproducible and efficient results.