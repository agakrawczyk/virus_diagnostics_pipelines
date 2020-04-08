#/bin/bash
#aga's YARA+SLIMM Pipeline
#
#USER NEEDS TO SPECIFY:

RUNDIR=/home/krawczyk/workdir/Virusseq/fastq
OUTDIR=/opt/exchange/VIR/yara_slimm_fastq_results
SLIMM_DB=/home/krawczyk/workdir/databases/slimm_db_C-RVDB16.0_HUMAN_GENOME.sldb
YARA_DB=/home/krawczyk/workdir/databases/C-RVDBv16.yara.index
BASEN=${RUNDIR##*/}


###
## PRINT CONFIGURATION
echo "[$(date)]: Running BOWTIE2 + SLIMM Pipeline with the following parameters:" >&2
echo "[$(date)]: RUNDIR = ${RUNDIR}" >&2
echo "[$(date)]: OUTPUTDIR = ${OUTDIR}" >&2
#echo "[$(date)]: SAMPLE_SHEET = ${SAMPLESHEET}" >&2
echo "[$(date)]: SLIMM_DATABASE = ${SLIMM_DB}" >&2
echo "[$(date)]: BOWTIE2_DATABASE = ${BOWTIE_DB}" >&2

### PREPARE THE SHELL 
echo "[$(date)]: Preparing shell." >&2
conda activate vir-agafix
ulimit -S -m 250000000
ulimit -a
mkdir -p $OUTDIR
mkdir -p $OUTDIR/FLASH_OUTPUT
mkdir -p $OUTDIR/slimm_reports
mkdir -p $OUTDIR/FASTQC



###
## FIND ALL FASTQ FILES
FQ=$(find -L "${RUNDIR}" -name "*_R1*.fastq" -type f)
if [ -z "$FQ" ]; then
  echo "[$(date)]: No FASTQs found. Exiting..." >&2
  exit 0
else
   echo "[$(date)]: The number of reads: ls -l | wc -l" >&2 
   echo "[$(date)]: Found the following FASTQs:" >&2
   echo $FQ | sort | sed -e "s/gz /gz\n/g" | sed "s/\(^.\)/\t\1/g" >&2
fi

function processSample {
  FR1=$1 

  FR1N=${FR1##*/}
  SAMPLEN=${FR1N/_R1*/}

  ###0 QA
  /usr/bin/time -v fastqc --verbose --threads 10 \
    --outdir $OUTDIR/FASTQC --adapters /opt/resources/fastqc_adapter_list.txt \
    --contaminants /opt/resources/fastqc_contaminant_list.txt \
    ${FR1} ${FR1/_R1/_R2} \
    > $OUTDIR/FASTQC/fastqc.time.log

  ###1. Joining reads with FLASH
  echo "[$(date)]: FLASH starts" >&2
  /usr/bin/time -v flash2 -M 250 -t 10 -o $OUTDIR/FLASH_OUTPUT/${SAMPLEN} ${FR1} ${FR1/_R1/_R2} 2>&1 | tee  $OUTDIR/FLASH_OUTPUT/${SAMPLEN}_%.time.log
  echo "[$(date)]: FLASH done" >&2

  ###2.Run YARA on both joined and unjoined reads 
  echo "[$(date)]: YARA starts" >&2
  /usr/bin/time -v yara_mapper -v -t 10 -s 2 \
    ${YARA_DB} \
    $OUTDIR/FLASH_OUTPUT/${SAMPLEN}.extendedFrags.fastq \
    -o $OUTDIR/${SAMPLEN}.join.bam \
    > $OUTDIR/${SAMPLEN}.join.time.log
  /usr/bin/time -v yara_mapper -v -t 10 -s 2 \
    ${YARA_DB} \
    $OUTDIR/FLASH_OUTPUT/${SAMPLEN}.notCombined_1.fastq \
    $OUTDIR/FLASH_OUTPUT/${SAMPLEN}.notCombined_2.fastq \
    -o $OUTDIR/${SAMPLEN}.un.bam \
    > $OUTDIR/${SAMPLEN}.un.time.log
  echo "[$(date)]: YARA finished" >&2


  ####removing the FASTQJOIN file after mapping it with yara
  #rm $OUTDIR/FLASH_OUTPUT/${SAMPLEN}.extendedFrags.fastq
  #rm $OUTDIR/FLASH_OUTPUT/${SAMPLEN}.notCombined_1.fastq
  #rm $OUTDIR/FLASH_OUTPUT/${SAMPLEN}.notCombined_2.fastq


  ###3. Merge the bam files with samtools 
  echo "[$(date)]: Samtools merge starts" >&2
  samtools merge --threads 10 \
    $OUTDIR/${SAMPLEN}.merged.bam $OUTDIR/${SAMPLEN}.un.bam $OUTDIR/${SAMPLEN}.join.bam
  echo "[$(date)]: Samtools merge done" >&2

  ####removing the intermediate bam files 
  rm $OUTDIR/${SAMPLEN}.join.bam 
  rm $OUTDIR/${SAMPLEN}.un.bam

  ###4. Run SLIMM 
  mkdir -p $OUTDIR/slimm_reports/${SAMPLEN}
  echo "[$(date)]: SLIMM starts" >&2
  /usr/bin/time -v slimm -w 1000 -r species \
    -ro -co -o $OUTDIR/slimm_reports/${SAMPLEN} \
    ${SLIMM_DB} \
    $OUTDIR/${SAMPLEN}.un.bam \
    > $OUTDIR/slimm_reports/${SAMPLEN}.time.log 2>&1
  echo "[$(date)]: SLIMM done" >&2
}
export -f processSample

for FR1 in ${FQ}; do
  #TODO: How to time the execution of a function?
  /usr/bin/time -v processSample $FR1 > $OUTDIR/${SAMPLEN}.total.time.log 
done

###6. Running multiqc
echo "[$(date)]: Starting multiqc" >&2
mkdir -p $OUTDIR/multiqc_output
multiqc $OUTDIR/FASTQC . --interactive > OUTDIR/multiqc_output
echo "[$(date)]: Multiqc done" >&2
