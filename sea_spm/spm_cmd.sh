#!/bin/bash
#SBATCH --job-name=spm
#SBATCH --nodes=1

set -e 

rm -rf /disk0/vhs/seasource /dev/shm/seasource
mkdir -p /dev/shm/seasource /dev/shm/defaultmount /disk0/vhs/seasource

source venv/bin/activate

export fs="$1"
idx="$2"
nthreads="$3"
data="$5"

if [[ ${data} == "preventad" ]]
then
    top_dir=/mnt/lustre/shared/preventad-open-bids/BIDS_dataset
elif [[ ${data} == "ds001545" ]]
then
    top_dir=/mnt/lustre/shared/ds001545
else
    top_dir=/mnt/lustre/shared/hcp-squashfs/HCP_1200_data
fi


njobs=16
export DATA_DIR=$4/job-${SLURM_JOB_ID}
stamp=$(basename $4)-$RANDOM
export type="run"

seamount=/mnt/lustre/vhs/seamount
base_dir=/mnt/lustre/vhs/seasource
lustre_dir=${base_dir}/spm.scripts.${data}/${stamp}
mem_dir=/dev/shm/seasource/spm.scripts.${data}/${stamp}
disk_dir=/disk0/vhs/seasource/spm.scripts.${data}/${stamp}

mkdir -p ${disk_dir}


if [[ "${fs}" != "sea" ]]
then
    type="exec"
    seamount=/mnt/lustre/vhs/defaultmount
    out_dir=${seamount}/spm.scripts.${data}/${stamp}
    mkdir -p "${out_dir}"
    exec_script="${out_dir}/launch_all_$(date +"%s").sh"
    singularity_launch="${out_dir}/singularity_launch_${fs}_$(date +"%s").$RANDOM.sh"
else
    out_dir=${seamount}/spm.scripts.${data}/${stamp}
    mkdir -p "${lustre_dir}" "${mem_dir}"
    exec_script="${lustre_dir}/launch_all_$(date +"%s").sh"
    singularity_launch="${lustre_dir}/singularity_launch_${fs}_$(date +"%s").$RANDOM.sh"
fi


echo "" > "${exec_script}"

if [[ ${data} == "preventad" ]]
then
    all_sessions=($(ls -d ${top_dir}/sub-*/ses-*/func/*bold.nii.gz))
elif [[ ${data} == "ds001545" ]]
then
    all_sessions=($(ls -d ${top_dir}/sub-*/func/*bold.nii.gz))
else
    all_sessions=($(ls -d ${top_dir}/*/unprocessed/3T/*fMRI*/*fMRI* | grep -E "[L | R].nii.gz"))
fi
subses=("${all_sessions[@]:${idx}:${nthreads}}")

for epi in ${subses[@]}
do
    echo "***ITERATING THROUGH SESSION***"
    subj=$(echo ${epi} | cut -d'/' -f 7)

    subj_base=$(dirname $(dirname $epi))

    if [[ ${data} == "preventad" ]]
    then
        ses=$(basename ${subj_base})
        anat_file=${subj_base}/anat/${subj}_${ses}_run-001_T1w.nii.gz
    elif [[ ${data} == "ds001545" ]]
    then
        subj=$(echo ${epi} | cut -d'/' -f 6)

        subj_base=$(dirname $(dirname $epi))
        ses="ses-001"
        anat_file=${subj_base}/anat/${subj}_T1w.nii.gz
    else
        ses=$(basename $(dirname $epi))
        anat_file=${subj_base}/T1w_MPR1/${subj}_3T_T1w_MPR1.nii.gz
    fi

    echo anat "${anat_file}"
    echo epi "${epi}"

    anat_bn=$(basename ${anat_file} | sed 's/\.gz//g')
    epi_bn=$(basename ${epi} | sed 's/\.gz//g')

    s_bn=$(echo "spmscript${RANDOM}.m" | sed 's/-/_/g' | sed 's/\.nii//g')

    if [[ "$fs" == "sea" ]]
    then
        script_base=${lustre_dir} #$(echo ${subject_output} | sed 's/seamount/seasource/g' )

        #echo "base" ${script_base}
        #mkdir -p ${script_base}
        script=${script_base}/${s_bn}

        script=$(echo ${script} | sed 's/seasource/seamount/g')
        type="run"
    else
        script_base=${out_dir} #$(echo ${subject_output} | sed 's/seamount/defaultmount/g')
        #mkdir -p ${script_base}

        #echo "base" ${script_base}
        script=${script_base}/${s_bn}

        type="exec"

    fi

    #echo "session output: $session_output"

    input_bn=${subj}_${ses}_input_files
    if [[ ${fs} == "sea" ]]
    then
        input_dir=${base_dir}/${input_bn}
    else
        input_dir=${seamount}/${input_bn}
    fi
    
    rm -rf ${input_dir}
    mkdir -p ${input_dir}
    cp ${anat_file} ${epi} ${input_dir}
    gunzip ${input_dir}/*
    
    anat_file=${input_dir}/${anat_bn}
    epi_file=${input_dir}/${epi_bn}
    chmod 644 ${anat_file} ${epi_file}

    prefetch=".sea_prefetchlist_${stamp}_${RANDOM}"
    echo ${input_bn}/${anat_bn} > ${prefetch}
    echo ${input_bn}/${epi_bn} >> ${prefetch}

    mkdir -p ${DATA_DIR}/scripts ${DATA_DIR}/benchmarks
    python prepare_spm_template.py ${data} ${epi_file} ${anat_file} ${DATA_DIR}/scripts/${s_bn}
    echo "octave ${DATA_DIR}/scripts/launch_${s_bn}" >> ${exec_script}
done

export DATA_DIR=${DATA_DIR}/benchmarks
echo "SINGULARITY LAUNCH ${singularity_launch}"
cat <<EOT >> ${singularity_launch}
#!/bin/bash
singularity ${type} -B /bin/strace -B /mnt/lustre/vhs \
    -B /mnt/lustre/vhs/seamount -B /mnt/lustre/shared \
    -B /mnt/lustre/vhs/defaultmount \
    -B $PWD:$PWD -B $PWD/sea.ini:/sea/sea.ini \
    -B .sea_flushlist:/sea/.sea_flushlist \
    -B .sea_evictlist:/sea/.sea_evictlist \
    -B ${prefetch}:/sea/.sea_prefetchlist \
    -B /disk0/vhs/seasource \
    -B /usr/bin/parallel \
    ghcr.io_valhayot_sea-spm_master-2021-10-11-118c4a69988d.sif \
    bash -c "parallel --jobs ${njobs} < ${exec_script} || echo $?"
EOT
chmod +x ${singularity_launch}

echo "EXP_TIMESTAMP $(date +%s)"
/home/vhs/RUIS/ruis.sh "${singularity_launch}"

if [[ ${fs} == "sea" ]]
then
    for f in $(find ${base_dir} -follow -type f | sort); do echo ${f},$(stat -c%s "${f}") >> ${DATA_DIR}/filesizes.csv ; done
else
    for f in $(find ${out_dir} -follow -type f | sort); do echo ${f},$(stat -c%s "${f}") >> ${DATA_DIR}/filesizes.csv ; done
fi
