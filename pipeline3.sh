#/bin/bash
#aga's Kaiju Pipeline
#
#USER NEEDS TO SPECIFY:

RUNDIR=/home/krawczyk/workdir/Virusseq/fastq
OUTDIR=/opt/exchange/VIR/kaiju_fastq_results
KAIJU_DB=/home/krawczyk/workdir/databases/rvdb/kaiju_db_rvdb.fmi

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
  mkdir -p ${OUTDIR}/Kaiju_out
  /usr/bin/time --verbose --output=${OUTDIRS}/kaiju.time.log \
    bash kaiju.sh ${FR1} ${KAIJU_DB} ${OUTDIRS} \
    2>&1 | tee ${OUTDIRS}/kaiju.log
done

### Running multiqc
echo "[$(date)]: Starting multiqc" >&2
conda activate aga 
multiqc --verbose --interactive --force --no-ansi \
  --outdir $OUTDIR --title "MultiQC Kaiju VirusSeq" \
  $OUTDIR \
  2>&1 | tee $OUTDIR/MultiQC-Kaiju-VirusSeq.log
echo "[$(date)]: Multiqc done" >&2