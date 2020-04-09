#/bin/bash
#aga's YARA+SLIMM Pipeline
#
#USER NEEDS TO SPECIFY:

RUNDIR=/home/helmuth/workspace/VIR/analyses/Aga/virus_diagnostics_pipelines/your-highness/testfq #/home/krawczyk/workdir/Virusseq/fastq
OUTDIR=/opt/exchange/VIR/yara_slimm_fastq_results
SLIMM_DB=/home/krawczyk/workdir/databases/slimm_db_C-RVDB16.0_HUMAN_GENOME.sldb
YARA_DB=/home/krawczyk/workdir/databases/C-RVDBv16.yara.index


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
  /usr/bin/time --verbose --output=${OUTDIRS}/yara+slimm.time.log \
    bash yara+slimm.sh ${FR1} ${YARA_DB} ${SLIMM_DB} ${OUTDIRS} \
    2>&1 | tee ${OUTDIRS}/yara+slimm.log
done

###6. Running multiqc
echo "[$(date)]: Starting multiqc" >&2
mkdir -p $OUTDIR/multiqc_output
conda activate vir-agafix 
multiqc --verbose --interactive --force --no-ansi \
  --outdir $OUTDIR --title "MultiQC YARA+SLIMM VirusSeq" \
  $OUTDIR \
  > $OUTDIR/multiqc_output.log \
  2> $OUTDIR/multiqc_output.err 
echo "[$(date)]: Multiqc done" >&2
