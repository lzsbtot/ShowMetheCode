#!/bin/bash

USAGE="Usage: ${0} [--syslogOnly|-s] (should be run on any of PL-s)"
SYSLOG_TAG="deactivateAppTraceSession"
LOG_DEST=0 # 0: console+syslog, 1: syslogOnly
RESET_APPTRACE_CMD="./reset.sh -f"

function logMsg()
{
   logger -t $SYSLOG_TAG $1
   if [[ $LOG_DEST == 0 ]]
   then
      echo $1
   fi
}

for i in "$@"
do
   case $i in
      -h|--help)
         logMsg "$USAGE"
         exit 0
         ;;
      -s|--syslogOnly)
         LOG_DEST=1
         shift
         ;;
      *)
         logMsg "error: invalid argument '$1'"
         logMsg "$USAGE"
         exit 0
         ;;
   esac
done

HOST_NODE=`hostname`
if ! [[ $HOST_NODE =~ "PL-" ]]
then
   logMsg "Script must be run on the PL-s!"
   exit 0
fi


exit 0