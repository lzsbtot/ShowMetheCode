#!/bin/bash

if [ $# -eq 1 ]
then
    sleeptime=$1
else
    sleeptime=5
fi


cluster_IP=$(cluster list | grep -v ACTIVE | awk '{print $1}')

while :
do
    mpstat
    free -k | grep -v Swap
    printf "%-100s\n" -------------------------------------------------------------------------------------------------    
    for IP in $cluster_IP; do ssh $IP "mpstat; free -k | grep -v Swap; printf '%-100s\n' ------------------------------------------------------------------------------------------------"; done;
    sleep $sleeptime
done