#!/bin/bash
#SBATCH -c 1 # Number of cores
#SBATCH --mem 25G # Memory pool for all cores
#SBATCH --error=/directory/logs/slurm_%A_%a.err
#SBATCH --output=/directory/logs/slurm_%A_%a.out
#SBATCH --job-name=x_redo
#SBATCH --time=48:00:00 #expected time of completion
#SBATCH --array=1-10 #whatever the number of params files is (that are listed in the PARAMS_LIST file)

#variables & paths:
I_LINE=$SLURM_ARRAY_TASK_ID
ROOT=/project2/[path]/sldxr_JAN2026
SDIR=/project2/[path]/sumstats
PDIR=${ROOT}/parameters
PARAMS_LIST=${PDIR}/list4.params
FILE=$(head -n $I_LINE $PARAMS_LIST | tail -n 1)
PARAM_FILE=${PDIR}/${FILE}
NUM=$(wc -l < $PARAM_FILE)
SLDXRDIR=~/software/sldxr_2025/s-ldxr
GCORSCRIPT=s-ldxr.py
CANNOT_GCOR=cont_annot_gcor.py #this version is updated to python3
CANNOT_EXP=pred_binannot_from_contannot.py
REF_LD_CHR=/project2/[path]/data/LDSC_ref/1000G_EUR/baselineLD_sldxr_v2.2_ldscores/baselineLD.
W_LD_CHR=/project2/[path]/data/LDSC_ref/weights_hm3_no_MHC_sldxr/weights.hm3_noMHC.
FRQFILE1=/project2/[path]/data/LDSC_ref/1000G_EUR/frq/1000G.EUR.QC.
FRQFILE2=/project2/[path]/data/LDSC_ref/1000G_EUR/frq/1000G.EUR.QC.
ANNOT=/project2/[path]/data/LDSC_ref/1000G_EUR/baselineLD_v2.2_ldscores/baselineLD.
SHRINK=1.0

#go to root directory 
cd $ROOT

#output directory
OUTDIR=sldxr_out
mkdir -p "$OUTDIR"
#if changing shrinkage param:
mkdir -p ${OUTDIR}/shrink${SHRINK}
mkdir -p ${OUTDIR}/shrink${SHRINK}/logs
mkdir -p ${OUTDIR}/shrink${SHRINK}/tau_theta_files


ERRLOG=${ROOT}/logs/slurm_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}.err
OUTLOG=${ROOT}/logs/slurm_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}.out

#log info
echo "[LOG] SLURM ID: ${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
echo "[LOG] Directory: ${ROOT}"
echo "[LOG] Params file: ${PARAM_FILE}"
echo "[LOG] Shrinkage alpha: ${SHRINK}"

#check that param file was extracted correctly
if [[ -z "$PARAM_FILE" || ! -f "$PARAM_FILE" ]]; then
    echo "Error: PARAM_FILE is empty or does not exist for SLURM_ARRAY_TASK_ID=$I_LINE" >> $ERRLOG
    exit 1
fi

#debug log
echo "PARAM_FILE=$PARAM_FILE" >> $ERRLOG
echo "PARAM_FILE=$PARAM_FILE" >> $OUTLOG

for i in $(seq 1 $NUM); do
    params=$(head -n $i  $PARAM_FILE | tail -n 1)
    #check that params is not empty
    if [[ -z "$params" ]]; then
        echo "Error: params is empty for i=$i in file $PARAM_FILE" >> $ERRLOG
        exit 1
    fi
        p1=`echo $params | cut -f 1 -d ' '`
    p2=`echo $params | cut -f 2 -d ' '`
    
#1) "typical command"
#estimate enrichment of stratified squared cross-trait genetic correlation
    echo "[LOG] ${PARAM_FILE} line ${i}"
    echo "[LOG] S-LDXR Step 1 started at $(date)"
    echo "[LOG] Estimating enrichment of stratified cross-trait rg (--gcor)..."

    conda run -n int_sldxr_py3 python "${SLDXRDIR}/${GCORSCRIPT}" \
        --gcor ${SDIR}/${p1} ${SDIR}/${p2} \
        --ref-ld-chr "$REF_LD_CHR" \
        --w-ld-chr "$W_LD_CHR" \
        --frqfile "$FRQFILE1" "$FRQFILE2" \
        --annot "$ANNOT" \
        --apply-shrinkage ${SHRINK} \
        --save-pseudo-coef \
        --out ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}

  if [ $? -ne 0 ]; then
    echo "[ERROR] S-LDXR step 1 failed for ${PARAM_FILE} line ${i}" >&2
    exit 1
  fi

    echo "[LOG] S-LDXR Step 1 completed at $(date)"
    echo "[LOG] Step 1 files written to: ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}"

#2) "Estimating λ2(C) for continuous-valued annotations"
#continuous annotations
    echo "[LOG] S-LDXR Step 2 S-LDXR started at $(date)"
    echo "[LOG] Estimating enrichment for quintiles of continuous-valued annotations..."

    conda run -n int_sldxr_py3 python "${SLDXRDIR}/${CANNOT_GCOR}" \
        --coef ${OUTDIR}/shrink${SHRINK}/${p1}_${p2} \
        --frqfile "$FRQFILE1" "$FRQFILE2" \
        --annot "$ANNOT" \
        --names GERP.NS \
            MAF_Adj_Predicted_Allele_Age \
            MAF_Adj_LLD_AFR \
            Recomb_Rate_10kb \
            Nucleotide_Diversity_10kb \
            Backgrd_Selection_Stat \
            CpG_Content_50kb \
            MAF_Adj_ASMC \
    --nbins 5 \
    --apply-shrinkage ${SHRINK} \
    --out ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}_contannot

  if [ $? -ne 0 ]; then
    echo "[ERROR] S-LDXR step 2 failed for ${PARAM_FILE} line ${i}" >&2
    exit 1
  fi
    echo "[LOG] S-LDXR Step 2 completed at $(date)"
    echo "[LOG] Step 2 files written to: ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}_contannot"

#3) "Expected λ2(C) from continuous-valued annotations: part 1"
#estimate expected lambda^2C from continuous-valued annots
    echo "[LOG] S-LDXR Step 3 S-LDXR started at $(date)"
    echo "[LOG] Estimating expected enrichment for quintiles of continuous-valued annotations..."
    conda run -n int_sldxr_py3 python "${SLDXRDIR}/${GCORSCRIPT}" \
        --gcor ${SDIR}/${p1} ${SDIR}/${p2} \
        --ref-ld-chr "$REF_LD_CHR" \
        --w-ld-chr "$W_LD_CHR" \
        --frqfile "$FRQFILE1" "$FRQFILE2" \
        --annot "$ANNOT" \
        --save-pseudo-coef \
        --out ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}_contannot_step1

    echo "[LOG] S-LDXR Step 3 completed at $(date)"
    echo "[LOG] Step 3 files written to: ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}_contannot_step1"

#4) "Expected λ2(C) from continuous-valued annotations: part 2"
    echo "[LOG] S-LDXR Step 4 S-LDXR started at $(date)"
    conda run -n int_sldxr_py3 python "${SLDXRDIR}/${CANNOT_EXP}" \
        --coef ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}_contannot_step1 \
        --frqfile "$FRQFILE1" "$FRQFILE2" \
        --cont-annot "$ANNOT" \
        --bin-annot "$ANNOT" \
        --apply-shrinkage ${SHRINK} \
        --out ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}_contannot_step2

    echo "[LOG] S-LDXR Step 4 completed at $(date)"
    echo "[LOG] Step 4 files written to: ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}_contannot_step2"

#directory cleanup
    echo "[LOG] Moving .log & *.gz files to subdirectories ${OUTDIR}/shrink${SHRINK}/logs & ${OUTDIR}/shrink${SHRINK}/tau_theta_files"
    mv ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}.log ${OUTDIR}/shrink${SHRINK}/logs/
    mv ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}.pseudo_tau2.gz ${OUTDIR}/shrink${SHRINK}/tau_theta_files/
    mv ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}.pseudo_tau1.gz ${OUTDIR}/shrink${SHRINK}/tau_theta_files/
    mv ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}.pseudo_theta.gz ${OUTDIR}/shrink${SHRINK}/tau_theta_files/
    mv ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}_contannot.log ${OUTDIR}/shrink${SHRINK}/logs/
    mv ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}_contannot_step2.log  ${OUTDIR}/shrink${SHRINK}/logs/
    mv ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}_contannot_step1.log  ${OUTDIR}/shrink${SHRINK}/logs/
    mv ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}_contannot_step1.pseudo_theta.gz ${OUTDIR}/shrink${SHRINK}/tau_theta_files/
    mv ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}_contannot_step1.pseudo_tau2.gz ${OUTDIR}/shrink${SHRINK}/tau_theta_files/
    mv ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}_contannot_step1.pseudo_tau1.gz ${OUTDIR}/shrink${SHRINK}/tau_theta_files/
    mv ${OUTDIR}/shrink${SHRINK}/${p1}_${p2}_contannot.pseudo_theta.gz ${OUTDIR}/shrink${SHRINK}/tau_theta_files/

done 
