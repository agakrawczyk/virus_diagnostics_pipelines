#/bin/bash
#aga's BOWTIE2+SLIMM Pipeline
#
#USER NEEDS TO SPECIFY:

RUNDIR=/home/krawczyk/workdir/Virusseq/fastq
OUTDIR=/opt/exchange/VIR/bowtie_slimm_fastq_results
SLIMM_DB=/home/krawczyk/workdir/databases/slimm_db_C-RVDB16.0_HUMAN_GENOME.sldb
BOWTIE2_DB=/home/krawczyk/workdir/databases/C-RVDBv16.bowtie2


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

for FR1 in ${FQ}; do
  FR1N=${FR1##*/}
  SAMPLEN=${FR1N/_R1*/}
  OUTDIRS=${OUTDIR}/${SAMPLEN}
  mkdir -p ${OUTDIRS}
  /usr/bin/time --verbose --output=${OUTDIRS}/bowtie2+slimm.time.log \
    bash bowtie2+slimm.sh ${FR1} ${BOWTIE2_DB} ${SLIMM_DB} ${OUTDIRS} \
    2>&1 | tee ${OUTDIRS}/bowtie2+slimm.log
done

###6. Running multiqc
echo "[$(date)]: Starting multiqc" >&2
conda activate vir-agafix 
multiqc --verbose --interactive --force --no-ansi \
  --outdir $OUTDIR --title "MultiQC BOWTIE2+SLIMM VirusSeq" \
  $OUTDIR \
  2>&1 | tee $OUTDIR/MultiQC-BOWTIE2SLIMM-VirusSeq.log
echo "[$(date)]: Multiqc done" >&2