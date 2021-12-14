#!/bin/bash
#SBATCH --account=rrg-glatard
#SBATCH --time=04:00:00
#SBATCH --mem=186G
#SBATCH --cpus-per-task=40
#SBATCH --nodes=1
#SBATCH --ntasks=1


set -e 

# input args
export fs="$1"
idx="$2"
nthreads="$3"
data="$5"
rand_id="$6"
pipeline="$7"
system="$8"
fs_type="$9"

# set container
if [[ ${pipeline} == "fsl" ]]
then
	container="sea_fsl/ghcr.io_valhayot_sea-fsl_master-2021-10-15-766f50525ed8.sif"
elif [[ ${pipeline} == "afni" ]]
then
	container="sea_afni/ghcr.io_valhayot_sea-afni_master-2021-10-15-7a6b77d50db2.sif"
else
	container="sea_spm/ghcr.io_valhayot_sea-spm_master-2021-10-15-cd52991aa994.sif"
fi

if [[ ${system} == "beluga" ]]
then

    module load singularity/3.8

    # Get root of data
    if [[ ${data} == "preventad" ]]
    then
        top_dir=$(readlink -f /home/vhayots/projects/rrg-glatard/cbrain-conp/conp-dataset/projects/preventad-open-bids/BIDS_dataset)
    elif [[ ${data} == "ds001545" ]]
    then
        top_dir=/scratch/vhayots/ds001545
    else
        top_dir=/scratch/vhayots/HCP
    fi
    export CONP_HOME=$(readlink -f /home/vhayots/projects/rrg-glatard/cbrain-conp/conp-dataset)
    export PARALLEL_BIN=/cvmfs/soft.computecanada.ca/gentoo/2020/usr/bin/parallel
    export RUIS_HOME=/home/vhayots/RUIS/ruis.sh
    export LUSTRE_HOME=/scratch/vhayots
else
    # Get root of data
    if [[ ${data} == "preventad" ]]
    then
        top_dir=/mnt/lustre/shared/preventad-open-bids/BIDS_dataset
    elif [[ ${data} == "ds001545" ]]
    then
        top_dir=/mnt/lustre/shared/ds001545
    else
        top_dir=/mnt/lustre/shared/hcp-squashfs/HCP_1200_data
    fi
    export CONP_HOME=/mnt/lustre/shared/preventad-open-bids
    export PARALLEL_BIN=/usr/bin/parallel
    export RUIS_HOME=/home/vhs/RUIS/ruis.sh
    export SLURM_TMPDIR=/disk0/vhs
    export LUSTRE_HOME=/mnt/lustre/vhs/results
fi


export DATA_DIR=$4/job-${SLURM_JOB_ID}
stamp=$(basename $4)-$RANDOM

# application output directory
output_dn=${pipeline}.results.${data}/${stamp}

if [[ "${fs}" == "sea" ]]
then
    export type="run"

    # mountpoint path
    export SEAMOUNT=${LUSTRE_HOME}/seamount

    export SEA_LOCALDIR=${SLURM_TMPDIR}/seasource
    export SEA_BASEDIR=${LUSTRE_HOME}/sea_${pipeline}_${data}_${SLURM_JOB_ID}/seasource 

    rm -rf  ${SEA_LOCALDIR}
    mkdir -p ${SEA_LOCALDIR} ${SEAMOUNT}

else
    type="exec"

    if [[ "${fs}" == "tmpfs"* ]]
    then
    	export SEAMOUNT=/dev/shm/defaultmount
    else
        export SEAMOUNT=${LUSTRE_HOME}/default_${pipeline}_${data}_${SLURM_JOB_ID}/defaultmount
    fi

    export SEA_LOCALDIR=${SLURM_TMPDIR} # not in sea so can just set it to the tmpdir to not cause issues with singularity mounts
    export SEA_BASEDIR=${SEAMOUNT} # not in sea so just mount the default mount

fi

echo "BASE DIRECTORY: ${SEA_BASEDIR}"

# Configure Sea environment variables
mkdir -p /dev/shm/seasource

lustre_dir=${SEA_BASEDIR}/${output_dn}
mem_dir=/dev/shm/seasource/${output_dn}
disk_dir=${SEA_LOCALDIR}/${output_dn}

mkdir -p "${lustre_dir}"
exec_script="${lustre_dir}/launch_all_$(date +"%s").sh"
singularity_launch="${lustre_dir}/singularity_launch_${fs}_$(date +"%s").$RANDOM.sh"

# empty contents of ${exec_script} if it already exists
echo "" > "${exec_script}"

# get all the epi files in the dataset
if [[ ${data} == "preventad" ]]
then
    all_sessions=($(ls -d ${top_dir}/sub-*/ses-*/func/*bold.nii.gz))
elif [[ ${data} == "ds001545" ]]
then
    all_sessions=($(ls -d ${top_dir}/sub-*/func/*bold.nii.gz))
else
    all_sessions=($(ls -d ${top_dir}/*/unprocessed/3T/*fMRI*/*fMRI* | grep -E "[L | R].nii.gz"))
fi

# only care about the epi files that we can process given thread
subses=("${all_sessions[@]:${idx}:${nthreads}}")

# iterate through all epi files
for epi in ${subses[@]}
do
    echo "***ITERATING THROUGH SESSION***"

    if [[ ${data} == "preventad" ]]
    then

        if [[ ${system} == "beluga" ]]
        then
            subj=$(echo ${epi} | cut -d'/' -f 10)
        else
            subj=$(echo ${epi} | cut -d'/' -f 7)
        fi

        subj_base=$(dirname $(dirname $epi))
        ses=$(basename ${subj_base})
        anat_file=${subj_base}/anat/${subj}_${ses}_run-001_T1w.nii.gz
        ses=${ses}_$(echo ${epi} | cut -d"_" -f4,5 )
    elif [[ ${data} == "ds001545" ]]
    then

        if [[ ${system} == "beluga" ]]
        then
            subj=$(echo ${epi} | cut -d'/' -f 5)
        else
            subj=$(echo ${epi} | cut -d'/' -f 6)
        fi

        subj_base=$(dirname $(dirname $epi))
        ses=$(echo ${epi} | cut -d"_" -f 3)
        anat_file=${subj_base}/anat/${subj}_T1w.nii.gz
    else
        if [[ ${system} == "beluga" ]]
        then
    	    subj=$(echo ${epi} | cut -d'/' -f 5)
        else
    	    subj=$(echo ${epi} | cut -d'/' -f 7)
        fi

    	subj_base=$(dirname $(dirname $epi))
        ses=$(basename $(dirname $epi))
        anat_file=${subj_base}/T1w_MPR1/${subj}_3T_T1w_MPR1.nii.gz
    fi

    echo anat "${anat_file}"
    echo epi "${epi}"

    anat_bn=$(basename ${anat_file})
    epi_bn=$(basename ${epi})

    subject_output=${SEAMOUNT}/${output_dn}/${subj}
    session_output=${subject_output}/${ses}-${RANDOM}
    script_base=${DATA_DIR}/scripts
    mkdir -p ${script_base} ${DATA_DIR}/benchmarks ${lustre_dir}/${subj}

    if [[ ${fs_type} == "tmpfs_all" && ! ${pipeline} == "spm" ]]
    then
        input_dir="/dev/shm/inputs/${subj}_${ses}" 
        mkdir -p ${input_dir}
        cp ${epi} ${anat_file} ${input_dir}
        export EPI=${input_dir}/$(basename ${epi})
        anat_file=${input_dir}/$(basename ${anat_file})
    else
        export EPI=${epi}
    fi

    if [[ ${pipeline} == "fsl" ]]
    then
	    mkdir -p ${lustre_dir}/${subj}/${ses}
	    bet_file=${session_output}/${subj}_${ses}_T1w_BET.nii.gz

	    echo BET DIR ${bet_file}.anat

	    script=${script_base}/${subj}_${ses}_featscript.fsf

	    prefetch=".sea_prefetchlist"
	    touch ${prefetch}

	    export ANAT=${bet_file}/T1_biascorr_brain.nii.gz
	    export OUTPUTDIR=${session_output}/processed

        echo "epi file ${EPI}"
	    echo "output dir ${OUTPUTDIR}.feat"
	    multiply () {
		local IFS='*'
		echo "$(( $* ))"
	    }

        info=$(singularity exec -B ${LUSTRE_HOME} -B ${top_dir} -B ${CONP_HOME} ${container} fslinfo ${EPI})
	    dims=($(echo "${info}" | grep "^dim" | awk '{print $2}'))

	    export TOTAL_VOXELS=$(multiply "${dims[@]}")
	    export TOTAL_VOLUMES=${dims[3]}
	    export TR=$(echo "${info}" | grep "^pixdim4" | awk '{print $2}')

	    echo "total voxels: ${TOTAL_VOXELS}"
	    echo "total volumes: ${TOTAL_VOLUMES}"
	    echo "TR: ${TR}"

	    cat sea_fsl/design.fsf | envsubst > ${script}
	    echo "bash -c \"source /usr/local/fsl/etc/fslconf/fsl.sh && fsl_anat --nocrop --nobias -i ${anat_file} -o ${bet_file} && feat ${script}\"" >> ${exec_script}
    elif [[ ${pipeline} == "afni" ]]
    then

	    prefetch=".sea_prefetchlist"
	    touch ${prefetch}

        script=${script_base}/${subj}_${ses}_afniscript
	    echo "tcsh -xef ${script} ${subj}-run${RANDOM} 2>&1 ${script_base}/output.${subj}_${ses}_afniscript " >> "${exec_script}"

	    cat "${exec_script}"

	    singularity ${type} \
        -B sea.ini:/sea/sea.ini \
	    -B sea_${pipeline}/.sea_flushlist:/sea/.sea_flushlist \
		-B sea_${pipeline}/.sea_evictlist:/sea/.sea_evictlist \
		-B ${prefetch}:/sea/.sea_prefetchlist \
        -B ${LUSTRE_HOME} \
        -B ${SEAMOUNT} \
		-B ${SEA_LOCALDIR} \
		-B ${CONP_HOME} \
		-B ${top_dir} \
		-B ${SEA_BASEDIR} \
		${container} \
		afni_proc.py -subj_id ${subj} -script ${script} -scr_overwrite -blocks tshift align tlrc volreg blur mask scale \
		-copy_anat ${anat_file} -dsets ${EPI} -tcat_remove_first_trs 0 -align_opts_aea \
		-giant_move -tlrc_base ${PWD}/sea_afni/MNI_avg152T1+tlrc -volreg_align_to MIN_OUTLIER -volreg_align_e2a -volreg_tlrc_warp \
		-blur_size 4.0 -out_dir ${session_output} -html_review_style pythonic
    else
	mkdir -p ${lustre_dir}/${subj}/${ses}
        anat_bn=$(basename ${anat_file} | sed 's/\.gz//g')
        epi_bn=$(basename ${epi} | sed 's/\.gz//g')
        s_bn=$(echo "spmscript_${RANDOM}.m")

        script=${script_base}/${s_bn}

        input_bn=${subj}_${ses}_input_files
        input_dir=${lustre_dir}/${input_bn}

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
        
        source sea_spm/venv/bin/activate
        python sea_spm/prepare_spm_template.py ${data} ${epi_file} ${anat_file} ${DATA_DIR}/scripts/${s_bn} ${SEA_LOCALDIR} ${SEAMOUNT}
        echo "octave ${DATA_DIR}/scripts/launch_${s_bn}" >> ${exec_script}
    fi
done

export DATA_DIR=${DATA_DIR}/benchmarks
echo "SINGULARITY LAUNCH ${singularity_launch}"

cat <<EOT >> ${singularity_launch}
#!/bin/bash
singularity ${type} \
    -B sea.ini:/sea/sea.ini \
    -B sea_${pipeline}/.sea_flushlist:/sea/.sea_flushlist \
    -B sea_${pipeline}/.sea_evictlist:/sea/.sea_evictlist \
    -B ${prefetch}:/sea/.sea_prefetchlist \
    -B ${LUSTRE_HOME} \
    -B ${SEAMOUNT} \
    -B ${SEA_LOCALDIR} \
    -B ${CONP_HOME} \
    -B ${top_dir} \
    -B ${SEA_BASEDIR} \
    -B ${PARALLEL_BIN} \
    ${container} \
    ${PARALLEL_BIN} --jobs ${nthreads} < ${exec_script} || echo $?
EOT
chmod +x ${singularity_launch}

echo "EXP_TIMESTAMP $(date +%s)"
eval "${RUIS_HOME} ${singularity_launch}"
echo "EXP_ENDTIMESTAMP $(date +%s)"

if [[ ${fs} == "sea" ]]
then
    for f in $(find ${lustre_dir} -follow -type f | sort); do echo ${f},$(stat -c%s "${f}") >> ${DATA_DIR}/filesizes.csv ; done
    for f in $(find ${mem_dir} -follow -type f | sort); do echo ${f},$(stat -c%s "${f}") >> ${DATA_DIR}/filesizes.csv ; done
    for f in $(find ${disk_dir} -follow -type f | sort); do echo ${f},$(stat -c%s "${f}") >> ${DATA_DIR}/filesizes.csv ; done
else
    for f in $(find ${lustre_dir} -follow -type f | sort); do echo ${f},$(stat -c%s "${f}") >> ${DATA_DIR}/filesizes.csv ; done
fi

if [ -f /tmp/sea.log ]
then
    mv /tmp/sea.log ${DATA_DIR}/sea.log
fi

rm ${prefetch}
