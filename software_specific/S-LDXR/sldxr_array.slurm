#!/bin/bash
#SBATCH -c 1 # Number of cores
#SBATCH --mem 60G # Memory pool for all cores
#SBATCH --job-name=sldxr1
#SBATCH --time=48:00:00 #expected time of completion
#SBATCH --array=1-196
#SBATCH --error=/path/to/dir/logs/sldxr1.err
#SBATCH --out=/path/to/dir/logs/sldxr1.out


#go to directory & activate Conda
cd /path/to/dir/sumstats_sldxr/

module purge
module load conda

source ~/.bashrc 
conda activate int_sldxr 

# Check if Conda environment was activated successfully
if [ $? -eq 0 ]; then
    echo "Conda environment 'int_sldxr' activated successfully." >> /path/to/dir/logs/sldxr1.err
else
    echo "Error: Failed to activate Conda environment 'int_sldxr'." >> /path/to/dir/sldxr1.err
    exit 1
fi

# variables:
PDIR=/path/to/dir/sumstats_sldxr/parameters/
PARAMS_LIST=/path/to/dir/parameters/list_params.txt
I_LINE=$SLURM_ARRAY_TASK_ID
FILE=$(head -n $I_LINE $PARAMS_LIST | tail -n 1)
PARAM_FILE=${PDIR}${FILE}
NUM=$(wc -l < $PARAM_FILE)


#check that param file was extracted correctly
if [[ -z "$PARAM_FILE" || ! -f "$PARAM_FILE" ]]; then
    echo "Error: PARAM_FILE is empty or does not exist for SLURM_ARRAY_TASK_ID=$I_LINE" >> /path/to/dir/logs/sldxr1.err
    exit 1
fi

#debug log
echo "PARAM_FILE=$PARAM_FILE" >> /path/to/dir/logs/sldxr1.err
echo "PARAM_FILE=$PARAM_FILE" >> /path/to/dir/logs/sldxr1.out

for i in $(seq 1 $NUM); do
    params=$(head -n $i  $PARAM_FILE | tail -n 1)
    #check that params is not empty
    if [[ -z "$params" ]]; then
        echo "Error: params is empty for i=$i in file $PARAM_FILE" >> /path/to/dir/sldxr1.err
        exit 1
    fi
    p1=`echo $params | cut -f 1 -d ' '`
    p2=`echo $params | cut -f 2 -d ' '`
    python /home1/cataldor/software/s-ldxr-0.3-beta/s-ldxr.py \
    --gcor $p1 $p2 \
    --ref-ld-chr /path/to/dir/baselineLD_v2.2_EUR/baselineLD. \
    --w-ld-chr /path/to/dir/weights_EUR/weight_EUR_standardized_chr \
    --frqfile /path/to/dir/reference_files/1000G_EUR_Phase3/plink_files/1000G.EUR.QC. \
              /path/to/dir/reference_files/1000G_EUR_Phase3/plink_files/1000G.EUR.QC. \
    --annot /path/to/dir/baselineLD_v2.2_EUR/baselineLD. \
    --apply-shrinkage 0.5 \
    --save-pseudo-coef \
    --out /path/to/dir/sldxr_OUT/${p1}_${p2}.txt
done 
