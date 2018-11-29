#!/bin/bash

if [ ! -n "$1" ]
then
  echo "You must enter a parameter with this script"
  echo "USAGE $1 <Testcase Number>"
  exit
fi

TC=$1
MAINDIR=/cluster/E2E_tcpdump/tmp
DATEANDTIME=`date +"%Y-%m-%d_T%H-%M-%S"`
mkdir -p ${MAINDIR}/${TC}

function fetching_fees {
		ssh $PL "ip netns | grep "fee"" >> ${MAINDIR}/fees.txt
}

function tracing_fees {
		for fee in `cat ${MAINDIR}/fees.txt`
		do
			interface=`ssh $PL ip netns exec $fee ip a | grep eth | head -1 | awk -F":" '{print $2}'`
			echo "tracing on $fee   $interface"
			ssh $PL ip netns exec $fee tcpdump -i $interface -s0 -w ${MAINDIR}/${TC}/${PL}_${fee}_${DATEANDTIME}.pcap >& /dev/null &
		done	
}

for PL in `cat /etc/cluster/nodes/payload/*/hostname`
do
	fetching_fees
	fee_num=`cat ${MAINDIR}/fees.txt | wc -l`
	
	if [ $fee_num != 0 ];then
	
		echo "fee running on $PL"
		echo $PL >> ${MAINDIR}/fee-PLs.txt

		tracing_fees
		echo
	else
		echo "No fee running on $PL"
		echo
	fi
	
	rm -f ${MAINDIR}/fees.txt
done
	
echo
echo "Press ENTER key to stop tracing"
echo
read A
echo "Delay 10 sec"
sleep 10

for PL in `cat ${MAINDIR}/fee-PLs.txt`
do
	echo "stopping tcpdump on $PL"
	ssh $PL ps -ef | grep -i tcpdump | awk '{print$2}' | ssh $PL xargs -i kill -9 '{}'
done

rm -f ${MAINDIR}/fee-PLs.txt

echo
echo "+-----------------------------------------------+"
echo "|         Logging Stopped!           |"
echo "+-----------------------------------------------+"
echo
echo "Be aware of the disc-space! Cleanup when ready!"
echo
