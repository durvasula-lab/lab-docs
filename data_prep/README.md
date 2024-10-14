### Upload general data preparation scripts/examples here. 

*Make sure to update this README file when adding new files (add new section to "Contents" below).*
******

# Contents

**shared_SNPs.R**
* Description:
   + R script that extracts a list of SNPs shared between two GWAS summary stats files.
   + Requires `readr` and `dplyr` packages
* Input: two summary stats files (here, in '.gz' format)
* Output:
   + `file.snplist`: single column list with one rsID per row
   + `Trait1_subTrait2.sumstats.gz`: summary stat 1 file reduced to SNP intersection with summary stat 2
   + `Trait2_subTrait1.sumstats.gz`: summary stat 2 file reduced to SNP intersection with summary stat 1
* Use:
   + Modify file with the correct suffixes/extensions(~lines 19,42,43) & path to your output directory (~lines 29,46,47)
   + Save the script to a file, and make it executable by running:`chmod +x shared_SNPs.R`
   + Module load R: `module load gcc/11.3.0  openblas/0.3.20 r/4.4.1`
   + Run the script on the server, providing the two input summary stats files as arguments:`./shared_SNPs.R /path/to/Trait1.sumstats.gz /path/to/Trait2.sumstats.gz`


**sumstats_add_CHR_BP.R**
* Description:
   + R script that adds CHR & BP columns to summary stats .gz files
   + Uses Prive et al/LDpred2 HapMap3+ SNP set and map file (`/DATA/HapMap3/map_hm3_plus.rds`)
   + Requires `readr`,`dplyr`, and `data.table` packages
* Input:
   + `filelist.txt`: single column list with one sumstats.gz file per row
* Output:
   + `sumstat_HM3_sldxr.gz`: new sumstats file(s) with header `SNP  CHR  BP  A1  A2  Z  N`
* Use:
   + Save the script to a file, and make it executable by running:`chmod +x sumstats_add_CHR_BP.R`
   + Modify file with correct paths and suffixes/extensions (see variable `outdir`)
   + Module load R: `module load gcc/11.3.0  openblas/0.3.20 r/4.4.1`
   + Run the script on the server, providing the filelist as an argument (make sure to include paths):
```
cat /path/to/filelist.txt | while read line; do
    ./sumstats_add_CHR_BP.R /path/to/sumstats/$line ;
done
```
