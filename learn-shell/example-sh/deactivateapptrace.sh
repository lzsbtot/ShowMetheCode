#!/bin/bash

#################################################################################
# Script to deactivate apptrace session. To be used before an upgrade called    #
# from the upgrade procedure automatically or called manually by the operator.  #
# Should be run on any of the PL-s!                                             #
#                                                                               #
# Script logs to console+syslog by default but can optionally log only to the   #
# syslog of the node it is run on (normally PL-3)                               #
#################################################################################

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

cd /opt/lpmsv/bin/apptrace

RES=`./display_session.sh 2>&1`

if [[ $RES =~ "No session running" || $RES =~ "Session not found" ]]; then
   logMsg "No AppTrace session found. Nothing to be done."
   exit 0
fi

RES=`./stop_trace.sh`

if [[ $RES =~ "stop_trace done" ]]; then
   logMsg "Stop trace OK."
else
   logMsg "Problem stopping trace! ($RES)"
   eval $RESET_APPTRACE_CMD
   exit 0
fi

RES=`timeout 75s ./unload_session.sh`

if [[ $? == 124 ]] #timeout errorCode
then
   logMsg "Timeout for unload session!"
   eval $RESET_APPTRACE_CMD
   exit 0
else
   if [[ $RES =~ "unload_session done" ]]; then
      logMsg "Unload session OK."
   else
      logMsg "Problem unloading session! ($RES)"
      eval $RESET_APPTRACE_CMD
      exit 0
   fi
fi

RES=`./end_session.sh`

if [[ $RES =~ "end_session done" ]]; then
   logMsg "End session OK."
else
   logMsg "Problem ending session! ($RES)"
   eval $RESET_APPTRACE_CMD
   exit 0
fi

exit 0