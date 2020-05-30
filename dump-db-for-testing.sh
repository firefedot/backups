#!/bin/bash

timestamp(){
  date +%Y-%m-%d" "%X,%3N
}

if [[ -z "$1" ]]
then
  echo "$(timestamp)" "write name"
  exit 1
fi

DB_NAME='taxi'
DB_USER='taxi'
DB_HOST='localhost'

EXT=$1
HOME_PATH=$HOME
#check this our server
name_prod=$EXT
# EXT=$1 on first line script
START_TIME=$(date +%s)
indicator=$HOME/_log/$name_prod"_dump.start"
BACKUP_FILE_NAME="$EXT-prod.backup.bz2"
BACKUP_NEW_FILE_NAME="$EXT-prod-new.backup.bz2"
BACKUP_PATH=$HOME_PATH/"_backup"
report_list=$HOME/"_log/NAMEPROD_backup_production_db.list"
log="$HOME/_log/$name_prod"_"`echo "$(timestamp)" $0 | rev | cut -d/ -f1 | cut -c 4- | rev`.log"
#json_log=$HOME/_log/$name_prod"_"`echo "$(timestamp)" $0 | rev | cut -d/ -f1 | cut -c 4- | rev`.json
json_log=$HOME/"_log/NAMEPROD.json"
logerr="$HOME/_log/$name_prod"_"`echo "$(timestamp)" $0 | rev | cut -d/ -f1 | cut -c 4- | rev`_error.log"

DATE_MONTH_AGO=`date +%Y_%m --date="month ago"`

if [[ -f $BACKUP_PATH/$name_prod"-prod.backup.bz2" ]]
  then
  DUMP_FILE=$BACKUP_PATH/$name_prod"-prod.backup.bz2"
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

function json_gen {
  if [[ -f $json_log ]]
  then
    if [[ ! `grep $name_prod $json_log` ]]
    then
      sed -i -e 's/]}/,{"{#NAMEPROD}":"'$name_prod'"}]}/' $json_log
    fi
  else
    JSON="{ \"data\":["
    SEP=""

    JSON+=$SEP"{\"{#NAMEPROD}\":\"${NAMEPROD}\"}"
    JSON+="]}"
    echo "$(timestamp)" $JSON > $json_log
  fi
}

#function create report list for zabbix
function create_list {
  echo $name_prod"_name: $name_prod" >> $report_list
  echo $name_prod"_status: " >> $report_list
  echo $name_prod"_size: " >> $report_list
  echo $name_prod"_databackup: " >> $report_list
  echo $name_prod"_timeleft: " >> $report_list
  echo $name_prod"_lastbackup: " >> $report_list
  echo $name_prod"_lastdump: $LASTDUMP" >> $report_list
  echo $name_prod"_dumpstatus: $STATUS" >> $report_list
  echo $name_prod"_dumpsize: $SIZE" >> $report_list
  echo $name_prod"_dumpdata: $CURRENT_DATE" >> $report_list
  echo $name_prod"_dumptime: $TIME_LEFT" >> $report_list
}

function edit_list {
  sed -i "/"$name_prod"_lastdump:/c "$name_prod"_lastdump: $LASTDUMP" $report_list
  sed -i "/"$name_prod"_dumpstatus:/c "$name_prod"_dumpstatus: $STATUS" $report_list
  sed -i "/"$name_prod"_dumpsize:/c "$name_prod"_dumpsize: $SIZE" $report_list
  sed -i "/"$name_prod"_dumpdata:/c "$name_prod"_dumpdata: $CURRENT_DATE" $report_list
  sed -i "/"$name_prod"_dumptime:/c "$name_prod"_dumptime: $TIME_LEFT" $report_list
}

function report_backup {
  if [[ -f $report_list ]]
  then
    if [[ `grep $name_prod $report_list` ]]
    then
      edit_list
    else
      create_list
    fi
  else
    create_list
  fi
}

if [[ ! -d "$HOME/_log/" ]]
then
  mkdir -p "$HOME/_log/"
fi

exec 2>$logerr

function errexit {
  failed=$?
  echo "$(timestamp)" "============================="
  if [[ "$failed" == 1 ]]
  then
    echo "$(timestamp)" "||--------WARNING-----------||"
    echo "$(timestamp)" "||=====Script=Corrupt=======||"
    echo "$(timestamp)" "||==========================||"
    json_gen
    DIFF=$(( $(date +%s) - $START_TIME ))
    SIZE=`du -m $BACKUP_PATH/$BACKUP_FILE_NAME | awk '{print $1}'`
    TIME_LEFT=$DIFF
    STATUS=0
    CURRENT_DATE=`date +%F`
    report_backup
    rm $indicator
  else
    echo "$(timestamp)" "||--------SUCCESS-----------||"
    echo "$(timestamp)" "||=====Script=Complete======||"
  fi
  echo "$(timestamp)" "=============================="
}

trap "errexit" EXIT >> $log

function err_mesg {
  if [[ ! -z "${1}" && $2 != "user" ]]
  then
    if [[ ! -z `echo $1 | grep -E "$2"` ]]
    then
      echo "$(timestamp)" "========================"
      echo "$(timestamp)" "Production backup is failed"
      echo "$(timestamp)" "$3"
      echo "$(timestamp)" "====Backup=Failed========"
      exit 1
    fi
  fi

  if [[ -z ${1} && $2 == "user" ]]
  then
    echo "$(timestamp)" " "
    echo "$(timestamp)" "!!! User $DB_USER non correct !!!"
    echo "$(timestamp)" " "
    mesg="!!! User $DB_USER for DB non correct !!!"
    exit 1
  fi
}

touch $indicator
if [[ ! -d $BACKUP_PATH ]]
then
 mkdir -p $BACKUP_PATH
fi

umask 077
set -e

#check user PSQL in file .pgpass
ERR2=`grep "$DB_USER" ~/.pgpass`
err_mesg "$ERR2" "user"

# check exist DB $DB_NAME
if [[ -z `timeout 10 psql -h $DB_HOST -U $DB_USER  -c \\\l  -d $DB_NAME | grep $DB_NAME` ]]
then
  echo "$(timestamp)" "Database $DB_NAME does not exist or .pgpass is corrupt"
  mesg="Database $DB_NAME does not exist or .pgpass is corrupt"
  exit 1
fi

# get name tables for exclude
for exclude in dn_position_history_ dn_driver_history_ dn_job_history_
do
  EXCLUDE_TABLES+=`psql -h $DB_HOST -U $DB_USER $DB_NAME -c "with dn AS (select tablename from pg_tables where tablename like '$exclude%') select * from dn where tablename not like '$exclude$DATE_MONTH_AGO'" | grep $exclude | sed -e 's/dn/--exclude-table-data="dn/g' -e 's/$/"/g'`
done

echo "$(timestamp)" " "
echo "$(timestamp)" "Backup production db for deployment on test environment $(date '+%Y-%m-%d %H:%M:%S')"
set +e
pg_dump -h $DB_HOST -Fp -U $DB_USER -v --no-owner --no-privileges \
        $EXCLUDE_TABLES --exclude-table-data='sys_sending_attachment' \
        --exclude-table-data='sys_sending_message' \
        --exclude-table-data='sys_entity_snapshot_*' \
        --exclude-table-data='taxi_tracking_event' \
        --exclude-table-data='taxi_customer_log_attr' \
        --exclude-table-data='taxi_transaction_execution_log' \
        --exclude-table-data='cc_credit_card_transaction_log' \
        --exclude-table-data='cc_credit_card_transaction' \
        --exclude-table-data='cc_maintenance_operation' \
        --exclude-table-data='taxi_entity_log_item' \
        --exclude-table-data='taxi_entity_log_attr' \
        --exclude-table-data='taxi_sms_message' $DB_NAME | bzip2 > $BACKUP_PATH/$BACKUP_NEW_FILE_NAME

ERR1=`grep -i -E "failed|error" $logerr`
ERR2=`grep -i -E "server closed" $logerr`

err_mesg "${ERR1}" "could not connect to server" "Postgres service STOPED"
err_mesg "${ERR1}" "закрытие подключения по команде администратора" "Postgres not unexpectedly interrupted his work"
err_mesg "$ERR1" "Error message from server" "Postgres not unexpectedly interrupted his work"
err_mesg "$ERR1" "EOF detected" "Postgres not unexpectedly interrupted his work"
err_mesg "$ERR2" "closed the connection unexpectedly" "Postgres not unexpectedly interrupted his work"
set -e

#del old this files (trash)
rm -f -v $BACKUP_PATH"/"$BACKUP_NEW_FILE_NAME"-"*
rm -f -v $BACKUP_PATH"/rec"*

SIZE=`du -k $BACKUP_PATH/$BACKUP_NEW_FILE_NAME | awk '{print $1}'`
echo "$(timestamp)" "Size "$SIZE
let "newsize=$SIZE - 100"
split -b $newsize"k" $BACKUP_PATH/$BACKUP_NEW_FILE_NAME $BACKUP_PATH/$BACKUP_NEW_FILE_NAME"-"
REC_FILE=`ls $BACKUP_PATH | grep $BACKUP_NEW_FILE_NAME"-" | sort | tail -n 1`
bzip2recover $BACKUP_PATH"/$REC_FILE"
num=`ls $BACKUP_PATH | grep rec[0-9][0-9][0-9][0-9][0-9]*"$EXT" | sort | tail -n 1`

if [[ -z `bzcat $BACKUP_PATH"/$num" | tail -n 4 | grep "database dump complete"` ]]
then
  echo "$(timestamp)" "dump corrupted"
  mesg="Failed backup production db for deployment on test environment"
  exit 1
fi

rm -f -v $BACKUP_PATH/$BACKUP_NEW_FILE_NAME"-"*
rm -f -v $BACKUP_PATH"/rec"*

echo "$(timestamp)" "Remove old backup $BACKUP_FILE_NAME"
rm -f -v $BACKUP_PATH/$BACKUP_FILE_NAME
mv $BACKUP_PATH/{$BACKUP_NEW_FILE_NAME,$BACKUP_FILE_NAME}
shasum $BACKUP_PATH/$BACKUP_FILE_NAME | cut -d" " -f1 > $BACKUP_PATH/$BACKUP_FILE_NAME.shasum

json_gen
DIFF=$(( $(date +%s) - $START_TIME ))
SIZE=`du -m $BACKUP_PATH/$BACKUP_FILE_NAME | awk '{print $1}'`
TIME_LEFT=$DIFF
STATUS=1
CURRENT_DATE=`date +%F`
report_backup

echo "$(timestamp)" " "
echo "$(timestamp)" "Backup Complete"
rm $indicator
echo "$(timestamp)" "Script execution time: $DIFF sec"
exit 0
