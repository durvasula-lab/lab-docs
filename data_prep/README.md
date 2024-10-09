### Upload general data preparation scripts/examples here. 

*Make sure to update this README file when adding new files (add new section to "Contents" section below).*
******

# Contents

**sharedSNPs.R**
* Description:
   + R script that extracts a list of SNPs shared between two GWAS summary stats files.
* Use:
   + Modify file with the correct suffixes/extensions(~line 19) & path (~line 29) to your output directory
   + Save the script to a file, and make it executable by running:`chmod +x sharedSNPs.R`
   + Run the script on the server, providing the two input summary stats files as arguments:
  
```./extract_shared_snps.R /path/to/Trait1.sumstats.gz /path/to/Trait2.sumstats.gz```

