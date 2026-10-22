#!/usr/bin/env Rscript

# Edoardo Giuili (edoardo.giuili@ugent.be)
# 06 / 2024

# Deconvolution using MeDeCom
suppressWarnings(suppressMessages(library(MeDeCom)))
version <- "0.1"
copyright <- "Copyright (C) 2024 Edoardo Giuili (edoardo.giuili@ugent.be)"


# Create print version header
printVersion <- function() {
  cat("run_medecom.R, version", version, "\n")
  cat(copyright, "\n")
  q()
}


# Create the usage for help
usage <- function() {
  cat('Usage: Rscript run_medecom.R  [options] -m <mixfile> -l lambda -k <clusters>

  Positional arguments:
    -m <mixfile>                 Sample file(s) to deconvolve
    -k <clusters>                Number of clusters
  Optional parameters:
    -n <ninit>                   Number of random initializations (def. 10)
    -f <nfold>                   Number of folds for CV (def. 10)
    -r <itermax>                 Max number of iterations (def. 300)
    -c <ncores>                  Number of cores (def. 4)
  ')
  q()
}


# def parameters
lambda <- c(0,10^(-5:-1))
ninit <- 10
nfold <- 10
itermax <- 300
ncores <- 4


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
      if (args[i] == "-m") {
        mixfile <- args[i + 1]
      } else if (args[i] == "-k") {
        clusters <- args[i + 1]
      } else if (args[i] == "-f") {
        nfold <- args[i + 1]
      } else if (args[i] == "-c") {
        ncores <- args[i + 1]
      } else if (args[i] == "-n") {
        ninit <- args[i + 1]
      } else if (args[i] == "-r") {
        itermax <- args[i + 1]
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
if (is.null(clusters)) {
  cat("Error! Must specify the number of clusters\n")
  usage()
}
if (is.null(lambda)) {
  cat("Error! Must specify the lambda value\n")
  usage()
}


# Ensure the params are integer
ninit <- as.integer(ninit)
nfold <- as.integer(nfold)
itermax <- as.integer(itermax)
ncores <- as.integer(ncores)


# Read the files
samples_m <- na.omit(read.csv(mixfile,row.names = 1,check.names=F))
rownames(samples_m) <- paste0(samples_m$chr, ":", samples_m$start, "-", samples_m$end)
samples_m[,c('chr','start','end')] <- NULL
samples_m <- as.matrix(samples_m)


# Run deconvolution
medecom.result<-runMeDeCom(samples_m, as.numeric(clusters), lambda, NINIT=ninit, NFOLDS=nfold, ITERMAX=itermax, NCORES=ncores)
min.index <- which.min(medecom.result@outputs$`1`$rmse)
opt.lambda <- medecom.result@parameters$lambdas[min.index]
results <- t(getProportions(medecom.result, K = clusters, lambda = opt.lambda))
rownames(results) <- colnames(samples_m)
write.csv(results, paste0("test_samples_deconv_output_lambda",opt.lambda,".csv"), quote = FALSE)
rds_file <- paste0("medecom_result_lambda_",opt.lambda,".rds")
saveRDS(medecom.result, rds_file)
