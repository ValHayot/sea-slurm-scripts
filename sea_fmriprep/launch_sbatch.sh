#/bin/bash

rm -r /mnt/lustre/vhs/defaultmount/* /mnt/lustre/vhs/seamount/* /mnt/lustre/vhs/seasource/* /home/vhs/defaultmount/* /mnt/lustre/vhs/increment_out/*

mkdir -p /mnt/lustre/vhs/defaultmount /mnt/lustre/vhs/seamount /mnt/lustre/vhs/seasource /home/vhs/defaultmount

sudo bash /home/shared/dropcache_compute.sh

totalp=$1
np=$2
busy=$3

conds=( "sea" "default" )
stamp=$(date +%s)
datadir=outputs/${totalp}subs_${np}nps_${busy}bw_preventad/${stamp}
mkdir -p ${datadir}/logs

for (( i=0; i<${busy}; i+=1 ))
do
    sbatch launch_incrementation.sh
done

sleep 60

for (( i=0; i<${totalp}; i+=${np} ))
do
    conds=( $(shuf -e "${conds[@]}") )
    for c in "${conds[@]}"
    do

        echo "sbatch --job-name "${c}-fmriprep" --output ${datadir}/logs/%x-%j-%N.out launch_preventad.sh $i $np ${datadir} ${c}"
        sbatch  --job-name "${c}-fmriprep" --output ${datadir}/logs/%x-%j-%N.out launch_preventad.sh $i $np ${datadir} ${c}
    done
done
