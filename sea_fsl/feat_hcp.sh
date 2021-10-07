#!/bin/bash
#SBATCH --job-name=fsl
#SBATCH --nodes=1
#SBATCH --ntasks=1

set -e 

rm -rf /disk0/vhs/seasource
mkdir -p /dev/shm/seasource /dev/shm/defaultmount /disk0/vhs/seasource
export fs="$1"
idx="$2"
nthreads="$3"
export DATA_DIR=$4/job-${SLURM_JOB_ID}
stamp=$(basename $4)-$RANDOM
dataset="$5"

export type="run"

seamount=/mnt/lustre/vhs/seamount
mem_dir=/dev/shm/seasource/feat.results.${dataset}/${stamp}
disk_dir=/disk0/vhs/seasource/feat.results.${dataset}/${stamp}

if [[ "${fs}" != "sea" ]]
then
    type="exec"
    seamount=/mnt/lustre/vhs/defaultmount
    out_dir=${seamount}/feat.results.${dataset}/${stamp}
    mkdir -p "${out_dir}"
    exec_script="${out_dir}/launch_all_$(date +"%s").sh"
    echo "source \$FSLDIR/etc/fslconf/fsl.sh" > "${exec_script}"
else
    out_dir=${seamount}/feat.results.${dataset}/${stamp}
    mkdir -p "${out_dir}" "${mem_dir}" "${disk_dir}"
    exec_script="${mem_dir}/launch_all_$(date +"%s").sh"
    echo "" > "${exec_script}"
fi


singularity_launch="${out_dir}/singularity_launch_${fs}_$(date +"%s").$RANDOM.sh"


if [[ ${dataset} == "preventad" ]]
then
    top_dir=/mnt/lustre/shared/preventad-open-bids/BIDS_dataset
    all_sessions=($(ls -d ${top_dir}/sub-*/ses-*/func/*bold.nii.gz))
elif [[ ${dataset} == "ds001545" ]]
then
    top_dir=/mnt/lustre/shared/ds001545-resolved
    all_sessions=($(ls -d ${top_dir}/sub-*/func/*bold.nii.gz))
else
    top_dir=/mnt/hcp/HCP_1200_data/
    all_sessions=($(ls -d /mnt/lustre/shared/hcp-squashfs/HCP_1200_data/*/unprocessed/3T/*fMRI*/*fMRI* | grep -E "[L | R].nii.gz"))
fi
subses=("${all_sessions[@]:${idx}:${nthreads}}")

for epi in ${subses[@]}
do
    echo "***ITERATING THROUGH SESSION***"
    subj=$(echo ${epi} | cut -d'/' -f 7)

    subj_base=$(dirname $(dirname $epi))


    if [[ ${dataset} == "preventad" ]]
    then
        ses=$(basename ${subj_base})
        anat_file=${subj_base}/anat/${subj}_${ses}_run-001_T1w.nii.gz
    elif [[ ${dataset} == "ds001545" ]]
    then
        subj=$(echo ${epi} | cut -d'/' -f 6)

        subj_base=$(dirname $(dirname $epi))
        ses="ses-001"
        anat_file=${subj_base}/anat/${subj}_T1w.nii.gz
    else
        ses=$(basename $(dirname $epi))
        anat_file=${subj_base}/T1w_MPR1/${subj}_3T_T1w_MPR1.nii.gz
    fi
    #epi_files=($(ls -d ${sses}/*REST*/*REST*.nii.gz | grep -e "[ L|R ].nii.gz"))

    echo anat "${anat_file}"
    echo epi "${epi}"

    subject_output=${out_dir}/${subj}
    session_output=${subject_output}/${ses}
    bet_file=${session_output}/${subj}_${ses}_T1w_BET.nii.gz

    if [[ "$fs" == "sea" ]]
    then
        script_base=$(echo ${subject_output} | sed 's/seamount/seasource/g' )

        echo "base" ${script_base}
        script=${script_base}/${subj}_${ses}_featscript.fsf

        mkdir -p ${script_base}
        #script=$(echo ${script} | sed 's/seasource/seamount/g')
        type="run"
    else
        script_base=$(echo ${subject_output} | sed 's/seamount/defaultmount/g')
        echo "base" ${script_base}
        script=${script_base}/${subj}_${ses}_featscript.fsf

        mkdir -p ${script_base}

    fi
    mkdir -p ${script_base}/${ses}
        
    export ANAT=${bet_file}
    export EPI=${epi}
    export OUTPUTDIR=${session_output}/processed

    echo "output dir ${OUTPUTDIR}"

    multiply () {
        local IFS='*'
        echo "$(( $* ))"
    }

    info=$(singularity exec -B /mnt/lustre sea-fsl-2021-08-26-c3282bc0268c.sif fslinfo ${EPI})
    dims=($(echo "${info}" | grep "^dim" | awk '{print $2}'))

    export TOTAL_VOXELS=$(multiply "${dims[@]}")
    export TOTAL_VOLUMES=${dims[3]}
    export TR=$(echo "${info}" | grep "^pixdim4" | awk '{print $2}')

    echo "total voxels: ${TOTAL_VOXELS}"
    echo "total volumes: ${TOTAL_VOLUMES}"
    echo "TR: ${TR}"

    cat design.fsf | envsubst > ${script}
    echo "bet ${anat_file} ${bet_file} -B && feat ${script} &" >> ${exec_script}
done

echo "wait" >> ${exec_script}

cat <<EOT >> ${singularity_launch}
#!/bin/bash
singularity ${type} -B /bin/strace -B /mnt/lustre/vhs \
    -B /mnt/lustre/vhs/seamount -B /mnt/lustre/shared \
    -B /mnt/lustre/vhs/defaultmount -B /disk0/vhs/seasource \
    -B $PWD:$PWD -B $PWD/sea.ini:/sea/home/sea.ini \
    -B .sea_flushlist:/sea/home/.sea_flushlist \
    -B .sea_evictlist:/sea/home/.sea_evictlist \
    -B /usr/bin/dc \
    -B $PWD/sea-app.sh:/bin/sea-app.sh -B sea_flusher.sh:/bin/sea_flusher.sh \
    sea-fsl-2021-08-26-c3282bc0268c.sif \
    bash ${exec_script}
EOT
chmod +x ${singularity_launch}

echo "EXP_TIMESTAMP $(date +%s)"
/home/vhs/RUIS/ruis.sh "${singularity_launch}"
