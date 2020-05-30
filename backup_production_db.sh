#!/bin/bash

timestamp(){
  date +%Y-%m-%d" "%X,%3N
}

NAMEPROD=$1
if [[ -z $NAMEPROD ]]
then
  echo "$(timestamp)" "Read please nameprod"
  exit 1
fi

START_TIME=$(date +%s)
#check this our server
HOME_PATH=$HOME
CURRENT_DATE=`date +%F`
DB_USER="taxi"
DB_NAME="taxi"
DB_HOST="localhost"
BACKUP_FILE_NAME="$DB_NAME-$CURRENT_DATE.backup"
BACKUP_PATH=$HOME_PATH/_backup
mkdir -p $BACKUP_PATH
# need for zabbix
backup_ok=$HOME/_log/$NAMEPROD"_backup.ok"

KEEP_BACKUP_DAYS=7
BACKUP_TO_REMOVE_DATE=`date +%F --date="$KEEP_BACKUP_DAYS days ago"`
BACKUP_TO_REMOVE_NAME="$DB_NAME-$BACKUP_TO_REMOVE_DATE.backup"
# This uncomment for exclude tables
#EXCLUDE="dn_position_history"

#variables for check yesterday backup
KEEP_BACKUP_YESTERDAY=1
BACKUP_YESTERDAY_DATE=`date +%F --date="$KEEP_BACKUP_YESTERDAY days ago"`
BACKUP_YESTERDAY_NAME="$DB_NAME-$BACKUP_YESTERDAY_DATE.backup"
if [[ -f $BACKUP_PATH/$NAMEPROD"-prod.backup.bz2" ]]
  then
  DUMP_FILE=$BACKUP_PATH/$NAMEPROD"-prod.backup.bz2"
  DUMP_FILE_EDIT=`ls -lt --time-style="+%s" $DUMP_FILE | awk '{print $6}'`
  DATE_AGO=`date -d "30 days ago" +%s`
  DATE_LAST_DUMP=$(( ${DUMP_FILE_EDIT} - ${DATE_AGO} ))
  if [[ $DATE_LAST_DUMP -lt 0 ]]
    then
    LASTDUMP=0
  else
    LASTDUMP=1
  fi
else
  LASTDUMP=0
fi

indicator=$HOME/_log/$NAMEPROD"_backup.start"
log="$HOME/_log/$NAMEPROD"_"`echo $0 | rev | cut -d/ -f1 | cut -c 4- | rev`.log"
logerr="$HOME/_log/$NAMEPROD"_"`echo $0 | rev | cut -d/ -f1 | cut -c 4- | rev`_error.log"
if [[ ! -f $logerr ]]
  then
  touch $logerr
fi
json_log=$HOME/"_log/NAMEPROD.json"
report_list=$HOME/_log/"NAMEPROD_backup_production_db.list"

ERR1=`grep -i -E "failed|error" $logerr || echo "no"`
ERR3=`grep -i "error" $logerr  || echo "no"`

touch $indicator
#generated json
function json_gen {
  if [[ -f $json_log ]]
  then
    if [[ ! `grep $NAMEPROD $json_log` ]]
    then
      sed -i -e 's/]}/,{"{#NAMEPROD}":"'$NAMEPROD'"}]}/' $json_log
    fi
  else
    JSON="{ \"data\":["
    SEP=""

    JSON+=$SEP"{\"{#NAMEPROD}\":\"${NAMEPROD}\"}"
    JSON+="]}"
    echo $JSON > $json_log
  fi
}

if [[ ! -d "$HOME/_log/" ]]
then
  mkdir -p "$HOME/_log/"
fi

#function create report list for zabbix
function create_list {
  echo $NAMEPROD"_name: $NAMEPROD" >> $report_list
  echo $NAMEPROD"_status: $STATUS" >> $report_list
  echo $NAMEPROD"_size: $SIZE" >> $report_list
  echo $NAMEPROD"_databackup: $CURRENT_DATE" >> $report_list
  echo $NAMEPROD"_timeleft: $TIME_LEFT" >> $report_list
  echo $NAMEPROD"_lastbackup: $LASTBACKUP" >> $report_list
  echo $NAMEPROD"_lastdump: $LASTDUMP" >> $report_list
}

function edit_list {
  sed -i "/"$NAMEPROD"_status:/c "$NAMEPROD"_status: $STATUS" $report_list
  sed -i "/"$NAMEPROD"_size:/c "$NAMEPROD"_size: $SIZE" $report_list
  sed -i "/"$NAMEPROD"_databackup:/c "$NAMEPROD"_databackup: $CURRENT_DATE" $report_list
  sed -i "/"$NAMEPROD"_timeleft:/c "$NAMEPROD"_timeleft: $TIME_LEFT" $report_list
  sed -i "/"$NAMEPROD"_lastbackup:/c "$NAMEPROD"_lastbackup: $LASTBACKUP" $report_list
  sed -i "/"$NAMEPROD"_lastdump:/c "$NAMEPROD"_lastdump: $LASTDUMP" $report_list
}

function report_backup {
  if [[ -f $report_list ]]
  then
    if [[ `grep $NAMEPROD $report_list` ]]
    then
      edit_list
    else
      create_list
    fi
  else
    create_list
  fi
}

# check last backup is success
if [[ -f "$log" ]]
then
  if [[ -z `tail -n 4 "$log" | grep -i success` ]]
  then
    # Last backup is failed
    LASTBACKUP=0
  else
    LASTBACKUP=1
  fi
fi

#function check yesterday backup
function add_check_backup {
    if [[ `grep $NAMEPROD $report_list` && ! `grep $NAMEPROD $report_list | grep $1` ]]
    then
      sed -i "/"$NAMEPROD"_lastbackup:/a "$NAMEPROD"_$1: $2" $report_list
    elif [[ `grep $NAMEPROD $report_list` &&  `grep $NAMEPROD $report_list | grep $1` ]]; then
      sed -i "/"$NAMEPROD"_"$1":/c "$NAMEPROD"_"$1": $2" $report_list
    fi
}

add_check_backup "lastdump" $LASTDUMP

function check_old_backup {
  if [[ -f $1 ]]
  then
   add_check_backup $2 "1"
  else
   add_check_backup $2 "0"
  fi
}

#Function for error exit
function errexit {
  failed=$?
  echo "$(timestamp)" "============================="
  if [[ "$failed" == 1 ]]
  then
    echo "$(timestamp)" "||--------WARNING----------||"
    echo "$(timestamp)" "||=====Script=Corrupt======||"
    echo "$(timestamp)" "||=========================||"
    json_gen
    DIFF=$(( $(date +%s) - $START_TIME ))
    SIZE=`du -m $BACKUP_PATH/$BACKUP_FILE_NAME | awk '{print $1}'`
    TIME_LEFT=$DIFF
    STATUS=0
    CURRENT_DATE=`date +%F`
    report_backup
    rm $indicator
    chmod 644 $json_log $report_list
  else
    echo "$(timestamp)" "||--------SUCCESS-----------||"
    echo "$(timestamp)" "||=====Script=Complete======||"
  fi
  echo "$(timestamp)" "============================="
}

trap "errexit" EXIT >> $log

#check error sql + user psql
function err_mesg {
  if [[ ! -z "${1}" && $2 != "user" ]]
  then
    if [[ ! -z `echo "$(timestamp)" $1 | grep -E "$2"` ]]
    then
      echo "$(timestamp)" " "
      echo "$(timestamp)" "========================"
      echo "$(timestamp)" "||| || | Error |  || |||"
      echo "$(timestamp)" "========================"
      echo "$(timestamp)" "Production backup is failed"
      echo "$(timestamp)" "$3"
      echo "$(timestamp)" "========================"
      exit 1
    fi
  fi
}

umask 077

echo "$(timestamp)" "======"
echo "$(timestamp)" "Backup production db ${CURRENT_DATE}"

# check exist DB $DB_NAME
if [[ -z `timeout 10 psql -h $DB_HOST -U $DB_USER  -c \\\l  -d $DB_NAME | grep $DB_NAME` ]]
then
  echo "$(timestamp)" "Database $DB_NAME does not exist or .pgpass is corrupt"
  exit 1
fi

if [[ ! -z $EXCLUDE ]]
then
  FULL_EXCLUDE=-T$EXCLUDE*
  num_exclude=`psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "\dt" | grep $EXCLUDE -c `
else
  FULL_EXCLUDE=''
  num_exclude=0
fi

numtables=`psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "\dt" | tail -n 2 | grep rows | cut -d" " -f1 | cut -c 2-`
# new counts rows if exclude tables
let num_new=$numtables-$num_exclude
pg_dump --verbose -h $DB_HOST -F c -U $DB_USER -f $BACKUP_PATH/$BACKUP_FILE_NAME $FULL_EXCLUDE $DB_NAME > $logerr 2>&1 # this $logerr 2>&1 need for logging pg_dump
numdump=`grep dumping $logerr -c`

err_mesg "$ERR1" "could not connect to server" "Postgres service STOPED" "error.log"
err_mesg "$ERR1" "Error message from server" "Postgres not unexpectedly interrupted his work" "error.log"

if [[ ! $num_new -eq $numdump ]]
then
  echo "$(timestamp)" "backup failed"
  exit 1
fi

echo "$(timestamp)" "Remove old backup $BACKUP_TO_REMOVE_NAME"
rm -f -v $BACKUP_PATH/$BACKUP_TO_REMOVE_NAME

chmod 644 $json_log $report_list
json_gen
DIFF=$(( $(date +%s) - $START_TIME ))
SIZE=`du -m $BACKUP_PATH/$BACKUP_FILE_NAME | awk '{print $1}'`
TIME_LEFT=$DIFF
STATUS=1
CURRENT_DATE=`date +%F`
report_backup
check_old_backup $BACKUP_PATH/$BACKUP_YESTERDAY_NAME yesterdaybackup
echo "$(timestamp)" " "
echo "$(timestamp)" $DIFF
rm $indicator

echo "$(timestamp)" "Backup complete. Script execution time: "`date -d@$DIFF -u +%H:%M:%S`
touch $backup_ok
exit 0
