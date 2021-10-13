#/bin/bash

rm -rf /mnt/lustre/vhs/defaultmount/* /mnt/lustre/vhs/seamount/* /mnt/lustre/vhs/seasource/* /home/vhs/defaultmount/* /mnt/lustre/vhs/increment_out/*

mkdir -p /mnt/lustre/vhs/defaultmount /mnt/lustre/vhs/seamount /mnt/lustre/vhs/seasource /home/vhs/defaultmount

sudo bash /home/shared/dropcache_compute.sh

totalp=$1
np=$2
data=$3
busy=$4

conds=(  "sea" "default" )
stamp=$(date +%s)
datadir=$PWD/outputs/${totalp}subs_${np}nps_${busy}bw_${data}/${stamp}
mkdir -p ${datadir}/logs

for (( i=0; i<${busy}; i+=1 ))
do
    sbatch ../incrementation/launch_incrementation.sh
done

sleep 60

for (( i=0; i<${totalp}; i+=${np} ))
do
    conds=( $(shuf -e "${conds[@]}") )
    for c in "${conds[@]}"
    do
        echo "sbatch --output ${datadir}/logs/%x-%j-%N.out spm_cmd.sh $c $i $np ${stamp}"
        sbatch --job-name "${c}-spm-${data}" --output ${datadir}/logs/%x-%j-%N.out spm_cmd.sh $c $i $np ${datadir} ${data}
    done
done
