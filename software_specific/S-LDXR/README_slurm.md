# README for Slurm script
*CCR Nov.27, 2024*

Required files are detailed here (assuming all summary statistics are already QC-ed)
***

**Create a list of unique pheno pairs from sumstats in /path/to/dir/sumstats_sldxr:**

copy all files into a list
```
ls *.sumstats_HM3_sldxr.gz > files_sldxr.txt
```

create a bash script, `/path/to/dir/trait_pairs.sh`:
```bash
#!/bin/bash

param1=($(cat files_sldxr.txt))  # Read file names into an array
param2=("${param1[@]}")    # Use the same array for param2

# Create the output directory if it doesn't exist
mkdir -p parameters

# Nested loop to iterate through the upper triangle of the matrix
for ((i = 0; i < ${#param1[@]}; i++)); do
    for ((j = i; j < ${#param2[@]}; j++)); do
        # Print only pairs where the indices are different
        if [ "$i" -ne "$j" ]; then
            echo "${param1[i]} ${param2[j]}" >> parameters/params.txt
        fi
    done
done
```

**check line count of the params file to ID Slurm Array Job count.**

Note the number of lines (pairs) in the params file, as we will need to split it up in order for CARC to be able to handle the analyses. About 35 pairs can be run in 48 hrs, so the file needs to be split such that no single params file has more than 35 lines (pairs).

**Split the params.txt file:**
```
split -l 35 params.txt params_
```
This splits by line count (`-l`), and sets the output file prefix as `params_`. You can also split by number of output files using the `-n` flag.

**List each param file in another list:**
```
ls params_* > list_params.txt
```
`wc -l` the params list file to obtain the input for the slurm task array


---
**Combining Outputs**

Navigate to the directory with your S-LDXR results & run `combine_sldxr_out.sh`:
```bash
bash ../../scripts/combine_sldxr_out.sh
```
This will:
- combine the binary annotation results: All files matching `*sumstats_HM3_sldxr.gz_*sumstats_HM3_sldxr.gz` (without _contannot suffix) → `all_bin_annots.out`
- combine binned-continuous annotation results: All files matching `*sumstats_HM3_sldxr.gz_*sumstats_HM3_sldxr.gz_contannot` → `all_binned_contannots.out`
- extract phenotype pairs (P1 and P2) from the filenames and add them as the first two columns
- preserve the header from the first file and append all subsequent results

The output files will be created in your current directory (where you run the script).

***Summary output files***

`all_bin_annots.out` (Binary annotations)

1. P1 - First phenotype name
2. P2 - Second phenotype name  
3. ANNOT - Annotation name
4. NSNP - Number of SNPs
5. STD - Standard deviation
6. TAU1 - Regression coefficient for trait 1
7. TAU1_SE - Standard error
8. TAU2 - Regression coefficient for trait 2
9. TAU2_SE - Standard error
10. THETA - Regression coefficient for genetic covariance
11. THETA_SE - Standard error
12. HSQ1 - Heritability for trait 1
13. HSQ1_SE - Standard error
14. HSQ2 - Heritability for trait 2
15. HSQ2_SE - Standard error
16. GCOV - Genetic covariance
17. GCOV_SE - Standard error
18. GCOR - Genetic correlation
19. GCOR_SE - Standard error
20. GCORSQ - Squared genetic correlation
21. GCORSQ_SE - Standard error
22. HSQ1_ENRICHMENT - Heritability enrichment for trait 1
23. HSQ1_ENRICHMENT_SE - Standard error
24. HSQ2_ENRICHMENT - Heritability enrichment for trait 2
25. HSQ2_ENRICHMENT_SE - Standard error
26. GCOV_ENRICHMENT - Genetic covariance enrichment
27. GCOV_ENRICHMENT_SE - Standard error
28. GCORSQ_ENRICHMENT - Enrichment for squared genetic correlation
29. GCORSQ_ENRICHMENT_SE - Standard error
30. GCORSQ_ENRICHMENT_P - P-value
31. GCOVSQ_DIFF - Difference in squared genetic covariance
32. GCOVSQ_DIFF_SE - Standard error
33. GCOVSQ_DIFF_P - P-value

`all_binned_contannots.out` (Binned continuous annotations)
1. P1 - First phenotype name
2. P2 - Second phenotype name
3. ANNOT - Annotation name (quantile bins)
4. NSNP - Number of SNPs
5. STD - Standard deviation
6. HSQ1 - Heritability for trait 1
7. HSQ1_SE - Standard error
8. HSQ2 - Heritability for trait 2
9. HSQ2_SE - Standard error
10. GCOV - Genetic covariance
11. GCOV_SE - Standard error
12. GCORSQ - Squared genetic correlation
13. GCORSQ_SE - Standard error
14. HSQ1_ENRICHMENT - Heritability enrichment for trait 1
15. HSQ1_ENRICHMENT_SE - Standard error
16. HSQ2_ENRICHMENT - Heritability enrichment for trait 2
17. HSQ2_ENRICHMENT_SE - Standard error
18. GCOV_ENRICHMENT - Genetic covariance enrichment
19. GCOV_ENRICHMENT_SE - Standard error
20. GCORSQ_ENRICHMENT - Enrichment for squared genetic correlation
21. GCORSQ_ENRICHMENT_SE - Standard error
22. GCORSQ_ENRICHMENT_P - P-value
23. GCOVSQ_DIFF - Difference in squared genetic covariance
24. GCOVSQ_DIFF_SE - Standard error
25. GCOVSQ_DIFF_P - P-value

Note: `all_binned_contannots.out` is missing the following columns:
- TAU1, TAU2, THETA, GCOR, GCOR_SE

Key Differences:
1. Binary annotations have TAU/THETA regression coefficients - these are the raw regression coefficients from the S-LDXR model
2. Binary annotations have GCOR (genetic correlation) - continuous annotations only have GCORSQ
3. Continuous annotations omit some columns that binary annotations include
4. Annotation names differ: Binary = e.g., Coding_UCSC, Continuous = converted to quintile bins (e.g., GERP.NS1)
