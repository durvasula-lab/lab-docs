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
Rscript scripts/01_sim_effects_corr.R \
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

Arguments:
  - `maf_file`: full path to `snp_maf.info` file, which is a 2-column tab-delimited file with a header. Column 1 is SNP rsID and column 2 is the MAF.
  - `bim_file`: full path to `real_data.bim`, which is a standard plink .bim file. This is actual data that will provide a realistic basis for the simulated phenotypes.
  - `maf_min`: the minimum MAF value of "causal" SNPs for your simulated trait.
  - `p_causal`: the percent of input variants that will be "causal"
  - `alpha1` & `alpha2`: input values for trait 1 and trait 2, respectively, to control frequency dependence/selection of causal SNPs. Value must be between 0 and 1.
  - `g1` & `g2`: genetic variances for trait 1 and trait 2, respectively.
  - `gen_corr`: genetic correlation between traits 1 & 2.
  - `sim`: number of simulations to run.
