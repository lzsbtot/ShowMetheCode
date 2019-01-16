#!/bin/bash

if  [ $# -eq 1 ]
then
    TC="$1"
    echo
    echo "****************************************************************"
    echo
    echo "Taking tcpdump for test case : ${TC}"
else
    echo "Usage:"
    echo "./capture-tcpdump.sh <test-case>"
    exit 1;
fi

DATETIME=`date +"%Y%m%d-T%H%M%S"`
DIR="/cluster/vmtas/${TC}"

EVIPXML="/storage/system/config/evip-apr9010467/evip.xml"

if [ -f ${EVIPXML} ]
then
    PLBLADES=`cat ${EVIPXML}| grep 'hostname="PL' | awk -F "[\"\"]" '{print $4}'`
    TRAFFICIP=`cat ${EVIPXML}| grep "vip address" | awk -F "[\"\"]" '{print $2}'`
else
    echo "Error: ${EVIPXML} is not existing! Check the evip.xml directory first!"
    exit 2;
fi

if [ ! -d ${DIR} ]
then
    echo "Directory: ${DIR} is not existing, Create it now!"
    mkdir -p ${DIR}
fi

echo
echo "****************************************************************"
echo

echo "tcpdump filter IP:"
for ip in ${TRAFFICIP}
do
    echo ${ip}
done
echo
echo "****************************************************************"
echo

function get-host {
    TCPDUMP_HOST=""
    for ip in ${TRAFFICIP}
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

function check-pl-status {
    echo "Current PL list:"
    echo "${PLBLADES}"
    echo
    echo "****************************************************************"
    echo
    echo "Checking if each PL blade is reachable"
    for blade in ${PLBLADES}
    do
        ssh ${blade} "exit" > /dev/null
        if [ $? -ne 0 ]
        then
            echo "${blade} is not reachable now, remove it from capture list. "
            echo "Please check if ${blade} status is expected"
            PLBLADES=`echo ${PLBLADES} | sed "s/${blade}//g"`
        else
            echo "${blade} ------------reachable"
        fi
    done
}

function start-appl-tcpdump {
    for blade in ${PLBLADES}
    do
        RESF="${DIR}/${TC}-${DATETIME}-${blade}.pcap"
        ssh -t -t ${blade} "tcpdump -i any host ${TCPDUMP_HOST} -s 0 -w ${RESF}" > /dev/null &
        echo "tcpdump is running on ${blade} now"
    done
    return 0
}

function stop-tcpdump {
    PIDS=`ps -ef | grep "${TC}-${DATETIME}" | grep -v grep | awk '{print $2}'`
    for pid in ${PIDS}
    do
        kill -9 ${pid}
    done
    return 0
}


get-host

check-pl-status
echo
echo "****************************************************************"
echo
start-appl-tcpdump
echo
echo "****************************************************************"
echo

while :
do
    read -n1 -p "Press [q/Q] to stop capturing tcpdump:" KEY
    case ${KEY} in
    q | Q)
        echo
        echo "Tcpdump will stop now!"
        stop-tcpdump
        sleep 1
        break
    ;;
    *)
        echo
        continue
    ;;
    esac
done

echo
echo "****************************************************************"
echo
echo "Result pcap files:"
ls -l ${DIR}/${TC}-${DATETIME}*.pcap
echo
echo "*************************** Done! ******************************"