#!/usr/bin/env Rscript

# John M. Gaspar (jsh58@wildcats.unh.edu)
# Dec. 2016

# Sofie Van de Velde (sofvdvel.vandevelde@ugent.be)
# 11 / 2024

# Finding differentially methylated regions from a table
#   of counts produced by bisulfite sequencing data.
# Underlying statistics are performed using the R package 'DSS'
#   (https://bioconductor.org/packages/release/bioc/html/DSS.html).

version <- '0.3'
copyright <- 'Copyright (C) 2016 John M. Gaspar (jsh58@wildcats.unh.edu)'

# Create print version header
printVersion <- function() {
    cat('findDMRs.r from DMRfinder, version', version, '\n')
    cat(copyright, '\n')
    q()
}

# Create the usage for help
usage <- function() {
  cat('Usage: Rscript findDMRs.r  [options]  -i <input>  -o <output>  \\
             <groupList1>  <groupList2>  [...]
    -i <input>    File listing genomic regions and methylation counts
    -o <output>   Output file listing methylation results
    <groupList>   Comma-separated list of sample names (at least two
                    such lists must be provided)
  Options:
    -n <str>      Comma-separated list of group names
    -k <str>      Column names of <input> to copy to <output> (comma-
                    separated; def. "chr, start, end, CpG")
    -s <str>      Column names of DSS output to include in <output>
                    (comma-separated; def. "mu, diff, pval")
    -c <int>      Min. number of CpGs in a region (def. 3)
    -d <float>    Min. methylation difference between sample groups
                    ([0-1]; def. 0.10)
    -p <float>    Max. p-value ([0-1]; def. 0.05)
    -q <float>    Max. q-value ([0-1]; def. 1)
    -t <int>      Report regions with at least <int> comparisons
                    that are significant (def. 1)
    -col <str>    Collapse method:"mean" or "median"
    -dir          Direction of methylation: can be either "hypo","hyper",
                    "both" or "random" (def. "None", takes all the regions)
    -top          Take the top x number (integer) of DMRs per cell state
                    (def. "None"): it can be used only if direction flag
                    is specified
')
  q()
}

# Error function for missing sample name
missingSample <- function(sample, infile, names) {
  cat('Error! Missing information for sample "', sample,
    '" from input file ', infile, '.\n',
    '  Valid sample names are:', sep='')
  nIdx <- xIdx <- NULL
  for (n in names) {
    spl <- strsplit(n, '-')[[1]]
    if (length(spl) < 2) { next }
    if (spl[length(spl)] == 'N') {
      if (spl[-length(spl)] %in% xIdx) {
        cat(' ', spl[-length(spl)], sep='')
      } else {
        nIdx <- c(nIdx, spl[-length(spl)])
      }
    } else if (spl[length(spl)] == 'X') {
      if (spl[-length(spl)] %in% nIdx) {
        cat(' ', spl[-length(spl)], sep='')
      } else {
        xIdx <- c(xIdx, spl[-length(spl)])
      }
    }
  }
  cat('\n')
  q()
}

# Default args/parameters
groups <- NULL
infile <- "combined_cpgs.txt"
outfile <- "reference_matrix_DMRfinder.csv"
names <- list()        # list of sample names
minCpG <- 3            # min. number of CpGs
minDiff <- 0.10        # min. methylation difference
maxPval <- 0.05        # max. p-value
maxQval <- 1           # max. q-value (fdr)
tCount <- 1            # min. number of significant comparisons
keep <- c('chr', 'start', 'end', 'CpG')  # columns of input to keep
dss <- c('chr', 'pos', 'mu', 'diff', 'pval') # columns of DSS output to keep
collapse_method <- "mean" # Collapse method: mean or median
top <- 250 # takes all the DMRs
direction <- "both"

#temp <- strsplit("healthy,nbl", '[ ,]')[[1]]
#groups <- temp[nchar(temp) > 0]
#
#temp <- "DNA097385,DNA097389,DNA097393 DNA041087,DNA044133,DNA044134"
#temp <- strsplit(temp, " ")[[1]]
#names <- lapply(temp, function(tmp) strsplit(tmp, ",")[[1]])

# Get CL args
args <- commandArgs(trailingOnly=T)
i <- 1
while (i <= length(args)) {
  if (substr(args[i], 1, 1) == '-') {
    if (args[i] == '-h' || args[i] == '--help') {
      usage()
    } else if (args[i] == '--version') {
      printVersion()
    } else if (i < length(args)) {
      if (args[i] == '-i') {
        infile <- args[i + 1]
      } else if (args[i] == '-o') {
        outfile <- args[i + 1]
      } else if (args[i] == '-n') {
        temp <- strsplit(args[i + 1], '[ ,]')[[1]]
        groups <- temp[nchar(temp) > 0]
      } else if (args[i] == '-k') {
        temp <- strsplit(args[i + 1], '[ ,]')[[1]]
        keep <- c(keep, temp[nchar(temp) > 0])
      } else if (args[i] == '-s') {
        temp <- strsplit(args[i + 1], '[ ,]')[[1]]
        dss <- c(dss, temp[nchar(temp) > 0])
      } else if (args[i] == '-c') {
        minCpG <- as.integer(args[i + 1])
      } else if (args[i] == '-d') {
        minDiff <- as.double(args[i + 1])
      } else if (args[i] == '-p') {
        maxPval <- as.double(args[i + 1])
      } else if (args[i] == '-q') {
        maxQval <- as.double(args[i + 1])
        dss <- c(dss, 'fdr')
      } else if (args[i] == '-t') {
        tCount <- as.integer(args[i + 1])
      } else if (args[i] == '-col') {
        collapse_method <- args[i + 1]
      } else if (args[i] == "-dir") {
        direction <- args[i + 1]
      } else if (args[i] == "-top") {
        top <- args[i + 1]
      } else {
        cat('Error! Unknown parameter:', args[i], '\n')
        usage()
      }
      i <- i + 1
    } else {
      cat('Error! Unknown parameter with no arg:', args[i], '\n')
      usage()
    }
  } else {
    temp <- strsplit(args[i], '[ ,]')[[1]]
    names <- c(names, list(temp[nchar(temp) > 0]))
  }
  i <- i + 1
}

# check DSS installation
if (!suppressMessages(suppressWarnings(require(DSS)))) {
  stop('Required package "DSS" not installed.\n',
    '  For installation information, please see:\n',
    '  https://bioconductor.org/packages/release/bioc/html/DSS.html\n')
}

# List of packages to load
packages <- c("DSS", "bsseq", "SummarizedExperiment",
              "MatrixGenerics", "GenomicRanges", "GenomeInfoDb",
              "IRanges", "S4Vectors", "BiocParallel",
              "Biobase", "BiocGenerics", "dplyr")

# Load the packages using lapply
invisible(lapply(packages, library, character.only = TRUE))

# Open a connection to a file to redirect print outputs
sink("DMRfinder_analysis.out")

# Check for parameter errors
cat("\n1) Check for parameter errors...\n")
if (is.null(infile) || is.null(outfile)) {
  cat('Error! Must specify input and output files\n')
  usage()
}
if (length(names) < 2) {
  cat('Error! Must specify at least two groups of samples\n')
  usage()
}
if (!(direction %in% c("hypo", "hyper", "both", "random", "None"))) {
  cat('Error! Must specify direction parameter among the following ones: "hypo","hyper","both","random","None"\n')
  usage()
}
if (top != "None") {
  if (as.numeric(top) %% 1 != 0) {
    cat("Error! Must specify an integer for the -t flag \n")
    usage()
  } else {
    top <- as.numeric(top)
  }
}
Sys.sleep(1)

# Check for samples duplicates
cat("\n2) Check for samples duplicates...\n")
if (any(duplicated(unlist(names)))) {
  stop('Sample(s) repeated in different groups: ',
    paste(unique(unlist(names)[duplicated(unlist(names))]),
    collapse=', '), '\n')
}
keep <- unique(keep)
dss <- unique(dss)
Sys.sleep(1)

# Group samples into a named list
cat("\n3) Group samples together...\n")
samples <- list()
for (i in 1:length(names)) {
  if (! is.null(groups) && i <= length(groups)) {
    group <- groups[i]
  } else {
    group <- paste(names[i][[1]], collapse='_')
  }
  if (group %in% names(samples)) {
    stop('Duplicated group name: ', group)
  }
  samples[[ group ]] <- names[i][[1]]
}
print(samples)
Sys.sleep(1)

# Load data, check for errors
cat("\n4) Read combine_CpG_sites.csv file ...\n")
data <- read.csv(infile, sep='\t', header=T, check.names=F)
if (any( ! keep %in% colnames(data))) {
  stop('Missing column(s) in input file ', infile, ': ',
    paste(keep[! keep %in% colnames(data)], collapse=', '), '\n')
}
if (colnames(data)[1] != 'chr') {
  stop('Improperly formatted input file ', infile, ':\n',
    '  Must have "chr" as first column\n')
}
print(head(data))
Sys.sleep(1)

# Determine columns for samples
cat("\n5) Determine columns for samples ...\n")
idx <- list()
idx[[ 'N' ]] <- list()
idx[[ 'X' ]] <- list()
for (i in names(samples)) {
  idx[[ 'N' ]][[ i ]] <- rep(NA, length(samples[[ i ]]))
  idx[[ 'X' ]][[ i ]] <- rep(NA, length(samples[[ i ]]))
}
for (i in names(samples)) {
  for (j in 1:length(samples[[ i ]])) {
    for (k in 1:ncol(data)) {
      spl <- strsplit(colnames(data)[k], '-')[[1]]
      if (length(spl) < 2) { next }
      if (spl[-length(spl)] == samples[[ i ]][ j ]) {
        if (spl[length(spl)] == 'N') {
          idx[[ 'N' ]][[ i ]][ j ] <- k
        } else if (spl[length(spl)] == 'X') {
          idx[[ 'X' ]][[ i ]][ j ] <- k
        }
      }
    }
    if ( is.na(idx[[ 'N' ]][[ i ]][ j ])
        || is.na(idx[[ 'X' ]][[ i ]][ j ]) ) {
      missingSample(samples[[ i ]][ j ], infile, colnames(data))
    }
  }
}
print(idx)
Sys.sleep(1)


# for each sample, create data frames to meet DSS requirements
cat("\n6) Optimise dataframe for DSS ...\n")
frames <- list()
for (i in names(samples)) {
  for (j in 1:length(samples[[ i ]])) {
    tab <- data.frame('chr'=data$chr, 'pos'=data$start,
      'N'=data[, idx[[ 'N' ]][[ i ]][ j ] ],
      'X'=data[, idx[[ 'X' ]][[ i ]][ j ] ])
    frames[[ samples[[ i ]][ j ] ]] <- tab
  }
}

# filter out all rows containing NA values in frames for each dataframe
frames_filtered <- lapply(frames, function(df) na.omit(df))
names(frames_filtered) <- names(frames)
Sys.sleep(1)


# perform DML pairwise tests using DSS
cat("\n7) Perform DML pairwise test using DSS ...")
cat("\n   - Collapsing method:", collapse_method)
cat("\n   - min. number of CpGs:", minCpG)
cat("\n   - min. methylation difference:", minDiff)
cat("\n   - max. p-value:", maxPval)
cat("\n   - max. q-value (fdr):", maxQval)
cat("\n   - direction:", direction)
cat("\n   - top:", top)
cat("\n")

bsdata <- makeBSseqData(frames_filtered, names(frames_filtered))
print(bsdata)
res <- data[, keep]  # results table

# matrix of booleans: does region meet threshold(s) for each comparison
mat <- matrix(nrow=nrow(res), ncol=length(samples)*(length(samples)-1)/2)
comps <- c()  # group comparison strings

for (i in 1:(length(samples)-1)) {
  for (j in (i+1):length(samples)) {

    # perform DML test
    comp <- paste(names(samples)[i], names(samples)[j], sep='->')
    comps <- c(comps, comp)
    cat('Comparing group "', names(samples)[i], '" to group "', names(samples)[j], '"\n  ', sep='')

    if (length(samples[[i]]) < 2 || length(samples[[j]]) < 2) {
      # without replicates, must set equal.disp=T
      dml <- DMLtest(bsdata, group1=samples[[i]], group2=samples[[j]], equal.disp=T)
    } else {
      dml <- DMLtest(bsdata, group1=samples[[i]], group2=samples[[j]])
    }

    # make sure necessary columns are present, remove extraneous
    col <- colnames(dml)
    if (any(!dss %in% col & !paste(dss, '1', sep='') %in% col)) {
      stop('Missing column(s) from DSS result: ',
           paste(dss[!dss %in% col & !paste(dss, '1', sep='') %in% col], collapse=', '), '\n')
    }
    dml[, !col %in% dss & !substr(col, 1, nchar(col)-1) %in% dss] <- NULL

    if (direction == "hypo") {
      sort_results <- dml[order(dml$diff, decreasing = F), ]
      sort_results <- sort_results[sort_results$diff < 0, ]
    } else if (direction == "hyper") {
      sort_results <- dml[order(dml$diff, decreasing = T), ]
      sort_results <- sort_results[sort_results$diff > 0, ]
    } else {
      sort_results <- dml[order(dml$diff, decreasing = F), ]
    }
    if (top != "None") {
      if (direction == "both") {
          up <- head(sort_results,top)
          bottom <- tail(sort_results,top)
          sort_results <- rbind(up,bottom)
      } else if (direction == "random") {
        sort_results <- sort_results[sample(nrow(sort_results), top),]
      } else {
        sort_results <- head(sort_results,top)
      }
    }

    # add results to res table
    start <- ncol(res) + 1
    res <- suppressWarnings(merge(res, sort_results, by.x=c('chr', 'start'), by.y=c('chr', 'pos'), all.x=T))

    # determine if rows meet threshold(s)
    if (maxQval < 1) {
      mat[, length(comps)] <- !(is.na(res[, 'diff'])
                                | abs(res[, 'diff']) < minDiff
                                | is.na(res[, 'pval']) | res[, 'pval'] > maxPval
                                | is.na(res[, 'fdr']) | res[, 'fdr'] > maxQval)
    } else {
      mat[, length(comps)] <- !(is.na(res[, 'diff'])
                                | abs(res[, 'diff']) < minDiff
                                | is.na(res[, 'pval']) | res[, 'pval'] > maxPval)
    }
    # add groups to column names
    for (k in start:ncol(res)) {
      col <- colnames(res)[k]
      if (substr(col, nchar(col), nchar(col)) == '1') {
        colnames(res)[k] <- paste(names(samples)[i], substr(col, 1, nchar(col)-1), sep=':')
      } else if (substr(col, nchar(col), nchar(col)) == '2') {
        colnames(res)[k] <- paste(names(samples)[j], substr(col, 1, nchar(col)-1), sep=':')
      } else {
        colnames(res)[k] <- paste(comp, col, sep=':')
      }
    }
  }
}
Sys.sleep(1)



# Filter regions based on CpG sites and mat matrix
cat("\n8) Filter regions based on CpG sites and mat matrix ...\n")
res <- res[res[, 'CpG'] >= minCpG & rowSums(mat) >= tCount, ]

# For repeated columns, average the values
repCols <- c() #columns that have been processed
sampleCols <- c() #names of sample columns that will be averaged
groupCols <- c() #names of group columns (which are not duplicates) and will not be averaged.
for (i in 1:ncol(res)) {
  if (i %in% repCols) { next }

  # find duplicated columns
  repNow <- c(i)
  if (i < ncol(res)) {
    for (j in (i + 1):ncol(res)) {
      if (colnames(res)[i] == colnames(res)[j]) {
        repNow <- c(repNow, j)
      }
    }
  }

  # average duplicates
  if (length(repNow) > 1) {
    if (collapse_method == "mean") {
      res[, i] <- rowMeans(res[, repNow], na.rm = TRUE)  # Take the mean
    } else if (collapse_method == "median") {
      res[, i] <- apply(res[, repNow], 1, median, na.rm = TRUE)  # Take the median
    }
    repCols <- c(repCols, repNow)  # Mark columns as processed
    sampleCols <- c(sampleCols, colnames(res)[i])  # Save the column name for samples
  } else if (!colnames(res)[i] %in% keep) {
    groupCols <- c(groupCols, colnames(res)[i])  # Non-duplicate group column
  }
}
Sys.sleep(1)

# Reorder and sort data frame
cat("\n9) Reorder columns in the data frame ...\n")
res <- res[, c(keep, sampleCols, groupCols)]

# limit results to 7 digits; reverse sign on diffs
options(scipen=999)
for (col in c(sampleCols, groupCols)) {
  spl <- strsplit(col, ':')[[1]]
  if (spl[length(spl)] == 'diff') {
    res[, col] <- -round(res[, col], digits=7)
  } else {
    res[, col] <- round(res[, col], digits=7)
  }
}

# sort chromosome names by number/letter
level <- levels(as.factor(res$chr))
intChr <- strChr <- intLev <- strLev <- c()
for (i in 1:length(level)) {
  if (substr(level[i], 1, 3) == 'chr') {
    sub <- substr(level[i], 4, nchar(level[i]))
    if (!is.na(suppressWarnings(as.integer(sub)))) {
      intChr <- c(intChr, as.numeric(sub))
    } else {
      strChr <- c(strChr, sub)
    }
  } else {
    sub <- level[i]
    if (!is.na(suppressWarnings(as.integer(sub)))) {
      intLev <- c(intLev, as.numeric(sub))
    } else {
      strLev <- c(strLev, sub)
    }
  }
}
# put numeric chroms first, then strings
chrOrder <- c(paste('chr', levels(factor(intChr)), sep=''),
  levels(factor(intLev)),
  paste('chr', levels(factor(strChr)), sep=''),
  levels(factor(strLev)))
Sys.sleep(1)

# Saving results
cat("\n10) Saving results from DMRfinder analysis ...\n")
res <- res[order(match(res$chr, chrOrder), res$start), ] # sort based on chr,start
res <- res[, c("chr", "start", "end", grep(":mu$", colnames(res), value = TRUE))]
colnames(res) <- gsub(":mu$", "", colnames(res))  # Remove ":mu" from column names
res <- res[complete.cases(res),] #remove rows containing NA values

# Print the number of regions reported
cat("\n\n------> Significant DMRs finally retained:", nrow(res), "<------")
outfile <- sub("\\.[^\\.]*$", "", outfile)

# Write TSV output
write.table(res, paste0(outfile,"_",maxPval,"_",maxQval,".tsv"), sep = '\t', quote = F, row.names = F)

# Write CSV output
res$DMR <- paste(res$chr, ":", res$start, "-", res$end, sep="")
res <- res[, c("DMR", setdiff(colnames(res), "DMR"))]
res <- res[, !(colnames(res) %in% c("chr", "start", "end"))]
write.table(res,paste0(outfile,"_",maxPval,"_",maxQval,".csv"), sep = ',', quote = T, row.names = F)
sink()
