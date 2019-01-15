#!/bin/bash

############## tbe ############

if  [ $# -eq 1 ]
then
    TC="$1"
else
    TC="default-testcase"
    echo
    echo "Using default test case name: default-testcase "
    echo "Please provide testcase-name as input parameter next time!"
    echo "For example: ./capture-tcpdump.sh Testcase-1-1-1"
    echo
    # exit 1;
fi

CAPDIR=/cluster/tmp
DATETIME=`date +"%Y%m%d-T%H%M%S"`
PLBLADES=`cat /etc/cluster/nodes/payload/*/hostname`
# EVIPXML=/storage/system/config/evip-apr9010467/evip.xml

if [ ! -d $CAPDIR ]
then
    echo "Directory: $CAPDIR is not existing, Create it now!"
    mkdir -p $CAPDIR
fi

function get_fee{
    ip netns list | egrep fee\|FEE
}

function fee-tcpdump{
    ip netns exec $fee tcpdump -i any -w ${CAPDIR}/${TC}/${pl}-${fee}-${datetime}.pcap > /dev/null &
}

function stop_tcpdump {
    for blade in $PLBLADES; do ssh $blade "pkill tcpdump" > /dev/null; done
    echo "fee-tcpdump stopped!"
    return 0
}

mkdir $CAPDIR/${TC}

for pl in $PLBLADES
do
    ssh $pl "for fee in get_fee; do fee-tcpdump; done"
done



