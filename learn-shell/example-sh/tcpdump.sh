#!/usr/bin/env bash

#######################################################################################
####   Script to take tcpdump on vmtas, Do NOT use it in commerical environment!    ###
#######################################################################################

function usage {
    echo "Usage:"
    echo "${0} <test-case> [-f|h]"
    echo "    take application level tcpdump by default, without any option parameter"
    echo "    -f | --fee  : take evip fee level tcpdump"
    echo "    -h | --help : help"
}


if  [ $# -eq 2 ]
then
    TC="${1}"
    case ${2} in
    -h | --help)
        usage
        ;;
    -f | --fee)
        OPTION="fee"
        ;;
    *)
        echo "Error: invalid option ${2}"
        usage
        exit 0
        ;;
    esac
elif [ $# -eq 1 ]
then
    TC="${1}"
    OPTION="appl"
else
    usage
    exit 0
fi

echo
echo "Take ${OPTION} tcpdump for test case : ${TC}"
echo

DIR="/cluster/vmtas/${TC}"
DATETIME=`date +"%Y%m%d-T%H%M%S"`
EVIPXML="/storage/system/config/evip-apr9010467/evip.xml"
declare -A map=()


if [ ! -f ${EVIPXML} ]
then
    echo "Error: ${EVIPXML} is not existing! Check the evip.xml directory first!"
    exit 0
fi

if [ ! -d ${DIR} ]
then
    echo "Directory: ${DIR} is not existing, Create it now!"
    mkdir -p ${DIR}
fi

function check-pl-status {
    echo "**********************      PL list     ************************"
    echo "${PL_LIST}"
    echo
    echo "********************   Check PL status    **********************"
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
    echo
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

function start-appl-tcpdump {
    HOST_FILTER=`cat ${EVIPXML}| grep "vip address" | awk -F "[\"\"]" '{print $2}' | sed ':a;N;s/\n/ or /;ba'`
    echo "*****************    start capturing now    ********************"
    for pl in ${PL_LIST}
    do
        RESF="${DIR}/${TC}-${DATETIME}-${OPTION}-${pl}.pcap"
        ssh -t -t ${pl} "tcpdump -i any host \\(${HOST_FILTER}\\) -s 0 -w ${RESF}" > /dev/null &
        echo "${OPTION} tcpdump is running on ${pl} now"
    done
    return 0
}

function start-fee-tcpdump {
    echo "*****************    start capturing now    ********************"
    for pl in ${PL_LIST}
    do
        for fee in ${map["${pl}"]}
        do
            RESF="${DIR}/${TC}-${DATETIME}-${OPTION}-${pl}-${fee}.pcap"
            INTERFACE=`ssh ${pl} ip netns exec ${fee} ifconfig | grep eth | awk '{print $1}'`
            ssh -t -t ${pl} "ip netns exec ${fee} tcpdump -i ${INTERFACE} -s 0 -w ${RESF}" > /dev/null &
            echo "${OPTION} tcpdump is running on ${pl} ${fee} now"
            echo
        done
    done 
    return 0
}

function stop-tcpdump {
    PIDS=`ps -ef | grep "${TC}-${DATETIME}-${OPTION}" | grep -v grep | awk '{print $2}'`
    for pid in ${PIDS}
    do
        kill -9 ${pid}
    done
    return 0
}

case ${OPTION} in
appl)
    PL_LIST=`cat ${EVIPXML}| grep 'hostname="PL' | awk -F "[\"\"]" '{print $4}'`
    check-pl-status
    start-appl-tcpdump
    ;;
fee)
    PL_LIST=`cat ${EVIPXML} | grep "<fee " | awk -F "[\"\"]" '{print $2}' | sort -u | sed "s/^/PL-/g"`
    check-pl-status
    fetch-fee-info
    start-fee-tcpdump
    ;;
*)
    echo "Error: Invalid capture option!"
    usage
    exit 0
    ;;
esac

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
ls -l ${DIR}/${TC}-${DATETIME}-${OPTION}*.pcap
echo
echo "*************************** Done! ******************************"
exit 0