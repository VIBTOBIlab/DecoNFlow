#!/usr/bin/env Rscript

# Edoardo Giuili (edoardo.giuili@ugent.be)
# 06 / 2024

# Deconvolution using MethylResolver
library(MethylResolver)
version <- "0.1"
copyright <- "Copyright (C) 2024 Edoardo Giuili (edoardo.giuili@ugent.be)"


# Create print version header
printVersion <- function() {
  cat("run_methylresolver.R, version", version, "\n")
  cat(copyright, "\n")
  q()
}


# Create the usage for help
usage <- function() {
  cat('Usage: Rscript run_methylresolver.R  [options]  -s <infile> -m <mixfile> -a <alpha>

  Positional arguments:
    -s <infile>                  Matrix with DMRs on rows and cell entities on cols
    -m <mixfile>                 Sample file(s) to deconvolve (same structure of sig_matrix)
                                 (no missing values)
    -a <alpha>                   Alpha value for the model (def. 0.5)

  ')
  q()
}


# default args/parameters
alpha <- 0.5


# get CL args
args <- commandArgs(trailingOnly = TRUE)
i <- 1
while (i <= length(args)) {
  if (substr(args[i], 1, 1) == "-") {
    if (args[i] == "-h" || args[i] == "--help") {
      usage()
    } else if (args[i] == "--version") {
      printVersion()
    } else if (i < length(args)) {
      if (args[i] == "-s") {
        infile <- args[i + 1]
      } else if (args[i] == "-m") {
        mixfile <- args[i + 1]
      } else if (args[i] == "-a") {
        alpha <- args[i + 1]
      } else {
        cat("Error! Unknown parameter:", args[i], "\n")
        usage()
      }
      i <- i + 1
    } else {
      cat("Error! Unknown parameter with no arg:", args[i], "\n")
      usage()
    }
  }
  i <- i + 1
}


# check for parameter errors
if (alpha == "None") {
  cat("Error! Must specify an alpha value\n")
  usage()
} else if (is.na(as.numeric(alpha)) == TRUE) {
  cat("Error! Must specify a numeric alpha value\n")
  usage()
} else if (as.numeric(alpha) > 0.9 | as.numeric(alpha) < 0.5) {
  cat("Error! Must specify an alpha value between 0.5 and 0.9 \n")
  usage()
}


# Read the files
MethylSig <- read.csv(infile,row.names = 1,check.names=F)
MethylMix <- read.csv(mixfile,row.names = 1,check.names=F)
rownames(MethylMix) <- paste0(MethylMix$chr, ":", MethylMix$start, "-", MethylMix$end)
MethylMix[,c('chr','start','end')] <- NULL


# Run deconvolution
MethylResolver(methylMix = as.matrix(MethylMix),
               methylSig = as.matrix(MethylSig),
               doPar = T,
               numCores = 4,
               betaPrime = F,
               absolute = F,
               alpha = as.numeric(alpha))


# Save the results
results <- read.table("MethylResolver.txt")
results <- results[,colnames(MethylSig)]
write.csv(results, paste0("test_samples_deconv_output_alpha_",alpha,".csv"))
