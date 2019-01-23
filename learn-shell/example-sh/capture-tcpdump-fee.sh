#!/usr/bin/env bash
#tbe

if  [ $# -eq 1 ]
then
    TC="$1"
    echo
    echo "*************  ${TC}  *************"
    echo
else
    echo "Usage:"
    echo "${0} <test-case>"
    exit 1;
fi

DATETIME=`date +"%Y%m%d-T%H%M%S"`
DIR="/cluster/vmtas/${TC}"
EVIPXML=/storage/system/config/evip-apr9010467/evip.xml
declare -A map=()

if [ -f ${EVIPXML} ]
then
    PL_LIST=`cat ${EVIPXML} | grep "<fee " | awk -F "[\"\"]" '{print $2}' | sort -u | sed "s/^/PL-/g"`
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
            echo "${pl} ------------  OK"
        fi
    done
}

function fetch-fee-info {
    for pl in ${PL_LIST}
    do
        FEE_LIST=`ssh ${pl} ip netns list | grep fee`
        echo "***************** fee running on ${pl}  ********************"
        for fee in ${FEE_LIST}; do echo ${fee}; done
        echo
        map["${pl}"]="${FEE_LIST}"
    done
}

function start-fee-tcpdump {
    for pl in ${PL_LIST}
    do
        for fee in ${map["${pl}"]}
        do
            RESF="${DIR}/${TC}-${DATETIME}-${pl}-${fee}.pcap"
            ssh -t -t ${pl} "ip netns exec ${fee} tcpdump -i any -s 0 -w ${RESF}" > /dev/null &
            echo "tcpdump is running on ${pl}-${fee} now"
        done
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
fetch-fee-info
echo
echo "********************** start capturing *************************"
start-fee-tcpdump
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
ls -l ${DIR}/*${DATETIME}*.pcap
echo
echo "*************************** Done! ******************************"