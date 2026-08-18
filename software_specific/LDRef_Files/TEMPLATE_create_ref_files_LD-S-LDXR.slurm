#!/bin/bash
#SBATCH --nodes=1
#SBATCH -c 1 # Number of cores
#SBATCH --ntasks=1
#SBATCH --mem=32G
#SBATCH --job-name=ld_sldxr_build
#SBATCH --time=4:00:00
#SBATCH --array=1-22
#SBATCH --error=/path/to/output/logs/rebuild_%A_%a.err
#SBATCH --output=/path/to/output/logs/rebuild_%A_%a.out

################################################################################
# LD Score & S-LDXR Reference File Generation Pipeline
# HapMap3 + MAF>0.05 filtering
# GRCh37
################################################################################

set -e  # Exit on any error
set -u  # Exit on undefined variables
set -o pipefail  # Exit on pipe failures

# Record start time
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
echo "[INFO] Job started at: ${START_TIME}"
echo "[INFO] SLURM Job ID: ${SLURM_JOB_ID}"
echo "[INFO] Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "[INFO] Node: ${HOSTNAME}"

################################################################################
# CONFIG
################################################################################

CHR=${SLURM_ARRAY_TASK_ID}
echo "[INFO] Processing chromosome: ${CHR}"

# Base directories
BASE_DIR="/path/to/output/reference_data"
ANNOT_SOURCE_DIR="/path/to/annotation/files"

# Input paths
ORIG_BFILE="${BASE_DIR}/QC_genotypes/1000G.POPULATION.QC.${CHR}"
ANNOT_FILE="${ANNOT_SOURCE_DIR}/baselineLD_v2.2/baselineLD.${CHR}.annot.gz"
HM3_SNPLIST="/path/to/hapmap3/hm3_no_MHC.list"

# Output directory structure
PLINK_DIR="${BASE_DIR}/plink_files"
SNPLIST_DIR="${BASE_DIR}/snplists"
LD_DIR="${BASE_DIR}/LD_scores"
SLDXR_DIR="${BASE_DIR}/baselineLD_sldxr_v2.2_ldscores"
WEIGHTS_DIR="${BASE_DIR}/weights"
LOG_DIR="${BASE_DIR}/logs"

# Create output directories
mkdir -p "${PLINK_DIR}" "${SNPLIST_DIR}" "${LD_DIR}" "${SLDXR_DIR}" "${WEIGHTS_DIR}" "${LOG_DIR}"

# Software paths
SLDXR_SCRIPT="/path/to/software/s-ldxr/s-ldxr.py"
LDSC_SCRIPT="/path/to/software/ldsc/ldsc.py"

# Conda environments
LDSC_ENV="ldsc_env"
SLDXR_ENV="sldxr_env"

################################################################################
# MODULE & ENVIRONMENT SETUP
################################################################################

echo "[STEP 1] Loading modules"
module purge
module load gcc/13.3.0 plink2/2.00a4.3 conda
echo "[INFO] Modules loaded successfully"

################################################################################
# STEP 2: FILTER TO HAPMAP3 + MAF > 0.05
################################################################################

echo "[STEP 2] Filtering to HapMap3 SNPs with MAF > 0.05"

FILTERED_BFILE="${PLINK_DIR}/1000G.POPULATION.QC.hm3.maf05.${CHR}"
TEMP_HM3="${PLINK_DIR}/temp_hm3_chr${CHR}"

# First filter to HapMap3
echo "[INFO] Filtering to HapMap3 SNPs..."
plink2 \
    --bfile "${ORIG_BFILE}" \
    --extract "${HM3_SNPLIST}" \
    --make-bed \
    --out "${TEMP_HM3}" \
    2>&1 | tee -a "${LOG_DIR}/plink_hm3_chr${CHR}.log"

# Then filter MAF > 0.05
echo "[INFO] Filtering to MAF > 0.05..."
plink2 \
    --bfile "${TEMP_HM3}" \
    --maf 0.05 \
    --make-bed \
    --out "${FILTERED_BFILE}" \
    2>&1 | tee -a "${LOG_DIR}/plink_maf05_chr${CHR}.log"

# Clean up temp files
rm -f "${TEMP_HM3}".*

# Extract SNP list
echo "[INFO] Extracting SNP list..."
awk '{print $2}' "${FILTERED_BFILE}.bim" > "${SNPLIST_DIR}/POPULATION.hm3.maf05.${CHR}.snplist"
SNP_COUNT=$(wc -l < "${SNPLIST_DIR}/POPULATION.hm3.maf05.${CHR}.snplist")
echo "[INFO] Chromosome ${CHR}: ${SNP_COUNT} SNPs after filtering"

# Generate frequency file
echo "[INFO] Generating frequency file..."
plink2 \
    --bfile "${FILTERED_BFILE}" \
    --freq \
    --out "${FILTERED_BFILE}" \
    2>&1 | tee -a "${LOG_DIR}/plink_freq_chr${CHR}.log"

echo "[SUCCESS] Frequency file created: ${FILTERED_BFILE}.afreq"

################################################################################
# STEP 3: COMPUTE STANDARD LD SCORES (for LDSC)
################################################################################

echo "[STEP 3] Computing standard LD scores for LDSC"

conda run -n "${LDSC_ENV}" python "${LDSC_SCRIPT}" \
    --bfile "${FILTERED_BFILE}" \
    --l2 \
    --ld-wind-cm 1.0 \
    --yes-really \
    --print-snps "${SNPLIST_DIR}/POPULATION.hm3.maf05.${CHR}.snplist" \
    --out "${LD_DIR}/POPULATION.${CHR}" \
    2>&1 | tee -a "${LOG_DIR}/ldsc_chr${CHR}.log"

echo "[SUCCESS] Standard LD scores computed: ${LD_DIR}/POPULATION.${CHR}.l2.ldscore.gz"

################################################################################
# STEP 4: COMPUTE S-LDXR BASELINE LD SCORES
################################################################################

echo "[STEP 4] Computing S-LDXR baseline LD scores"

# Check if annotation file exists
if [ ! -f "${ANNOT_FILE}" ]; then
    echo "[ERROR] Annotation file not found: ${ANNOT_FILE}" >&2
    exit 1
fi

# Run S-LDXR with allelic scoring using the filtered bfiles
conda run -n "${SLDXR_ENV}" python "${SLDXR_SCRIPT}" \
    --score allelic \
    --ld-wind-cm 1.0 \
    --print-snps "${SNPLIST_DIR}/POPULATION.hm3.maf05.${CHR}.snplist" \
    --bfile "${FILTERED_BFILE}" "${FILTERED_BFILE}" \
    --annot "${ANNOT_FILE}" \
    --out "${SLDXR_DIR}/baselineLD.${CHR}" \
    2>&1 | tee -a "${LOG_DIR}/sldxr_baseline_chr${CHR}.log"

SLDXR_EXIT=$?
if [ ${SLDXR_EXIT} -ne 0 ]; then
    echo "[ERROR] S-LDXR baseline computation failed for chr${CHR}" >&2
    echo "[DEBUG] Last 20 lines of S-LDXR output:"
    tail -n 20 "${LOG_DIR}/sldxr_baseline_chr${CHR}.log"
    exit 1
fi

echo "[SUCCESS] S-LDXR baseline LD scores computed for chr${CHR}"

################################################################################
# STEP 5: GENERATE S-LDXR WEIGHTS
################################################################################

echo "[STEP 5] Generating S-LDXR weights"

WEIGHTS_PREFIX="${WEIGHTS_DIR}/weights.POPULATION.hm3_noMHC.${CHR}"

# Use the same filtered bfiles for weights (consistent with baseline LD scores)
conda run -n "${SLDXR_ENV}" python "${SLDXR_SCRIPT}" \
    --score allelic \
    --ld-wind-cm 1.0 \
    --print-snps "${HM3_SNPLIST}" \
    --bfile "${FILTERED_BFILE}" "${FILTERED_BFILE}" \
    --annot "${ANNOT_FILE}" \
    --out "${WEIGHTS_PREFIX}" \
    2>&1 | tee -a "${LOG_DIR}/sldxr_weights_chr${CHR}.log"

WEIGHTS_EXIT=$?
if [ ${WEIGHTS_EXIT} -ne 0 ]; then
    echo "[ERROR] S-LDXR weight generation failed for chr${CHR}" >&2
    echo "[DEBUG] Last 20 lines of output:"
    tail -n 20 "${LOG_DIR}/sldxr_weights_chr${CHR}.log"
    exit 1
fi

# Verify weight files were created
if [ -f "${WEIGHTS_PREFIX}_pop1.gz" ] && [ -f "${WEIGHTS_PREFIX}_pop2.gz" ]; then
    echo "[SUCCESS] Generated ${WEIGHTS_PREFIX}_pop1.gz and ${WEIGHTS_PREFIX}_pop2.gz"
    ls -lh "${WEIGHTS_PREFIX}"*
else
    echo "[ERROR] Expected weight files not found" >&2
    ls -lh "${WEIGHTS_PREFIX}"* 2>&1 || echo "No weight files found"
    exit 1
fi

################################################################################
# STEP 6: VERIFY ALL OUTPUTS
################################################################################

echo "[STEP 6] Verifying all outputs for chromosome ${CHR}..."

# Check S-LDXR baseline LD score outputs
if [[ -f "${SLDXR_DIR}/baselineLD.${CHR}_pop1.gz" ]] && \
   [[ -f "${SLDXR_DIR}/baselineLD.${CHR}_pop2.gz" ]] && \
   [[ -f "${SLDXR_DIR}/baselineLD.${CHR}_te.gz" ]]; then
    
    echo "✓ S-LDXR baseline output files present"
    
    # Count SNPs in outputs
    POP1_SNPS=$(zcat "${SLDXR_DIR}/baselineLD.${CHR}_pop1.gz" | tail -n +2 | wc -l)
    POP2_SNPS=$(zcat "${SLDXR_DIR}/baselineLD.${CHR}_pop2.gz" | tail -n +2 | wc -l)
    TE_SNPS=$(zcat "${SLDXR_DIR}/baselineLD.${CHR}_te.gz" | tail -n +2 | wc -l)
    LDSC_SNPS=$(zcat "${LD_DIR}/POPULATION.${CHR}.l2.ldscore.gz" | tail -n +2 | wc -l)
    
    echo "  - Standard LDSC: ${LDSC_SNPS} SNPs"
    echo "  - S-LDXR pop1: ${POP1_SNPS} SNPs"
    echo "  - S-LDXR pop2: ${POP2_SNPS} SNPs"
    echo "  - S-LDXR trans-ethnic: ${TE_SNPS} SNPs"
    
    if [[ ${POP1_SNPS} -eq ${LDSC_SNPS} ]] && \
       [[ ${POP2_SNPS} -eq ${LDSC_SNPS} ]] && \
       [[ ${TE_SNPS} -eq ${LDSC_SNPS} ]]; then
        echo "✓ SNP counts consistent across all baseline outputs"
    else
        echo "⚠ WARNING: SNP count mismatch in baseline outputs!"
    fi
else
    echo "✗ ERROR: Some S-LDXR baseline output files missing"
    exit 1
fi

# Check weight files
if [[ -f "${WEIGHTS_PREFIX}_pop1.gz" ]] && [[ -f "${WEIGHTS_PREFIX}_pop2.gz" ]]; then
    WEIGHT_POP1_SNPS=$(zcat "${WEIGHTS_PREFIX}_pop1.gz" | tail -n +2 | wc -l)
    WEIGHT_POP2_SNPS=$(zcat "${WEIGHTS_PREFIX}_pop2.gz" | tail -n +2 | wc -l)
    echo "✓ S-LDXR weight files present"
    echo "  - Weights pop1: ${WEIGHT_POP1_SNPS} SNPs"
    echo "  - Weights pop2: ${WEIGHT_POP2_SNPS} SNPs"
else
    echo "✗ ERROR: Weight files missing"
    exit 1
fi

################################################################################
# COMPLETION
################################################################################

END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
START_SEC=$(date -d "${START_TIME}" +%s)
END_SEC=$(date -d "${END_TIME}" +%s)
RUNTIME=$((END_SEC - START_SEC))
RUNTIME_MIN=$((RUNTIME / 60))

echo "=========================================="
echo "[SUCCESS] Chromosome ${CHR} processing complete!"
echo "[INFO] Started: ${START_TIME}"
echo "[INFO] Ended: ${END_TIME}"
echo "[INFO] Total runtime: ${RUNTIME} seconds (${RUNTIME_MIN} minutes)"
echo "=========================================="
