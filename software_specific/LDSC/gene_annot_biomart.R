#APRIL 2025
#CCR
#creating a gene-coord-file for use with SLDSC
#--gene-coord-file, a gene coordinate file, with columns GENE, CHR, START, and END, where START and END are base pair coordinates of TSS and TES. This file can contain more genes than are in the gene set. 


#tutorials & resources:
# https://bioconductor.org/packages/release/bioc/vignettes/biomaRt/inst/doc/accessing_ensembl.html
# https://www.biostars.org/p/365798/#366388
# https://grch37.ensembl.org/info/data/biomart/biomart_r_package.html

#packages
library(biomaRt)
library(readr)
library(dplyr)
library(data.table)

####biomaRt####

ensembl = useEnsembl(biomart="ensembl", dataset="hsapiens_gene_ensembl", GRCh=37)

#for SNPs in build 37, do
grch37_snp = useMart(biomart="ENSEMBL_MART_SNP", host="https://grch37.ensembl.org", dataset="hsapiens_snp")


####loop over all files in dir####
# Define input and output directories
input_dir <- "~/path/to/MSigDB/H/genelists/"
output_dir <- "~/path/to/MSigDB/H/genecoords/"

# Ensure the output directory exists
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# List all files in the input directory that match the pattern "HALLMARK_*.txt"
file_list <- list.files(input_dir, pattern = "^HALLMARK_.*\\.txt$", full.names = TRUE)

# Process each gene list file
for (file_path in file_list) {
  
  # Extract the gene set name (remove directory path and "HALLMARK_" prefix)
  file_name <- basename(file_path)
  gene_set_name <- gsub("^HALLMARK_", "", gsub("\\.txt$", "", file_name))
  
  # Read in gene list
  h1 <- fread(file_path, header = FALSE)
  genes <- as.list(h1)
  
  # Retrieve gene coordinates from BioMart
  h1.bm <- getBM(
    attributes = c('external_gene_name', 'chromosome_name', 'start_position', 'end_position', 
                   'ensembl_gene_id', 'ensembl_gene_id_version'),
    filters = 'external_gene_name',
    values = genes,
    mart = ensembl
  )
  
  # Save raw data as RDS
  saveRDS(h1.bm, paste0(output_dir, "H_", gene_set_name, "_info_b37.RDS"))
  
  # Format output dataframe
  h1.out <- h1.bm[, c("external_gene_name", "chromosome_name", "start_position", "end_position")]
  colnames(h1.out) <- c("GENE", "CHR", "START", "END")
  
  # Filter out non-numeric chromosomes (X, Y, patches)
  h1.out <- h1.out[h1.out$CHR %in% as.character(1:22), ]
  
  # Order by chromosome and start position
  h1.out$CHR <- as.numeric(h1.out$CHR)
  h1.out <- h1.out[order(h1.out$CHR, h1.out$START), ]
  
  # Write full output file
  write_delim(h1.out, paste0(output_dir, "H_", gene_set_name, ".coord.txt"), 
              col_names = TRUE, quote = "none", delim = "\t")
  
  # Subset by chromosome and save individual chromosome files
  for (chr in 1:22) {
    subset_df <- h1.out[h1.out$CHR == chr, ]
    output_file <- paste0(output_dir, "H_", gene_set_name, ".coord.", chr, ".txt")
    write_delim(subset_df, file = output_file, col_names = TRUE, quote = "none", delim = "\t")
  }
  
  print(paste("Processed:", gene_set_name))
}
