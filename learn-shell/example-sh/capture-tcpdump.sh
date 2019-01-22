#!/usr/bin/env bash

if  [ $# -eq 1 ]
then
    TC="$1"
    echo
    echo "*************  ${TC}  *************"
    echo
else
    echo "Usage:"
    echo "${0} <test-case>"
    exit 0;
fi

DATETIME=`date +"%Y%m%d-T%H%M%S"`
DIR="/cluster/vmtas/${TC}"
EVIPXML="/storage/system/config/evip-apr9010467/evip.xml"

if [ -f ${EVIPXML} ]
then
    PL_LIST=`cat ${EVIPXML}| grep 'hostname="PL' | awk -F "[\"\"]" '{print $4}'`
    HOST_FILTER=`cat ${EVIPXML}| grep "vip address" | awk -F "[\"\"]" '{print $2}' | sed ':a;N;s/\n/ or /;ba'`
else
    echo "Error: ${EVIPXML} is not existing! Check the evip.xml directory first!"
    exit 0;
fi

if [ ! -d ${DIR} ]
then
    echo "Directory: ${DIR} is not existing, Create it now!"
    echo
    mkdir -p ${DIR}
fi


function check-pl-status {
    echo "**********************      PL list     ************************"
    echo "${PL_LIST}"
    echo
    echo "********************** Check PL status  ************************"
    for pl in ${PL_LIST}
    do
        ssh ${pl} "exit" > /dev/null
        if [ $? -ne 0 ]
        then
            echo "${pl} is not reachable now, remove it from capture list. "
            PL_LIST=`echo ${PL_LIST} | sed "s/${pl}//g"`
        else
            echo "${pl} ------------reachable"
        fi
    done
}

function start-appl-tcpdump {
    for pl in ${PL_LIST}
    do
        RESF="${DIR}/${TC}-${DATETIME}-${pl}.pcap"
        ssh -t -t ${pl} "tcpdump -i any host \\(${HOST_FILTER}\\) -s 0 -w ${RESF}" > /dev/null &
        echo "tcpdump is running on ${pl} now"
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


check-pl-status
echo
echo "********************** start capturing *************************"
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
exit 0