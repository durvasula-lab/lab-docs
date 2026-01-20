#!/bin/bash

# Define input and output files
BIN_FILE="all_bin_annots.out"
CONT_FILE="all_binned_contannots.out"
OUTPUT_FILE="<OUTPUT_FILE_NAME>.txt"

# Define continuous valued annotations to exclude
CONT_ANNOTS="GERP.NS|MAF_Adj_Predicted_Allele_Age|MAF_Adj_LLD_AFR|Recomb_Rate_10kb|Nucleotide_Diversity_10kb|Backgrd_Selection_Stat|CpG_Content_50kb|MAF_Adj_ASMC"

# Columns to remove (column names)
REMOVE_COLS="TAU1|TAU1_SE|TAU2|TAU2_SE|THETA|THETA_SE|GCOR|GCOR_SE"

# Get header from bin file
head -n 1 "$BIN_FILE" > temp_header.txt

# Get column numbers to keep (all except the ones to remove)
# First, get all column names
awk -F'\t' 'NR==1 {for(i=1;i<=NF;i++) print i,$i}' "$BIN_FILE" > temp_cols.txt

# Get column numbers to keep (exclude TAU1, TAU1_SE, TAU2, TAU2_SE, THETA, THETA_SE, GCOR, GCOR_SE)
# Use exact match (with tabs) to avoid matching GCORSQ when looking for GCOR
COLS_TO_KEEP=$(awk -F' ' '
    $2 != "TAU1" && $2 != "TAU1_SE" && $2 != "TAU2" && $2 != "TAU2_SE" && 
    $2 != "THETA" && $2 != "THETA_SE" && $2 != "GCOR" && $2 != "GCOR_SE" {
        printf "%s%s", (NR==1?"":","), $1
    }
' temp_cols.txt)

# Process binary annotations file: exclude continuous annots and remove specific columns
awk -F'\t' -v cols="$COLS_TO_KEEP" -v cont="$CONT_ANNOTS" '
BEGIN {
    split(cols, arr, ",")
    for (i in arr) keep[arr[i]] = 1
}
NR==1 {
    for (i=1; i<=NF; i++) {
        if (i in keep) {
            printf "%s%s", (out++>0?"\t":""), $i
        }
    }
    print ""
    next
}
$3 !~ cont {
    out=0
    for (i=1; i<=NF; i++) {
        if (i in keep) {
            printf "%s%s", (out++>0?"\t":""), $i
        }
    }
    print ""
}' "$BIN_FILE" > temp_binned.txt

# Combine binned and continuous files (skip header from continuous file)
(cat temp_binned.txt && tail -n +2 "$CONT_FILE") > "$OUTPUT_FILE"

# Clean up temporary files
rm -f temp_header.txt temp_cols.txt temp_binned.txt

echo "Processing complete. Output written to: $OUTPUT_FILE"
