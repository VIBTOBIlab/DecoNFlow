#!/usr/bin/env Rscript

# Sofie Van de Velde (sofie.vandevelde@ugent.be)
# 06 / 2024

# Run EpiDISH deconvolution
suppressWarnings(suppressMessages(library(EpiDISH)))
version <- "0.1"
copyright <- "Copyright (C) 2024 Sofie Van de Velde  (sofie.vandevelde@ugent.be)"


# Create print version header
printVersion <- function() {
  cat("EpiDISH.r, version", version, "\n")
  cat(copyright, "\n")
  q()
}


# Create the usage for help
usage <- function() {
  cat('Usage: Rscript EpiDISH.R [options] -s <infile> -m <mixfile> -d <mod>

  Positional arguments:
    -s <infile>                  Matrix with DMRs on rows and cell entities on cols
    -m <mixfile>                 Sample file(s) to deconvolve (same structure of sig_matrix)
                                 (no missing values)
    -d <mod>                     Modality to use ([RPC, CBS, CP_ineq, CP_eq], def. "RPC")
  ')
  q()
}


# default params
mod <- "RPC"


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
        mod <- args[i + 1]
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
if (is.null(infile)) {
  cat("Error! Must specify the sig matrix\n")
  usage()
}
if (is.null(mixfile)) {
  cat("Error! Must specify the sample file to deconvolve\n")
  usage()
}


# Reference dataset
message("Formatting the datasets: initiated!")
sig_matrix <- as.matrix(read.csv(infile, row.names = 1,check.names=F))
mixture_file <- read.csv(mixfile, row.names = 1,check.names=F)
rownames(mixture_file) <- paste0(mixture_file$chr, ":", mixture_file$start, "-", mixture_file$end)
mixture_file[,c('chr','start','end')] <- NULL
sig_matrix <- as.matrix(sig_matrix)


# Running EpiDISH
message("Running EpiDISH deconvolution algorithm. EpiDISH can be run in 4 modalities - RPC, CBS, CP_ineq, CP_eq.")
message("EpiDISH deconvolution: started!")
message(paste("Selected modality:", mod))

# Define the parameters based on the value of 'mod'
params <- switch(mod,
                 "RPC" = list(method = "RPC", maxit = 10000),
                 "CBS" = list(method = "CBS"),
                 "CP_ineq" = list(method = "CP", constraint = "inequality"),
                 "CP_eq" = list(method = "CP", constraint = "equality"))

# run the deconvolution for each file separately to remove NAs only in the single samples
results <- data.frame()
for (col in colnames(mixture_file)) {
    sample <- as.matrix(mixture_file[,col])
    colnames(sample) <- col
    rownames(sample) <- rownames(mixture_file)
    sample <- as.matrix(sample[!is.na(sample),])
    res <- do.call(epidish, c(list(sample, sig_matrix), params))$estF
    rownames(res) <- col
    print(res)
    results <- rbind(results,res)
}

# Construct the filename dynamically and write the result to a CSV file
write.csv(results, file = file.path(paste0("epidish_res_", mod, ".csv")))

message("EpiDISH deconvolution: done!")
