#!/bin/bash
#
# YARA+SLIMM Processing
# 
# Arguments: 
#   $1 FASTQ Read1 Path
#   $2 yara_mapper index
#   $3 slimm index
#   $4 output directory
# 

#TODO: use /usr/bin/time with -o as log file and store error output of each command separately
#TODO: check if all used tools use 10 threads!

FR1=$1
YARA_DB=$2
SLIMM_DB=$3
OUTDIR=$4

YARA_STRATA_RATE=1

###
## PRINT CONFIGURATION
echo "[$(date)]: Running yara+slimm with the following parameters:" >&2
echo "[$(date)]: FASTQ_R1 = ${FR1}" >&2
echo "[$(date)]: YARA_DATABASE = ${YARA_DB}" >&2
echo "[$(date)]: SLIMM_DATABASE = ${SLIMM_DB}" >&2
echo "[$(date)]: OUTPUTDIR = ${OUTDIR}" >&2

FR1N=${FR1##*/}
SAMPLEN=${FR1N/_R1*/}

touch ${OUTDIR}.started

mkdir -p $OUTDIR
mkdir -p $OUTDIR/FLASH_OUTPUT
mkdir -p $OUTDIR/slimm_reports
mkdir -p $OUTDIR/FASTQC

### PREPARE THE SHELL 
echo "[$(date)]: Preparing shell." >&2
#NOTE: conda environment containing only yara + helpers
conda activate vir-agafix 
ulimit -S -m 250000000
#ulimit -a

###0 QA
/usr/bin/time --verbose --output=${OUTDIRS}/FASTQC/fastqc.time.log \
  fastqc --verbose --threads 10 \
  --adapters /opt/resources/fastqc_adapter_list.txt \
  --contaminants /opt/resources/fastqc_contaminant_list.txt \
  --outdir $OUTDIR/FASTQC \
  ${FR1} ${FR1/_R1/_R2} \
  > $OUTDIR/FASTQC/fastqc.log \
  2> $OUTDIR/FASTQC/fastqc.err

###1. Joining reads with FLASH
echo "[$(date)]: FLASH starts" >&2
#NOTE: flash needs output directory (-d) and outputprefix (-o) seperately!!!
/usr/bin/time --verbose --output=${OUTDIRS}/FLASH_OUTPUT/flash2.time.log \
  flash2 --max-overlap=250 --threads=10 \
  --output-directory=$OUTDIR/FLASH_OUTPUT/ \
  --output-prefix=${SAMPLEN} \
  ${FR1} ${FR1/_R1/_R2} \
  > $OUTDIR/FLASH_OUTPUT/flash2.log \
  2> $OUTDIR/FLASH_OUTPUT/flash2.err
echo "[$(date)]: FLASH done" >&2

###2.Run YARA on both joined and unjoined reads 
echo "[$(date)]: YARA starts" >&2
/usr/bin/time --verbose --output=$OUTDIR/${SAMPLEN}.join.time.log\
  yara_mapper --very-verbose --threads 10 \
  --strata-rate ${YARA_STRATA_RATE} \
  --output-file $OUTDIR/${SAMPLEN}.join.bam \
  ${YARA_DB} \
  $OUTDIR/FLASH_OUTPUT/${SAMPLEN}.extendedFrags.fastq \
  > $OUTDIR/${SAMPLEN}.join.log \
  2> $OUTDIR/${SAMPLEN}.join.err
/usr/bin/time --verbose --output=$OUTDIR/${SAMPLEN}.un.time.log\
  yara_mapper --very-verbose --threads 10 \
  --strata-rate ${YARA_STRATA_RATE} \
  --output-file $OUTDIR/${SAMPLEN}.un.bam \
  ${YARA_DB} \
  $OUTDIR/FLASH_OUTPUT/${SAMPLEN}.notCombined_1.fastq \
  $OUTDIR/FLASH_OUTPUT/${SAMPLEN}.notCombined_2.fastq \
  > $OUTDIR/${SAMPLEN}.un.log \
  2> $OUTDIR/${SAMPLEN}.un.err
echo "[$(date)]: YARA finished" >&2


####removing the FASTQJOIN file after mapping it with yara
rm $OUTDIR/FLASH_OUTPUT/${SAMPLEN}.extendedFrags.fastq
rm $OUTDIR/FLASH_OUTPUT/${SAMPLEN}.notCombined_1.fastq
rm $OUTDIR/FLASH_OUTPUT/${SAMPLEN}.notCombined_2.fastq


###3. Merge the bam files with samtools 
echo "[$(date)]: Samtools merge starts" >&2
/usr/bin/time --verbose --output=$OUTDIR/${SAMPLEN}.merged.time.log \
  samtools merge --threads 10 \
  $OUTDIR/${SAMPLEN}.merged.bam $OUTDIR/${SAMPLEN}.un.bam \
  $OUTDIR/${SAMPLEN}.join.bam \
  > $OUTDIR/${SAMPLEN}.merged.log \
  2> $OUTDIR/${SAMPLEN}.merged.err \
echo "[$(date)]: Samtools merge done" >&2

####removing the intermediate bam files 
rm -f $OUTDIR/${SAMPLEN}.join.bam $OUTDIR/${SAMPLEN}.un.bam

###4. Run SLIMM 
echo "[$(date)]: SLIMM starts" >&2
#NOTE: Wrong bam file used here!!!
/usr/bin/time --verbose --output=$OUTDIR/slimm_reports/${SAMPLEN}.time.log \
  slimm --verbose \
  --bin-width 1000 --rank species \
  --raw-output --coverage-output \
  --output-prefix $OUTDIR/slimm_reports/${SAMPLEN} \
  ${SLIMM_DB} \
  $OUTDIR/${SAMPLEN}.merged.bam \
  > $OUTDIR/slimm_reports/${SAMPLEN}.log \
  2> $OUTDIR/slimm_reports/${SAMPLEN}.err
echo "[$(date)]: SLIMM done" >&2

touch ${OUTDIR}.finished
