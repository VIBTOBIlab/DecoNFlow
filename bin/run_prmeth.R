#!/usr/bin/env Rscript

# Edoardo Giuili (edoardo.giuili@ugent.be)
# 06 / 2024

# Deconvolution using PRMeth
library(matrixStats)
library(quadprog)
# PRMeth (https://github.com/hedingqin/PRMeth, commit 5a4b35b) is in bin/PRMeth, next to this script,
# unchanged. Note: the PRMeth repository does not include a license.
script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE))))
source(file.path(script_dir, "PRMeth", "R", "prmeth.R"))
version <- "0.1"
copyright <- "Copyright (C) 2024 Edoardo Giuili (edoardo.giuili@ugent.be)"


# Create print version header
printVersion <- function() {
  cat("run_prmeth.R, version", version, "\n")
  cat(copyright, "\n")
  q()
}


# Create the usage for help
usage <- function() {
  cat('Usage: Rscript run_prmeth.R  [options]  -s <infile> -m <mixfile> -k <ncells> -d <modality>

  Positional arguments:
    -s <infile>                  Matrix with DMRs on rows and cell entities on cols
    -m <mixfile>                 Sample file(s) to deconvolve (same structure of sig_matrix)
                                 (no missing values)
    -k <ncells>                  Number of expected cell types
  Optional arguments:
    -d <modality>                Modality to use for deconvolution (def. "RF")

  ')
  q()
}


# default args/parameters
modality <- "RF"
ncells <- 0


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
      } else if (args[i] == "-d") {
        modality <- args[i + 1]
      } else if (args[i] == "-k") {
        ncells <- args[i + 1]
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
if (modality != "RF" & modality != "NMF" & modality != "QP") {
  cat("Error! Must specify a correct modality\n")
  usage()
}
if (ncells==0 & modality != "QP") {
  cat("Error! Must specify the number of expected cell types ( >= 2 )\n")
  usage()
}


# Read the files
ref_m <- read.csv(infile,row.names = 1,check.names=F)
samples_m <- na.omit(read.csv(mixfile,row.names = 1,check.names=F))
rownames(samples_m) <- paste0(samples_m$chr, ":", samples_m$start, "-", samples_m$end)
samples_m[,c('chr','start','end')] <- NULL
ref_m <- ref_m[rownames(samples_m),]



# Run deconvolution
if (modality == "RF") {
  # ref-free
  fit <- rf(as.matrix(samples_m), as.numeric(ncells))
} else if (modality == "NMF") {
  # partial ref-free
  samples_m <- samples_m[rownames(ref_m),]
  fit <- prmeth(as.matrix(samples_m), as.matrix(ref_m), as.numeric(ncells))
} else if (modality == "QP") {
  # ref-based
  samples_m <- samples_m[rownames(ref_m),]
  fit <- qp(as.matrix(samples_m), as.matrix(ref_m))
}
res <- round(t(fit$H), 4)
write.csv(res, paste0("test_samples_deconv_output_mod_",modality,".csv"), quote = FALSE)

# Write the estimated methylation profiles of cell types (W matrix, DMRs x cell types)
# QP is ref-based and does not estimate W
if (!is.null(fit$W)) {
  W <- round(fit$W, 4)
  write.csv(W, paste0("test_samples_deconv_W_mod_",modality,".csv"), quote = FALSE)
}
