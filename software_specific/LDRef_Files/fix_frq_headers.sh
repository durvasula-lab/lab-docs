#!/bin/bash

# Script to replace PLINK2 .afreq header with LDSC-compatible .frq header
# Usage: bash fix_frq_headers.sh

# Base directory (modify as needed)
BASE_DIR="/path/to/data/LDSC_ref/1000G_POP/plink_files"

# Loop through all 22 chromosomes
for CHR in {1..22}; do
    AFREQ_FILE="${BASE_DIR}/1000G.POP.QC.hm3.maf05.${CHR}.afreq"
    FRQ_FILE="${BASE_DIR}/1000G.POP.QC.hm3.maf05.${CHR}.frq"
    
    if [ ! -f "${AFREQ_FILE}" ]; then
        echo "Warning: ${AFREQ_FILE} not found, skipping chromosome ${CHR}"
        continue
    fi
    
    echo "Processing chromosome ${CHR}..."
    
    # Create new header and append data (skipping old header)
    echo -e "CHR\tSNP\tA1\tA2\tMAF\tNCHROBS" > "${FRQ_FILE}"
    tail -n +2 "${AFREQ_FILE}" >> "${FRQ_FILE}"
    
    echo "Created ${FRQ_FILE}"
done

echo "Done! All .frq files created with new headers."
