#!/bin/bash

#check this our server
log="$HOME/log/"$1"_backup.log"

script_name=`echo $0 | rev | cut -d"/" -f1 | rev `

if [[ ! -d "$HOME/log/" ]]
then
  mkdir -p "$HOME/log/"
fi
logerr="$HOME/log/"$1"_backup_error.log"

exec 2>$logerr

# check last backup is success
if [[ -f "$log" ]]
then
  if [[ -z `tail -n 4 "$log" | grep -i success` ]]
  then
    echo "===="
    echo "Last backup is failed"
    echo " "
  fi
fi


function errexit {
  failed=$?
  echo "============================="
  if [[ "$failed" != 0 ]]
  then
    echo "||--------WARNING----------||"
    echo "||=====Script=Corrupt======||"
    echo "||send message administator||"
    if [[ -f "/etc/Muttrc" ]]
    then
      if [[ $failed > 1 ]]
      then
        mesg="details in $logerr and $log"
      fi
      if [[ ! $mesg ]]
      then
        echo "mesg empty"
        mesg=`ssh $REMOTE_HOST -C "cat /var/lib/sherlock-agent/error.agent"`
        echo $mesg
      fi
      echo "Script failed on $DEPLOYMENT_ID NNN  $mesg " | sed 's/NNN/\n/g' | mutt -s "The script $script_name failed on $DEPLOYMENT_ID host" sherlock-exceptions@haulmont.com
    fi
  else
    echo "||--------SUCCESS-----------||"
    echo "||=====Script=Complete======||"
  fi
  echo "============================="
}

trap "errexit" EXIT >> $log

# func for detected loop
function looped {
  if [[ $1 == $2 ]]
  then
    echo " "
    echo "Loop detected in $SQL_FOLDER/cleanup.sql"
    mesg=`echo "Loop detected in $SQL_FOLDER/cleanup.sql"`
    echo " "
    echo "Drop temp db $TEST_DB_NAME"
    echo "DROP DATABASE $TEST_DB_NAME;" | psql -h localhost -U root -d postgres
    echo "======Failed========="
    #failed=1
    exit 1
  fi
}

DEPLOYMENT_ID=$1
if [ -z "$DEPLOYMENT_ID" ]; then
    echo "Deployment ID is not specified"
    exit 1
fi

TEMP_DIR="/tmp"
START_TIME=$(date +%s)

TEST_DB_NAME="$1_prod_copy"
DB_FILE="$DEPLOYMENT_ID-prod.backup.bz2"
SHA_BACKUP="$DB_FILE"".shasum"
USE_SHERLOCK_AGENT=yes

DUMP_FILE="_backup/$DB_FILE"

case "$DEPLOYMENT_ID" in
  angola)
    REMOTE_HOST=angola-app1
    ;;
  beirut)
    REMOTE_HOST=beirut-app1
    ;;
  cambridge)
    REMOTE_HOST=cambridge-app1
    ;;
  carasap)
    REMOTE_HOST=carasap-app1
    ;;
  coventry)
    REMOTE_HOST=coventry-app1
    ;;
  miiles)
    REMOTE_HOST=miiles-app1
    ;;
  luxecars)
    REMOTE_HOST=miiles-app1
    ;;
  bizcab)
    REMOTE_HOST=miiles-app1
    ;;
  pewin)
    REMOTE_HOST=pewin-app1
    ;;
  smartcars)
    REMOTE_HOST=smartcars-app1
    ;;
  hansom)
    REMOTE_HOST=hansom-app1
    ;;
  africab)
    REMOTE_HOST=africab-app1
    ;;
  morocco)
    REMOTE_HOST=morocco-app1
    ;;
  electric)
    REMOTE_HOST=electric-app1
    ;;
  westquay)
    REMOTE_HOST=westquay-prod
    ;;
  mycar)
    REMOTE_HOST=mycar-app1
    ;;
  drivr)
    REMOTE_HOST=westquay-prod
    ;;
  eurekar)
    REMOTE_HOST=westquay-prod
    ;;
  priorycars)
    REMOTE_HOST=westquay-prod
    ;;
  bev)
    REMOTE_HOST=bev-app1
    ;;
  onetouch)
    REMOTE_HOST=onetouch-app1
    ;;
  streamline)
    REMOTE_HOST=streamline
    ;;
  flash)
    REMOTE_HOST=electric-app1
    ;;
  sixt)
    REMOTE_HOST=sixt-app1
    ;;
  greencabs)
    REMOTE_HOST=greencabs-app1
    ;;
  portdouglas)
    REMOTE_HOST=portdouglas-app1
    ;;
  leadercabs)
    REMOTE_HOST=leadercabs-app1
    ;;
  cloudcars)
    REMOTE_HOST=electric-app1
    ;;
  *)
    echo "Unknown deployment ID"
    mesg="Unknown deployment ID: $DEPLOYMENT_ID"
    exit 1;
esac

timestamp()
{
 date '+%Y-%m-%d %H:%M:%S'
}

# check connect host
ssh -q $REMOTE_HOST exit
if [[ $? != 0 ]]
then
  echo "Connect is false"
  mesg='Host '$REMOTE_HOST' is not available'
  exit 1
fi

#files existence check function
function fileExist {
  if ssh -q $REMOTE_HOST '[ ! -f '$1' ]'
  then
     mesg="File $1 does not exist on host $REMOTE_HOST"
     exit 1
  else
    if ssh -q $REMOTE_HOST '[ ! -f '$1".shasum"' ]'
    then
      #ssh $REMOTE_HOST 'shasum '$1' | cut -d" " -f1 > '$1'."shasum"'
      mesg="SHASUM $1 is does not exist. $1.shasum not found"
      exit 1
    fi
  fi
}

set -e

function shaDump {
SHA=`shasum "$TEMP_DIR/$DB_FILE" | cut -d" " -f1`
if [[ ! "$SHA" == `cat $TEMP_DIR/$SHA_BACKUP` ]]
then
  echo "backup is corrupted"
  echo "SHASUM not Right"
  mesg="SHASUM not right from $TEMP_DIR/$DB_FILE"
  exit 1
fi
}

echo ''
echo "$(timestamp) get-prod-dump.sh started"
echo "$(timestamp) Download dump from production server"
if [ "$USE_SHERLOCK_AGENT" == "yes" ]; then
    echo "$(timestamp) Using sherlock-agent user"
    ssh $REMOTE_HOST "sudo /usr/local/bin/sh-take-dump-for-testing.sh $DEPLOYMENT_ID"
    fileExist $DEPLOYMENT_ID/$DB_FILE
    scp -v $REMOTE_HOST:$DEPLOYMENT_ID/\{$DB_FILE,$SHA_BACKUP\} "$TEMP_DIR/"
    shaDump
    ssh $REMOTE_HOST "rm -rf -v $DEPLOYMENT_ID/*"
else
    fileExist $DB_FILE
    echo "$(timestamp) Using standard user"
    scp -v $REMOTE_HOST:$DUMP_FILE "$TEMP_DIR/$DB_FILE"
fi

# check exist DB $TEST_DB_NAME
if [[ ! -z `psql -h localhost -U root  -c \\\l  -d postgres | grep $TEST_DB_NAME` ]]
then
  echo "Database $TEST_DB_NAME is exist"
  echo "Drop temp db $TEST_DB_NAME"
  echo "DROP DATABASE $TEST_DB_NAME;" | psql -h localhost -U root -d postgres
fi

echo "$(timestamp) Create temp db $TEST_DB_NAME"
echo "CREATE DATABASE $TEST_DB_NAME OWNER root ENCODING 'UTF8';" | psql -h localhost -U root -d postgres

PSQL="psql -h localhost -U root -d $TEST_DB_NAME"
SQL_FOLDER=$HOME/git/test-dumps/sql

echo "$(timestamp) Restore to temp database"
bzcat $TEMP_DIR/$DB_FILE | $PSQL --quiet --echo-errors

# check sql
function sqlscript {
  # $1 - path to sql script
  cat $1 | $PSQL
  set +e
  ERR1=`grep -i -E "ошибка|error" $logerr | grep -v "echo-errors" | grep -E 'does not exist|не существует'`
  set -e
  if [[ ! -z $ERR1 ]]
  then
    echo " "
    echo "Error in file $1 $ERR1"
    mesg=`echo "Error in file $1 $ERR1 __ Line error $linerr" `
    echo " "
    exit 1
  fi
}

echo "$(timestamp) Set date dump now"
sqlscript $SQL_FOLDER/point_date_dump.sql

echo "$(timestamp) Remove original dump file"
rm -v $TEMP_DIR/$DB_FILE


echo "$(timestamp) Clear pricing tables"
sqlscript $SQL_FOLDER/clear-pricing.sql

echo "$(timestamp) Minimize dockets count"
lenerr=$LINENO
sqlscript $SQL_FOLDER/create-temp-table.sql

rowsCount=`$PSQL -t -c "select count(*) from taxi_docket"`
countWhile=$rowsCount
echo "$(timestamp) Current docket count: $rowsCount"
while [ $rowsCount -gt 200000 ]
do
  sqlscript $SQL_FOLDER/cleanup.sql
  rowsCount=`$PSQL -t -c "select count(*) from taxi_docket"`
  looped $countWhile $rowsCount
  echo "$(timestamp) Current docket count: $rowsCount"
done

rowsCount=`$PSQL -t -c "select count(*) from taxi_passenger_survey"`
countWhile=$rowsCount
echo "$(timestamp) Current survey count: $rowsCount"
while [ $rowsCount -gt 200000 ]
do
  sqlscript $SQL_FOLDER/cleanup_survey.sql
  rowsCount=`$PSQL -t -c "select count(*) from taxi_passenger_survey"`
  looped $countWhile $rowsCount
  echo "$(timestamp) Current survey count: $rowsCount"
done

echo "$(timestamp) Clear other large tables"
sqlscript $SQL_FOLDER/clear-other-large-tables.sql

echo "$(timestamp) Shield sensitive data"
sqlscript $SQL_FOLDER/obfuscate.sql
echo "$(timestamp) Running generated shielding scripts"

sqlvar="/home/haulmont/git/production-env-scripts -type f -name productionEnvironmentScript.sql"
if [[ -z `/usr/bin/find $sqlvar` ]]
then
  mesg="Does not exist productionEnvironmentScript.sql"
  exit 1
fi

/usr/bin/find $sqlvar | while read script
  do
    echo "$(timestamp) Running $script"
    sqlscript $script
  done

echo "$(timestamp) Clear file descriptor links"
sqlscript $SQL_FOLDER/clear_file_descriptor_links.sql

echo "$(timestamp) Drop old dn_xxx_history partitions"
sqlscript $SQL_FOLDER/drop_old_dn_history.sql

echo "$(timestamp) Drop temporary data structures"
sqlscript $SQL_FOLDER/drop_temp_structures.sql

CLEAN_DUMP_FILE=/home/haulmont/clean_dumps/$DEPLOYMENT_ID.bz2
echo "$(timestamp) Dump db to $CLEAN_DUMP_FILE"
pg_dump -h localhost -Fp -U root $TEST_DB_NAME | bzip2 > $CLEAN_DUMP_FILE

echo "$(timestamp) Drop temp db $TEST_DB_NAME"
echo "DROP DATABASE $TEST_DB_NAME;" | psql -h localhost -U root -d postgres

DIFF=$(( $(date +%s) - $START_TIME ))
echo "Script execution time: $DIFF sec"
echo "$(timestamp) get-prod-dump.sh finished"

exit 0
