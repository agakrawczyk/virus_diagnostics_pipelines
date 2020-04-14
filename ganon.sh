#!/bin/bash
#
# Ganon Processing
# 
# Arguments: 
#   $1 FASTQ Read1 Path
#   $2 Ganon index
#   $3 output directory
#   
# 

#TODO: use /usr/bin/time with -o as log file and store error output of each command separately
#TODO: check if all used tools use 10 threads!

FR1=$1
KAIJU_DB=$2
OUTDIR=$3


###
## PRINT CONFIGURATION
echo "[$(date)]: Running Bowtie2+slimm with the following parameters:" >&2
echo "[$(date)]: FASTQ_R1 = ${FR1}" >&2
echo "[$(date)]: KAIJU_DATABASE = ${KAIJU_DB}" >&2
echo "[$(date)]: OUTPUTDIR = ${OUTDIR}" >&2

FR1N=${FR1##*/}
SAMPLEN=${FR1N/_R1*/}

touch ${OUTDIR}.started

mkdir -p $OUTDIR/{FASTQC,FLASH_OUTPUT,slimm_reports}

### PREPARE THE SHELL 
echo "[$(date)]: Preparing shell." >&2

conda activate aga
ulimit -S -m 250000000
#ulimit -a

###1 QA
echo "[$(date)]: FASTQC starts" >&2
/usr/bin/time --verbose --output=${OUTDIR}/FASTQC/fastqc.time.log \
  fastqc --verbose --threads 10 \
  --adapters /opt/resources/fastqc_adapter_list.txt \
  --contaminants /opt/resources/fastqc_contaminant_list.txt \
  --outdir $OUTDIR/FASTQC \
  ${FR1} ${FR1/_R1/_R2} $OUTDIR/FLASH_OUTPUT/${SAMPLEN}*fastq \
  2>&1 | tee $OUTDIR/FASTQC/fastqc.log
echo "[$(date)]: FASTQC done" >&2

###2. Run Ganon 

echo "[$(date)]: Ganon starts" >&2
/usr/bin/time --verbose --output=${OUTDIR}/Ganon.classification.time.log \
  ganon classify -t 10 -d ${Ganon_DB} -p ${FR1} ${FR1/_R1/_R2} -o $OUTDIR/Ganon_out/${SAMPLEN} 
echo "[$(date)]: Ganon done" >&2
done


touch ${OUTDIR}.finished