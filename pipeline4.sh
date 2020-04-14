#/bin/bash
#aga's Ganon Pipeline
#
#USER NEEDS TO SPECIFY:

RUNDIR=/home/krawczyk/workdir/Virusseq/fastq
OUTDIR=/opt/exchange/VIR/Ganon_fastq_results
GANON_DB=/home/krawczyk/workdir/databases/ganon_viruses_db

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
  mkdir -p ${OUTDIR}/Ganon_out
  /usr/bin/time --verbose --output=${OUTDIRS}/ganon.time.log \
    bash ganon.sh ${FR1} ${GANON_DB} ${OUTDIRS} \
    2>&1 | tee ${OUTDIRS}/ganon.log
done

### Running multiqc
echo "[$(date)]: Starting multiqc" >&2
conda activate aga 
multiqc --verbose --interactive --force --no-ansi \
  --outdir $OUTDIR --title "MultiQC Ganon VirusSeq" \
  $OUTDIR \
  2>&1 | tee $OUTDIR/MultiQC-Ganon-VirusSeq.log
echo "[$(date)]: Multiqc done" >&2