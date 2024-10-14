#!/usr/bin/env Rscript

#Adding CHR and BP to sumstats files
#using hapmap3+ Prive/LDpred2 snpset
#for use with S-LDXR
#Oct.10, 2024; CCR

#packages
library(readr)
library(dplyr)
library(data.table)

# Get command-line arguments (file path)
args <- commandArgs(trailingOnly = TRUE)

# Check if the user has provided the file path
if (length(args) == 0) {
  stop("No file path provided. Usage: script.R /path/to/file/NAME.sumstats.gz")
}

# Define input file
input_file <- args[1]

# Define the output directory and load additional data -- MODIFY
outdir <- "/path/to/sumstats/"

# Read in hapmap file
info <- readRDS("/project/durvasul_1174/DATA/HapMap3/map_hm3_plus.rds")

# Extract file name without extension
file_name <- tools::file_path_sans_ext(basename(input_file))

# Read the input sumstats file
gz <- fread(input_file, header = TRUE)
#gz <- read_delim(input_file, delim = "\t", col_names = TRUE)

# Subset the data
sub_gz <- gz[which(gz$SNP %in% info$rsid),]

# Match index and add the new columns
index <- match(sub_gz$SNP,info$rsid)
sub_gz$CHR <- info$chr[index]
sub_gz$BP <- info$pos[index]

sumstats_sldxr <- sub_gz[,c('SNP','CHR','BP','A1','A2','Z','N')]

output_file <- paste0(outdir, file_name, "_HM3_sldxr.gz")
write_delim(sumstats_sldxr, output_file, delim = "\t", quote = "none", col_names = TRUE)

# Print message on completion
cat("Output written to: ", output_file, "\n")
