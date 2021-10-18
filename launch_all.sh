#!/bin/bash

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

if [[ $1 == "beluga" ]]
then
	declare -a num_elements=( $(for (( i=0; i<"${#exp_beluga[@]}"; i+=1 )); do echo $i; done) )

	num_elements=( $(shuf -e "${num_elements[@]}") )

	for e in "${num_elements[@]}"
	do
	    echo "launching exp ${exp_beluga[$e]}"
	    eval "${exp_beluga[$e]}"
	done
fi

