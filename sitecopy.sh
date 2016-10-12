#!/bin/bash

usage() {
  echo "usage: $0 [OPTIONS] user@hostname local-db [remote-db]"
  echo "Options"
  echo "  -u, --user[=name]   run this script under another account."
  echo "  -t, --type[=name]   website type {i.e. wp}."
  echo "  -h, --help          display this help and exit."
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
SITE=""

if [ -d /Applications ] ; then # OS X
  options=$(getopt hu:t: "$@")
else # GNU getopt
  options=$(getopt -o hu:t: -l help,user: -- "$@")
fi

if [ -z "$options" ] ; then
  # something went wrong, getopt will put out an error message for us
  exit 1
fi

eval set -- $options

until [ -z "$1" ] ; do
  case $1 in
    -h|--help) usage ; exit 1 ;;
    -u|--user) USER=$2 ; shift ;;
    -t|--type) SITE=$2 ; shift ;;
    --) shift; break;;
    (-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
    (*) break;;
  esac
  shift
done

if [ "$USER" = "root" ] ; then
  echo "cannot run as root. did you forget to add -u?"
  exit 1
fi

if [ ! "$USER" = "`whoami`" ] ; then
  echo "running $0 as $USER"
  CMD="$SCRIPT $*"
  su $USER -c "echo $CMD"
  exit
fi

SOURCE=$1
DSTDB=$2
SRCDB=$3

if [ -z "$SOURCE" ] ; then
  usage
  exit
fi

cd $HOME
## begin rsync public folder
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


wp_read_config() {
  ( echo "<?php" ; grep DB_ $1 ; cat <<EOF
echo 'SRCDBPASS="' . DB_PASSWORD . '"' . PHP_EOL;
echo 'SRCDBUSER="' . DB_USER . '"' . PHP_EOL;
echo 'SRCDBNAME="' . DB_NAME . '"' . PHP_EOL;
EOF
) | php
}

wp_write_config() {
  echo "modifying wp-config.php"
}

## find database credentials
if [ "$SITE" = "wp" ] ; then
  wpconfig="public/wp-config.php"
  if [ -e $wpconfig ] ; then
    echo "reading credential from $wpconfig"
    eval `wp_read_config $wpconfig`
    echo "name: $SRCDBNAME"
    echo "user: $SRCDBUSER"
  else
    echo "no such file: $wpconfig"
  fi
fi

if [ ! -z "$SRCDB" ] ; then
  [ -z "$SRCDBNAME" ] && SRCDBNAME=$SRCDB
  [ -z "$SRCDBUSER" ] && SRCDBUSER=$SRCDB
fi
if [ -z "$SRCDBPASS" ] && [ ! -z "$SRCDBNAME" ]; then
  echo -n "MySQL Password for $SRCDBNAME:"
  read -s SRCDBPASS
  echo
fi

if [ ! -z "$DSTDB" ] ; then
  [ -z "$DSTDBNAME" ] && DSTDBNAME=$DSTDB
  [ -z "$DSTDBUSER" ] && DSTDBUSER=$DSTDB
fi
if [ -z "$DSTDBPASS" ] && [ ! -z "$DSTDBNAME" ] ; then
  echo -n "MySQL Password for $DSTDBNAME:"
  read -s DSTDBPASS
  echo
fi

## begin copy database
if [ ! -z "$SRCDBNAME" ] ; then
  echo "exporting database $SRCDBUSER/$SRCDBNAME to $SRCDBNAME.sql"
  dbexport $SRCDBNAME $SRCDBUSER $SRCDBPASS $SOURCE
fi
if [ ! -z "$DSTDBNAME" ] ; then
  echo "importing database $DSTDBUSER/$DSTDBNAME from $SRCDBNAME.sql"
  if [ -e $SRCDBNAME.sql ] ; then
    dbimport $DSTDBNAME $DSTDBUSER $DSTDBPASS $SRCDBNAME.sql && rm -f $SRCDBNAME.sql
  fi
fi
