#!/bin/bash
#SBATCH --job-name=incrementation
#SBATCH --nodes=1
#SBATCH --ntasks=1


source /home/vhs/sea-slurm-scripts/sea_fmriprep/spark-venv/bin/activate
spark-submit --master local[*] --driver-memory 200G /home/vhs/sea-slurm-scripts/sea_fmriprep/spark_inc.py /mnt/lustre/shared/bigbrain/nii/5000_blocks /mnt/lustre/vhs/increment_out 3  --cli --delay 5
