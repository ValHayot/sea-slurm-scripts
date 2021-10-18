#!/bin/bash
#SBATCH --account=rrg-glatard
#SBATCH --time=04:00:00
#SBATCH --mem=186G
#SBATCH --cpus-per-task=40
#SBATCH --nodes=1
#SBATCH --ntasks=1


module load singularity/3.8

set -e 

# input args
export fs="$1"
idx="$2"
nthreads="$3"
data="$5"
rand_id="$6"
pipeline="$7"

# set container
if [[ ${pipeline} == "fsl" ]]
then
	container="sea_fsl/ghcr.io_valhayot_sea-fsl_master-2021-10-15-766f50525ed8.sif"
else
	container="sea_afni/ghcr.io_valhayot_sea-afni_master-2021-10-15-7a6b77d50db2.sif"
fi

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

# Configure Sea environment variables
rm -rf  ${SEA_LOCALDIR}
mkdir -p /dev/shm/seasource /dev/shm/defaultmount ${SEA_LOCALDIR}


export DATA_DIR=$4/job-${SLURM_JOB_ID}
stamp=$(basename $4)-$RANDOM

# application output directory
output_dn=${pipeline}.results.${data}/${stamp}

if [[ "${fs}" == "sea" ]]
then
    export type="run"

    # mountpoint path
    seamount=/scratch/vhayots/seamount

    export SEA_LOCALDIR=${SLURM_TMPDIR}/seasource
    export SEA_BASEDIR=/scratch/vhayots/sea_${rand_id}/seasource 

    mkdir -p ${SEA_LOCALDIR}

else
    type="exec"

    if [[ "${fs}" == "tmpfs" ]]
    then
    	seamount=/dev/shm/defaultmount
    else
    	seamount=/scratch/vhayots/default_${rand_id}/defaultmount
    fi

    export SEA_LOCALDIR=${SLURM_TMPDIR} # not in sea so can just set it to the tmpdir to not cause issues with singularity mounts
    export SEA_BASEDIR=${seamount} # not in sea so just mount the default mount

fi

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
    subj=$(echo ${epi} | cut -d'/' -f 10)

    subj_base=$(dirname $(dirname $epi))

    if [[ ${data} == "preventad" ]]
    then
        ses=$(basename ${subj_base})
        anat_file=${subj_base}/anat/${subj}_${ses}_run-001_T1w.nii.gz
    elif [[ ${data} == "ds001545" ]]
    then
        subj=$(echo ${epi} | cut -d'/' -f 5)

        subj_base=$(dirname $(dirname $epi))
        ses="ses-001"
        anat_file=${subj_base}/anat/${subj}_T1w.nii.gz
    else
    	subj=$(echo ${epi} | cut -d'/' -f 5)

    	subj_base=$(dirname $(dirname $epi))
        ses=$(basename $(dirname $epi))
        anat_file=${subj_base}/T1w_MPR1/${subj}_3T_T1w_MPR1.nii.gz
    fi

    echo anat "${anat_file}"
    echo epi "${epi}"

    anat_bn=$(basename ${anat_file})
    epi_bn=$(basename ${epi})

    subject_output=${seamount}/${output_dn}/${subj}
    session_output=${subject_output}/${ses}
    script_base=${DATA_DIR}/scripts
    mkdir -p ${script_base} ${DATA_DIR}/benchmarks ${lustre_dir}/${subj}

    if [[ ${pipeline} == "fsl" ]]
    then
	    bet_file=${session_output}/${subj}_${ses}_T1w_BET.nii.gz

	    echo BET FILE ${bet_file}


	    script=${script_base}/${subj}_${ses}_featscript.fsf

	    prefetch=".sea_prefetchlist"
	    touch ${prefetch}

	    export ANAT=${bet_file}/T1_biascorr_brain.nii.gz
	    export EPI=${epi}
	    export OUTPUTDIR=${session_output}/processed

	    echo "output dir ${OUTPUTDIR}.feat"
	    multiply () {
		local IFS='*'
		echo "$(( $* ))"
	    }

	    info=$(singularity exec -B /scratch/vhayots ${container} fslinfo ${EPI})
	    dims=($(echo "${info}" | grep "^dim" | awk '{print $2}'))

	    export TOTAL_VOXELS=$(multiply "${dims[@]}")
	    export TOTAL_VOLUMES=${dims[3]}
	    export TR=$(echo "${info}" | grep "^pixdim4" | awk '{print $2}')

	    echo "total voxels: ${TOTAL_VOXELS}"
	    echo "total volumes: ${TOTAL_VOLUMES}"
	    echo "TR: ${TR}"

	    cat ../design.fsf | envsubst > ${script}
	    echo "bash -c \"source /usr/local/fsl/etc/fslconf/fsl.sh && fsl_anat --nocrop --nobias -i ${anat_file} -o ${bet_file} && feat ${script}\"" >> ${exec_script}
    else

	    prefetch=".sea_prefetchlist"
	    touch ${prefetch}

            script=${script_base}/${subj}_${ses}_afniscript
	    echo "tcsh -xef ${script} ${subj}-run${RANDOM} 2>&1 ${script_base}/output.${subj}_${ses}_afniscript " >> "${exec_script}"

	    cat "${exec_script}"

	    singularity ${type} -B /scratch/vhayots \
                -B /home/vhayots:/home/vhayots -B sea.ini:/sea/sea.ini \
	        -B sea_${pipeline}/.sea_flushlist:/sea/.sea_flushlist \
		-B sea_${pipeline}/.sea_evictlist:/sea/.sea_evictlist \
		-B ${prefetch}:/sea/.sea_prefetchlist \
		-B ${SEA_LOCALDIR} \
		-B $(readlink -f /home/vhayots/projects/rrg-glatard/cbrain-conp/conp-dataset) \
		-B ${top_dir} \
		-B ${SEA_BASEDIR} \
		${container} \
		afni_proc.py -subj_id ${subj} -script ${script} -scr_overwrite -blocks tshift align tlrc volreg blur mask scale \
		-copy_anat ${anat_file} -dsets ${epi} -tcat_remove_first_trs 0 -align_opts_aea \
		-giant_move -tlrc_base ${PWD}/sea_afni/MNI_avg152T1+tlrc -volreg_align_to MIN_OUTLIER -volreg_align_e2a -volreg_tlrc_warp \
		-blur_size 4.0 -out_dir ${session_output} -html_review_style pythonic
    fi


done

export DATA_DIR=${DATA_DIR}/benchmarks
echo "SINGULARITY LAUNCH ${singularity_launch}"

cat <<EOT >> ${singularity_launch}
#!/bin/bash
singularity ${type} -B /scratch/vhayots \
    -B /home/vhayots:/home/vhayots -B sea.ini:/sea/sea.ini \
    -B sea_${pipeline}/.sea_flushlist:/sea/.sea_flushlist \
    -B sea_${pipeline}/.sea_evictlist:/sea/.sea_evictlist \
    -B ${prefetch}:/sea/.sea_prefetchlist \
    -B ${SEA_LOCALDIR} \
    -B $(readlink -f /home/vhayots/projects/rrg-glatard/cbrain-conp/conp-dataset) \
    -B ${top_dir} \
    -B ${SEA_BASEDIR} \
    -B /cvmfs/soft.computecanada.ca/gentoo/2020/usr/bin/parallel \
    ${container} \
    /cvmfs/soft.computecanada.ca/gentoo/2020/usr/bin/parallel --jobs ${nthreads} < ${exec_script} || echo $?
EOT
chmod +x ${singularity_launch}

echo "EXP_TIMESTAMP $(date +%s)"
/home/vhayots/RUIS/ruis.sh "${singularity_launch}"

if [[ ${fs} == "sea" ]]
then
    for f in $(find ${lustre_dir} -follow -type f | sort); do echo ${f},$(stat -c%s "${f}") >> ${DATA_DIR}/filesizes.csv ; done
else
    for f in $(find ${lustre_dir} -follow -type f | sort); do echo ${f},$(stat -c%s "${f}") >> ${DATA_DIR}/filesizes.csv ; done
fi
