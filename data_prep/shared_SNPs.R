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

# Extract file names before ".sumstats.sldxr.gz" -- MODIFY suffix/extension!
trait1 <- gsub("\\.sumstats\\.sldxr\\.gz", "", basename(args[1]))
trait2 <- gsub("\\.sumstats\\.sldxr\\.gz", "", basename(args[2]))

# Find shared SNPs (this assumes the header is present and the column name is 'SNP'
s1 <- c(sumstats1$SNP)
s2 <- c(sumstats2$SNP)
shared <- data.frame(dplyr::intersect(s1, s2))
colnames(shared) <- 'rsID'

# Create output file name-- MODIFY PATH!
output_file <- paste0("/path/to/file/", trait1, "_", trait2, ".snplist")

# Write shared SNPs to the output file
write_delim(shared, output_file, delim = "\t", quote = "none", col_names = FALSE)

cat("Shared SNP list written to", output_file, "\n")

# Subset sumstats1 and sumstats2 by the shared SNPs
sub_1 <- sumstats1[which(sumstats1$SNP %in% shared$rsID),]
sub_2 <- sumstats2[which(sumstats2$SNP %in% shared$rsID),]

# Create dynamic output file names-- MODIFY PATH!
output_file_sub1 <- paste0("/path/to/file/", trait1, "_sub", trait2, ".sumstats.sldxr.gz")
output_file_sub2 <- paste0("/path/to/file/", trait2, "_sub", trait1, ".sumstats.sldxr.gz")

# Write the subsets to the new files
write_delim(sub_1, output_file_sub1, delim = "\t", quote = "none", col_names = TRUE)
write_delim(sub_2, output_file_sub2, delim = "\t", quote = "none", col_names = TRUE)

cat("Subset data written to", output_file_sub1, "and", output_file_sub2, "\n")
