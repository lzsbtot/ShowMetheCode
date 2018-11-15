#!/bin/bash


if  [ $# -eq 2 ]
  then
    LC_parameter="$1"
    testcase="$2"
  else
    echo "Please give duration(s) and testcase name as input parameter!"
    exit 1;
fi

function mtas_tcpdump {
for blade in `cat /etc/cluster/nodes/payload/*/hostname`; do ssh $blade  -o SendEnv=LC_parameter "timeout '$LC_parameter' tcpdump -i any host \(172.17.110.224 or 172.17.110.188 or 172.17.147.28 or 172.17.110.225 or 172.17.147.60 or 172.17.147.92 or 172.17.147.61 or 172.17.147.62 or 172.17.147.93 or 172.17.147.94\) -w /cluster/E2E_tcpdump/tmp/capture/$blade.pcap" & done
}

function cpfile {
for file in `ls`; do cp $file ../"$testcase"_"$file"; done
}

#function transfer {
#transfer all tcpdump files to external location
#tbd
#}

mtas_tcpdump

sleep $1
sleep 5

cd /cluster/E2E_tcpdump/tmp/capture
cpfile

#transfer

echo "Done!"