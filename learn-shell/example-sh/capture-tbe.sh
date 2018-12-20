#!/bin/bash

##########################################################################
# This script can be used to take tcpdumps in all PLs of a vMTAS vnf.
# Please do not use it in commerical environment!
# Author: EFJKMNT 
##########################################################################


if  [ $# -eq 2 ]
then
    TC="$1"
    OPTION="$2"
else
    echo "Usage: "
    echo
    echo "take tcpdump on evip-fee: ./<scripts-name> <test-case-name> -f"
    echo "take tcpdump on application: ./<scripts-name> <test-case-name> -a"
    echo
    exit 1;
fi

################### log funciton tbd ####################
# function logMsg()
# {
#     logger -t $SYSLOG_TAG $1 -f ${LOG_FILE}
#     echo $1
# }

DIR="/cluster/tmp/${TC}"
DATETIME=`date +"%Y%m%d-T%H%M%S"`
PLBLADES=`cat /etc/cluster/nodes/payload/*/hostname`
EVIPXML="/storage/system/config/evip-apr9010467/evip.xml"


if [ ! -d $DIR ]
then
    echo "Directory: $DIR is not existing, Create it now!"
    mkdir -p $DIR
fi

if [ -f $EVIPXML ]
then
    TRAFFICIP=`cat $EVIPXML | grep "vip address" | awk -F "[\"\"]" '{print $2}'`
else
    echo "Error: $EVIPXML is not existing! Check the evip.xml directory first!"
    exit 2;
fi


function check-pl-status {
# check if all PLs are reachable from SC-MIP
    echo "checking if all PLs are reachable"
    for blade in $PLBLADES
    do
        ssh $blade "exit" > /dev/null
        if [ $? -ne 0]
        then
            echo "${blade} is not reachable now! tcpdump will be taken from other PLs"
            echo "Please check if ${blade} status is expected"
        else
            echo "${blade} is not reachable"
        fi
    done
}

function check-tcpdump-status {
# check if there's on going tcpdump
    for blade in $PLBLADES
    do
        RES=`ssh $blade "ps -ef | grep tcpdump | grep -v grep"`
        if [ $RES -ne 0]
        then
            echo "There's tcpdump running on ${blade} now!"
            echo "Stop the running tcpdump and try again!"
            exit 3;
        fi
    done
}


function get-host {
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

function start-appl-tcpdump {
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
        ssh $blade "tcpdump -i any host ${TCPDUMP_HOST} -s 0 -w ${DIR}/${DATETIME}-${blade}.pcap" >& /dev/null &
        echo "tcpdump is running on ${blade} now"
    done
    echo
    return 0
}

function stop-tcpdump {
# stop all tcpdump process in PL, might also kill tcpdump process running by someone else, be careful
    for blade in $PLBLADES
    do
        ssh $blade "pkill tcpdump" >& /dev/null
        echo "Tcpdump stopped on ${blade}!"
    done
    return 0
}

get-host
start-appl-tcpdump

echo
echo "Press ENTER key to stop tcpdump"
echo
read A
echo "Tcpdump will stop 3 seconds later!"
sleep 3

stop-tcpdump
sleep 1

echo
echo "Result Pcap Files:"
echo $DIR
cd $DIR
for blade in $PLBLADES; do echo `ls -l ${DATETIME}-${blade}.pcap`; done

echo
echo "Done!"
exit 0

######################## fee tcpdump ##################
function start-fee-tcpdump{
# take fee tcpdump
    for pl in $PLBLADES
    do
        ssh $pl > /dev/null 2>&1 << EOF
            for fee in `ip netns list | egrep '(fee)|(FEE)'`
            do
                ip netns exec ${fee} tcpdump -i any -s 0 -w ${DIR}/${pl}-${fee}-${datetime}.pcap > /dev/null &
            done
            exit
EOF
    done
}
