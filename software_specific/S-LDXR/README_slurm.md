# README for Slurm script

Required files are detailed here (assuming all summary statistics are already QC-ed)

**Create a list of unique pheno pairs from sumstats in /path/to/dir/sumstats_sldxr:**

copy all files into a list
```
ls *.sumstats_HM3_sldxr.gz > files_sldxr.txt
```

create a bash script, `/path/to/dir/trait_pairs.sh`
```
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

The number of pairs in the example slurm script is 17578 lines, so we will need to split it up in order for CARC to be able to handle it. If one run (one pair) takes ~ 30 min, then a max of 96 (48x2) jobs can be submitted per batch. We'll round down to 90 to account for rounding/slow disk reads. 

**Split the params.txt file:**
```
split -l 90 params.txt params_
```
This splits by line count (-l), and sets the output file prefix as params_. You can also split by number of output files using the -n flag.

**List each param file in another list:**
```
ls params_* > list_params.txt
```
`wc -l` shows that his file is 196 lines long-- this will be the input for the slurm task array
