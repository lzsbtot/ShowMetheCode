#!/usr/bin/env bash

usage="Script to capture the tcpdump.

$(basename "$0") [-h] -c [CASE] -t [TYPE]

where:
    -h  Show this help text
    -c  test case name
    -t  capture type: application level tcpdump(appl) or fee tcpdump(fee)"

optFlag=0
while getopts ':ht:c:' option; do
  case "$option" in
    h) echo "$usage"
       exit
       ;;
    c) if [ -n $OPTARG ]
       then
           TC=$OPTARG
           (( optFlag++ ))
       else
           printf "ERROR: CASE name can not be empty!" >&2
           echo "$usage" >&2
           exit 1
       fi
       ;;
    t) case $OPTARG in
         appl|fee) TYPE=$OPTARG
                            (( optFlag++ ))
                            ;;
         *) printf "ERROR: Invalid argument for option -p: %s\n\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
       esac
       ;;
    :) printf "ERROR: Missing argument for -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
   \?) printf "ERROR:  Illegal option: -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
  esac
done
if [ $optFlag -ne 2 ]
then
  echo "ERROR: Missing option/argument. See usage:" >&2
  echo "$usage" >&2
  exit 1
fi

echo
echo "Take ${TYPE} tcpdump for test case : ${TC}"
echo

DIR="/cluster/storage/capture/${TC}"
DATETIME=`date +"%Y%m%d-T%H%M%S"`
PL_LIST=`cluster config -p | grep "payload PL" | awk '{print $4}'`
HOST_FILTER=`cluster config -p | grep "host all" | awk '{print $3}' | sed ':a;N;s/\n/ or /;ba'`

declare -A map=()

if [ ! -d ${DIR} ]
then
    echo "Directory: ${DIR} is not existing, Create it now!"
    mkdir -p ${DIR}
fi

function fetch-fee-info {
    for pl in ${PL_LIST}
    do
        FEE_LIST=`ssh ${pl} ip netns list | grep -i fee`
        if [ "${FEE_LIST}" ]
        then
            echo "***************** fee running on ${pl}  ********************"
            for fee in ${FEE_LIST}; do echo ${fee}; done
            echo
            map["${pl}"]="${FEE_LIST}"
        fi
    done
}

function start-appl-tcpdump {
    echo "*****************    start capturing now    ********************"
    for pl in ${PL_LIST}
    do
        RESF="${DIR}/${DATETIME}-${TC}-${TYPE}-${pl}.pcap"
        ssh -t -t -f ${pl} tcpdump -i any host ${HOST_FILTER} -s 0 -w ${RESF} < /dev/null > /dev/null 2>&1
        echo "${TYPE} tcpdump is running on ${pl} now"
    done
}

function start-fee-tcpdump {
    echo "*****************    start capturing now    ********************"
    for pl in ${!map["${pl}"]}
    do
        for fee in ${map["${pl}"]}
        do
            RESF="${DIR}/${DATETIME}-${TC}-${TYPE}-${pl}-${fee}.pcap"
            INTERFACE=`ssh ${pl} ip netns exec ${fee} ifconfig | grep eth | awk '{print $1}'`
            ssh -t -t -f ${pl} ip netns exec ${fee} tcpdump -i ${INTERFACE} -s 0 -w ${RESF} < /dev/null > /dev/null 2>&1
            echo "${TYPE} tcpdump is running on ${pl} ${fee} now"
            echo
        done
    done 
}

function stop-tcpdump {
    PIDS=`ps -ef | grep "${DATETIME}-${TC}-${TYPE}" | grep -v grep | awk '{print $2}'`
    if [ "${PIDS}" ]
    then
        for pid in ${PIDS}
        do
            kill -9 ${pid}
        done
    else
        echo "Error: PID not found!"
        exit 0
    fi
}

case ${TYPE} in
appl)
    start-appl-tcpdump
    ;;
fee)
    fetch-fee-info
    start-fee-tcpdump
    ;;
*)
    echo "$usage" >&2
    exit 1
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
ls -l ${DIR}/${TC}-${DATETIME}-${TYPE}*.pcap
echo
echo "*************************** Done! ******************************"
exit 0