#!/bin/bash

# code errors:
# code 11 - volume isn't running
# code 22 - peer status if failed
# code 33 - one or some nodes is disconnected
# code 44 - volume don't mount 

# get dicovery volume_name if $1 is absent
if [[ -z $1 ]]
then
  JSON='{"data": ['
  SEP=''
  COUNT=0
  for i in `gluster volume list`
  do
    let "COUNT=$COUNT + 1"
    if [[ $COUNT -gt 1 ]]; then SEP=",";fi
    JSON+=$SEP'{"{#VOLUME_NAME}": "'$i'"}'
  done
  
  JSON+="]}"
  
  echo $JSON
  exit 0
fi


# Volume info
VOLUMENAME=$1

if [[ ! `gluster volume info $VOLUMENAME | grep -i "status" | cut -d" " -f2` == "Started" ]]
then
  echo "11"
  exit 0
fi

if [[ ! `gluster peer status | grep -i "(connected)"` ]]
then
  echo "22"
  exit 0
fi

# Poll list
COUNT_LIST=0
COUNT_LIST_NODE=0
for i in `gluster pool list | grep -v UUID | awk '{print $3}'`
do
  let "COUNT_LIST+=$COUNT_LIST + 1"
  if [[ $i == "Connected" ]]
  then
    let "COUNT_LIST_NODE+=$COUNT_LIST_NODE + 1"
  fi
done
if [[ ! $COUNT_LIST -eq $COUNT_LIST_NODE ]]
then
  echo "33"
  exit 0
fi

# Volume mount
if [[ ! `mount | grep "localhost:/$VOLUMENAME"` ]]
then
  echo "44"
  exit 0
fi

# When all right
echo "1"
