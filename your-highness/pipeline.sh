#/bin/bash
#aga's YARA+SLIMM Pipeline
#
#USER NEEDS TO SPECIFY:

RUNDIR=/home/krawczyk/workdir/Virusseq/fastq
#RUNDIR=testfq
OUTDIR=/opt/exchange/VIR/yara_slimm_fastq_results
#OUTDIR=testout
SLIMM_DB=/home/krawczyk/workdir/databases/slimm_db_C-RVDB16.0_HUMAN_GENOME.sldb
YARA_DB=/home/krawczyk/workdir/databases/C-RVDBv16.yara.index


###
## FIND ALL FASTQ FILES
FQ=$(find -L "${RUNDIR}" -name "*_R1*.fastq" -type f)

# MANUAL FILE LIST
FQ="
  /home/krawczyk/workdir/Virusseq/fastq/181025_06_56305_RNA_HSV2_R1.fastq
  /home/krawczyk/workdir/Virusseq/fastq/180911_03_TBEVBENZ_RNA_TBEV_R1.fastq
  /home/krawczyk/workdir/Virusseq/fastq/181025_11_14104_DNA_HSV-VZV_R1.fastq
  /home/krawczyk/workdir/Virusseq/fastq/181119_04_180_RNA_HDV_R1.fastq
  /home/krawczyk/workdir/Virusseq/fastq/180911_09_CSpecVir205_RNA_WNV_R1.fastq
  /home/krawczyk/workdir/Virusseq/fastq/180911_11_CSpecVir114_DNA_YFV_R1.fastq
  /home/krawczyk/workdir/Virusseq/fastq/180809_812_RNA_HEV_R1.fastq
  /home/krawczyk/workdir/Virusseq/fastq/181025_10_8539_RNA_HSV2_R1.fastq
  /home/krawczyk/workdir/Virusseq/fastq/180911_10_CSpecVir89_DNA_YFV_R1.fastq
  /home/krawczyk/workdir/Virusseq/fastq/180911_01_RKI_RNA_Enterovirus-Coxsackievirus_R1.fastq
  /home/krawczyk/workdir/Virusseq/fastq/180831_01_173_RNA_Cosavirus-Coxsackievirus_R1.fastq
  /home/krawczyk/workdir/Virusseq/fastq/181012_173_RNA_Cosavirus-Coxackievirus_R1.fastq
  /home/krawczyk/workdir/Virusseq/fastq/181025_12_49454_DNA_HSV-VZV_R1.fastq
"

if [ -z "$FQ" ]; then
  echo "[$(date)]: No FASTQs found. Exiting..." >&2
  exit 0
else
   echo "[$(date)]: The number of reads: ls -l | wc -l" >&2 
   echo "[$(date)]: Found the following FASTQs:" >&2
   for f in $FQ; do echo "  $f"; done
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
conda activate vir-agafix 
multiqc --verbose --interactive --force --no-ansi \
  --outdir $OUTDIR --title "MultiQC YARA+SLIMM VirusSeq" \
  $OUTDIR \
  2>&1 | tee $OUTDIR/MultiQC-YARASLIMM-VirusSeq.log
echo "[$(date)]: Multiqc done" >&2
