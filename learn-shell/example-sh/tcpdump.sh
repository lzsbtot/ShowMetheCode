#!/usr/bin/env bash

usage="Script to capture the tcpdump.

    $(basename "$0") [-h] -c [CASE] -t [TYPE]

    where:
        -h  Show this help text
        -c  test case name
        -t  capture type: 
                appl        application level tcpdump
                fee         evip fee tcpdump
                all         appl and fee"

optFlag=0
while getopts ':ht:c:' option;
do
    case "$option" in
        h) echo "$usage"
           exit
           ;;
        c) if [ -n $OPTARG ]
           then
                TC=$OPTARG
                (( optFlag++ ))
           else
                printf "ERROR: TEST CASE name can not be empty!" >&2
                echo "$usage" >&2
                exit 1
           fi
           ;;
        t) case $OPTARG in
                appl|fee|all) TYPE=$OPTARG
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
        \?) printf "ERROR: Illegal option: -%s\n" "$OPTARG" >&2
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

DATETIME=`date +"%Y%m%d-T%H%M%S"`
BASE_RES="/cluster/home/${DATETIME}-${TC}"
PL_LIST=`cluster config -p | grep "payload PL" | awk '{print $4}'`
HOST_IP=`cluster config -p | grep "host all" | awk '{print $3}' | xargs |sed 's/ / or /g'`

function start-appl-tcpdump {
    for pl in ${PL_LIST}
    do
        ssh -t -t -f ${pl} tcpdump -i any host ${HOST_IP} -s 0 -w ${BASE_RES}-${pl}.pcap < /dev/null > /dev/null 2>&1
        echo "capture appl tcpdump on ${pl}"
    done
}

function start-fee-tcpdump {
    declare -A map=()
    for pl in ${PL_LIST}
    do
        FEE_LIST=`ssh ${pl} ip netns list | grep -i fee`
        if [ "${FEE_LIST}" ]
        then
            map["${pl}"]="${FEE_LIST}"
            for fee in ${map["${pl}"]}
            do
                INTERFACE=`ssh ${pl} ip netns exec ${fee} ifconfig | grep eth | awk '{print $1}'`
                ssh -t -t -f ${pl} "ip netns exec ${fee} tcpdump -i ${INTERFACE} -s 0 -w ${BASE_RES}-fee-${pl}-${fee}.pcap" < /dev/null > /dev/null 2>&1
                echo "capture fee tcpdump on ${pl} : ${fee}"
            done
        fi
    done
}

case ${TYPE} in
    appl)
        start-appl-tcpdump
        ;;
    fee)
        start-fee-tcpdump
        ;;
    all)
        start-appl-tcpdump
        echo
        start-fee-tcpdump
        ;;
    *)
        echo "$usage" >&2
        exit 1
        ;;
esac

while :
do
    read -n1 -p "Press [q/Q] to stop capturing:" KEY
    case ${KEY} in
        q|Q)
            echo -e "\n\ntcpdump will stop now!"
            ps -ef | grep "${BASE_RES}" | grep -v grep | awk '{print $2}' | xargs kill -9
            break
            ;;
        *)
            echo
            continue
            ;;
    esac
done

echo -e "\nCompress Result pcap files:"
tar -zcvf ${BASE_RES}.tar.gz `ls ${BASE_RES}*.pcap` --remove-files 2>/dev/null
echo -e "\nDownload your result file from here:"
ls -lh ${BASE_RES}.tar.gz
echo "*************************** Done! ******************************"
exit 0