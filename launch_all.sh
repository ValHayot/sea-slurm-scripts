#!/bin/bash

cluster=$1
fs_type=$2 #options == normal; tmpfs_all; tmpfs_out

declare -a exp_beluga=( 
    "bash submit_sbatch.sh 1 1 ds001545 0 afni" 
    "bash submit_sbatch.sh 8 8 ds001545 0 afni" 
    "bash submit_sbatch.sh 16 16 ds001545 0 afni" 
    "bash submit_sbatch.sh 1 1 preventad 0 afni" 
    "bash submit_sbatch.sh 8 8 preventad 0 afni" 
    "bash submit_sbatch.sh 16 16 preventad 0 afni" 
    "bash submit_sbatch.sh 1 1 hcp 0 afni" 
    "bash submit_sbatch.sh 8 8 hcp 0 afni" 
    "bash submit_sbatch.sh 16 16 hcp 0 afni" 
)

#declare -a exp_slashbin=( 
#    "bash submit_sbatch.sh 1 1 ds001545 6 afni" 
#    "bash submit_sbatch.sh 8 8 ds001545 6 afni" 
#    "bash submit_sbatch.sh 16 16 ds001545 6 afni" 
#    "bash submit_sbatch.sh 1 1 preventad 6 afni" 
#    "bash submit_sbatch.sh 8 8 preventad 6 afni" 
#    "bash submit_sbatch.sh 16 16 preventad 6 afni" 
#    "bash submit_sbatch.sh 1 1 hcp 6 afni" 
#    "bash submit_sbatch.sh 8 8 hcp 6 afni" 
#    "bash submit_sbatch.sh 16 16 hcp 6 afni" 
#)

#declare -a exp_slashbin=( 
#    "bash submit_sbatch.sh 1 1 ds001545 6 afni" 
#    "bash submit_sbatch.sh 8 8 ds001545 6 afni" 
#    "bash submit_sbatch.sh 16 16 ds001545 6 afni" 
#    "bash submit_sbatch.sh 1 1 preventad 6 afni" 
#    "bash submit_sbatch.sh 8 8 preventad 6 afni" 
#    "bash submit_sbatch.sh 16 16 preventad 6 afni" 
#    "bash submit_sbatch.sh 1 1 hcp 6 afni" 
#    "bash submit_sbatch.sh 8 8 hcp 6 afni" 
#    "bash submit_sbatch.sh 16 16 hcp 6 afni" 
#    "bash submit_sbatch.sh 1 1 ds001545 0 afni" 
#    "bash submit_sbatch.sh 8 8 ds001545 0 afni" 
#    "bash submit_sbatch.sh 16 16 ds001545 0 afni" 
#    "bash submit_sbatch.sh 1 1 preventad 0 afni" 
#    "bash submit_sbatch.sh 8 8 preventad 0 afni" 
#    "bash submit_sbatch.sh 16 16 preventad 0 afni" 
#    "bash submit_sbatch.sh 1 1 hcp 0 afni" 
#    "bash submit_sbatch.sh 8 8 hcp 0 afni" 
#    "bash submit_sbatch.sh 16 16 hcp 0 afni" 
#)

#declare -a exp_slashbin=( 
#    "bash submit_sbatch.sh 1 1 ds001545 6 spm" 
#    "bash submit_sbatch.sh 8 8 ds001545 6 spm" 
#    "bash submit_sbatch.sh 16 16 ds001545 6 spm" 
#    "bash submit_sbatch.sh 1 1 preventad 6 spm" 
#    "bash submit_sbatch.sh 8 8 preventad 6 spm" 
#    "bash submit_sbatch.sh 16 16 preventad 6 spm" 
#    "bash submit_sbatch.sh 1 1 hcp 6 spm" 
#    "bash submit_sbatch.sh 8 8 hcp 6 spm" 
#    "bash submit_sbatch.sh 16 16 hcp 6 spm" 
#)

#        "bash submit_sbatch.sh 1 1 ds001545 6 fsl slashbin ${fs_type}" 
#        "bash submit_sbatch.sh 8 8 ds001545 6 fsl slashbin ${fs_type}" 
#        "bash submit_sbatch.sh 16 16 ds001545 6 fsl slashbin ${fs_type}" 
#        "bash submit_sbatch.sh 1 1 preventad 6 fsl slashbin ${fs_type}"
#        "bash submit_sbatch.sh 8 8 preventad 6 fsl slashbin ${fs_type}" 
#        "bash submit_sbatch.sh 16 16 preventad 6 fsl slashbin ${fs_type}" 
#        "bash submit_sbatch.sh 1 1 hcp 6 fsl slashbin ${fs_type}" 
#        "bash submit_sbatch.sh 8 8 hcp 6 fsl slashbin ${fs_type}" 
#        "bash submit_sbatch.sh 16 16 hcp 6 fsl slashbin ${fs_type}" 

if [[ ${fs_type} == "tmpfs"* ]]
then
    declare -a exp_slashbin=( 
        "bash submit_sbatch.sh 1 1 ds001545 0 fsl slashbin ${fs_type}"
        "bash submit_sbatch.sh 8 8 ds001545 0 fsl slashbin ${fs_type}"
        "bash submit_sbatch.sh 16 16 ds001545 0 fsl slashbin ${fs_type}" 
        "bash submit_sbatch.sh 1 1 preventad 0 fsl slashbin ${fs_type}"
        "bash submit_sbatch.sh 8 8 preventad 0 fsl slashbin ${fs_type}"
        "bash submit_sbatch.sh 16 16 preventad 0 fsl slashbin ${fs_type}" 
        "bash submit_sbatch.sh 1 1 hcp 0 fsl slashbin ${fs_type}" 
        "bash submit_sbatch.sh 8 8 hcp 0 fsl slashbin ${fs_type}" 
        "bash submit_sbatch.sh 16 16 hcp 0 fsl slashbin ${fs_type}" 
        "bash submit_sbatch.sh 1 1 ds001545 0 afni slashbin ${fs_type}"
        "bash submit_sbatch.sh 8 8 ds001545 0 afni slashbin ${fs_type}"
        "bash submit_sbatch.sh 16 16 ds001545 0 afni slashbin ${fs_type}" 
        "bash submit_sbatch.sh 1 1 preventad 0 afni slashbin ${fs_type}"
        "bash submit_sbatch.sh 8 8 preventad 0 afni slashbin ${fs_type}"
        "bash submit_sbatch.sh 16 16 preventad 0 afni slashbin ${fs_type}" 
        "bash submit_sbatch.sh 1 1 hcp 0 afni slashbin ${fs_type}" 
        "bash submit_sbatch.sh 8 8 hcp 0 afni slashbin ${fs_type}" 
        "bash submit_sbatch.sh 16 16 hcp 0 afni slashbin ${fs_type}" 
        "bash submit_sbatch.sh 1 1 ds001545 0 spm slashbin ${fs_type}"
        "bash submit_sbatch.sh 8 8 ds001545 0 spm slashbin ${fs_type}"
        "bash submit_sbatch.sh 16 16 ds001545 0 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 1 1 preventad 0 spm slashbin ${fs_type}"
        "bash submit_sbatch.sh 8 8 preventad 0 spm slashbin ${fs_type}"
        "bash submit_sbatch.sh 16 16 preventad 0 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 1 1 hcp 0 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 8 8 hcp 0 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 16 16 hcp 0 spm slashbin ${fs_type}" 
    )
else
    declare -a exp_slashbin=( 
        "bash submit_sbatch.sh 1 1 ds001545 6 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 1 1 preventad 6 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 1 1 hcp 6 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 1 1 ds001545 0 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 1 1 preventad 0 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 1 1 hcp 0 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 8 8 ds001545 6 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 8 8 preventad 6 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 8 8 hcp 6 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 8 8 ds001545 0 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 8 8 preventad 0 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 8 8 hcp 0 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 16 16 ds001545 6 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 16 16 preventad 6 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 16 16 hcp 6 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 16 16 ds001545 0 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 16 16 preventad 0 spm slashbin ${fs_type}" 
        "bash submit_sbatch.sh 16 16 hcp 0 spm slashbin ${fs_type}" 
    )
fi


if [[ ${cluster} == "beluga" ]]
then
	declare -a num_elements=( $(for (( i=0; i<"${#exp_beluga[@]}"; i+=1 )); do echo $i; done) )

	num_elements=( $(shuf -e "${num_elements[@]}") )

	for e in "${num_elements[@]}"
	do
	    echo "launching exp ${exp_beluga[$e]}"
	    eval "${exp_beluga[$e]} beluga"
	done
else
	declare -a num_elements=( $(for (( i=0; i<"${#exp_slashbin[@]}"; i+=1 )); do echo $i; done) )

	num_elements=( $(shuf -e "${num_elements[@]}") )

	for e in "${num_elements[@]}"
	do
        while [[ $(squeue | grep -E 'sea|default' | wc -l) -ge 1 ]]
        do
            sleep 5
        done


        echo "restarting any drained lustre nodes"
        squeue
        scancel -u vhs

        while [[ $(squeue | wc -l) -ge 2 ]]
        do
            sleep 5
        done

        sudo bash /home/shared/resume_lustre.sh

	    echo "launching exp ${exp_slashbin[$e]}"
	    eval "${exp_slashbin[$e]}"
	done
fi
