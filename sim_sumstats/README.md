README
----

This directory contains the scripts and documentation for simulating pairs of traits with user-defined MAF-dependency, genome-wide genetic correlation, and heritabilities, and generating their resulting GWAS summary statistics for use with LDSC and S-LDXR.

### Pipeline overview:
1. `R`: read in SNP info & generate effect sizes to Plink `--score` input file format
2. `Plink`: run `--score`
3. `R`: Read in `.sscore` & generate phenotypes for specified heritability values, output new `.FAM` file with phenotypes
4. `plink`: run `--glm` on new file set
5. `CARC/Conda`: munge resulting summary stats file
6. `LDSC` & `R` checks: h2 & rg of simulated data
7. `R`: add back in `CHR` and `BP` columns to generate `.sumstats.gz` file compatible with `S-LDXR`
----

## 1. R: Create initial effect sizes

`scripts/01_sim_effects_corr2A.R`

Usage:
```
Rscript scripts/01_sim_effects_corr2A.R \
    <maf_file> \
    <bim_file> \
    <maf_min> \
    <p_causal> \
    <alpha1> \
    <alpha2> \
    <g1> \
    <g2> \
    <gen_corr> \
    <sim>
```

Input arguments:
  - `maf_file`: full path to `snp_maf.info` file, which is a 2-column tab-delimited file with a header. Column 1 is SNP rsID and column 2 is the MAF.
  - `bim_file`: full path to `real_data.bim`, which is a standard plink .bim file. This is actual data that will provide a realistic basis for the simulated phenotypes.
  - `maf_min`: the minimum MAF value of "causal" SNPs for your simulated trait.
  - `p_causal`: the percent of input variants that will be "causal"
  - `alpha1` & `alpha2`: input values for trait 1 and trait 2, respectively, to control frequency dependence/selection of causal SNPs. Value must be between 0 and 1.
  - `g1` & `g2`: genetic variances for trait 1 and trait 2, respectively.
  - `gen_corr`: genetic correlation between traits 1 & 2.
  - `sim`: number of simulations to run.

Output:
  - `/01_causal/*.snps`: directory with files that list rsIDs of causal SNPs.
  - `/01_sim_eff/*.txt`: directory with files for use with plink's --score flag. These files retain the full set of variants to avoid having to generate a new plink set (the causal SNPs subset) for every analysis.
  - `/plots/*.png`: directory with scatterplots of MAF x BETA for each simulated pair.

---

## 2. PLINK: Linear scoring
**Documentation:**
* plink2 linear scoring: https://www.cog-genomics.org/plink/2.0/score
* plink2 `.sscore` output format: https://www.cog-genomics.org/plink/2.0/formats#sscore
* plink1.9 scoring:https://www.cog-genomics.org/plink/1.9/score
* PRS in plink tutorial: https://choishingwan.github.io/PRS-Tutorial/plink/

Run plink's linear scoring analysis on each trait in a simulated pair.

Flags and inputs:
* `--bfile`: plink file set
* `--score`: simulated effects files for both traits
* `--out`: output path and prefix

Example call with a `for` loop:
```
module load plink2/2.00a4.3 gcc/13.3.0
for i in {1..4}; do
plink2 \
    --bfile /full/path/to/geno/prefix \
    --score out/01_sim_eff/p0.01_a0.75_gvar0.01.P1.${i}.txt 2 3 5 header \
    --out out/02_sscore/p01_a75_g01.P1${i}
plink2 \
    --bfile /full/path/to/geno/prefix \
    --score out/01_sim_eff/p0.01_a0.75_gvar0.001.P2.${i}.txt 2 3 5 header \
    --out out/02_sscore/p01_a75_g001.P2.${i}
done
```

Outputs:
- `out/02_sscore/*.sscore` file with a header line and one line per sample. `ALLELE_CT` lists the number of alleles across scored variants, `NAMED_ALLELE_DOSAGE_SUM` lists the sum of named allele dosages, and `SCORE1_AVG` lists the score averages. Example:
```
#FID	IID	ALLELE_CT	NAMED_ALLELE_DOSAGE_SUM	SCORE1_AVG
sample1	sample1	1312408	1052146	1.95103e-06
sample2	sample2	1318128	1057949	2.1416e-06
```

---

## 3. R: Generate phenotypes with specified h2
