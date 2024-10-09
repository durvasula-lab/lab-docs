#!/usr/bin/env Rscript

# Load required libraries
library(readr)
library(dplyr)

# Get command-line arguments
args <- commandArgs(trailingOnly = TRUE)

# Check if two arguments (input files) are provided
if (length(args) != 2) {
  stop("Please provide exactly two input files.")
}

# Read input files
sumstats1 <- read_delim(args[1], delim = "\t", col_names = TRUE)
sumstats2 <- read_delim(args[2], delim = "\t", col_names = TRUE)

# Extract file names before ".sumstats.sldxr.gz"
trait1 <- gsub("\\.sumstats\\.sldxr\\.gz", "", basename(args[1]))
trait2 <- gsub("\\.sumstats\\.sldxr\\.gz", "", basename(args[2]))

# Find shared SNPs
s1 <- c(sumstats1$SNP)
s2 <- c(sumstats2$SNP)
shared <- data.frame(dplyr::intersect(s1, s2))

# Create output file name-- MODIFY PATH!
output_file <- paste0("/path/to/file/sumstats_sldxr/snpLists/", trait1, "_", trait2, ".snplist")

# Write shared SNPs to the output file
write_delim(shared, output_file, delim = "\t", quote = "none", col_names = FALSE)

cat("Shared SNP list written to", output_file, "\n")
