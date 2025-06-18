#!/usr/bin/env Rscript

# Edoardo Giuili (edoardo.giuili@ugent.be)
# 06 / 2024

# Finding differentially methylated regions from a table
#   of counts produced by bisulfite sequencing data.
# Underlying statistics are performed using the R package 'limma'
#   (https://bioconductor.org/packages/release/bioc/vignettes/limma/inst/doc/intro.html).
suppressPackageStartupMessages(library(limma))
suppressPackageStartupMessages(library(tibble))
suppressPackageStartupMessages(library(dplyr))
version <- "0.1"
copyright <- "Copyright (C) 2024 Edoardo Giuili (edoardo.giuili@ugent.be)"



# Create print version header
printVersion <- function() {
  cat("test_DMR.r, version", version, "\n")
  cat(copyright, "\n")
  q()
}


# Create the usage for help
usage <- function() {
  cat('Usage: Rscript test_DMR.r  [options]  -i <input>

    -i <input>            File listing genomic regions and methylation counts

  Options:
    -p <pvalue>           Adjusted p-value threshold (def. 0.001)
    -j <adj_method>       Multiple testing correction method (def. "BH")
                          among the ones available in limma R package
    -c <collapse_method>  How collapsing the samples values for each region
                          (median or mean, def. mean)
    -d <direction>        Direction of methylation: can be either "hypo","hyper",
                          "both" or "random" (def. "None", takes all the regions)
    -t <top>              Take the top x number (integer) of DMRs per cell state
                          (def. "None"): it can be used only if direction flag
                          is specified


  ')
  q()
}


# default args/parameters
pvalue <- 0.001
adj_method <- "BH"
collapse_method <- "mean"
top <- "None" # takes all the DMRs
direction <- "None"


# get CL args
args <- commandArgs(trailingOnly = TRUE)
i <- 1
parameters <- c()
while (i <= length(args)) {
  if (substr(args[i], 1, 1) == "-") {
    if (args[i] == "-h" || args[i] == "--help") {
      usage()
    } else if (args[i] == "--version") {
      printVersion()
    } else if (i < length(args)) {
      if (args[i] == "-i") {
        infile <- args[i + 1]
      } else if (args[i] == "-p") {
        pvalue <- args[i + 1]
        pvalue <- as.numeric(pvalue)
      } else if (args[i] == "-j") {
        adj_method <- args[i + 1]
      } else if (args[i] == "-c") {
        collapse_method <- args[i + 1]
      } else if (args[i] == "-d") {
        direction <- args[i + 1]
        parameters <- c(parameters, direction)
      } else if (args[i] == "-t") {
        top <- args[i + 1]
        parameters <- c(parameters, top)
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
parameters <- c(parameters, pvalue, adj_method, collapse_method)


# check for parameter errors
if (is.null(infile)) {
  cat("Error! Must specify the input file\n")
  usage()
}
if (collapse_method != "mean" & collapse_method != "median") {
  cat("Error! Must specify mean or median as collapse method\n")
  usage()
}
if (top != "None" & direction == "None") {
  cat("Error! Must specify direction parameter before specifying the top parameter\n")
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


# Open a connection to a file to redirect print outputs
sink("dmr_analysis.out")


# Read the input file
cat("\n1) Reading the region file...\n")
df <- read.csv(infile, row.names = 1)
rownames(df) <- paste0(df$chr, ":", df$start, "-", df$end)
beta_matrix <- as.matrix(df[, 4:(dim(df)[2])])
rownames(beta_matrix) <- paste0(df$chr, ":", df$start, "-", df$end)
print(head(beta_matrix))
Sys.sleep(1)


# Define groups
cat("\n2) Defining groups for comparison...\n")
Sys.sleep(1)
columns <- colnames(beta_matrix)
groups <- sub("_\\d+.V", "", columns)
groups <- factor(groups)
group_levels <- levels(groups)
cat("\nGroup levels created: \n")
print(group_levels)
Sys.sleep(1)


# Create design matrix
design <- model.matrix(~ 0 + groups)
colnames(design) <- group_levels


# Fit the linear model
cat("\n3) Fitting the linear model...\n")
fit <- lmFit(beta_matrix, design)
Sys.sleep(1)


# Create contrasts for comparisons
contrast_pairs <- c()
if (length(group_levels) == 2) {
  contrast_formula <- paste0(group_levels[1], "-", group_levels[2])
  contrast_pairs[[group_levels[1]]] <- contrast_formula
} else {
  for (group in group_levels) {
    other_groups <- setdiff(group_levels, group)
    contrast_formula <- paste0(group, "-(", paste(other_groups, collapse = " + "), ")/", length(other_groups))
    contrast_pairs[[group]] <- contrast_formula
  }
}
contrast_pairs <- unlist(contrast_pairs)
contrast_matrix <- makeContrasts(
  contrasts = contrast_pairs,
  levels = design
)


# Apply empirical Bayes moderation
cat("\n4) Apply empirical Bayes moderation using the following contrasts: \n")
print(contrast_matrix)
fit <- contrasts.fit(fit, contrast_matrix)
fit <- eBayes(fit)
Sys.sleep(1)


# Extract results for each contrast
cat("\n5) Extracting the results for each contrast...\n")
cat("\n   - Multiple testing correction method:", adj_method)
cat("\n   - Adjusted p-value threshold:", pvalue)
cat("\n   - Collapsing method:", collapse_method)
cat("\n   - Direction used:", direction)
cat("\n   - Top DMRs retained:", top)

get_top_genes <- function(topTableResults, n_top = top, direction = direction) {

  # Validate 'direction' input
  valid_directions <- c("both", "hypo", "hyper", "random")
  if (!(direction %in% valid_directions)) {
    stop(paste("Invalid direction. Choose from:", paste(valid_directions, collapse = ", ")))
  }

  # Count hyper/hypo DMRs
  num_over <- sum(topTableResults$logFC > 0)
  num_under <- sum(topTableResults$logFC < 0)
  total_genes <- nrow(topTableResults)

  # Error handling for zero DMRs in the specified direction
  if (direction %in% c("hyper") && num_over == 0) {
    stop("No hyper- DMRs detected in the dataset.")
  }
  if (direction %in% c("hypo") && num_under == 0) {
    stop("No hypo- DMRs detected in the dataset.")
  }
  if ((direction == "random" || direction == "both") && total_genes == 0) {
    stop("The dataset is empty. No DMRs available for selection.")
  }

  # If n_top is NULL, select all available DMRs
  if (n_top == "None") {
    n_over <- num_over
    n_under <- num_under
    n_random <- total_genes
  } else {
    # Adjust counts with warnings if n_top exceeds available DMRs
    n_over <- if (direction %in% c("both", "hyper")) min(n_top, num_over) else 0
    n_under <- if (direction %in% c("both", "hypo")) min(n_top, num_under) else 0
    n_random <- min(n_top, total_genes)

    if (direction %in% c("both", "hyper") && n_top > num_over) {
      warning(paste("Requested", n_top, "hyper DMRs, but only", num_over, "are available. Returning all available hyper DMRs."))
    }
    if (direction %in% c("both", "hypo") && n_top > num_under) {
      warning(paste("Requested", n_top, "hypo DMRs, but only", num_under, "are available. Returning all available hypo DMRs."))
    }
    if (direction == "random" && n_top > total_genes) {
      warning(paste("Requested", n_top, "random DMRs, but only", total_genes, "are available. Returning all available DMRs."))
    }
  }

  # Select DMRs based on direction
  if (direction == "hyper" || direction == "both") {
    top_overexpressed <- topTableResults[topTableResults$logFC > 0, ]
    top_overexpressed <- top_overexpressed[order(-top_overexpressed$logFC), ][seq_len(n_over), ]
  } else {
    top_overexpressed <- data.frame()
  }

  if (direction == "hypo" || direction == "both") {
    top_underexpressed <- topTableResults[topTableResults$logFC < 0, ]
    top_underexpressed <- top_underexpressed[order(top_underexpressed$logFC), ][seq_len(n_under), ]
  } else {
    top_underexpressed <- data.frame()
  }

  # Handle random selection
  if (direction == "random") {
    top_genes <- topTableResults[sample(1:total_genes, n_random), ]
  } else {
    # Combine hyper-/hypo- DMRs
    top_genes <- rbind(top_overexpressed, top_underexpressed)
  }

  return(top_genes)
}

results_df <- data.frame()
for (contrast_name in colnames(contrast_matrix)) {
  contrast_results <- topTable(fit, coef = contrast_name, adjust.method = adj_method, number = Inf, p.value = pvalue)
  if (direction != "None") {
    contrast_results <- get_top_genes(contrast_results,top,direction)
  }
  contrast_results <- rownames_to_column(contrast_results, "DMR")
  contrast_label <- paste0(unlist(strsplit(contrast_name, "-"))[1], "-all")
  colnames(contrast_results)[2] <- "MethylDiff"
  contrast_results$Contrast <- contrast_label
  results_df <- rbind(results_df, contrast_results)
}
Sys.sleep(1)

# Add the mean/median columns per cell state per row if more than one sample per group has been specified
for (group in group_levels) {
  group_cols <- grep(group, colnames(beta_matrix), value = TRUE)
  if (length(group_cols) == 1) {
    results_df[[group]] <-beta_matrix[results_df$DMR, group_cols]
  } else {
    if (collapse_method == "mean") {
      results_df[[group]] <- apply(beta_matrix[results_df$DMR, group_cols], 1, mean, na.rm = TRUE)
    } else {
      results_df[[group]] <- apply(beta_matrix[results_df$DMR, group_cols], 1, median, na.rm = TRUE)
    }
  }
}
print(results_df)
# Generate the reference matrix according to the parameters specified above
reference_matrix <- data.frame()
for (contrast in unique(results_df$Contrast)) {
  group_results <- results_df[results_df$Contrast == contrast,c("DMR", group_levels)]
  reference_matrix <- rbind(
      reference_matrix,
      group_results
  )
}

# Remove duplicate rows based on the 'id' column, retaining only one instance of each duplicate
fin_ref <- reference_matrix %>% distinct(DMR, .keep_all = TRUE)
cat("\n\n------> Significant DMRs finally retained:", nrow(fin_ref), "<------")

# Save the results
cat("\n\n6) Saving results from DMR analysis...")
write.csv(fin_ref, paste0("reference_matrix_limma.csv"), row.names = F)

# Create a tsv matrix
split_chr_position = strsplit(fin_ref$DMR, ":")
chr <- sapply(split_chr_position, `[`, 1)
position <- sapply(split_chr_position, `[`, 2)
split_start_end <- strsplit(position, "-")
start <- sapply(split_start_end, `[`, 1)
end <- sapply(split_start_end, `[`, 2)
fin_ref <- cbind(chr, start, end, fin_ref)
fin_ref$DMR <- NULL

write.table(fin_ref, paste0("reference_matrix_limma.tsv"), row.names = F, sep = "\t", quote = F)
sink()
