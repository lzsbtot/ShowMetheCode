#!/bin/bash

##########################################################################
# This script can be used to take tcpdumps in all PLs of a vCSCF/vMTAS.
# Please do not use it in commerical environment!
# Author: EFJKMNT 
# email: roy.liu@ericsson.com
##########################################################################

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
EVIPXML="/storage/system/config/evip-apr9010467/evip.xml"

if [ ! -d $CAPDIR ]
then
    echo "Directory: $CAPDIR is not existing, Create it now!"
    mkdir -p $CAPDIR
fi

if [ -f $EVIPXML ]
then
    TRAFFICIP=`cat $EVIPXML | grep "vip address" | awk -F "[\"\"]" '{print $2}'`
else
    echo "Error: $EVIPXML is not existing! Check the evip.xml directory first!"
    exit 1;
fi

function get_host {
# get traffic IPs to prepare tcpdump filter
    TCPDUMP_HOST=""
    for ip in $TRAFFICIP
    do
        if [ -z "${TCPDUMP_HOST}" ]
        then
            TCPDUMP_HOST="\\(${ip}"
        else
            TCPDUMP_HOST="${TCPDUMP_HOST} or ${ip}"
        fi
    done
    TCPDUMP_HOST="${TCPDUMP_HOST}\\)"
    return 0
}

function start_tcpdump {
# start tcpdump in all PLs
    echo "tcpdump filter IP:"
    for ip in $TRAFFICIP
    do
        echo $ip
    done
    echo
    echo
    for blade in $PLBLADES
    do
        ssh $blade "tcpdump -i any host $TCPDUMP_HOST -w ${CAPDIR}/${TC}-${DATETIME}-${blade}.pcap" >& /dev/null &
        echo "tcpdump is running on ${blade}"
    done
    echo
    return 0
}

function stop_tcpdump {
# stop all tcpdump process in PL, might also kill tcpdump process running by someone else, be careful
    for blade in $PLBLADES; do ssh $blade "pkill tcpdump" >& /dev/null; done
    echo "Tcpdump stopped!"
    return 0
}

get_host
start_tcpdump

echo
echo "Press ENTER key to stop tcpdump"
echo
read A
echo "Tcpdump will stop 3 seconds later!"
sleep 3

stop_tcpdump
sleep 1

echo
echo "Result Pcap Files:"
echo $CAPDIR
cd $CAPDIR
for blade in $PLBLADES; do echo `ls -l ${TC}-${DATETIME}-${blade}.pcap`; done

echo
echo "Done!"
exit 0