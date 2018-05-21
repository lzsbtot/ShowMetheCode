#!/bin/bash
# get some informatio
if [  -n "$1" ]
then
    LOG_FILE=$1
else
    LOG_FILE="default.log"
fi

COMMAND_LIST="date who uptime"

for command in $COMMAND_LIST
do
    echo "the output of $command is :" >> $LOG_FILE
    $command >> $LOG_FILE
    echo >> $LOG_FILE
done