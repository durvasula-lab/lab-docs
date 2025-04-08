# Creating annotations for use with LDSC partitioned heritability
*CCR April 2025*

***
Resources / info:
* https://github.com/bulik/ldsc/wiki/LD-Score-Estimation-Tutorial#partitioned-ld-scores

*make sure to already have a Conda environment built, QC-ed summary statistics, & reference files* 

***

## Gene set inputs & pre-processing

Here, I'll be using the Hallmark gene set from MSigDB as the example. See https://www.gsea-msigdb.org/gsea/msigdb/human/collections.jsp for more info, or to download the `symbols.gmt` files.

To use the `make_annot.py` script (from the LDSC github) to compute annot files from a gene set, you will need the following inputs:

* `--gene-set-file`, a gene set file with the names of the genes in your gene set, one line per gene name.
After downloading a gene set from MSigDB, for example, the Hallmark gene set, use the script `transpose_gene_list.sh` to convert the .symbols.gmt file into multiple gene sets (1 column, 1 gene per row).
./scripts_n_codes/transpose_gene_list.sh h.all.v2024.1.Hs.symbols.gmt
this will output each gene set into the subdirectory genelists.

* `--gene-coord-file`, a gene coordinate file, with columns GENE, CHR, START, and END, where START and END are base pair coordinates of TSS and TES. This file can contain more genes than are in the gene set. See `gene_annot_biomart.R`-- this will output a coord file, ex: H_ADIPOGENESIS.coord.txt in the directory `genecoords` or `genecoords_GRCh37` 

* `--windowsize`, the window size you would like to use. The annotation will include all SNPs within this many base pairs of the transcribed region.

* `--bimfile`, the plink bim file of the dataset you will use to compute LD scores.
e.g. /redacted/path/DATA/ldsc/reference_files/1000G_EUR_Phase3/plink_files/1000G.EUR.QC.

* `--annot-file`, the name of the annot file to output. If this ends with .gz then the resulting file will be gzip-ed.

## Running make_annot.py

For one gene set: 
```
conda activate int_ldsc
for CHR in {1..22}; do
    python /path/to/software/ldsc/make_annot.py \
--gene-set-file /path/to/DATA/GSEA/h.all/genelists/HALLMARK_COAGULATION.txt \
--gene-coord-file /path/to/DATA/GSEA/h.all/genecoords_GRCh37/H_COAGULATION.coord.${CHR}.txt \
--windowsize 100000 \
--bimfile /path/to/DATA/LDSC_ref/1000G_EUR/plink_files/1000G.EUR.QC.${CHR}.bim \
--annot-file /path/to/DATA/GSEA/h.all/annots_GRCh37_EURO/H_COAGULATION.${CHR}.annot
done
```

For a list of gene sets, first create a list of genelists, without prefix or suffix, eg:
```
COAGULATION
COMPLEMENT
DNA_REPAIR
E2F_TARGETS
```

Then, run in a SLURM script:
```
#!/bin/bash
#SBATCH -c 62 # Number of cores
#SBATCH -N 1 # Ensure that all cores are on one machine
#SBATCH --mem 30G # Memory pool for all cores
#SBATCH --job-name=h.annot
#SBATCH --time=10:00:00 #expected time of completion
#SBATCH --error=/path/to/DATA/GSEA/h.all/h_annot.err
#SBATCH --out=/path/to/DATA/GSEA/h.all/h_annot.out


#variables
LIST=/path/to/DATA/GSEA/h.all/LIST.txt
OUTDIR=/path/to/DATA/GSEA/h.all/annots_GRCh37_EURO/
ERR=h_annot.err

#go to directory with pre-QCed summary stats
cd /path/to/sumstats_sldxr/

module purge
module load conda

# start running
source ~/.bashrc #do not run 'conda init'-- use this to call the source
conda activate int_ldsc #make sure you built this environment within an interactive session or else it will glitch

# Check if Conda environment was activated successfully
if [ $? -eq 0 ]; then
    echo "Conda environment 'LDSC_env' activated successfully." >> ${OUTDIR}${ERR}
else
    echo "Error: Failed to activate Conda environment 'LDSC_env'." >> ${OUTDIR}${ERR}
    exit 1
fi

while read -r line; do
    NAME=${line}
    for CHR in {1..22}; do
        python /path/to/software/ldsc/make_annot.py \
            --gene-set-file /path/to/DATA/GSEA/h.all/genelists/HALLMARK_${NAME}.txt \
            --gene-coord-file /path/to/DATA/GSEA/h.all/genecoords_GRCh37/H_${NAME}.coord.${CHR}.txt \
            --windowsize 100000 \
            --bimfile /path/to/DATA/LDSC_ref/1000G_EUR/plink_files/1000G.EUR.QC.${CHR}.bim \
            --annot-file /path/to/DATA/GSEA/h.all/annots_GRCh37_EURO/H_${NAME}.${CHR}.annot
    done
done < $LIST
```

## Compute LD scores with `.annot` files

*MAKE SURE TO USE THE SAME SNPS THAT ARE IN THE BASELINE FILE YOU ARE USING

Note: you can print them from the baselineLD files you already have & use these snplists as input for the `--print-snps` flag:
```
for CHR in {1..22}; do
zcat /path/to/DATA/ldsc/reference_files/1000G_EUR_Phase3/baselineLD_v2.2/baselineLD.${CHR}.l2.ldscore.gz | awk '{print $2}' > baselineLD.${CHR}.snplist
done
```

Because there are so many categories (~49?) in the Hallmark set, we'll continue to use a list of the annotation names without pre- / suffixes. Here, it's called `HALLMARK.list`.

Then, run ldsc to create the LD scored annot files:

Within an interactive session:
```
while read -r line; do
    NAME=${line}
    for CHR in {1..22}; do
        python /path/to/software/ldsc/ldsc.py \
        --l2 \
        --print-snps /path/to/DATA/LDSC_ref/baseline_annot_snplists/baselineLD.${CHR}.snplist \
        --bfile /path/to/DATA/LDSC_ref/1000G_EUR/plink_files/1000G.EUR.QC.${CHR} \
        --ld-wind-cm 1 \
        --annot /path/to/DATA/GSEA/h.all/annots_GRCh37_EURO/H_${NAME}.${CHR}.annot \
        --thin-annot \
        --out /path/to/DATA/GSEA/h.all/annotsLD_GRCh37_EURO/H_${NAME}.${CHR}
    done
done < HALLMARK.list
```

or, run via a SLURM script (e.g.: `annot_LD_array.slurm`). Relevent excerpt:
```
for CHR in {1..22}; do
  python /home1/cataldor/software/ldsc/ldsc.py \
    --l2 \
    --print-snps /path/to/DATA/LDSC_ref/baseline_annot_snplists/baselineLD.${CHR}.snplist \
    --bfile /path/to/DATA/LDSC_ref/1000G_EUR/plink_files/1000G.EUR.QC.${CHR} \
    --ld-wind-cm 1 \
    --annot /path/to/DATA/GSEA/h.all/annots_GRCh37_EURO/H_${NAME}.${CHR}.annot \
    --thin-annot \
    --out ${OUTDIR}H_${NAME}.${CHR}
done
```

Copy or move the `.annot` files to the same directory in which you output the LD annot files. You MUST have  `${prefix}.${chr}.annot.gz`, `${prefix}.${chr}.l2.ldscore`, and `${prefix}.${chr}.l2.M_5_50` in the same directory or LDSC will return an array indexing error.

