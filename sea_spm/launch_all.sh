#!/bin/bash

    #"bash sbatch_spm.sh 1 1 ds001545 0" 
    #"bash sbatch_spm.sh 8 8 ds001545 0" 
    #"bash sbatch_spm.sh 16 16 ds001545 0" 
    #"bash sbatch_spm.sh 1 1 ds001545 6" 
declare -a exp=( 
    "bash sbatch_spm.sh 1 1 preventad 0" 
    "bash sbatch_spm.sh 8 8 preventad 0" 
    "bash sbatch_spm.sh 16 16 preventad 0" 
    "bash sbatch_spm.sh 1 1 hcp 0" 
    "bash sbatch_spm.sh 8 8 hcp 0" 
    "bash sbatch_spm.sh 16 16 hcp 0" 
    "bash sbatch_spm.sh 8 8 ds001545 6" 
    "bash sbatch_spm.sh 16 16 ds001545 6" 
    "bash sbatch_spm.sh 1 1 preventad 6" 
    "bash sbatch_spm.sh 8 8 preventad 6" 
    "bash sbatch_spm.sh 16 16 preventad 6" 
    "bash sbatch_spm.sh 1 1 hcp 6" 
    "bash sbatch_spm.sh 8 8 hcp 6" 
    "bash sbatch_spm.sh 16 16 hcp 6" 
)


#exp=( $(shuf -e "${exp[@]}") )

for e in "${exp[@]}"
do
    while [[ $(squeue | wc -l) -ge 2 ]]
    do
        sleep 5
    done
    echo "launching exp ${e}"
    eval ${e}
done

