#!/bin/bash
#
# Kaiju Processing
# 
# Arguments: 
#   $1 FASTQ Read1 Path
#   $2 Kaiju index
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

##2. Run Kaiju 

echo "[$(date)]: Kaiju starts" >&2
/usr/bin/time --verbose --output=${OUTDIR}/Kaiju.classification.time.log \
  kaiju -z 10 -t databases/nodes.dmp -f ${Kaiju_DB} -i ${FR1} -j ${FR1/_R1/_R2}  -E 0.01 -o $OUTDIR/Kaiju_out/${SAMPLEN}.out.txt -v 2>&1 | tee $OUTDIR/Kaiju_out/${SAMPLEN}.out.txt.log 
echo "[$(date)]: Kaiju done" >&2
   
###3. Kaiju to krona 
echo "[$(date)]: Kaiju to krona starts" >&2
/usr/bin/time --verbose --output=${OUTDIR}/Kaiju.toKrona.time.log \
  kaiju2krona -t databases/nodes.dmp -n databases/names.dmp -i $OUTDIR/Kaiju_out/${SAMPLEN}.out.txt -o $OUTDIR/Kaiju_out/${SAMPLEN}.kaiju_summary.tsv -v 2>&1 | tee $OUTDIR/Kaiju_out/${SAMPLEN}.kaiju_summary.log 
  ktImportText -o $OUTDIR/Kaiju_out/${SAMPLEN}krona.html -o $OUTDIR/Kaiju_out/${SAMPLEN}.kaiju_summary.tsv
echo "[$(date)]: Kaiju to krona done" >&2   
done


touch ${OUTDIR}.finished