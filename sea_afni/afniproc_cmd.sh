#!/bin/bash
#SBATCH --job-name=afni
#SBATCH --nodes=1
#SBATCH --ntasks=1

set -e 

rm -rf /disk0/vhs/seasource
mkdir -p /dev/shm/seasource /dev/shm/defaultmount /disk0/vhs/seasource

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


parallel=16
export DATA_DIR=$4/job-${SLURM_JOB_ID}
stamp=$(basename $4)-$RANDOM

export type="run"
iterations=16

seamount=/mnt/lustre/vhs/seamount
mem_dir=/dev/shm/seasource/afni.results.${data}/${stamp}

disk_dir=/disk0/vhs/seasource/afni.results.${data}/${stamp}

mkdir -p ${disk_dir}


if [[ "${fs}" != "sea" ]]
then
    type="exec"
    seamount=/mnt/lustre/vhs/defaultmount
    out_dir=${seamount}/afni.results.${data}/${stamp}
    mkdir -p "${out_dir}"
    exec_script="${out_dir}/launch_all_$(date +"%s").sh"
else
    out_dir=${seamount}/afni.results.${data}/${stamp}
    mkdir -p "${out_dir}" "${mem_dir}"
    exec_script="${mem_dir}/launch_all_$(date +"%s").sh"
fi


all_subjects=($( cat preventAD_functional.out )) #($(ls ${top_dir}/sub-*/ses-* | grep "/ses-*" | sed 's/://g' ))
singularity_launch="${out_dir}/singularity_launch_${fs}_$(date +"%s").$RANDOM.sh"
echo "" > "${exec_script}"

if [[ ${data} == "preventad" ]]
then
    all_sessions=($(ls -d /mnt/lustre/shared/preventad-open-bids/BIDS_dataset/sub-*/ses-*/func/*bold.nii.gz))
elif [[ ${data} == "ds001545" ]]
then
    all_sessions=($(ls -d ${top_dir}/sub-*/func/*bold.nii.gz))
else
    all_sessions=($(ls -d /mnt/lustre/shared/hcp-squashfs/HCP_1200_data/*/unprocessed/3T/*fMRI*/*fMRI* | grep -E "[L | R].nii.gz"))
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
    #epi_files=($(ls -d ${sses}/*REST*/*REST*.nii.gz | grep -e "[ L|R ].nii.gz"))

    echo anat "${anat_file}"
    echo epi "${epi}"

    subject_output=${out_dir}/${subj}
    session_output=${subject_output}/${ses}
    mkdir -p ${subject_output}

#for (( i=${idx}; i<${nthreads}; i+=${iterations}))
#do  
#    echo "***ITERATION*** ${i}"
#    subses=("${all_subjects[@]:${i}:${parallel}}")
#    for sses in ${subses[@]}
#    do
#        outdir_it=${out_dir}/it-${i}
#        memdir_it=${mem_dir}/it-${i}
#        mkdir -p ${outdir_it} ${memdir_it} ${disk_dir}/it-${i}
#        echo "***ITERATING THROUGH SUBJ***"
#        subj=$(echo ${sses} | cut -d'/' -f 7)
#        ses=$(echo ${sses} | cut -d'/' -f 8)
#        anat_dir=${sses}/anat
#        epi_dir=${sses}/func
#
#        if [ ! -d ${anat_dir} ] || [ ! -d ${epi_dir} ]
#        then
#            continue
#            #n_idx=$(( ${idx} + ${nthreads} ))
#            #echo "SUBJ IDX ${n_idx}"
#            #while [ ! -d ${anat_dir} ] || [ ! -d ${epi_dir} ]
#            #do
#            #    nextsses="${all_subjects[${n_idx}]}"
#            #    subj=$(echo ${nextsses} | cut -d'/' -f 7)
#            #    ses=$(echo ${nextsses} | cut -d'/' -f 8)
#            #    anat_dir=${nextsses}/anat
#            #    epi_dir=${nextsses}/func
#            #    n_idx=$(( ${n_idx} + 1 ))
#            #    echo "SUBJ IDX ${n_idx}"
#
#
#            #done
#        fi
#
#        anat_files=($(ls -d ${anat_dir}/* | grep -E ".*T1w.nii.*"))
#        epi_files=($(ls -d ${epi_dir}/* | grep -E ".*rest.*bold.*.gz"))
#
#        echo anat "${anat_files}"
#        echo epi "${epi_files}"
#
#        subject_output=${outdir_it}/${subj}
#        session_output=${subject_output}/${ses}
#
    if [[ "$fs" == "sea" ]]
    then
        script_base=$(echo ${subject_output} | sed 's/seamount/seasource/g' )

        echo "base" ${script_base}
        mkdir -p ${script_base}
        script=${script_base}/${subj}_${ses}_afniscript
        echo "done if"

        #canat=($(ls ${anat_dir} | grep "T1w"))

        #echo ${canat}
        script=$(echo ${script} | sed 's/seasource/seamount/g')
        type="run"
    else
        script_base=$(echo ${subject_output} | sed 's/seamount/defaultmount/g')
        mkdir -p ${script_base}

        echo "base" ${script_base}
        script=${script_base}/${subj}_${ses}_afniscript

        #canat=($(ls ${anat_dir} | grep "T1w"))

        #echo ${canat}

        type="exec"
        prog="afni_proc.py "

    fi

    #session_output=$(echo ${session_output} | sed 's/afni.results.preventAD\///g')
    #script=$(echo ${script} | sed 's/afni.results.preventAD\///g')
    echo "session output: $session_output"

    launch=${script_base}/${subj}_${ses}_create.sh

    if [[ ${fs} == "sea" ]]
    then
        echo "tcsh -xef ${mem_dir}/${subj}/${subj}_${ses}_afniscript ${subj}-run${RANDOM} 2>&1 ${memdir}/${subj}/output.${subj}_${ses}_afniscript &" >> "${exec_script}"
    else
        echo "tcsh -xef ${script} ${subj}-run${RANDOM} 2>&1 ${script_base}/output.${subj}_${ses}_afniscript &" >> "${exec_script}"

    fi

    cat "${exec_script}"

    singularity ${type} -B /mnt/lustre/vhs \
        -B /mnt/lustre/shared:/mnt/lustre/shared -B $PWD:$PWD \
        -B $PWD/sea.ini:/sea/home/sea.ini -B sea_flusher.sh:/bin/sea_flusher.sh \
        -B /mnt/lustre/vhs/defaultmount \
        -B .sea_flushlist:/sea/home/.sea_flushlist \
        -B .sea_evictlist:/sea/home/.sea_evictlist \
        sea-afni-2021-08-09-060627837d32.sif \
        ${prog}-subj_id ${subj} -script ${script} -scr_overwrite -blocks tshift align tlrc volreg blur mask scale \
        -copy_anat ${anat_file} -dsets ${epi} -tcat_remove_first_trs 0 -align_opts_aea \
        -giant_move -tlrc_base ${PWD}/MNI_avg152T1+tlrc -volreg_align_to MIN_OUTLIER -volreg_align_e2a -volreg_tlrc_warp \
        -blur_size 4.0 -out_dir ${session_output} -html_review_style pythonic

    echo "***AFTER LAUNCH****"
        
done
echo "wait" >> ${exec_script}
cat <<EOT >> ${singularity_launch}
#!/bin/bash
singularity ${type} -B /bin/strace -B /mnt/lustre/vhs \
    -B /mnt/lustre/vhs/seamount -B /mnt/lustre/shared \
    -B /mnt/lustre/vhs/defaultmount \
    -B $PWD:$PWD -B $PWD/sea.ini:/sea/home/sea.ini \
    -B .sea_flushlist:/sea/home/.sea_flushlist \
    -B .sea_evictlist:/sea/home/.sea_evictlist \
    -B /disk0/vhs/seasource \
    -B $PWD/sea-app.sh:/bin/sea-app.sh -B sea_flusher.sh:/bin/sea_flusher.sh \
    sea-afni-2021-08-09-060627837d32.sif \
    bash ${exec_script}
EOT
chmod +x ${singularity_launch}

echo "EXP_TIMESTAMP $(date +%s)"
/home/vhs/RUIS/ruis.sh "${singularity_launch}"

if [[ ${fs} == "sea" ]]
then
    for f in $(find ${mem_dir} -follow -type f | sort); do echo ${f},$(stat -c%s "${f}") >> ${DATA_DIR}/filesizes.csv ; done
else
    for f in $(find ${out_dir} -follow -type f | sort); do echo ${f},$(stat -c%s "${f}") >> ${DATA_DIR}/filesizes.csv ; done
fi
#mkdir -p ${DATA_DIR}/sea-afni.results.preventAD/
#if [[ ${fs} == "sea" ]]
#then
#    mv ${mem_dir} ${DATA_DIR}/sea-afni.results.preventAD/${stamp}
#else
#    mv ${out_dir} ${DATA_DIR}/baseline-afni.results.preventAD/${stamp}
#fi
