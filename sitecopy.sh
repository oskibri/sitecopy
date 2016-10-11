#!/bin/bash

usage() {
  echo "usage: $0 [ options ] user@hostname [dbname]"
}

abspath() {
  echo $(cd "$(dirname $1)" ;pwd -P)
}

dbexport() {
  DBNAME=$1
  DBUSER=$2
  DBPASS=$3
  SOURCE=$4
  ssh $SOURCE "mysqldump --password=\"$DBPASS\" -u $DBUSER $DBNAME" > $DBNAME.sql
}

dbimport() {
  DBNAME=$1
  DBUSER=$2
  DBPASS=$3
  DUMP=$4
  mysql -u$DBUSER --password="$DBPASS" $DBNAME < $DUMP
}

AP=`abspath $0`
SCRIPT="$AP/$(basename $0)"
USER=`whoami`
FORCE=0

if ! options=$(getopt -o fhu: -l user:,force -- "$@")
then
    # something went wrong, getopt will put out an error message for us
    exit 1
fi

eval set -- $options

until [ -z "$1" ] ; do
  case $1 in
    -h) usage ; exit 1 ;;
    -f|--force) FORCE=1 ;;
    -u|--user) USER=$2 ; shift ;;
    --) shift; break;;
    (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
    (*) break;;
  esac
  shift
done

if [ ! "$USER" = "`whoami`" ] ; then
  echo "running $0 as $USER"
  CMD="$SCRIPT $*"
  su $USER -c "echo $CMD"
  exit
fi

SOURCE=$1
SRCDB=$2
DSTDB=$3

if [ -z "$SOURCE" ] ; then
  usage
  exit
fi

if [ ! -z "$SRCDB" ] ; then
  SRCDBNAME=$SRCDB
  SRCDBUSER=$SRCDB
  echo -n "MySQL Password for $SRCDBNAME:"
  read -s SRCDBPASS
  echo
fi

if [ ! -z "$DSTDB" ] ; then
  DSTDBNAME=$DSTDB
  DSTDBUSER=$DSTDB
  echo -n "MySQL Password for $DSTDBNAME:"
  read -s DSTDBPASS
  echo
fi

## begin rsync public folder

cd $HOME
echo "copy site from $SOURCE to $PWD"
if [ ! -e ~/.ssh/id_sitecopy ] ; then
  echo "generating new public/private key pair"
  ssh-keygen -N "" -f ~/.ssh/id_sitecopy
fi
echo "adding public key to authorized_keys"
ssh-copy-id -o StrictHostKeyChecking=no -o PreferredAuthentications=password -i ~/.ssh/id_sitecopy "$SOURCE"

if [ -z "$SSH_AGENT_PID" ]; then
  echo "starting local ssh-agent"
  eval `ssh-agent -s`
fi
ssh-add ~/.ssh/id_sitecopy

echo "copying public folder from $SOURCE"
rsync --delete -rauve ssh $SOURCE:public .

## begin copy database
if [ ! -z "$SRCDBNAME" ] ; then
  echo "exporting database $SRCDBUSER/$SRCDBNAME to $SRCDBNAME.sql"
  dbexport $SRCDBNAME $SRCDBUSER $SRCDBPASS $SOURCE
fi
if [ ! -z "$DSTDBNAME" ] ; then
  echo "importing database $DSTDBUSER/$DSTDBNAME from $SRCDBNAME.sql"
  if [ -e $SRCDBNAME.sql ] ; then
    dbimport $DSTDBNAME $DSTDBUSER $DSTDBPASS $SRCDBNAME.sql
    rm -f $SRCDBNAME.sql
  fi
fi
