#!/usr/bin/bash

if [ $# -eq 1 ]
then
    sleeptime=$1
else
    sleeptime=5
fi

while :
do
    for blade in `cat /etc/cluster/nodes/payload/*/hostname`; do ssh $blade "mpstat; free -k | grep -v Swap; printf '%-100s\n' ------------------------------------------------------------------------------------------------"; done;
    sleep $sleeptime
done