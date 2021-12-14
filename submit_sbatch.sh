#/bin/bash

totalp=$1
np=$2
data=$3
busy=$4
pipeline=$5
system=$6

conds=( "sea" "default" )
stamp=$(date +%s)
datadir=${PWD}/outputs/${totalp}subs_${np}nps_${busy}bw_${data}_${pipeline}/${stamp}

mkdir -p ${datadir}/logs

rand_id=${RANDOM}-$(date +%s)

if [[ ${system} == "slashbin" ]]
then

	rm -r /mnt/lustre/vhs/defaultmount/* /mnt/lustre/vhs/seamount/* /mnt/lustre/vhs/seasource/* /home/vhs/defaultmount/* /mnt/lustre/vhs/increment_out/*

	mkdir -p /mnt/lustre/vhs/defaultmount /mnt/lustre/vhs/seamount /mnt/lustre/vhs/seasource /home/vhs/defaultmount

	sudo bash /home/shared/dropcache_compute.sh

	for (( i=0; i<${busy}; i+=1 ))
	do
	    sbatch incrementation/launch_incrementation.sh 4
	done

	sleep 60
fi

for (( i=0; i<${totalp}; i+=${np} ))
do
    conds=( $(shuf -e "${conds[@]}") )
    for c in "${conds[@]}"
    do
        if [[ ${system} == "slashbin" ]]
        then
            echo "" > sea_${pipeline}/.sea_flushlist
        else
            cp sea_${pipeline}/.sea_flushlist_withflush sea_${pipeline}/.sea_flushlist
        fi
        echo "sbatch --output ${datadir}/logs/%x-%j-%N.out generic_sub.sh $c $i $np ${stamp} ${data} ${rand_id} ${pipeline} ${system}"
        sbatch --job-name "${c}-${pipeline}" --output ${datadir}/logs/%x-%j-%N.out generic_sub.sh $c $i $np ${datadir} ${data} ${rand_id} ${pipeline} ${system}
    done
done
