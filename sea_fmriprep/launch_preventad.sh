#!/bin/bash
#SBATCH --job-name=sea-fmriprep
#SBATCH --nodes=1
#SBATCH --ntasks=1

idx=$1
nsub=$2
export DATA_DIR=$3/job-${SLURM_JOB_ID}
fs=$4

images=(`ls -d /mnt/lustre/shared/preventad-open-bids/BIDS_dataset/*/*/func | sort | uniq --check-chars=63 | xargs -I{} find {} -name "*bold.nii*" | grep run-001`)
im=("${images[@]:$idx:${nsub}}")


export SEA_TMPFSDIR=/dev/shm/seasource
export SEA_LOCALDIR=/disk5/vhs/seasource
export SEA_LFSDIR=/mnt/lustre/vhs/seasource

if [[ ${fs} == "sea" ]]
then
    export SEAMOUNT=/mnt/lustre/vhs/seamount
    export execcmd="run"
else
    export SEAMOUNT=/mnt/lustre/vhs/defaultmount
    export execcmd="exec"
    export tool="fmriprep "
    mkdir -p ${SEAMOUNT}/${SLURM_JOB_ID}
fi

rm -rf /dev/shm/* ${SEA_LOCALDIR}

#echo  ${SEA_TMPFSDIR}/${SLURM_JOB_ID} ${SEA_LOCALDIR}/${SLURM_JOB_ID} ${SEA_LFSDIR}/${SLURM_JOB_ID}
mkdir -p ${SEA_TMPFSDIR}/${SLURM_JOB_ID} ${SEA_LOCALDIR}/${SLURM_JOB_ID} ${SEA_LFSDIR}/${SLURM_JOB_ID}

mkdir -p ${DATA_DIR}

#for s in ${subjects[@]}
#do
#    echo "${SEA_INPUT_DIR}/BIDS_dataset/$s.*" >> .sea_prefetchlist_${SLURM_JOB_ID}
#done

export CURR="$PWD"
export CONP="/mnt/lustre/shared"
export TEMPLATEFLOW_HOME="$CURR/fmriprep/templateflow"
export SEA_INPUT_DIR="$CONP/preventad-open-bids/"

export NTHREADS=$(( 64 / ${nsub} ))
$(echo 3 | sudo tee /proc/sys/vm/drop_caches ) &> /dev/null

cat <<EOT >> ${DATA_DIR}/${fs}.sh
#!/bin/bash

echo "EXP_TIMESTAMP \$(date +%s)"
echo "Executing on node: \$(uname -a)"

im=\$@

subjects=( \$(printf '%s\n' "${im[@]}" | cut -d "/" -f 10 | cut -d "_" -f 1) )
sessions=( \$(printf '%s\n' "${im[@]}" | cut -d "/" -f 10 | cut -d "_" -f 2) )
tasks=( \$(printf '%s\n' "${im[@]}" | cut -d "/" -f 10 | cut -d "_" -f 3) )

free
cat /proc/meminfo
date
date +%s
df -h

FMRICMD="
    \${tool}--random-seed 1234 --fs-no-reconall --skull-strip-fixed-seed  --nprocs 64 --omp-nthreads \${NTHREADS} \
    -w \${SEAMOUNT}/\${SLURM_JOB_ID}/fmriprep_work --skip_bids_validation \
    --participant-label \${subjects[@]} \
    --fs-license-file /fmriprep/license.txt --bids-database-dir /dev/shm \
    \${SEA_INPUT_DIR}/BIDS_dataset \${SEAMOUNT}/\${SLURM_JOB_ID}/fmriprep_out participant"

COMMAND="singularity \${execcmd} --bind \$CURR:\$CURR --bind \$CONP:\$CONP --bind \$CURR/sea.ini:/sea/sea.ini --bind \$CURR/.sea_flushlist:/sea/.sea_flushlist \
         --bind \$CURR/sea_launch.sh:/bin/sea_launch.sh --bind \$CURR/sea_prefetch.sh:/bin/sea_prefetch.sh --bind \$CURR/mirror:/sea/mirror \
         --bind \$CURR/libiniparser.so.1:/lib/libiniparser.so.1 --bind \$CURR/sea_flusher.sh:/bin/sea_flusher.sh \
         --bind \$CURR/.sea_evictlist:/sea/.sea_evictlist --bind \${SEA_LFSDIR}:\${SEA_LFSDIR} \
	     --bind \${SEA_LOCALDIR}:\${SEA_LOCALDIR} --bind \${SEA_TMPFSDIR}:\${SEA_TMPFSDIR} --bind \${SEAMOUNT}:\${SEAMOUNT} \
         --bind \$CURR/license.txt:/fmriprep/license.txt \
	     --workdir \$CURR \
	  ghcr.io_valhayot_sea-fmriprep_master-2021-07-19-03e6e915ac2e.sif \$FMRICMD"

echo \$COMMAND
/home/vhs/RUIS/ruis.sh \$COMMAND

free
cat /proc/meminfo
date
date +%s
df -h
EOT
# --anat-only   --boilerplate_only
# --bind \$CURR/.sea_prefetchlist_\${SLURM_JOB_ID}:/sea/.sea_prefetchlist 

bash ${DATA_DIR}/${fs}.sh ${im[@]}
