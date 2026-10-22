#!/usr/bin/env Rscript

# Edoardo Giuili (edoardo.giuili@ugent.be)
# 06 / 2024

# Deconvolution using EpiSCORE
library(EpiSCORE)
version <- "0.1"
copyright <- "Copyright (C) 2024 Edoardo Giuili (edoardo.giuili@ugent.be)"


# Create print version header
printVersion <- function() {
  cat("run_episcore.R, version", version, "\n")
  cat(copyright, "\n")
  q()
}


# Create the usage for help
usage <- function() {
  cat('Usage: Rscript run_episcore.R [options] -s <infile> -m <mixfile>

  Positional arguments:
    -s <infile>                  Matrix with DMRs on rows and cell entities on cols
    -m <mixfile>                 Sample file(s) to deconvolve (same structure of sig_matrix)
                                 (no missing values)
  Optional arguments:
    -w <weight>                  Weight to use for the deconvolution (def. 0.4)

  ')
  q()
}


# Default params
weight <- 0.4


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
      } else if (args[i] == "-w") {
        weight <- args[i + 1]
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
 if (is.na(as.numeric(weight)) == TRUE) {
  cat("Error! Must specify a numeric weight value\n")
  usage()
} else if (as.numeric(weight) > 0.9 | as.numeric(weight) < 0.05) {
  cat("Error! Must specify a weight between 0.05 and 0.9 \n")
  usage()
}


# Read the files
ref_m <- read.csv(infile,row.names = 1,check.names=F)
samples_m <- read.csv(mixfile,row.names = 1,check.names=F)
rownames(samples_m) <- paste0(samples_m$chr, ":", samples_m$start, "-", samples_m$end)
samples_m[,c('chr','start','end')] <- NULL
ref_m$weight <- apply(ref_m, 1, mean)


# Run deconvolution
estF.o <- wRPC(data=as.matrix(samples_m),ref=as.matrix(ref_m), useW = T, wth = weight)
write.csv(estF.o$estF,paste0("test_samples_deconv_output_weight_",weight,".csv"))
