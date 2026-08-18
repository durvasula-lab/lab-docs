# LD Score & S-LDXR Reference File Generation Pipeline

## Overview

This pipeline generates population-specific reference files for LD Score Regression (LDSC) and Stratified LD Score Regression for cross-population analyses (S-LDXR). The script processes 1000 Genomes Phase 3 genotype data to create LD scores, S-LDXR baseline LD scores, and regression weights for a given meta-population (e.g., East Asian, European, etc.). These scripts are specific to within-population analyses of stratified heritability and stratified genetic correlations (i.e., cross-trait analyses as opposed to cross-pop analyses).

## Purpose

LD Score Regression is used to estimate:
- SNP-based heritability (h²)
- Genetic correlations between traits
- Partitioned heritability across genomic annotations
- Cross-trait or trans-ethnic genetic correlation (via S-LDXR)

This pipeline creates the **reference files** required for these analyses.

## Requirements

### Software Dependencies
- Latest builds of LDSC & S-LDXR
- See conda environment `.yml` files in `LDSC` and `S-LDXR` directories

### Input Files Required
1. **Quality-controlled genotype files** (PLINK binary format: `.bed`, `.bim`, `.fam`)
   - One fileset per chromosome (chr1-22)
   - Format: `1000G.POPULATION.QC.{CHR}.{bed,bim,fam}`
   - Relatives (2nd degree or closer) removed; MAF > 0.05 or > 0.01

2. **HapMap3 SNP list** (excluding MHC region)
   - Single-column text file of rsIDs
   - Used to restrict analysis to well-imputed common variants
   - Example: `hm3_no_MHC.list`

3. **Baseline annotation files** (baselineLD v2.2)
   - One file per chromosome
   - Format: `baselineLD.{CHR}.annot.gz`
   - Contains evolutionary and functional genomic annotations


## Pipeline Steps

### Step 1: Module & Environment Setup
Loads (does not build) required system modules and sets up conda environments for LDSC and S-LDXR. 

### Step 2: SNP Filtering
**Purpose**: Create a high-quality SNP set for LD score estimation.

**Process**:
1. **HapMap3 filtering**: Restricts SNPs to the HapMap3 panel
   - ~1.2 million well-imputed common variants
   - Excludes MHC region (chr6:25-35 Mb) to avoid confounding
2. **MAF filtering**: Removes SNPs with MAF ≤ 0.05
   - Focuses on common variants
   - Reduces noise from low-frequency variants
3. **SNP list extraction**: Creates chromosome-specific SNP lists for downstream steps
4. **Frequency file generation**: Computes allele frequencies for filtered SNPs

**Outputs**:
- Filtered PLINK files: `1000G.POPULATION.QC.hm3.maf05.{CHR}.{bed,bim,fam}`
- SNP lists: `POPULATION.hm3.maf05.{CHR}.snplist`
- Frequency files: `1000G.POPULATION.QC.hm3.maf05.{CHR}.afreq`
    - NOTE: Frequency files may need to be updated prior to S-LDXR run due to header differences between plink 1.9 and plink 2. See `fix_frq_headers.sh`

### Step 3: Standard LD Score Computation
**Purpose**: Calculate LD scores for standard LDSC analyses (heritability, genetic correlation).

**Method**:
- Computes ℓ² LD scores: sum of squared correlations (r²) with all nearby SNPs
- LD window: 1 cM (centimorgans)
- Uses `--yes-really` flag to compute whole-chromosome LD scores
- Restricts to HapMap3 + MAF>0.05 SNPs

**Outputs**:
- LD score files: `POPULATION.{CHR}.l2.ldscore.gz`
- M files (SNP counts): `POPULATION.{CHR}.l2.M`
- M_5_50 files (SNP counts in MAF bins): `POPULATION.{CHR}.l2.M_5_50`

### Step 4: S-LDXR Baseline LD Score Computation
**Purpose**: Calculate population-specific LD scores for stratified **cross-trait** genetic correlation.

**Method**:
- Original method uses allelic scoring to account for allele frequency differences between populations, so even though we are using S-LDXR to assess stratified cross-trait genetic correlations, we still need to generate these files to maintain functionality
- Incorporates baselineLD v2.2 annotations (97 categories prior to binning)
- Creates three output types:
  - `_pop1.gz`: Population 1 LD scores
  - `_pop2.gz`: Population 2 LD scores  
  - `_te.gz`: "Trans-ethnic" (in our cases, same pop) LD scores

**Key Parameter**:
- `--bfile "${FILTERED_BFILE}" "${FILTERED_BFILE}"`: Uses same population twice for within-population analysis

**Outputs**:
- Baseline LD scores: `baselineLD.{CHR}_{pop1,pop2,te}.gz`

### Step 5: S-LDXR Regression Weight Generation
**Purpose**: Create regression weights for S-LDXR analyses.

**Process**:
- Similar to Step 4 but uses the full HapMap3 SNP list (without additional MAF filtering)
- Weights are used to down-weight SNPs in high-LD regions during regression

**Outputs**:
- Weight files: `weights.POPULATION.hm3_noMHC.{CHR}_{pop1,pop2}.gz`

### Step 6: Output Verification
**Purpose**: Validate that all expected files were created with consistent SNP counts.

**Checks**:
1. Presence of all S-LDXR baseline files (`_pop1`, `_pop2`, `_te`)
2. Presence of weight files
3. SNP count consistency across:
   - Standard LDSC LD scores
   - S-LDXR population-specific LD scores
   - "Trans-ethnic" LD scores
4. Weight file SNP counts

## Directory Structure

```
/path/to/output/reference_data/
├── QC_genotypes/               # Input: Quality-controlled 1000G data
│   └── 1000G.POPULATION.QC.{1..22}.{bed,bim,fam}
├── plink_files/                # Step 2: Filtered genotypes
│   └── 1000G.POPULATION.QC.hm3.maf05.{1..22}.{bed,bim,fam,afreq}
├── snplists/                   # Step 2: SNP lists
│   └── POPULATION.hm3.maf05.{1..22}.snplist
├── LD_scores/                  # Step 3: Standard LD scores
│   └── POPULATION.{1..22}.l2.{ldscore.gz,M,M_5_50}
├── baselineLD_sldxr_v2.2_ldscores/  # Step 4: S-LDXR baseline
│   └── baselineLD.{1..22}_{pop1,pop2,te}.gz
├── weights/                    # Step 5: Regression weights
│   └── weights.POPULATION.hm3_noMHC.{1..22}_{pop1,pop2}.gz
└── logs/                       # All steps: Log files
    ├── plink_hm3_chr{1..22}.log
    ├── plink_maf05_chr{1..22}.log
    ├── ldsc_chr{1..22}.log
    ├── sldxr_baseline_chr{1..22}.log
    └── sldxr_weights_chr{1..22}.log
```

## Usage

### Basic Execution
```bash
sbatch make_all_ld_sldxr_files-TEMPLATE.slurm
```

### Configuration
Before running, modify the following variables in the script:

```bash
# Base directories
BASE_DIR="/path/to/output/reference_data"
ANNOT_SOURCE_DIR="/path/to/annotation/files"

# Input paths
ORIG_BFILE="${BASE_DIR}/QC_genotypes/1000G.POPULATION.QC.${CHR}"
ANNOT_FILE="${ANNOT_SOURCE_DIR}/baselineLD_v2.2/baselineLD.${CHR}.annot.gz"
HM3_SNPLIST="/path/to/hapmap3/hm3_no_MHC.list"

# Software paths
SLDXR_SCRIPT="/path/to/software/s-ldxr/s-ldxr.py"
LDSC_SCRIPT="/path/to/software/ldsc/ldsc.py"

# Conda environments
LDSC_ENV="ldsc_env"
SLDXR_ENV="sldxr_env"
```

### SLURM Array Job
The pipeline uses SLURM array jobs to process all 22 autosomes in parallel:
```bash
#SBATCH --array=1-22
```

To process specific chromosomes only:
```bash
#SBATCH --array=1,5,10,22  # Specific chromosomes
#SBATCH --array=1-5        # Range
```

### Resource Allocation
Adjust based on your cluster's capabilities:
```bash
#SBATCH --mem=32G          # Increase if needed
#SBATCH --time=4:00:00     # Adjust based on benchmark runs
#SBATCH -c 1               # 1 core per chromosome (parallelized)
```

## Output Files

### File Formats

#### LD Score Files (`.l2.ldscore.gz`)
Tab-delimited, gzipped text file with columns:
- `CHR`: Chromosome
- `SNP`: rsID
- `BP`: Base pair position
- `L2`: LD Score (sum of r² with nearby SNPs)

#### S-LDXR Files (`_pop1.gz`, `_pop2.gz`, `_te.gz`)
Similar format to standard LD scores, but:
- Population-specific LD patterns
- Allelic scoring applied
- Multiple annotation categories (97 columns for baselineLD v2.2)

#### Weight Files
Used to down-weight high-LD regions during regression:
- Format similar to LD score files
- `_pop1.gz`: Population 1 weights
- `_pop2.gz`: Population 2 weights

## Troubleshooting

### Common Errors

**Error**: `ValueError: Do you really want to compute whole-chromosome LD Score?`
- **Cause**: LDSC safety check for large computations
- **Solution**: Add `--yes-really` flag (already included in template)

**Error**: `IndexError: index out of bounds`
- **Cause**: SNP mismatch between genotypes and annotations
- **Solution**: Ensure `.bim` files and `.annot.gz` files have matching SNPs in same order

**Error**: `FileNotFoundError: annotation file not found`
- **Cause**: Incorrect path to baselineLD annotations
- **Solution**: Verify `ANNOT_FILE` path and check files exist for all chromosomes

**Error**: Weight files not created
- **Cause**: S-LDXR computation failed silently
- **Solution**: Check log files in `${LOG_DIR}/sldxr_weights_chr${CHR}.log`


## References

1. **LD Score Regression (LDSC)**:
   - Bulik-Sullivan et al. (2015). *Nature Genetics*. [doi:10.1038/ng.3211](https://doi.org/10.1038/ng.3211)
   - GitHub: [https://github.com/bulik/ldsc](https://github.com/bulik/ldsc)

2. **S-LDXR (Stratified LD Score for Cross-population)**:
   - Shi et al. (2021). *Nature Communications*. [doi:10.1038/s41467-021-21286-1](https://doi.org/10.1038/s41467-021-21286-1)
   - GitHub: [https://github.com/huwenboshi/s-ldxr](https://github.com/huwenboshi/s-ldxr)

3. **Baseline Annotations (v2.2)**:
   - Gazal et al. (2017). *Nature Genetics*. [doi:10.1038/ng.3954](https://doi.org/10.1038/ng.3954)
   - Download: https://zenodo.org/records/10515792

4. **1000 Genomes Phase 3**:
   - 1000 Genomes Project Consortium (2015). *Nature*. [doi:10.1038/nature15393](https://doi.org/10.1038/nature15393)
   - Download genotype data: https://zenodo.org/records/6614170
